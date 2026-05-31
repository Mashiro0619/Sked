import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExportService platform helpers', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('detects Android through Flutter target platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      const service = ExportService();

      expect(service.isWeb, isFalse);
      expect(service.isAndroid, isTrue);
      expect(service.isWindows, isFalse);
    });

    test('detects Windows through Flutter target platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      const service = ExportService();

      expect(service.isWeb, isFalse);
      expect(service.isAndroid, isFalse);
      expect(service.isWindows, isTrue);
      expect(service.usesDesktopFileSaveErrors, isTrue);
    });

    test('uses desktop file-save errors on desktop platforms only', () {
      const service = ExportService();

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(service.usesDesktopFileSaveErrors, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(service.usesDesktopFileSaveErrors, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(service.usesDesktopFileSaveErrors, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(service.usesDesktopFileSaveErrors, isFalse);
    });
  });

  group('ExportService Android file save channel', () {
    const channel = MethodChannel('com.mashiro.sked/export_file');
    const payload = ExportPayload(
      fileName: 'Sked_export.json',
      content: '{"ok":true}',
    );

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns saved and sends text file payload to Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return payload.fileName;
          });

      final result = await const ExportService().saveFile(payload);

      expect(result.status, ExportSaveStatus.saved);
      expect(result.path, payload.fileName);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'saveTextFile');
      expect(
        calls.single.arguments,
        containsPair('fileName', payload.fileName),
      );
      expect(calls.single.arguments, containsPair('content', payload.content));
      expect(
        calls.single.arguments,
        containsPair('mimeType', payload.mimeType),
      );
    });

    test('maps Android null result to cancelled', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);

      final result = await const ExportService().saveFile(payload);

      expect(result.status, ExportSaveStatus.cancelled);
      expect(result.path, isNull);
    });

    test('maps Android permissionDenied error', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'permissionDenied');
          });

      final result = await const ExportService().saveFile(payload);

      expect(result.status, ExportSaveStatus.permissionDenied);
    });

    test('maps Android unsupported error', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'unsupported');
          });

      final result = await const ExportService().saveFile(payload);

      expect(result.status, ExportSaveStatus.unsupported);
    });

    test('maps other Android channel errors to failed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'failed');
          });

      final result = await const ExportService().saveFile(payload);

      expect(result.status, ExportSaveStatus.failed);
    });
  });
}
