import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

abstract interface class SchoolWebSessionCleaner {
  Future<void> clear();
}

/// Owns cleanup of the application's embedded school-browser session.
///
/// Browser owners suspend their native views before cleanup, so pages cannot
/// recreate cookies or local storage while the user's clear is in progress.
/// Errors propagate: a partial native clear must not be reported as success.
class SchoolWebSessionService extends ChangeNotifier
    implements SchoolWebSessionCleaner {
  SchoolWebSessionService({
    TargetPlatform? platform,
    bool? isWeb,
    Future<void> Function()? clearCookies,
    this.clearStorage,
    Future<void> Function()? clearCache,
    Future<void> Function()? clearWindowsProfile,
    Future<void> Function(int viewId)? disposeWindowsView,
  }) : _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb,
       _clearCookies = clearCookies ?? _deleteCookies,
       _clearCache = clearCache ?? InAppWebViewController.clearAllCache,
       _clearWindowsProfile = clearWindowsProfile ?? _clearNativeWindowsProfile,
       _disposeWindowsView = disposeWindowsView ?? _disposeNativeWindowsView;

  static final instance = SchoolWebSessionService();
  static const windowsChannel = MethodChannel(
    'com.mashiro.sked/school_web_session',
  );

  final TargetPlatform _platform;
  final bool _isWeb;
  final Future<void> Function() _clearCookies;
  final Future<void> Function()? clearStorage;
  final Future<void> Function() _clearCache;
  final Future<void> Function() _clearWindowsProfile;
  final Future<void> Function(int viewId) _disposeWindowsView;
  final _browsers = <Future<void> Function()>{};
  Future<void>? _clearing;

  bool get isClearing => _clearing != null;
  bool get requiresNativeClosureAcknowledgement =>
      !_isWeb && _platform == TargetPlatform.windows;

  /// Returns an unregister callback for the browser owner's dispose path.
  VoidCallback registerBrowser(Future<void> Function() suspend) {
    _browsers.add(suspend);
    return () => _browsers.remove(suspend);
  }

  /// Completes the Windows plugin's native disposal before clearing its profile.
  /// Widget disposal alone starts this operation without awaiting its reply.
  Future<void> finishClosingBrowser(InAppWebViewController controller) async {
    if (_isWeb || _platform != TargetPlatform.windows) return;
    final viewId = controller.getViewId();
    if (viewId is! int) {
      throw StateError('The school browser has no native Windows view ID.');
    }
    await _disposeWindowsView(viewId);
  }

  @override
  Future<void> clear() {
    final pending = _clearing;
    if (pending != null) return pending;
    final completion = Completer<void>();
    final operation = completion.future;
    _clearing = operation;
    notifyListeners();
    void finish() {
      _clearing = null;
      notifyListeners();
    }

    unawaited(
      _clear().then(
        (_) {
          finish();
          completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          finish();
          completion.completeError(error, stack);
        },
      ),
    );
    return operation;
  }

  Future<void> _clear() async {
    final suspended = <Future<void> Function()>{};
    while (true) {
      while (_browsers.any((browser) => !suspended.contains(browser))) {
        final pending = _browsers
            .where((browser) => !suspended.contains(browser))
            .toList();
        for (final suspend in pending) {
          suspended.add(suspend);
          await suspend();
        }
      }
      await _clearPlatformData();
      // Registration can also happen while the native clear is awaiting its
      // reply. Suspend those owners and repeat cleanup before reporting success.
      if (_browsers.every(suspended.contains)) return;
    }
  }

  Future<void> _clearPlatformData() async {
    if (_isWeb) return;
    switch (_platform) {
      case TargetPlatform.windows:
        // Windows plugin cache/storage methods have no native implementation.
        // Clear the actual WebView2 profile rather than calling those stubs.
        await _clearWindowsProfile();
      case TargetPlatform.android:
        await _clearCookies();
        await (clearStorage?.call() ??
            WebStorageManager.instance().deleteAllData());
        await _clearCache();
      case TargetPlatform.iOS:
        await _clearCookies();
        await (clearStorage?.call() ??
            WebStorageManager.instance().removeDataModifiedSince(
              dataTypes: WebsiteDataType.ALL,
              date: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            ));
        await _clearCache();
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
        // The school browser is not offered on these platforms.
        return;
    }
  }

  static Future<void> _deleteCookies() async {
    // Android returns false when no cookies existed, which is already clean.
    await CookieManager.instance().deleteAllCookies();
  }

  static Future<void> _clearNativeWindowsProfile() async {
    try {
      await windowsChannel.invokeMethod<String>('clear');
    } finally {
      // Runs after the native completion callback returns, when disposing the
      // hidden WebView2 controller is safe. Do not mask a cleanup failure.
      try {
        await windowsChannel.invokeMethod<void>('release');
      } catch (_) {
        // The native owner also disposes on teardown or the next clear call.
        // Preserve the profile-clear error if the engine is already stopping.
      }
    }
  }

  static Future<void> _disposeNativeWindowsView(int viewId) async {
    // This is the dispose protocol of the pinned Windows WebView plugin.
    // It is idempotent when widget disposal has already removed the view.
    const channel = MethodChannel(
      'com.pichillilorenzo/flutter_inappwebview_manager',
    );
    await channel.invokeMethod<void>('dispose', <String, Object?>{
      'id': viewId,
    });
  }
}
