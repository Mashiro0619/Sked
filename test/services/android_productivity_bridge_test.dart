import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/android_productivity_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AndroidProductivityChannel.name);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('notification diagnostics decode Android channel state', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(
            call.method,
            AndroidProductivityChannel.getNotificationDiagnostics,
          );
          return <String, Object?>{
            'supported': true,
            'appNotificationsEnabled': true,
            'postNotificationsGranted': true,
            'exactAlarmsAllowed': false,
            'channels': <Object?>[
              <String, Object?>{
                'id': 'sked_schedule_reminders',
                'name': 'Schedule reminders',
                'exists': true,
                'enabled': false,
                'importance': 0,
              },
              <String, Object?>{
                'id': 'sked_course_reminders',
                'name': 'Course reminders',
                'exists': true,
                'enabled': true,
                'importance': 4,
              },
            ],
          };
        });
    final bridge = AndroidProductivityBridge(channel: channel, enabled: true);
    addTearDown(bridge.dispose);

    final diagnostics = await bridge.notificationDiagnostics();

    expect(diagnostics.isSupported, isTrue);
    expect(diagnostics.appNotificationsEnabled, isTrue);
    expect(diagnostics.postNotificationsGranted, isTrue);
    expect(diagnostics.exactAlarmsAllowed, isFalse);
    expect(diagnostics.channels.map((channel) => channel.id), [
      'sked_course_reminders',
      'sked_schedule_reminders',
    ]);
    expect(diagnostics.channels.first.enabled, isTrue);
    expect(diagnostics.channels.last.importance, 0);
  });

  test(
    'malformed notification diagnostics safely degrade to unsupported',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            return <String, Object?>{
              'supported': true,
              'appNotificationsEnabled': true,
              'postNotificationsGranted': true,
              'exactAlarmsAllowed': true,
              'channels': <Object?>[
                <String, Object?>{
                  'id': 'sked_course_reminders',
                  'name': 'Course reminders',
                  'exists': 'yes',
                  'enabled': true,
                },
              ],
            };
          });
      final bridge = AndroidProductivityBridge(channel: channel, enabled: true);
      addTearDown(bridge.dispose);

      final diagnostics = await bridge.notificationDiagnostics();

      expect(diagnostics.isSupported, isFalse);
      expect(diagnostics.channels, isEmpty);
    },
  );

  test('non Android diagnostics do not call the method channel', () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          called = true;
          return null;
        });
    final bridge = AndroidProductivityBridge(channel: channel, enabled: false);
    addTearDown(bridge.dispose);

    final diagnostics = await bridge.notificationDiagnostics();

    expect(diagnostics.isSupported, isFalse);
    expect(diagnostics.channels, isEmpty);
    expect(called, isFalse);
  });

  test('disposing a diagnostics-only bridge preserves the coordinator intent handler', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case AndroidProductivityChannel.getInitialAgendaIntent:
              return null;
            case AndroidProductivityChannel.getNotificationDiagnostics:
              return <String, Object?>{
                'supported': true,
                'appNotificationsEnabled': true,
                'postNotificationsGranted': true,
                'exactAlarmsAllowed': true,
                'channels': const <Object?>[],
              };
          }
          return null;
        });
    final coordinatorBridge = AndroidProductivityBridge(
      channel: channel,
      enabled: true,
    );
    final received = <String>[];
    final subscription = coordinatorBridge.agendaIntents.listen(received.add);
    addTearDown(subscription.cancel);
    addTearDown(coordinatorBridge.dispose);
    await coordinatorBridge.initialize();

    final diagnosticsBridge = AndroidProductivityBridge(
      channel: channel,
      enabled: true,
    );
    await diagnosticsBridge.notificationDiagnostics();
    diagnosticsBridge.dispose();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          AndroidProductivityChannel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall(
              AndroidProductivityChannel.agendaIntentEvent,
              'agenda-target',
            ),
          ),
          null,
        );

    expect(received, ['agenda-target']);
  });
}
