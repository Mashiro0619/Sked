import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

const _agendaRuntimeMutationBrokerName =
    'com.mashiro.sked.agenda-runtime-mutation-lock.v1';
const _brokerHandshakeTimeout = Duration(seconds: 2);
const _brokerLeaseHeartbeat = Duration(seconds: 1);
const _brokerLeaseTimeout = Duration(seconds: 4);

var _nextRequestId = 0;

Future<T> withPlatformAgendaRuntimeMutationLock<T>(
  Future<T> Function() action,
) async {
  final processLease = await _acquireProcessLease();
  try {
    return await action();
  } finally {
    processLease.release();
  }
}

/// Acquires the isolate-wide half of the runtime mutation lock.
///
/// Dart's file locks are process-scoped on Android, Linux, and macOS. Two
/// Flutter isolates in the same process can therefore both acquire an
/// exclusive [RandomAccessFile] lock. The name server is shared by the Dart VM
/// and gives every isolate in this process one small broker before the file
/// lock is used to coordinate with other processes.
Future<_AgendaRuntimeMutationProcessLease> _acquireProcessLease() async {
  while (true) {
    final broker = await _lookupOrCreateBroker();
    final reply = ReceivePort();
    final requestId =
        '${pid}_${DateTime.now().microsecondsSinceEpoch}_'
        '${Isolate.current.hashCode}_${reply.sendPort.hashCode}_'
        '${_nextRequestId++}';
    final acknowledged = Completer<void>();
    final granted = Completer<void>();
    late final StreamSubscription<dynamic> subscription;
    subscription = reply.listen((message) {
      if (message is! List<Object?> ||
          message.length != 2 ||
          message[1] != requestId) {
        return;
      }
      switch (message[0]) {
        case _AgendaRuntimeMutationBroker.acknowledged:
          if (!acknowledged.isCompleted) acknowledged.complete();
        case _AgendaRuntimeMutationBroker.granted:
          if (!acknowledged.isCompleted) acknowledged.complete();
          if (!granted.isCompleted) granted.complete();
      }
    });
    broker.send(<Object?>[
      _AgendaRuntimeMutationBroker.acquire,
      requestId,
      reply.sendPort,
    ]);

    try {
      await acknowledged.future.timeout(_brokerHandshakeTimeout);
    } on TimeoutException {
      broker.send(<Object?>[_AgendaRuntimeMutationBroker.cancel, requestId]);
      await subscription.cancel();
      reply.close();
      final registered = IsolateNameServer.lookupPortByName(
        _agendaRuntimeMutationBrokerName,
      );
      if (registered == broker) {
        IsolateNameServer.removePortNameMapping(
          _agendaRuntimeMutationBrokerName,
        );
      }
      continue;
    }

    await granted.future;
    await subscription.cancel();
    reply.close();
    final lease = _AgendaRuntimeMutationProcessLease(broker, requestId);
    lease.startHeartbeat();
    return lease;
  }
}

Future<SendPort> _lookupOrCreateBroker() async {
  while (true) {
    final registered = IsolateNameServer.lookupPortByName(
      _agendaRuntimeMutationBrokerName,
    );
    if (registered != null) return registered;

    final ready = ReceivePort();
    try {
      await Isolate.spawn(
        _runAgendaRuntimeMutationBroker,
        ready.sendPort,
        debugName: 'sked-agenda-runtime-mutation-lock',
      );
      final candidate = await ready.first.timeout(_brokerHandshakeTimeout);
      if (candidate is SendPort) return candidate;
    } finally {
      ready.close();
    }
  }
}

void _runAgendaRuntimeMutationBroker(SendPort ready) {
  final broker = _AgendaRuntimeMutationBroker();
  if (IsolateNameServer.registerPortWithName(
    broker.sendPort,
    _agendaRuntimeMutationBrokerName,
  )) {
    ready.send(broker.sendPort);
    return;
  }
  ready.send(null);
  broker.close();
}

class _AgendaRuntimeMutationProcessLease {
  _AgendaRuntimeMutationProcessLease(this._broker, this._requestId);

  final SendPort _broker;
  final String _requestId;
  var _released = false;
  Timer? _heartbeatTimer;

  void startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_brokerLeaseHeartbeat, (_) {
      if (!_released) {
        _broker.send(<Object?>[
          _AgendaRuntimeMutationBroker.heartbeat,
          _requestId,
        ]);
      }
    });
  }

  void release() {
    if (_released) return;
    _released = true;
    _heartbeatTimer?.cancel();
    _broker.send(<Object?>[_AgendaRuntimeMutationBroker.release, _requestId]);
  }
}

class _AgendaRuntimeMutationBroker {
  _AgendaRuntimeMutationBroker() {
    _commands
      // Keep this dedicated broker alive for the lifetime of the Dart VM. It
      // never executes a mutation itself, so a long synchronous action in a
      // UI or headless isolate cannot prevent another isolate from joining the
      // queue or make the liveness handshake time out.
      ..keepIsolateAlive = true
      ..handler = _handle;
  }

  static const acquire = 'acquire';
  static const cancel = 'cancel';
  static const release = 'release';
  static const heartbeat = 'heartbeat';
  static const acknowledged = 'acknowledged';
  static const granted = 'granted';

  final RawReceivePort _commands = RawReceivePort();
  final Queue<_AgendaRuntimeMutationRequest> _waiting =
      Queue<_AgendaRuntimeMutationRequest>();
  String? _activeRequestId;
  Timer? _leaseTimer;
  bool _granting = false;

  void _startLeaseTimer() {
    _leaseTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final active = _activeRequestId;
      if (active == null) return;
      final request = _activeRequest;
      if (request == null ||
          DateTime.now().difference(request.lastHeartbeat) >
              _brokerLeaseTimeout) {
        _releaseActive(active);
      }
    });
  }

  _AgendaRuntimeMutationRequest? _activeRequest;

  SendPort get sendPort => _commands.sendPort;

  void _handle(dynamic message) {
    if (message is! List<Object?> || message.isEmpty) return;
    _startLeaseTimer();
    switch (message[0]) {
      case acquire:
        if (message.length != 3 ||
            message[1] is! String ||
            message[2] is! SendPort) {
          return;
        }
        final request = _AgendaRuntimeMutationRequest(
          message[1]! as String,
          message[2]! as SendPort,
        );
        request.reply.send(<Object?>[acknowledged, request.id]);
        _waiting.add(request);
        _grantNext();
      case cancel:
        if (message.length != 2 || message[1] is! String) return;
        final requestId = message[1]! as String;
        if (_activeRequestId == requestId) {
          _releaseActive(requestId);
          return;
        }
        _waiting.removeWhere((request) => request.id == requestId);
      case release:
        if (message.length != 2 || message[1] != _activeRequestId) return;
        _releaseActive(message[1]! as String);
      case heartbeat:
        if (message.length != 2 || message[1] != _activeRequestId) return;
        _activeRequest?.lastHeartbeat = DateTime.now();
    }
  }

  void _grantNext() {
    if (_activeRequestId != null || _granting || _waiting.isEmpty) return;
    final request = _waiting.removeFirst();
    _granting = true;
    unawaited(_openAndGrant(request));
  }

  Future<void> _openAndGrant(_AgendaRuntimeMutationRequest request) async {
    RandomAccessFile? lockFile;
    var locked = false;
    try {
      try {
        final path =
            '${Directory.systemTemp.path}${Platform.pathSeparator}'
            'sked_notification_runtime.lock';
        lockFile = await File(path).open(mode: FileMode.append);
        await lockFile.lock(FileLock.blockingExclusive);
        locked = true;
      } catch (_) {
        // A read-only host still gets the process-local queue semantics.
      }
      request.lockFile = lockFile;
      request.locked = locked;
      _activeRequestId = request.id;
      _activeRequest = request;
      request.reply.send(<Object?>[granted, request.id]);
    } catch (_) {
      if (lockFile != null) {
        try {
          if (locked) await lockFile.unlock();
          await lockFile.close();
        } catch (_) {}
      }
      _waiting.addFirst(request);
    } finally {
      _granting = false;
      _grantNext();
    }
  }

  void _releaseActive(String requestId) {
    final active = _activeRequest;
    if (active == null || active.id != requestId) return;
    _activeRequestId = null;
    _activeRequest = null;
    unawaited(_closeLock(active));
    _grantNext();
  }

  Future<void> _closeLock(_AgendaRuntimeMutationRequest request) async {
    final file = request.lockFile;
    if (file == null) return;
    try {
      if (request.locked) await file.unlock();
      await file.close();
    } catch (_) {}
  }

  void close() {
    _commands.close();
  }
}

class _AgendaRuntimeMutationRequest {
  _AgendaRuntimeMutationRequest(this.id, this.reply)
    : lastHeartbeat = DateTime.now();

  final String id;
  final SendPort reply;
  DateTime lastHeartbeat;
  RandomAccessFile? lockFile;
  bool locked = false;
}
