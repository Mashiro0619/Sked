import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/app_instance_lease_web.dart';
import 'package:sked/services/app_instance_web_lock.dart';
import 'package:sked/services/app_instance_web_lock_stub.dart'
    if (dart.library.js_interop) 'package:sked/services/app_instance_web_lock_browser.dart';

class _FakeRequester implements AppInstanceWebLockRequester {
  _FakeRequester(this.responses);

  final List<Object?> responses;
  var requestCount = 0;

  @override
  Future<AppInstanceWebLock?> tryAcquire(String name) async {
    requestCount += 1;
    final response = responses.removeAt(0);
    if (response is Future<AppInstanceWebLock?>) return response;
    if (response is Object && response is! AppInstanceWebLock) {
      throw response;
    }
    return response as AppInstanceWebLock?;
  }
}

class _FakeLock implements AppInstanceWebLock {
  var releaseCount = 0;

  @override
  Future<void> release() async {
    releaseCount += 1;
  }
}

void main() {
  test('distinguishes contention from requester failure', () async {
    final requester = _FakeRequester([null, UnsupportedError('unsupported')]);
    final lease = WebAppInstanceLease(requester: requester);

    expect(await lease.tryAcquire(), isFalse);
    await expectLater(lease.tryAcquire(), throwsA(isA<UnsupportedError>()));
  });

  test('keeps an acquired lock until explicit release', () async {
    final lock = _FakeLock();
    final requester = _FakeRequester([lock]);
    final lease = WebAppInstanceLease(requester: requester);

    expect(await lease.tryAcquire(), isTrue);
    expect(await lease.tryAcquire(), isTrue);
    expect(requester.requestCount, 1);

    await lease.release();
    await lease.release();
    expect(lock.releaseCount, 1);
  });

  test('serializes concurrent acquisition and release calls', () async {
    final response = Completer<AppInstanceWebLock?>();
    final lock = _FakeLock();
    final requester = _FakeRequester([response.future]);
    final lease = WebAppInstanceLease(requester: requester);

    final firstAcquire = lease.tryAcquire();
    final secondAcquire = lease.tryAcquire();
    await Future<void>.delayed(Duration.zero);

    expect(requester.requestCount, 1);
    response.complete(lock);
    expect(await Future.wait([firstAcquire, secondAcquire]), [isTrue, isTrue]);
    expect(requester.requestCount, 1);

    await Future.wait([lease.release(), lease.release()]);
    expect(lock.releaseCount, 1);
  });

  test('requester holds an exclusive lock until release', () async {
    final firstRequester = createAppInstanceWebLockRequester();
    final secondRequester = createAppInstanceWebLockRequester();
    const lockName = 'sked-test-exclusive-instance-lease';

    final firstLock = await firstRequester.tryAcquire(lockName);
    expect(firstLock, isNotNull);
    expect(await secondRequester.tryAcquire(lockName), isNull);

    await firstLock!.release();
    final secondLock = await secondRequester.tryAcquire(lockName);
    expect(secondLock, isNotNull);
    await secondLock!.release();
  });
}
