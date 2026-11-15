import 'dart:io';

import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';

bool get isWindows => Platform.isWindows;
bool get isAndroid => Platform.isAndroid;

class AgentOpenCopy {
  AgentOpenCopy._(this.path, this._directory);

  final String path;
  final Directory _directory;

  Future<void> discard() async => _directory.delete(recursive: true);
}

/// A viewer receives a named copy in the application cache. Android exposes
/// only this directory through its FileProvider; successful copies stay cached.
Future<AgentOpenCopy> prepareOpenCopy(String source, String name) async {
  if (!Platform.isAndroid && !Platform.isWindows) {
    throw UnsupportedError('File viewing copies are unavailable.');
  }
  if (!paths.isAbsolute(source) ||
      name.isEmpty ||
      name == '.' ||
      name == '..' ||
      name.contains(RegExp(r'[/\\\x00]'))) {
    throw ArgumentError('A file requires an absolute path and a file name.');
  }
  final cache = await getTemporaryDirectory();
  final root = Directory(paths.join(cache.path, 'agent-open-files'));
  await root.create(recursive: true);
  final directory = await root.createTemp('open-');
  try {
    final destination = paths.join(directory.path, name);
    await File(source).copy(destination);
    return AgentOpenCopy._(destination, directory);
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
}
