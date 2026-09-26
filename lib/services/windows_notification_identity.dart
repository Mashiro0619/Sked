/// Stable fallback AUMID for unpackaged Windows and the sideload package name.
/// Packaged apps (including Store builds) use their OS-provided package identity
/// for toast delivery; do not replace this fallback with a Store package name.
/// The activation GUID remains shared with both MSIX manifests.
abstract final class WindowsNotificationIdentity {
  static const appName = 'Sked';
  static const appUserModelId = 'Mashiro.Sked';
  static const activationGuid = '5d9d8f6a-4d1a-4f3a-9b0a-6a3e7d2c1f58';

  /// The MSIX configuration copies this asset to the package's Images folder.
  /// Unpackaged builds may ignore the URI and use the app identity icon.
  static const iconPath = 'ms-appx:///Images/StoreLogo.png';
}
