bool get desktopFilesSupported => false;
bool get windowsPaths => false;

Future<bool> desktopFileExists(String filePath) async => false;
Future<void> revealDesktopFile(String filePath) async =>
    throw UnsupportedError('Desktop file actions are unavailable.');
Future<void> copyDesktopFile(String source, String destination) async =>
    throw UnsupportedError('Desktop file actions are unavailable.');
