import 'dart:io';

Future<bool> desktopSourceIsDirectory(String path) async =>
    path.isNotEmpty &&
    await FileSystemEntity.type(path, followLinks: true) ==
        FileSystemEntityType.directory;
