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
  static const agendaIntentEvent = 'agendaIntent';
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
    if (_enabled) {
      _channel.setMethodCallHandler(null);
    }
    unawaited(_agendaIntentController.close());
  }
}

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
