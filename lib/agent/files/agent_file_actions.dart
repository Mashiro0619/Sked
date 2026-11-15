import 'package:flutter/services.dart';

import '../../services/desktop_file_actions.dart';
import '../bridge/generated/api/file_contracts.dart';
import 'agent_file_actions_stub.dart'
    if (dart.library.io) 'agent_file_actions_io.dart'
    as platform;

/// User-invoked actions on resource locations taken from actual tool receipts.
class AgentFileActions {
  const AgentFileActions();

  static const _channel = MethodChannel('com.mashiro.sked/agent_file_actions');
  static const _desktop = DesktopFileActions();

  static bool supportsOpen(FileResourceRef resource) =>
      (platform.isWindows && resource.kind == FileResourceKind.windowsPath) ||
      (platform.isAndroid &&
          (resource.kind == FileResourceKind.androidPath ||
              resource.kind == FileResourceKind.contentUri));

  static bool supportsReveal(FileResourceRef resource) =>
      platform.isWindows && resource.kind == FileResourceKind.windowsPath;

  Future<void> open({
    required FileResourceRef resource,
    required String name,
    String? mediaType,
    bool useViewingCopy = false,
  }) async {
    if (!supportsOpen(resource)) {
      throw UnsupportedError('This file cannot be opened on this platform.');
    }
    if (resource.kind == FileResourceKind.windowsPath && !useViewingCopy) {
      await _desktop.open(_desktopFile(resource));
      return;
    }
    if (resource.kind == FileResourceKind.contentUri) {
      await _openAndroid(resource, name, mediaType);
      return;
    }
    final copy = await platform.prepareOpenCopy(resource.value, name);
    if (resource.kind == FileResourceKind.windowsPath) {
      try {
        await _desktop.open(
          _desktopFile(FileResourceRef(kind: resource.kind, value: copy.path)),
        );
      } on StateError {
        await copy.discard();
        rethrow;
      }
      return;
    }
    try {
      await _openAndroid(
        FileResourceRef(kind: FileResourceKind.androidPath, value: copy.path),
        name,
        mediaType,
      );
    } on PlatformException catch (error) {
      // Native errors mean no viewer was launched. Other channel failures may
      // occur after handoff, so keep those copies available to the viewer.
      try {
        await copy.discard();
      } catch (cleanup) {
        throw PlatformException(
          code: error.code,
          message: error.message,
          details: {'native': error.details, 'cleanup': '$cleanup'},
        );
      }
      rethrow;
    }
  }

  Future<void> reveal(FileResourceRef resource) async {
    if (!supportsReveal(resource)) {
      throw UnsupportedError('File location is unavailable on this platform.');
    }
    await _desktop.reveal(_desktopFile(resource));
  }

  Future<void> copyLocation(FileResourceRef resource) =>
      Clipboard.setData(ClipboardData(text: resource.value));

  Future<void> _openAndroid(
    FileResourceRef resource,
    String name,
    String? mediaType,
  ) => _channel.invokeMethod<void>('open', {
    'kind': resource.kind.name,
    'value': resource.value,
    'name': name,
    'mediaType': mediaType,
  });

  SavedDesktopFile _desktopFile(FileResourceRef resource) =>
      SavedDesktopFile.fromConfirmedPath(resource.value) ??
      (throw StateError('The saved file location is invalid.'));
}
