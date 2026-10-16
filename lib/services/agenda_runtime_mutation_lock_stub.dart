const agendaRuntimeMutationDefaultBrokerNamespace =
    'com.mashiro.sked.agenda-runtime-mutation-lock.v1';
String? get platformAgendaRuntimeMutationDefaultLockFilePath => null;

Future<T> withPlatformAgendaRuntimeMutationLock<T>(
  Future<T> Function() action, {
  String? lockFilePath,
  String? brokerNamespace,
}) => action();
