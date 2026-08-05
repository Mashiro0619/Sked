import 'app_instance_lease_stub.dart'
    if (dart.library.io) 'app_instance_lease_io.dart'
    if (dart.library.js_interop) 'app_instance_lease_web.dart';

/// Holds the application's single-writer right for local persistent data.
abstract interface class AppInstanceLease {
  factory AppInstanceLease() = PlatformAppInstanceLease;

  /// Attempts to acquire the lease without waiting for another instance.
  ///
  /// Returns `true` when this object owns the lease. Repeated calls by the
  /// owner are idempotent.
  Future<bool> tryAcquire();

  /// Releases the lease when it is owned by this object.
  Future<void> release();
}
