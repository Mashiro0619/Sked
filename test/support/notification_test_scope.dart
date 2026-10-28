import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';

import 'agenda_notification_memory.dart';

/// Registers only the unrelated autostart capability read used by settings.
/// Unknown methods remain errors; tests of native behavior supply their own fake.
void setUpNotificationTestPlatform() {
  const channel = MethodChannel(AndroidProductivityChannel.name);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != AndroidProductivityChannel.getAutostartSupport) {
            throw StateError(
              'Unexpected settings platform call: ${call.method}',
            );
          }
          return null; // No vendor-specific autostart capability on this host.
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

/// MaterialApp builder for standalone UI tests that navigate through settings.
/// The provider owns disposal and follows the production platform-support rule;
/// permission reads and notification state use explicit in-memory dependencies.
Widget buildNotificationTestScope(BuildContext context, Widget? child) =>
    ChangeNotifierProvider<AgendaNotificationService>(
      create: (_) => AgendaNotificationService(
        gateway: MemoryAgendaNotificationGateway(),
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      ),
      child: child,
    );
