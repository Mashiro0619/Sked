import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as paths;
import 'package:url_launcher/url_launcher.dart';

import 'desktop_file_actions_stub.dart'
    if (dart.library.io) 'desktop_file_actions_io.dart'
    as platform;
import 'export_service.dart';

/// A host-confirmed saved file, never a path inferred from model reply text.
class SavedDesktopFile {
  const SavedDesktopFile._(this.path);

  static SavedDesktopFile? fromResult(ExportSaveResult result) {
    final savedPath = result.path;
    if (!platform.desktopFilesSupported ||
        !result.isSuccess ||
        savedPath == null ||
        !paths.isAbsolute(savedPath)) {
      return null;
    }
    return SavedDesktopFile._(paths.normalize(savedPath));
  }

  final String path;
  String get name => paths.basename(path);
}

/// File menus and saved artifacts share the same explicit system actions.
class DesktopFileActions {
  const DesktopFileActions();

  static bool get supported => platform.desktopFilesSupported;

  Future<void> _requireFile(SavedDesktopFile file) async {
    if (!platform.desktopFilesSupported ||
        !await platform.desktopFileExists(file.path)) {
      throw StateError('The saved file is unavailable.');
    }
  }

  Future<void> open(SavedDesktopFile file) async {
    await _requireFile(file);
    if (!await launchUrl(
      Uri.file(file.path, windows: platform.windowsPaths),
      mode: LaunchMode.externalApplication,
    )) {
      throw StateError('The system could not open the saved file.');
    }
  }

  Future<void> reveal(SavedDesktopFile file) async {
    await _requireFile(file);
    await platform.revealDesktopFile(file.path);
  }

  Future<void> copyPath(SavedDesktopFile file) =>
      Clipboard.setData(ClipboardData(text: file.path));

  Future<SavedDesktopFile?> saveCopy(SavedDesktopFile file) async {
    await _requireFile(file);
    final location = await getSaveLocation(suggestedName: file.name);
    if (location == null) return null;
    await platform.copyDesktopFile(file.path, location.path);
    return SavedDesktopFile.fromResult(
      ExportSaveResult(status: ExportSaveStatus.saved, path: location.path),
    );
  }
}
