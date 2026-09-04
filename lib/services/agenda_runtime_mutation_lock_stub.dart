Future<T> withPlatformAgendaRuntimeMutationLock<T>(
  Future<T> Function() action,
) => action();
