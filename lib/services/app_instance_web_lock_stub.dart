import 'app_instance_web_lock.dart';

AppInstanceWebLockRequester createAppInstanceWebLockRequester() =>
    _MemoryAppInstanceWebLockRequester();

class _MemoryAppInstanceWebLockRequester
    implements AppInstanceWebLockRequester {
  static final Set<String> _heldLocks = <String>{};

  @override
  Future<AppInstanceWebLock?> tryAcquire(String name) async {
    if (!_heldLocks.add(name)) return null;
    return _MemoryAppInstanceWebLock(name);
  }
}

class _MemoryAppInstanceWebLock implements AppInstanceWebLock {
  _MemoryAppInstanceWebLock(this.name);

  final String name;
  var _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _MemoryAppInstanceWebLockRequester._heldLocks.remove(name);
  }
}
