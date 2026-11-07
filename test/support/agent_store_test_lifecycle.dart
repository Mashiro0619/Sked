import 'dart:async';

import 'package:sked/agent/store/agent_store.dart';

/// The real close runs outside a widget's FakeAsync zone. Each caller receives
/// its result in its own zone, including errors, while the store closes once.
class TestLifecycleAgentStore extends AgentStore {
  TestLifecycleAgentStore(super.database, {Zone? lifecycleZone})
    : _lifecycleZone = lifecycleZone ?? Zone.current;

  final Zone _lifecycleZone;

  @override
  Future<void> close() {
    final completion = Completer<void>();
    _lifecycleZone.run(() {
      unawaited(
        super.close().then(
          completion.complete,
          onError: completion.completeError,
        ),
      );
    });
    return completion.future;
  }
}
