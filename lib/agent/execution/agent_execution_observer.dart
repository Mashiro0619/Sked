import 'dart:async';

import '../bridge/generated/api/execution.dart';
import '../bridge/generated/api/execution_contracts.dart';

/// A listener owns only its native subscription, never the running process.
class AgentExecutionObserver {
  AgentExecutionObserver({
    required ExecutionEventSubscription handle,
    required void Function(ExecutionEvent) onEvent,
    required void Function(Object, StackTrace) onError,
    required this._onClosed,
  }) : _handle = handle {
    void retire() => unawaited(close().catchError(onError));
    try {
      _subscription = handle.watch().listen(
        (event) {
          try {
            onEvent(event);
          } catch (error, stack) {
            try {
              onError(error, stack);
            } finally {
              retire();
            }
          }
        },
        onError: (Object error, StackTrace stack) {
          try {
            onError(error, stack);
          } finally {
            retire();
          }
        },
        onDone: retire,
      );
    } catch (error, stack) {
      (Object, StackTrace)? cleanupFailure;
      for (final release in [handle.close, handle.dispose]) {
        try {
          release();
        } catch (cleanupError, cleanupStack) {
          cleanupFailure ??= (cleanupError, cleanupStack);
        }
      }
      try {
        if (cleanupFailure case final failure?) {
          onError(failure.$1, failure.$2);
        }
      } finally {
        Error.throwWithStackTrace(error, stack);
      }
    }
  }

  final ExecutionEventSubscription _handle;
  final void Function() _onClosed;
  late final StreamSubscription<ExecutionEvent> _subscription;
  final _done = Completer<void>();
  Future<void>? _closing;

  Future<void> get done => _done.future;

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    (Object, StackTrace)? failure;
    // Wake the native watcher before cancelling the Dart stream, including
    // when no further output will arrive from a prepared or stopped process.
    for (final release in <FutureOr<void> Function()>[
      _handle.close,
      _subscription.cancel,
      _handle.dispose,
      _onClosed,
    ]) {
      try {
        await release();
      } catch (error, stack) {
        failure ??= (error, stack);
      }
    }
    _done.complete();
    if (failure case final failure?) {
      Error.throwWithStackTrace(failure.$1, failure.$2);
    }
  }
}
