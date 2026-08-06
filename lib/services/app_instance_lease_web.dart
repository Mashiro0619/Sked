import 'dart:async';

import 'app_instance_lease.dart';
import 'app_instance_web_lock.dart';
import 'app_instance_web_lock_stub.dart'
    if (dart.library.js_interop) 'app_instance_web_lock_browser.dart';

class PlatformAppInstanceLease extends WebAppInstanceLease {
  PlatformAppInstanceLease()
    : super(requester: createAppInstanceWebLockRequester());
}

class WebAppInstanceLease implements AppInstanceLease {
  WebAppInstanceLease({
    required this._requester,
    this.lockName = 'com.mashiro.sked.local-data-writer',
  });

  final AppInstanceWebLockRequester _requester;
  final String lockName;
  Future<void> _operationTail = Future<void>.value();
  AppInstanceWebLock? _lock;

  @override
  Future<bool> tryAcquire() => _enqueue(() async {
    if (_lock != null) return true;
    final lock = await _requester.tryAcquire(lockName);
    if (lock == null) return false;
    _lock = lock;
    return true;
  });

  @override
  Future<void> release() => _enqueue(() async {
    final lock = _lock;
    if (lock == null) return;
    _lock = null;
    await lock.release();
  });

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationTail.then((_) => action());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
