import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../attachments/attachment_models.dart';
import 'agent_desktop_file_source_stub.dart'
    if (dart.library.io) 'agent_desktop_file_source_io.dart';

/// A source retained only until its explicit desktop attachment action ends.
class AgentDesktopFile {
  AgentDesktopFile(DropItem item)
    : file = item,
      _directory = item is DropItemDirectory,
      _bookmark = item.extraAppleBookmark;

  AgentDesktopFile.fromFile(this.file, {Uint8List? appleBookmark})
    : _directory = false,
      _bookmark = appleBookmark;

  final XFile file;
  final bool _directory;
  final Uint8List? _bookmark;

  Future<bool> get isDirectory async =>
      _directory || await desktopSourceIsDirectory(file.path);

  Future<void> read(Future<void> Function(XFile) action) async {
    final bookmark = _bookmark;
    final scoped =
        defaultTargetPlatform == TargetPlatform.macOS &&
        bookmark != null &&
        bookmark.isNotEmpty;
    var accessed = false;
    if (scoped) {
      accessed = await DesktopDrop.instance
          .startAccessingSecurityScopedResource(bookmark: bookmark);
      if (!accessed) {
        throw const AttachmentException(AttachmentError.unavailable);
      }
    }
    try {
      await action(file);
    } finally {
      if (accessed) {
        try {
          await DesktopDrop.instance.stopAccessingSecurityScopedResource(
            bookmark: bookmark!,
          );
        } catch (error, stack) {
          // Releasing a platform grant cannot turn an admitted attachment into
          // a failed file and cause a retry to publish that file a second time.
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'Sked desktop file input',
            ),
          );
        }
      }
    }
  }
}

class AgentDesktopFileDrop extends StatefulWidget {
  const AgentDesktopFileDrop({
    super.key,
    required this.target,
    required this.enabled,
    required this.onDrop,
    required this.child,
  });

  final Object target;
  final bool enabled;
  final Future<void> Function(List<AgentDesktopFile>) onDrop;
  final Widget child;

  @override
  State<AgentDesktopFileDrop> createState() => _AgentDesktopFileDropState();
}

class _AgentDesktopFileDropState extends State<AgentDesktopFileDrop> {
  final _hitIdentity = Object();
  bool _hovered = false;

  bool get _supported =>
      !kIsWeb &&
      const {
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  bool _hit(Offset position) {
    if (!mounted || !widget.enabled) return false;
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      position,
      View.of(context).viewId,
    );
    return result.path.any(
      (entry) =>
          entry.target is RenderMetaData &&
          identical((entry.target as RenderMetaData).metaData, _hitIdentity),
    );
  }

  void _hover(bool value) {
    if (mounted && _hovered != value) setState(() => _hovered = value);
  }

  @override
  void didUpdateWidget(AgentDesktopFileDrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || oldWidget.target != widget.target) _hovered = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return widget.child;
    final colors = Theme.of(context).colorScheme;
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (details) => _hover(_hit(details.globalPosition)),
      onDragUpdated: (details) => _hover(_hit(details.globalPosition)),
      onDragExited: (_) => _hover(false),
      onDragDone: (details) {
        final accepted = _hit(details.globalPosition);
        _hover(false);
        if (!accepted || details.files.isEmpty) return;
        unawaited(
          widget.onDrop(details.files.map(AgentDesktopFile.new).toList()),
        );
      },
      child: MetaData(
        metaData: _hitIdentity,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            widget.child,
            if (_hovered)
              Positioned.fill(
                child: IgnorePointer(
                  child: Semantics(
                    liveRegion: true,
                    child: DecoratedBox(
                      key: const ValueKey('agent-desktop-file-drop-hint'),
                      decoration: ShapeDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.96),
                        shape: skedShapeSchemeOf(context).container.copyWith(
                          side: BorderSide(color: colors.primary, width: 2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.file_upload_outlined,
                                color: colors.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppLocalizations.of(context)
                                      .agentDropFilesHint,
                                  style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
