import 'dart:async';

import 'package:path/path.dart' as path;

import 'agenda_runtime_mutation_lock_stub.dart'
    if (dart.library.io) 'agenda_runtime_mutation_lock_io.dart';

/// An explicit lock file and its deterministic, process-wide broker identity.
///
/// The namespace is derived from the normalized absolute path. A supplied
/// namespace validates configuration received from another isolate; it cannot
/// assign a second broker to the same file. All callers must use the same path
/// rather than filesystem aliases such as symlinks or hard links.
final class AgendaRuntimeMutationLockScope {
  factory AgendaRuntimeMutationLockScope({
    required String lockFilePath,
    String? brokerNamespace,
  }) {
    final context = path.style == path.Style.windows
        ? path.windows
        : path.posix;
    if (!context.isAbsolute(lockFilePath) ||
        (context.style == path.Style.windows &&
            context.isRootRelative(lockFilePath)) ||
        lockFilePath.contains('\u0000')) {
      throw ArgumentError.value(
        lockFilePath,
        'lockFilePath',
        'An absolute file path is required.',
      );
    }
    final normalized = context.normalize(lockFilePath);
    if (context.dirname(normalized) == normalized) {
      throw ArgumentError.value(
        lockFilePath,
        'lockFilePath',
        'A file is required.',
      );
    }
    String identityOf(String value) {
      final normalizedValue = context.normalize(value);
      return context.style == path.Style.windows
          ? normalizedValue.toLowerCase()
          : normalizedValue;
    }

    final identity = identityOf(normalized);
    final defaultPath = platformAgendaRuntimeMutationDefaultLockFilePath;
    final resolvedNamespace =
        defaultPath != null && identity == identityOf(defaultPath)
        ? agendaRuntimeMutationDefaultBrokerNamespace
        : '$agendaRuntimeMutationDefaultBrokerNamespace.scoped.'
              '${Uri.encodeComponent(identity)}';
    if (brokerNamespace != null && brokerNamespace != resolvedNamespace) {
      throw ArgumentError.value(
        brokerNamespace,
        'brokerNamespace',
        'The namespace must match the lock file identity.',
      );
    }
    return AgendaRuntimeMutationLockScope._(normalized, resolvedNamespace);
  }

  const AgendaRuntimeMutationLockScope._(
    this.lockFilePath,
    this.brokerNamespace,
  );

  final String lockFilePath;
  final String brokerNamespace;
}

final Object _agendaRuntimeMutationLockScopeZoneKey = Object();

/// Installs the scope for this body and asynchronous callbacks created by it.
///
/// A spawned isolate must receive the path and namespace and install its own
/// scope. Place Flutter binding initialization and runApp in the same scope.
R withAgendaRuntimeMutationLockScope<R>(
  AgendaRuntimeMutationLockScope scope,
  R Function() body,
) => runZoned(
  body,
  zoneValues: <Object, Object>{_agendaRuntimeMutationLockScopeZoneKey: scope},
);

/// Serializes runtime read-modify-write operations across Flutter isolates.
///
/// The notification action callback and the WorkManager entry point can run in
/// separate isolates while sharing the same SharedPreferences file.  The
/// platform implementation combines a VM-wide isolate broker with a
/// short-lived file lock; web hosts without dart:io use the same API as a
/// no-op.
final Object _agendaRuntimeMutationLockZoneKey = Object();

class _AgendaRuntimeMutationToken {
  _AgendaRuntimeMutationToken(this.identity);

  final String identity;
  var active = true;
}

Future<T> withAgendaRuntimeMutationLock<T>(Future<T> Function() action) {
  final scope =
      Zone.current[_agendaRuntimeMutationLockScopeZoneKey]
          as AgendaRuntimeMutationLockScope?;
  final identity =
      scope?.brokerNamespace ?? agendaRuntimeMutationDefaultBrokerNamespace;
  final inheritedValue = Zone.current[_agendaRuntimeMutationLockZoneKey];
  final inherited = inheritedValue is List<_AgendaRuntimeMutationToken>
      ? inheritedValue
      : const <_AgendaRuntimeMutationToken>[];
  for (final owner in inherited) {
    if (owner.active && owner.identity == identity) return action();
  }
  final token = _AgendaRuntimeMutationToken(identity);
  return withPlatformAgendaRuntimeMutationLock(
    () async {
      try {
        return await runZoned(
          action,
          zoneValues: <Object, Object>{
            _agendaRuntimeMutationLockZoneKey: <_AgendaRuntimeMutationToken>[
              for (final owner in inherited)
                if (owner.active) owner,
              token,
            ],
          },
        );
      } finally {
        // Async callbacks retain their Zone after the outer action completes.
        // Mark the token inactive so a later callback reacquires the platform
        // lock instead of incorrectly treating a released lease as reentrant.
        token.active = false;
      }
    },
    lockFilePath: scope?.lockFilePath,
    brokerNamespace: scope?.brokerNamespace,
  );
}
