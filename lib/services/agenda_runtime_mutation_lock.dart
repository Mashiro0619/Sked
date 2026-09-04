import 'dart:async';

import 'agenda_runtime_mutation_lock_stub.dart'
    if (dart.library.io) 'agenda_runtime_mutation_lock_io.dart';

/// Serializes runtime read-modify-write operations across Flutter isolates.
///
/// The notification action callback and the WorkManager entry point can run in
/// separate isolates while sharing the same SharedPreferences file.  The
/// platform implementation combines a VM-wide isolate broker with a
/// short-lived file lock; web hosts without dart:io use the same API as a
/// no-op.
final Object _agendaRuntimeMutationLockZoneKey = Object();

class _AgendaRuntimeMutationToken {
  var active = true;
}

Future<T> withAgendaRuntimeMutationLock<T>(Future<T> Function() action) {
  final inherited = Zone.current[_agendaRuntimeMutationLockZoneKey];
  if (inherited is _AgendaRuntimeMutationToken && inherited.active) {
    return action();
  }
  final token = _AgendaRuntimeMutationToken();
  return withPlatformAgendaRuntimeMutationLock(() async {
    try {
      return await runZoned(
        action,
        zoneValues: <Object, Object>{_agendaRuntimeMutationLockZoneKey: token},
      );
    } finally {
      // Async callbacks retain their Zone after the outer action completes.
      // Mark the token inactive so a later callback reacquires the platform
      // lock instead of incorrectly treating a released lease as reentrant.
      token.active = false;
    }
  });
}
