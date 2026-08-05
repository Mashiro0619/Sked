import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'app_instance_web_lock.dart';

AppInstanceWebLockRequester createAppInstanceWebLockRequester() =>
    const _BrowserAppInstanceWebLockRequester();

class _BrowserAppInstanceWebLockRequester
    implements AppInstanceWebLockRequester {
  const _BrowserAppInstanceWebLockRequester();

  @override
  Future<AppInstanceWebLock?> tryAcquire(String name) async {
    if (!web.window.navigator.hasProperty('locks'.toJS).toDart) {
      throw UnsupportedError(
        'This browser does not support the Web Locks API.',
      );
    }

    final granted = Completer<_BrowserAppInstanceWebLock?>();
    final releaseSignal = Completer<JSAny?>();
    final callback = ((web.Lock? lock) {
      if (lock == null) {
        granted.complete(null);
        return null;
      }
      final handle = _BrowserAppInstanceWebLock(releaseSignal);
      granted.complete(handle);
      return releaseSignal.future.toJS;
    }).toJS;

    final request = web.window.navigator.locks
        .request(
          name,
          web.LockOptions(mode: 'exclusive', ifAvailable: true),
          callback,
        )
        .toDart;
    unawaited(
      request.then<void>(
        (_) {
          if (!granted.isCompleted) granted.complete(null);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!granted.isCompleted) {
            granted.completeError(error, stackTrace);
          }
        },
      ),
    );

    final handle = await granted.future;
    handle?._attachCompletion(request);
    return handle;
  }
}

class _BrowserAppInstanceWebLock implements AppInstanceWebLock {
  _BrowserAppInstanceWebLock(this._releaseSignal);

  final Completer<JSAny?> _releaseSignal;
  Future<JSAny?>? _completion;

  void _attachCompletion(Future<JSAny?> completion) {
    _completion = completion;
  }

  @override
  Future<void> release() async {
    if (!_releaseSignal.isCompleted) {
      _releaseSignal.complete(null);
    }
    await _completion;
  }
}
