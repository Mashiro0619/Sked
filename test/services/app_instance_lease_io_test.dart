import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/app_instance_lease_io.dart';

Future<({Process process, File releaseSignal})> _startHolder(
  Directory directory,
) async {
  final releaseSignal = File(
    '${directory.path}${Platform.pathSeparator}'
    'release-${DateTime.now().microsecondsSinceEpoch}',
  );
  final lockFile = File(
    '${directory.path}${Platform.pathSeparator}'
    '${IoAppInstanceLease.lockFileName}',
  );
  final process = await Process.start(_dartExecutable(), [
    '--packages=${File('.dart_tool/package_config.json').absolute.path}',
    File('test/fixtures/app_instance_lease_holder.dart').absolute.path,
    lockFile.path,
    releaseSignal.path,
  ], workingDirectory: Directory.current.path);
  String firstLine;
  try {
    firstLine = await process.stdout
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    await _terminateProcess(process);
    rethrow;
  }
  if (firstLine != 'acquired') {
    await _terminateProcess(process);
    final error = await process.stderr
        .transform(const SystemEncoding().decoder)
        .join();
    fail('Lease holder did not acquire the lock: $firstLine\n$error');
  }
  return (process: process, releaseSignal: releaseSignal);
}

Future<void> _terminateProcess(Process process) async {
  process.kill();
  try {
    await process.exitCode.timeout(const Duration(seconds: 5));
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode.timeout(const Duration(seconds: 5));
  }
}

String _dartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    fail('FLUTTER_ROOT is required for the lease subprocess test.');
  }
  final separator = Platform.pathSeparator;
  return '$flutterRoot${separator}bin${separator}cache$separator'
      'dart-sdk${separator}bin${separator}dart${Platform.isWindows ? '.exe' : ''}';
}

IoAppInstanceLease _leaseFor(Directory directory) {
  return IoAppInstanceLease(directoryProvider: () async => directory);
}

Future<bool> _tryAcquireAfterProcessExit(
  IoAppInstanceLease lease, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    if (await lease.tryAcquire()) return true;
    // Windows can report a child process exit before its file handle and
    // byte-range lock become available to other processes.
    await Future<void>.delayed(const Duration(milliseconds: 20));
  } while (DateTime.now().isBefore(deadline));
  return false;
}

class _MemoryProcessGuard implements AppInstanceProcessGuard {
  String? ownerId;

  @override
  Future<bool> tryAcquire(String candidateOwnerId) async {
    final current = ownerId;
    if (current != null && current != candidateOwnerId) return false;
    ownerId = candidateOwnerId;
    return true;
  }

  @override
  Future<void> release(String candidateOwnerId) async {
    if (ownerId == candidateOwnerId) ownerId = null;
  }
}

void main() {
  late Directory directory;

  File lockFile() => File(
    '${directory.path}${Platform.pathSeparator}'
    '${IoAppInstanceLease.lockFileName}',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sked-instance-lease-');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('returns quickly while another process owns the lease', () async {
    final holder = await _startHolder(directory);
    try {
      final lease = _leaseFor(directory);
      final stopwatch = Stopwatch()..start();

      expect(await lease.tryAcquire(), isFalse);
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    } finally {
      await holder.releaseSignal.writeAsString('release');
      expect(await holder.process.exitCode, 0);
    }
  });

  test('can acquire after graceful release and process termination', () async {
    final holder = await _startHolder(directory);
    await holder.releaseSignal.writeAsString('release');
    expect(await holder.process.exitCode, 0);

    final lease = _leaseFor(directory);
    expect(await lease.tryAcquire(), isTrue);
    expect(await lease.tryAcquire(), isTrue);
    await lease.release();

    final crashedHolder = await _startHolder(directory);
    expect(crashedHolder.process.kill(), isTrue);
    await crashedHolder.process.exitCode.timeout(const Duration(seconds: 5));

    expect(await _tryAcquireAfterProcessExit(lease), isTrue);
    await lease.release();
  });

  test('propagates directory access failures', () async {
    final lease = IoAppInstanceLease(
      directoryProvider: () => Future<Directory>.error(
        const FileSystemException('directory unavailable'),
      ),
    );

    await expectLater(lease.tryAcquire(), throwsA(isA<FileSystemException>()));
  });

  test('rejects a directory at the instance-lock path', () async {
    await Directory(lockFile().path).create();
    final lease = _leaseFor(directory);

    await expectLater(lease.tryAcquire(), throwsA(isA<FileSystemException>()));
    expect(
      await FileSystemEntity.type(lockFile().path, followLinks: false),
      FileSystemEntityType.directory,
    );
  });

  test('rejects an instance-lock symlink', () async {
    final outsideDirectory = await Directory.systemTemp.createTemp(
      'sked-instance-lock-target-',
    );
    final lease = _leaseFor(directory);
    try {
      final target = File(
        '${outsideDirectory.path}${Platform.pathSeparator}lock',
      );
      await target.writeAsString('outside lock');
      try {
        await Link(lockFile().path).create(target.path);
      } on FileSystemException {
        // Some Windows hosts do not allow unprivileged symlink creation.
        return;
      }

      await expectLater(
        lease.tryAcquire(),
        throwsA(isA<FileSystemException>()),
      );
      expect(await target.readAsString(), 'outside lock');
      expect(
        await FileSystemEntity.type(lockFile().path, followLinks: false),
        FileSystemEntityType.link,
      );
    } finally {
      await lease.release();
      if (await outsideDirectory.exists()) {
        await outsideDirectory.delete(recursive: true);
      }
    }
  });

  test('process guard rejects a second lease in the same process', () async {
    final processGuard = _MemoryProcessGuard();
    final first = IoAppInstanceLease(
      directoryProvider: () async => directory,
      processGuard: processGuard,
    );
    final second = IoAppInstanceLease(
      directoryProvider: () async => directory,
      processGuard: processGuard,
    );

    expect(await first.tryAcquire(), isTrue);
    expect(await second.tryAcquire(), isFalse);

    await first.release();
    expect(await second.tryAcquire(), isTrue);
    await second.release();
  });

  test('releases the process guard when file setup fails', () async {
    final processGuard = _MemoryProcessGuard();
    final failing = IoAppInstanceLease(
      directoryProvider: () => Future<Directory>.error(
        const FileSystemException('directory unavailable'),
      ),
      processGuard: processGuard,
    );
    final next = IoAppInstanceLease(
      directoryProvider: () async => directory,
      processGuard: processGuard,
    );

    await expectLater(
      failing.tryAcquire(),
      throwsA(isA<FileSystemException>()),
    );
    expect(await next.tryAcquire(), isTrue);
    await next.release();
  });
}
