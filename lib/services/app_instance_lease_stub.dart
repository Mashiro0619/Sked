import 'app_instance_lease.dart';

class PlatformAppInstanceLease implements AppInstanceLease {
  var _acquired = false;

  @override
  Future<bool> tryAcquire() async {
    if (_acquired) return true;
    _acquired = true;
    return true;
  }

  @override
  Future<void> release() async {
    _acquired = false;
  }
}
