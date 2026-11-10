import 'dart:io';

import 'package:path/path.dart' as path;

bool get desktopFilesSupported =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
bool get windowsPaths => Platform.isWindows;

Future<bool> desktopFileExists(String filePath) => File(filePath).exists();

Future<void> revealDesktopFile(String filePath) async {
  if (Platform.isWindows) {
    // Each path is a native argument. No command shell interprets filenames.
    await Process.start('explorer.exe', [
      '/select,',
      filePath,
    ], mode: ProcessStartMode.detached);
    return;
  }
  final result = Platform.isMacOS
      ? await Process.run('open', ['-R', filePath])
      : await Process.run('xdg-open', [path.dirname(filePath)]);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'The system could not reveal the file.',
      filePath,
    );
  }
}

Future<void> copyDesktopFile(String source, String destination) async {
  if (await File(destination).exists() &&
      await FileSystemEntity.identical(source, destination)) {
    return;
  }
  await File(source).copy(destination);
}
