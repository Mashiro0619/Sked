import 'dart:io';

Future<bool> desktopSourceIsDirectory(String path) async =>
    await FileSystemEntity.type(path, followLinks: true) ==
    FileSystemEntityType.directory;
