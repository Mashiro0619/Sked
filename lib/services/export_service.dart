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
      return const ExportSaveResult(status: ExportSaveStatus.unsupported);
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
        final savedName = await _androidChannel
            .invokeMethod<String>('saveTextFile', {
              'fileName': payload.fileName,
              'content': payload.content,
              'mimeType': payload.mimeType,
            });
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
