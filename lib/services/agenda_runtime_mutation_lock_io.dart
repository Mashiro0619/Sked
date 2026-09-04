import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

const _agendaRuntimeMutationBrokerName =
    'com.mashiro.sked.agenda-runtime-mutation-lock.v1';
const _brokerHandshakeTimeout = Duration(seconds: 2);

var _nextRequestId = 0;

Future<T> withPlatformAgendaRuntimeMutationLock<T>(
  Future<T> Function() action,
) async {
  final processLease = await _acquireProcessLease();
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
      // A read-only or restricted host must not make the notification feature
      // unusable. The store still retains its per-isolate queue as a fallback.
      return await action();
    }
    return await action();
  } finally {
    if (lockFile != null) {
      if (locked) {
        try {
          await lockFile.unlock();
        } catch (_) {}
      }
      try {
        await lockFile.close();
      } catch (_) {}
    }
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
    return _AgendaRuntimeMutationProcessLease(broker, requestId);
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

  void release() {
    if (_released) return;
    _released = true;
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
  static const acknowledged = 'acknowledged';
  static const granted = 'granted';

  final RawReceivePort _commands = RawReceivePort();
  final Queue<_AgendaRuntimeMutationRequest> _waiting =
      Queue<_AgendaRuntimeMutationRequest>();
  String? _activeRequestId;

  SendPort get sendPort => _commands.sendPort;

  void _handle(dynamic message) {
    if (message is! List<Object?> || message.isEmpty) return;
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
          _activeRequestId = null;
          _grantNext();
          return;
        }
        _waiting.removeWhere((request) => request.id == requestId);
      case release:
        if (message.length != 2 || message[1] != _activeRequestId) return;
        _activeRequestId = null;
        _grantNext();
    }
  }

  void _grantNext() {
    if (_activeRequestId != null || _waiting.isEmpty) return;
    final request = _waiting.removeFirst();
    _activeRequestId = request.id;
    request.reply.send(<Object?>[granted, request.id]);
  }

  void close() {
    _commands.close();
  }
}

class _AgendaRuntimeMutationRequest {
  const _AgendaRuntimeMutationRequest(this.id, this.reply);

  final String id;
  final SendPort reply;
}
