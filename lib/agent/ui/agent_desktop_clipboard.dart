import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pasteboard/pasteboard.dart';

import '../attachments/attachment_models.dart';
import 'agent_desktop_file_drop.dart';

bool get agentDesktopClipboardSupported =>
    !kIsWeb &&
    const {
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

class AgentDesktopClipboardPayload {
  const AgentDesktopClipboardPayload.files(this.files) : text = null;
  const AgentDesktopClipboardPayload.text(this.text) : files = const [];

  final List<AgentDesktopFile> files;
  final String? text;
}

/// Chooses one representation for a paste. File lists take precedence over any
/// preview image or text that the same clipboard source also publishes.
Future<AgentDesktopClipboardPayload> readAgentDesktopClipboard({
  required bool Function() isCurrent,
}) async {
  void check() {
    if (!isCurrent()) {
      throw const AttachmentException(AttachmentError.cancelled);
    }
  }

  check();
  if (defaultTargetPlatform == TargetPlatform.windows) {
    final payload = await const MethodChannel('sked/desktop_clipboard')
        .invokeMapMethod<String, Object?>('read');
    check();
    if (payload?['files'] case final List<Object?> paths) {
      return AgentDesktopClipboardPayload.files([
        for (final path in paths)
          AgentDesktopFile.fromFile(XFile(path as String)),
      ]);
    }
    if (payload?['image'] case final Uint8List bytes) {
      final png = await _clipboardPng(bytes);
      check();
      return AgentDesktopClipboardPayload.files([
        AgentDesktopFile.fromFile(_AgentClipboardImage(png)),
      ]);
    }
    return AgentDesktopClipboardPayload.text(payload?['text'] as String?);
  }
  final files = <AgentDesktopFile>[];
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    // NSURL also represents web links. The native reader keeps only file URLs
    // instead of accidentally treating a copied web URL's path as a local file.
    final values = await const MethodChannel('sked/desktop_clipboard')
        .invokeListMethod<Object?>('files');
    check();
    for (final value in values ?? const []) {
      if (value is! Map || value['path'] is! String) {
        throw const FormatException('Invalid clipboard file metadata.');
      }
      final path = value['path'] as String;
      if (path.isEmpty) continue;
      files.add(
        AgentDesktopFile.fromFile(
          XFile(path),
          appleBookmark: value['bookmark'] as Uint8List?,
        ),
      );
    }
  } else {
    final paths = await Pasteboard.files();
    check();
    files.addAll(
      paths
          .where((path) => path.isNotEmpty)
          .map((path) => AgentDesktopFile.fromFile(XFile(path))),
    );
  }
  if (files.isNotEmpty) return AgentDesktopClipboardPayload.files(files);

  final image = await Pasteboard.image;
  check();
  if (image != null) {
    if (image.isEmpty) throw const FormatException('Empty clipboard image.');
    final png = await _clipboardPng(image);
    check();
    return AgentDesktopClipboardPayload.files([
      AgentDesktopFile.fromFile(_AgentClipboardImage(png)),
    ]);
  }
  final text = await Clipboard.getData(Clipboard.kTextPlain);
  check();
  return AgentDesktopClipboardPayload.text(text?.text);
}

// cross_file's native in-memory constructor ignores its name argument. Keep
// the screenshot name explicitly while retaining an empty filesystem path.
class _AgentClipboardImage extends XFile {
  _AgentClipboardImage(super.bytes)
    : name = 'clipboard-${DateTime.now().millisecondsSinceEpoch}.png',
      super.fromData(mimeType: 'image/png');

  @override
  final String name;
}

Future<Uint8List> _clipboardPng(Uint8List bytes) async {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= signature.length &&
      listEquals(bytes.sublist(0, signature.length), signature)) {
    return bytes;
  }
  // Windows exposes a DIB as BMP. Flutter normalizes that clipboard bitmap to
  // PNG while retaining its original dimensions and releasing decoder handles.
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw const FormatException('Clipboard image decode failed.');
      }
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// Overrides only the composer's built-in paste action. The original action is
/// still used when the desktop attachment path is unavailable or IME is active.
class AgentDesktopPasteAction extends Action<PasteTextIntent> {
  AgentDesktopPasteAction({required this.shouldRead, required this.onPaste});

  final bool Function() shouldRead;
  final Future<void> Function(PasteTextIntent) onPaste;

  @override
  Object? invoke(PasteTextIntent intent) {
    if (!shouldRead()) return callingAction?.invoke(intent);
    unawaited(onPaste(intent));
    return null;
  }
}
