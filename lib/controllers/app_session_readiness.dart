import 'package:flutter/foundation.dart';

/// Loading readiness and the durable storage gate, independent of UI changes.
@immutable
class AppSessionReadiness {
  const AppSessionReadiness({
    this.isLoaded = false,
    this.isLoading = false,
    this.canWrite = false,
    this.isWriteStateUnknown = false,
  });

  final bool isLoaded;
  final bool isLoading;
  final bool canWrite;
  final bool isWriteStateUnknown;
  bool get isReady => isLoaded && !isLoading;

  @override
  bool operator ==(Object other) =>
      other is AppSessionReadiness &&
      other.isLoaded == isLoaded &&
      other.isLoading == isLoading &&
      other.canWrite == canWrite &&
      other.isWriteStateUnknown == isWriteStateUnknown;

  @override
  int get hashCode =>
      Object.hash(isLoaded, isLoading, canWrite, isWriteStateUnknown);
}
