import 'dart:async';

import 'generated/api/contracts.dart';
import 'generated/api.dart';

/// Shares one native event stream across the UI and the business tool host.
class AgentRustClient {
  AgentRustClient({required this._initialize});

  final Future<AgentCore> Function() _initialize;
  final _events = StreamController<AgentEvent>.broadcast();
  Future<AgentCore>? _initializing;
  AgentCore? _openedCore;
  StreamSubscription<AgentEvent>? _subscription;
  Future<void>? _shutdownFuture;
  bool _closed = false;
  bool _suspended = false;
  Future<void>? _suspending;

  Stream<AgentEvent> get events => _events.stream;
  bool get isInitialized => _openedCore != null;
  // Host callbacks must remain able to return an accepted save while shutdown
  // rejects new UI commands and waits for that save to finish.
  Future<AgentCore> get core {
    final opened = _openedCore;
    return opened == null ? ensureInitialized() : Future.value(opened);
  }

  Future<AgentCore> ensureInitialized() {
    if (_closed || _suspended) {
      return Future.error(StateError('Agent core is closed.'));
    }
    return _initializing ??= _open();
  }

  Future<AgentCore> _open() async {
    try {
      final value = await _initialize();
      _openedCore = value;
      final ready = Completer<void>();
      _subscription = value.watchEvents().listen(
        (event) {
          if (event.kind == EventKind.ready && !ready.isCompleted) {
            ready.complete();
          }
          _events.add(event);
        },
        onError: (Object error, StackTrace stack) {
          if (!ready.isCompleted) ready.completeError(error, stack);
          _events.addError(error, stack);
        },
        onDone: () {
          if (!ready.isCompleted) {
            ready.completeError(StateError('Agent event stream closed.'));
          }
        },
      );
      await ready.future;
      return value;
    } catch (_) {
      _initializing = null;
      _openedCore = null;
      rethrow;
    }
  }

  Future<CommandResult> dispatch(AgentCommand command) async =>
      (await ensureInitialized()).dispatch(command: command);

  Future<QueryResult> query(AgentQuery query) async =>
      (await ensureInitialized()).query(query: query);

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> suspendForDataClear({String? conversationId}) =>
      _suspending ??= _suspendForDataClear(conversationId);

  Future<void> _suspendForDataClear(String? conversationId) async {
    _suspended = true;
    final opening = _initializing;
    try {
      if (opening != null) {
        await (await opening).shutdownForDataClear(
          conversationId: conversationId,
        );
      }
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _openedCore = null;
      _initializing = null;
    }
  }

  void resumeAfterFailedDataClear() {
    if (_closed) return;
    _suspended = false;
    _suspending = null;
  }

  Future<void> _shutdown() async {
    _closed = true;
    await _suspending;
    final opening = _initializing;
    try {
      if (opening != null) await (await opening).shutdown();
    } finally {
      await _subscription?.cancel();
      await _events.close();
      _openedCore = null;
    }
  }
}
