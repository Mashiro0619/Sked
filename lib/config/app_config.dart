class AppConfig {
  const AppConfig._();

  static const updateVersionUrl = String.fromEnvironment(
    'SKED_UPDATE_VERSION_URL',
    defaultValue: '',
  );

  static bool get hasUpdateVersionUrl => updateVersionUrl.trim().isNotEmpty;
}
