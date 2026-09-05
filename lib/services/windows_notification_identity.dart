/// Stable Windows toast identity shared by the Flutter gateway and MSIX
/// packaging. Changing the AUMID or GUID makes Windows treat the app as a new
/// notification publisher and strands previously scheduled toasts.
abstract final class WindowsNotificationIdentity {
  static const appName = 'Sked';
  static const appUserModelId = 'Mashiro.Sked';
  static const activationGuid = '5d9d8f6a-4d1a-4f3a-9b0a-6a3e7d2c1f58';

  /// The MSIX configuration copies this asset to the package's Images folder.
  /// Unpackaged builds may ignore the URI and use the app identity icon.
  static const iconPath = 'ms-appx:///Images/StoreLogo.png';
}
