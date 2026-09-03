import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Stable method-channel names shared by the Flutter and Android layers.
abstract final class AndroidProductivityChannel {
  static const name = 'com.mashiro.sked/android_productivity';
  static const getInitialAgendaIntent = 'getInitialAgendaIntent';
  static const requestNotificationPermission = 'requestNotificationPermission';
  static const isNotificationPermissionGranted =
      'isNotificationPermissionGranted';
  static const canScheduleExactAlarms = 'canScheduleExactAlarms';
  static const requestExactAlarmPermission = 'requestExactAlarmPermission';
  static const scheduleAgendaReconciliation = 'scheduleAgendaReconciliation';
  static const cancelAgendaReconciliation = 'cancelAgendaReconciliation';
  static const completeBackgroundAgendaReconciliation =
      'completeBackgroundAgendaReconciliation';
  static const getNotificationDiagnostics = 'getNotificationDiagnostics';
  static const agendaIntentEvent = 'agendaIntent';
}

/// A channel owned by Sked as reported by Android's [NotificationManager].
///
/// Android creates notification channels lazily. [exists] is therefore false
/// until the corresponding reminder or developer test has been scheduled at
/// least once; it does not mean that the application lacks notification
/// support.
class AndroidNotificationChannelState {
  const AndroidNotificationChannelState({
    required this.id,
    required this.name,
    required this.exists,
    required this.enabled,
    this.importance,
  });

  final String id;
  final String name;
  final bool exists;
  final bool enabled;
  final int? importance;

  static AndroidNotificationChannelState? tryDecode(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final name = value['name'];
    final exists = value['exists'];
    final enabled = value['enabled'];
    final importance = value['importance'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        exists is! bool ||
        enabled is! bool ||
        (importance != null && importance is! num)) {
      return null;
    }
    return AndroidNotificationChannelState(
      id: id,
      name: name,
      exists: exists,
      enabled: enabled,
      importance: importance is num ? importance.toInt() : null,
    );
  }
}

/// Snapshot of Android-owned notification state for the developer diagnostic
/// surface. The agenda service remains the owner of scheduling; this bridge
/// only reports system settings and channel-level blocks.
class AndroidNotificationDiagnostics {
  const AndroidNotificationDiagnostics({
    required this.isSupported,
    required this.appNotificationsEnabled,
    required this.postNotificationsGranted,
    required this.exactAlarmsAllowed,
    required this.channels,
  });

  const AndroidNotificationDiagnostics.unsupported()
    : isSupported = false,
      appNotificationsEnabled = false,
      postNotificationsGranted = false,
      exactAlarmsAllowed = false,
      channels = const [];

  final bool isSupported;
  final bool appNotificationsEnabled;
  final bool postNotificationsGranted;
  final bool exactAlarmsAllowed;
  final List<AndroidNotificationChannelState> channels;

  static AndroidNotificationDiagnostics? tryDecode(Object? value) {
    if (value is! Map) return null;
    final supported = value['supported'];
    final appNotificationsEnabled = value['appNotificationsEnabled'];
    final postNotificationsGranted = value['postNotificationsGranted'];
    final exactAlarmsAllowed = value['exactAlarmsAllowed'];
    final rawChannels = value['channels'];
    if (supported is! bool ||
        appNotificationsEnabled is! bool ||
        postNotificationsGranted is! bool ||
        exactAlarmsAllowed is! bool ||
        rawChannels is! List) {
      return null;
    }
    final channels = <AndroidNotificationChannelState>[];
    for (final rawChannel in rawChannels) {
      final channel = AndroidNotificationChannelState.tryDecode(rawChannel);
      if (channel == null) return null;
      channels.add(channel);
    }
    channels.sort((left, right) => left.id.compareTo(right.id));
    return AndroidNotificationDiagnostics(
      isSupported: supported,
      appNotificationsEnabled: appNotificationsEnabled,
      postNotificationsGranted: postNotificationsGranted,
      exactAlarmsAllowed: exactAlarmsAllowed,
      channels: List.unmodifiable(channels),
    );
  }
}

/// Flutter-side facade for Android permissions, background reconciliation and deep links.
///
/// The facade is deliberately a no-op outside Android. This keeps the domain
/// projection and its tests platform-neutral while allowing a single
/// coordinator to be used by every Flutter target.
class AndroidProductivityBridge {
  AndroidProductivityBridge({MethodChannel? channel, bool? enabled})
    : _channel =
          channel ?? const MethodChannel(AndroidProductivityChannel.name),
      _enabled = enabled ?? _isAndroid;

  final MethodChannel _channel;
  final bool _enabled;
  final StreamController<String> _agendaIntentController =
      StreamController<String>.broadcast(sync: true);
  Future<void>? _initialization;
  bool _initialized = false;
  // A diagnostics-only facade shares this method-channel name with the
  // coordinator's bridge, but it never installs an incoming handler.  Track
  // ownership so disposing that facade cannot remove the coordinator's
  // deep-link handler.
  bool _methodCallHandlerInstalled = false;
  bool _disposed = false;

  bool get isSupported => _enabled && !_disposed;

  Stream<String> get agendaIntents => _agendaIntentController.stream;

  /// Installs the incoming-event handler and consumes a cold-start intent.
  Future<void> initialize() {
    if (!_enabled || _disposed || _initialized) return Future<void>.value();
    final inFlight = _initialization;
    if (inFlight != null) return inFlight;

    final operation = _initialize();
    _initialization = operation;
    return operation.whenComplete(() {
      if (identical(_initialization, operation)) {
        _initialization = null;
      }
    });
  }

  Future<void> _initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    _methodCallHandlerInstalled = true;
    final initial = await _channel.invokeMethod<String>(
      AndroidProductivityChannel.getInitialAgendaIntent,
    );
    // The platform method can complete after the host has torn down this
    // bridge (for example during a hot restart). Do not publish into the
    // closed intent stream in that case.
    if (_disposed) return;
    _initialized = true;
    if (initial != null && initial.isNotEmpty) {
      _agendaIntentController.add(initial);
    }
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method == AndroidProductivityChannel.agendaIntentEvent) {
      final target = call.arguments;
      if (target is String && target.isNotEmpty && !_disposed) {
        _agendaIntentController.add(target);
      }
    }
    return null;
  }

  Future<String?> getInitialAgendaIntent() async {
    if (!_enabled || _disposed) return null;
    return _channel.invokeMethod<String>(
      AndroidProductivityChannel.getInitialAgendaIntent,
    );
  }

  Future<bool> requestNotificationPermission() async {
    if (!_enabled || _disposed) return true;
    return await _channel.invokeMethod<bool>(
          AndroidProductivityChannel.requestNotificationPermission,
        ) ??
        false;
  }

  Future<bool> isNotificationPermissionGranted() async {
    if (!_enabled || _disposed) return true;
    return await _channel.invokeMethod<bool>(
          AndroidProductivityChannel.isNotificationPermissionGranted,
        ) ??
        false;
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!_enabled || _disposed) return true;
    return await _channel.invokeMethod<bool>(
          AndroidProductivityChannel.canScheduleExactAlarms,
        ) ??
        false;
  }

  Future<bool> requestExactAlarmPermission() async {
    if (!_enabled || _disposed) return true;
    return await _channel.invokeMethod<bool>(
          AndroidProductivityChannel.requestExactAlarmPermission,
        ) ??
        false;
  }

  /// Reads system-level notification state and all current `sked_` channels.
  ///
  /// This intentionally does not initialize the agenda intent bridge or the
  /// local-notifications plugin. It is safe to use from the developer page and
  /// becomes a no-op on non-Android platforms.
  Future<AndroidNotificationDiagnostics> notificationDiagnostics() async {
    if (!_enabled || _disposed) {
      return const AndroidNotificationDiagnostics.unsupported();
    }
    final raw = await _channel.invokeMethod<Object?>(
      AndroidProductivityChannel.getNotificationDiagnostics,
    );
    return AndroidNotificationDiagnostics.tryDecode(raw) ??
        const AndroidNotificationDiagnostics.unsupported();
  }

  /// Schedules the next headless projection boundary on Android. The native
  /// scheduler coalesces this with boot/time-zone broadcasts and executes the
  /// same Dart Agenda path that foreground commits use.
  Future<void> scheduleAgendaReconciliation(DateTime? at) async {
    if (!_enabled || _disposed) return;
    await _channel.invokeMethod<void>(
      AndroidProductivityChannel.scheduleAgendaReconciliation,
      <String, Object?>{'atEpochMillis': at?.millisecondsSinceEpoch},
    );
  }

  Future<void> cancelAgendaReconciliation() async {
    if (!_enabled || _disposed) return;
    await _channel.invokeMethod<void>(
      AndroidProductivityChannel.cancelAgendaReconciliation,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_enabled && _methodCallHandlerInstalled) {
      _channel.setMethodCallHandler(null);
      _methodCallHandlerInstalled = false;
    }
    unawaited(_agendaIntentController.close());
  }
}

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
