import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/export_service.dart';

class _BinaryExportHost {
  _BinaryExportHost(this.directory);

  final Directory directory;
  final calls = <MethodCall>[];
  final saveStarted = Completer<void>();
  Future<String?> Function(File source)? save;
  bool discardFails = false;
  int preparations = 0;
  String? _id;
  String? _fileName;
  File? source;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    final arguments = Map<String, Object?>.from(call.arguments as Map);
    switch (call.method) {
      case 'prepareBinaryFile':
        if (_id != null) throw PlatformException(code: 'busy');
        _id = 'prepared-${++preparations}';
        _fileName = arguments['fileName']! as String;
        source = File.fromUri(directory.uri.resolve('payload-$preparations'));
        await source!.create();
        return {'id': _id, 'path': source!.path};
      case 'savePreparedBinaryFile':
        expect(arguments, {'id': _id});
        if (!saveStarted.isCompleted) saveStarted.complete();
        return save == null ? _fileName : save!(source!);
      case 'discardBinaryFile':
        if (discardFails) throw PlatformException(code: 'failed');
        if (arguments['id'] == _id) {
          await source!.delete();
          _id = null;
        }
        return null;
      case 'saveTextFile':
        if (_id != null) throw PlatformException(code: 'busy');
        return arguments['fileName'];
      default:
        throw MissingPluginException();
    }
  }
}

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

  group('ExportService Android binary export', () {
    const channel = MethodChannel('com.mashiro.sked/export_file');
    const fileName = 'Sked_备份.zip';
    final bytes = Uint8List.fromList([
      0x50,
      0x4b,
      0x03,
      0x04,
      for (var i = 0; i < 131137; i++) i % 256,
    ]);
    late Directory directory;
    late _BinaryExportHost host;

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      directory = await Directory.systemTemp.createTemp('sked-binary-export-');
      host = _BinaryExportHost(directory);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, host.handle);
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
      await directory.delete(recursive: true);
    });

    Future<ExportSaveResult> saveBytes([Uint8List? content]) =>
        const ExportService().saveBytes(
          fileName: fileName,
          bytes: content ?? bytes,
          mimeType: 'application/zip',
        );

    test(
      'writes exact bytes before offering only the native export token',
      () async {
        host.save = (source) async {
          expect(await source.readAsBytes(), bytes);
          return fileName;
        };

        final result = await saveBytes();

        expect(result.status, ExportSaveStatus.saved);
        expect(result.path, fileName);
        expect(host.calls.map((call) => call.method), [
          'prepareBinaryFile',
          'savePreparedBinaryFile',
          'discardBinaryFile',
        ]);
        expect(host.calls.first.arguments, {
          'fileName': fileName,
          'mimeType': 'application/zip',
          'byteLength': bytes.length,
        });
        expect(host.calls[1].arguments, {'id': 'prepared-1'});
        expect(host.calls[2].arguments, {'id': 'prepared-1'});
        expect(await directory.list().toList(), isEmpty);
      },
    );

    test(
      'cancelled destination selection releases the prepared source',
      () async {
        host.save = (source) async {
          expect(await source.readAsBytes(), bytes);
          return null;
        };

        final result = await saveBytes();

        expect(result.status, ExportSaveStatus.cancelled);
        expect(result.path, isNull);
        expect(await directory.list().toList(), isEmpty);
      },
    );

    for (final (code, status) in [
      ('permissionDenied', ExportSaveStatus.permissionDenied),
      ('unsupported', ExportSaveStatus.unsupported),
      ('failed', ExportSaveStatus.failed),
      ('busy', ExportSaveStatus.failed),
    ]) {
      test('preserves $code and cleans the prepared source', () async {
        host.save = (source) async {
          expect(await source.readAsBytes(), bytes);
          throw PlatformException(code: code);
        };

        final result = await saveBytes();

        expect(result.status, status);
        expect(result.path, isNull);
        expect(await directory.list().toList(), isEmpty);
      });
    }

    test(
      'holds one export while Android is still completing its copy',
      () async {
        final completion = Completer<String?>();
        host.save = (_) => completion.future;
        var completed = false;
        final first = saveBytes().then((value) {
          completed = true;
          return value;
        });
        await host.saveStarted.future;
        expect(completed, isFalse);
        expect(await host.source!.readAsBytes(), bytes);

        expect((await saveBytes()).status, ExportSaveStatus.failed);
        expect(
          (await const ExportService().saveFile(
            const ExportPayload(fileName: 'other.json', content: '{}'),
          )).status,
          ExportSaveStatus.failed,
        );
        expect(host.preparations, 1);
        expect(await host.source!.exists(), isTrue);
        expect(completed, isFalse);

        completion.complete(fileName);
        expect((await first).status, ExportSaveStatus.saved);
        expect(completed, isTrue);
        expect(await directory.list().toList(), isEmpty);
      },
    );

    test(
      'local staging failure releases the token without opening a picker',
      () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              if (call.method == 'prepareBinaryFile') {
                return {
                  'id': 'failed-write',
                  'path': File.fromUri(directory.uri.resolve('missing/payload'))
                      .path,
                };
              }
              expect(call.method, 'discardBinaryFile');
              expect(call.arguments, {'id': 'failed-write'});
              return null;
            });

        expect((await saveBytes()).status, ExportSaveStatus.failed);
        expect(calls.map((call) => call.method), [
          'prepareBinaryFile',
          'discardBinaryFile',
        ]);
        expect(await directory.list().toList(), isEmpty);
      },
    );

    test(
      'invalid preparation path is rejected and its token released',
      () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return call.method == 'prepareBinaryFile'
                  ? {'id': 'invalid-preparation'}
                  : null;
            });

        expect((await saveBytes()).status, ExportSaveStatus.failed);
        expect(calls.map((call) => call.method), [
          'prepareBinaryFile',
          'discardBinaryFile',
        ]);
        expect(calls.last.arguments, {'id': 'invalid-preparation'});
      },
    );

    test(
      'zero-byte export still saves and cleans the allocated file',
      () async {
        host.save = (source) async {
          expect(await source.readAsBytes(), isEmpty);
          return fileName;
        };

        expect((await saveBytes(Uint8List(0))).status, ExportSaveStatus.saved);
        expect(host.calls.first.arguments, containsPair('byteLength', 0));
        expect(await directory.list().toList(), isEmpty);
      },
    );

    test('cancelled preparation never writes or opens a destination', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });

      expect((await saveBytes()).status, ExportSaveStatus.cancelled);
      expect(calls.single.method, 'prepareBinaryFile');
      expect(await directory.list().toList(), isEmpty);
    });

    test(
      'missing native binary support is reported without a cache artifact',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async {
              throw MissingPluginException();
            });

        expect((await saveBytes()).status, ExportSaveStatus.unsupported);
        expect(await directory.list().toList(), isEmpty);
      },
    );

    test(
      'cleanup failure is not reported as a fully completed export',
      () async {
        host.discardFails = true;

        final result = await saveBytes();

        expect(result.status, ExportSaveStatus.failed);
        expect(result.path, isNull);
        expect(await host.source!.readAsBytes(), bytes);
      },
    );
  });
}
