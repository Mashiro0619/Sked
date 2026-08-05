abstract interface class AppInstanceWebLock {
  Future<void> release();
}

abstract interface class AppInstanceWebLockRequester {
  Future<AppInstanceWebLock?> tryAcquire(String name);
}
