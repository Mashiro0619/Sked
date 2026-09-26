class AppConfig {
  const AppConfig._();

  // Set only by the Microsoft Store build. The product ID is public metadata,
  // not a credential; an empty value keeps the existing GitHub update channel.
  static const microsoftStoreId = String.fromEnvironment(
    'SKED_MICROSOFT_STORE_ID',
  );

  static const updateVersionUrl = String.fromEnvironment(
    'SKED_UPDATE_VERSION_URL',
    defaultValue: '',
  );

  static bool get hasUpdateVersionUrl => updateVersionUrl.trim().isNotEmpty;
}
