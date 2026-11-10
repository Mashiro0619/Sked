import 'dart:async';

import 'package:flutter/foundation.dart';

import 'agent_native_ui_state.dart';
import 'generated/api/contracts.dart';
import 'generated/api/ui.dart';
import 'generated/api/ui_contracts.dart' as native_ui;
import 'generated/api.dart';

/// Shares one native event stream across the UI and the business tool host.
class AgentRustClient {
  AgentRustClient({required this._initialize});

  final Future<AgentCore> Function() _initialize;
  final _events = StreamController<AgentEvent>.broadcast();
  final uiContributions = ValueNotifier<AgentNativeUiState>(
    const AgentNativeUiState(),
  );
  Future<AgentCore>? _initializing;
  AgentCore? _openedCore;
  StreamSubscription<AgentEvent>? _subscription;
  StreamSubscription<native_ui.UiContributionSnapshot>? _uiSubscription;
  UiContributionSubscription? _uiHandle;
  Object? _uiToken;
  bool _uiDisposed = false;
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
    AgentCore? openingCore;
    UiContributionSubscription? openingUi;
    StreamSubscription<native_ui.UiContributionSnapshot>? openingUiStream;
    StreamSubscription<AgentEvent>? openingEvents;
    try {
      final value = await _initialize();
      openingCore = value;
      _openedCore = value;
      final token = Object();
      if (!_closed && !_suspended) {
        _uiToken = token;
        uiContributions.value = AgentNativeUiState(sessionToken: token);
      }
      final uiReady = Completer<void>();
      final uiHandle = value.openUiContributions();
      openingUi = uiHandle;
      _uiHandle = uiHandle;
      openingUiStream = uiHandle.watch().listen(
        (snapshot) {
          // Initialization must settle even if shutdown retired the UI while
          // waiting for this first snapshot. It can then close the same core.
          if (!uiReady.isCompleted) uiReady.complete();
          if (identical(_uiToken, token) && identical(_openedCore, value)) {
            uiContributions.value = AgentNativeUiState(
              sessionToken: token,
              snapshot: agentUiSnapshotFromNative(snapshot),
            );
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!uiReady.isCompleted) uiReady.completeError(error, stack);
          if (identical(_uiToken, token)) _retireUi();
        },
        onDone: () {
          if (!uiReady.isCompleted) {
            uiReady.completeError(
              StateError('Agent UI contribution stream closed.'),
            );
          }
          if (identical(_uiToken, token)) _retireUi();
        },
      );
      _uiSubscription = openingUiStream;
      final ready = Completer<void>();
      openingEvents = value.watchEvents().listen(
        (event) {
          if (event.kind == EventKind.ready && !ready.isCompleted) {
            ready.complete();
          }
          if (!_events.isClosed && identical(_openedCore, value)) {
            _events.add(event);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!ready.isCompleted) ready.completeError(error, stack);
          if (!_events.isClosed && identical(_openedCore, value)) {
            _events.addError(error, stack);
          }
        },
        onDone: () {
          if (!ready.isCompleted) {
            ready.completeError(StateError('Agent event stream closed.'));
          }
        },
      );
      _subscription = openingEvents;
      await Future.wait([ready.future, uiReady.future], eagerError: true);
      return value;
    } catch (error, stack) {
      _retireUi();
      await _collectCleanupFailures([
        () => openingUi?.close(),
        () async => openingUiStream?.cancel(),
        () async => openingEvents?.cancel(),
        () async => openingCore?.shutdown(),
      ]);
      if (identical(_uiHandle, openingUi)) _uiHandle = null;
      if (identical(_uiSubscription, openingUiStream)) _uiSubscription = null;
      if (identical(_subscription, openingEvents)) _subscription = null;
      _initializing = null;
      _openedCore = null;
      Error.throwWithStackTrace(error, stack);
    }
  }

  void _retireUi() {
    _uiToken = null;
    if (!_uiDisposed) uiContributions.value = const AgentNativeUiState();
  }

  Future<void> _closeUiSubscription() async {
    final handle = _uiHandle;
    final subscription = _uiSubscription;
    _uiHandle = null;
    _uiSubscription = null;
    await _settleCleanup([
      () => handle?.close(),
      () async => subscription?.cancel(),
    ]);
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
    _retireUi();
    final opening = _initializing;
    await _settleCleanup([
      () async {
        if (opening != null) {
          await (await opening).shutdownForDataClear(
            conversationId: conversationId,
          );
        }
      },
      _closeUiSubscription,
      () async => _subscription?.cancel(),
      () {
        _subscription = null;
        _openedCore = null;
        _initializing = null;
      },
    ]);
  }

  void resumeAfterFailedDataClear() {
    if (_closed) return;
    _suspended = false;
    _suspending = null;
  }

  Future<void> _shutdown() async {
    _closed = true;
    _retireUi();
    final opening = _initializing;
    await _settleCleanup([
      () async => _suspending,
      () async {
        if (opening != null) await (await opening).shutdown();
      },
      _closeUiSubscription,
      () async => _subscription?.cancel(),
      _events.close,
      () {
        _subscription = null;
        _openedCore = null;
        _initializing = null;
        _uiDisposed = true;
        uiContributions.dispose();
      },
    ]);
  }
}

/// Every owner gets its cleanup attempt, even if an earlier listener fails.
/// Return the first failure so callers can retain the primary operation error.
Future<({Object error, StackTrace stack})?> _collectCleanupFailures(
  List<FutureOr<void> Function()> steps,
) async {
  ({Object error, StackTrace stack})? failure;
  for (final step in steps) {
    try {
      await step();
    } catch (error, stack) {
      failure ??= (error: error, stack: stack);
    }
  }
  return failure;
}

Future<void> _settleCleanup(List<FutureOr<void> Function()> steps) async {
  final failure = await _collectCleanupFailures(steps);
  if (failure != null) {
    Error.throwWithStackTrace(failure.error, failure.stack);
  }
}
