import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ExportPayload {
  const ExportPayload({
    required this.fileName,
    required this.content,
    this.mimeType = 'application/json',
    this.allowedExtensions = const ['json'],
  });

  final String fileName;
  final String content;
  final String mimeType;
  final List<String> allowedExtensions;

  XFile toXFile() {
    return XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      mimeType: mimeType,
      name: fileName,
    );
  }
}

enum ExportSaveStatus {
  saved,
  cancelled,
  permissionDenied,
  permissionPermanentlyDenied,
  failed,
  unsupported,
}

class ExportSaveResult {
  const ExportSaveResult({required this.status, this.path});

  final ExportSaveStatus status;
  final String? path;

  bool get isSuccess => status == ExportSaveStatus.saved;
}

class ExportService {
  const ExportService();

  static const _androidChannel = MethodChannel('com.mashiro.sked/export_file');

  Future<void> shareFile(ExportPayload payload) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [payload.toXFile()],
        fileNameOverrides: [payload.fileName],
        subject: payload.fileName,
      ),
    );
  }

  Future<void> shareBytes({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    final file = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [fileName],
        subject: fileName,
      ),
    );
  }

  Future<ExportSaveResult> saveBytes({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    final file = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
    if (kIsWeb) {
      try {
        await file.saveTo(fileName);
        return const ExportSaveResult(status: ExportSaveStatus.saved);
      } catch (_) {
        return const ExportSaveResult(status: ExportSaveStatus.unsupported);
      }
    }
    if (isAndroid) {
      return _saveAndroidBytes(
        file: file,
        fileName: fileName,
        mimeType: mimeType,
        byteLength: bytes.length,
      );
    }
    try {
      final location = await getSaveLocation(suggestedName: fileName);
      if (location == null) {
        return const ExportSaveResult(status: ExportSaveStatus.cancelled);
      }
      await file.saveTo(location.path);
      return ExportSaveResult(
        status: ExportSaveStatus.saved,
        path: location.path,
      );
    } catch (_) {
      return const ExportSaveResult(status: ExportSaveStatus.failed);
    }
  }

  Future<ExportSaveResult> _saveAndroidBytes({
    required XFile file,
    required String fileName,
    required String mimeType,
    required int byteLength,
  }) async {
    String? preparationId;
    var outcome = const ExportSaveResult(status: ExportSaveStatus.failed);
    try {
      final prepared = await _androidChannel.invokeMapMethod<String, dynamic>(
        'prepareBinaryFile',
        {'fileName': fileName, 'mimeType': mimeType, 'byteLength': byteLength},
      );
      if (prepared == null) {
        outcome = const ExportSaveResult(status: ExportSaveStatus.cancelled);
      } else {
        final id = prepared['id'];
        if (id is! String || id.isEmpty) {
          throw const FormatException('Missing export preparation identity.');
        }
        preparationId = id;
        final path = prepared['path'];
        if (path is! String || path.isEmpty) {
          throw const FormatException('Missing export preparation path.');
        }
        // The native owner allocates this private cache file. Send only its
        // token back after the write closes; binary content never crosses the
        // channel as a string, and native does not accept arbitrary paths.
        await file.saveTo(path);
        final savedName = await _androidChannel.invokeMethod<String>(
          'savePreparedBinaryFile',
          {'id': id},
        );
        outcome = savedName == null
            ? const ExportSaveResult(status: ExportSaveStatus.cancelled)
            : ExportSaveResult(status: ExportSaveStatus.saved, path: savedName);
      }
    } on MissingPluginException {
      outcome = const ExportSaveResult(status: ExportSaveStatus.unsupported);
    } on PlatformException catch (error) {
      outcome = ExportSaveResult(
        status: switch (error.code) {
          'permissionDenied' => ExportSaveStatus.permissionDenied,
          'unsupported' => ExportSaveStatus.unsupported,
          _ => ExportSaveStatus.failed,
        },
      );
    } catch (_) {
      outcome = const ExportSaveResult(status: ExportSaveStatus.failed);
    } finally {
      if (preparationId != null) {
        try {
          // Also releases a preparation if writing the local file failed.
          // Completion/cancellation already cleans it natively; this is an
          // idempotent fallback bound to the same preparation identity.
          await _androidChannel.invokeMethod<void>('discardBinaryFile', {
            'id': preparationId,
          });
        } catch (_) {
          outcome = const ExportSaveResult(status: ExportSaveStatus.failed);
        }
      }
    }
    return outcome;
  }

  Future<ExportSaveResult> saveFile(ExportPayload payload) async {
    if (kIsWeb) {
      try {
        await payload.toXFile().saveTo(payload.fileName);
        return const ExportSaveResult(status: ExportSaveStatus.saved);
      } catch (_) {
        return const ExportSaveResult(status: ExportSaveStatus.unsupported);
      }
    }

    if (isAndroid) {
      try {
        final savedName = await _androidChannel.invokeMethod<String>(
          'saveTextFile',
          {
            'fileName': payload.fileName,
            'content': payload.content,
            'mimeType': payload.mimeType,
          },
        );
        if (savedName == null) {
          return const ExportSaveResult(status: ExportSaveStatus.cancelled);
        }
        return ExportSaveResult(
          status: ExportSaveStatus.saved,
          path: savedName,
        );
      } on PlatformException catch (error) {
        return switch (error.code) {
          'permissionDenied' => const ExportSaveResult(
            status: ExportSaveStatus.permissionDenied,
          ),
          'unsupported' => const ExportSaveResult(
            status: ExportSaveStatus.unsupported,
          ),
          _ => const ExportSaveResult(status: ExportSaveStatus.failed),
        };
      } catch (_) {
        return const ExportSaveResult(status: ExportSaveStatus.failed);
      }
    }

    try {
      final location = await getSaveLocation(suggestedName: payload.fileName);
      if (location == null) {
        return const ExportSaveResult(status: ExportSaveStatus.cancelled);
      }
      await payload.toXFile().saveTo(location.path);
      return ExportSaveResult(
        status: ExportSaveStatus.saved,
        path: location.path,
      );
    } catch (_) {
      return const ExportSaveResult(status: ExportSaveStatus.failed);
    }
  }

  Future<void> openSettings() async {}

  bool get isWeb => kIsWeb;
  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  bool get usesDesktopFileSaveErrors =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);
}
