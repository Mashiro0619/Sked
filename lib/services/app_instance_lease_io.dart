import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_instance_lease.dart';

class PlatformAppInstanceLease extends IoAppInstanceLease {
  PlatformAppInstanceLease();
}

class IoAppInstanceLease implements AppInstanceLease {
  IoAppInstanceLease({
    Future<Directory> Function()? directoryProvider,
    AppInstanceProcessGuard? processGuard,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _processGuard =
           processGuard ??
           (Platform.isAndroid ? const AndroidAppInstanceProcessGuard() : null),
       _processGuardOwnerId = 'lease-${_nextProcessGuardOwnerId++}';

  static const lockFileName = 'Sked_instance.lock';
  static int _nextProcessGuardOwnerId = 0;

  final Future<Directory> Function() _directoryProvider;
  final AppInstanceProcessGuard? _processGuard;
  final String _processGuardOwnerId;
  Future<void> _operationTail = Future<void>.value();
  RandomAccessFile? _handle;
  var _processGuardOwned = false;

  @override
  Future<bool> tryAcquire() => _enqueue(() async {
    if (_handle != null) return true;

    final processGuard = _processGuard;
    if (processGuard != null) {
      final acquired = await processGuard.tryAcquire(_processGuardOwnerId);
      if (!acquired) return false;
      _processGuardOwned = true;
    }

    RandomAccessFile? handle;
    try {
      final directory = await _directoryProvider();
      await directory.create(recursive: true);
      final file = File(path.join(directory.path, lockFileName));
      handle = await file.open(mode: FileMode.append);
      try {
        await handle.lock(FileLock.exclusive, 0, 1);
      } on FileSystemException catch (error) {
        await handle.close();
        handle = null;
        if (_isLockContention(error)) {
          await _releaseProcessGuardIfOwned();
          return false;
        }
        rethrow;
      }
      _handle = handle;
      return true;
    } catch (_) {
      if (handle != null) {
        await handle.close();
      }
      await _releaseProcessGuardIfOwned();
      rethrow;
    }
  });

  @override
  Future<void> release() => _enqueue(() async {
    final handle = _handle;
    if (handle == null) {
      await _releaseProcessGuardIfOwned();
      return;
    }
    _handle = null;
    try {
      await handle.unlock(0, 1);
    } finally {
      try {
        await handle.close();
      } finally {
        await _releaseProcessGuardIfOwned();
      }
    }
  });

  Future<void> _releaseProcessGuardIfOwned() async {
    if (!_processGuardOwned) return;
    _processGuardOwned = false;
    await _processGuard?.release(_processGuardOwnerId);
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationTail.then((_) => action());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  bool _isLockContention(FileSystemException error) {
    final errorCode = error.osError?.errorCode;
    if (Platform.isWindows) return errorCode == 33;
    return errorCode == 11 || errorCode == 13 || errorCode == 35;
  }
}

abstract interface class AppInstanceProcessGuard {
  Future<bool> tryAcquire(String ownerId);

  Future<void> release(String ownerId);
}

class AndroidAppInstanceProcessGuard implements AppInstanceProcessGuard {
  const AndroidAppInstanceProcessGuard();

  static const _channel = MethodChannel('com.mashiro.sked/app_instance_lease');

  @override
  Future<bool> tryAcquire(String ownerId) async {
    final acquired = await _channel.invokeMethod<bool>('tryAcquire', {
      'ownerId': ownerId,
    });
    if (acquired == null) {
      throw StateError('Android app instance lease returned no result.');
    }
    return acquired;
  }

  @override
  Future<void> release(String ownerId) {
    return _channel.invokeMethod<void>('release', {'ownerId': ownerId});
  }
}
