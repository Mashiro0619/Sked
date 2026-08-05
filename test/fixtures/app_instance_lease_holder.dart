import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('Expected lock and release-signal paths.');
    exitCode = 64;
    return;
  }

  final handle = await File(arguments[0]).open(mode: FileMode.append);
  try {
    await handle.lock(FileLock.exclusive, 0, 1);
    stdout.writeln('acquired');
    final releaseSignal = File(arguments[1]);
    while (!await releaseSignal.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await handle.unlock(0, 1);
  } finally {
    await handle.close();
  }
}
