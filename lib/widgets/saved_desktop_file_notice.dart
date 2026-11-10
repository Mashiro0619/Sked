import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/desktop_file_actions.dart';
import 'desktop_context_menu.dart';
import 'sked_popup_menu.dart';

/// A completed export becomes its own file target after the save task ends.
class SavedDesktopFileNotice extends StatefulWidget {
  const SavedDesktopFileNotice({super.key, required this.file});

  final SavedDesktopFile file;

  static void show(BuildContext context, SavedDesktopFile file) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        persist: true,
        showCloseIcon: true,
        content: SavedDesktopFileNotice(file: file),
      ),
    );
  }

  @override
  State<SavedDesktopFileNotice> createState() => _SavedDesktopFileNoticeState();
}

class _SavedDesktopFileNoticeState extends State<SavedDesktopFileNotice> {
  static const _files = DesktopFileActions();
  var _busy = false;
  var _failed = false;
  var _copied = false;
  var _generation = 0;

  @override
  void didUpdateWidget(SavedDesktopFileNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.file, widget.file)) {
      _generation++;
      _busy = false;
      _failed = false;
      _copied = false;
    }
  }

  List<DesktopAction> _actions([DesktopActionContext? invocation]) {
    final l = AppLocalizations.of(context);
    final generation = _generation;
    final file = widget.file;
    final route = ModalRoute.of(context);
    bool current() =>
        mounted &&
        generation == _generation &&
        identical(file, widget.file) &&
        route?.isActive != false;
    DesktopAction action(
      String id,
      String label,
      IconData icon,
      Future<void> Function() operation,
    ) => DesktopAction(
      id: id,
      label: label,
      icon: icon,
      enabled: !_busy && current() && invocation?.isCurrent() != false,
      onInvoke: () async {
        if (_busy || !current() || invocation?.isCurrent() == false) return;
        setState(() {
          _busy = true;
          _failed = false;
          _copied = false;
        });
        try {
          await operation();
        } catch (_) {
          if (current()) {
            setState(() => _failed = true);
          }
        } finally {
          if (current()) setState(() => _busy = false);
        }
      },
    );
    return [
      action(
        'open',
        l.desktopOpenFile,
        Icons.open_in_new,
        () => _files.open(file),
      ),
      action(
        'reveal',
        l.desktopRevealFile,
        Icons.folder_open_outlined,
        () => _files.reveal(file),
      ),
      action('copy-path', l.desktopCopyFilePath, Icons.copy_outlined, () async {
        await _files.copyPath(file);
        if (current()) {
          setState(() => _copied = true);
        }
      }),
      action('save-copy', l.desktopSaveFileCopy, Icons.save_alt, () async {
        final saved = await _files.saveCopy(file);
        if (mounted && current() && saved != null) {
          SavedDesktopFileNotice.show(context, saved);
        }
      }),
    ];
  }

  @override
  Widget build(BuildContext context) => DesktopContextMenuRegion(
    target: widget.file,
    enabled: !_busy,
    actionsBuilder: _actions,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                AppLocalizations.of(context).savedToPath(widget.file.path),
                maxLines: 3,
              ),
              if (_failed)
                Text(AppLocalizations.of(context).desktopFileActionFailed),
              if (_copied) Text(AppLocalizations.of(context).copiedToClipboard),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SkedPopupMenuButton<DesktopAction>(
          key: ObjectKey(widget.file),
          tooltip: AppLocalizations.of(context).more,
          enabled: !_busy,
          itemBuilder: (_) => [
            for (final action in _actions())
              SkedPopupMenuItem(
                value: action,
                enabled: action.enabled,
                child: Text(action.label),
              ),
          ],
          onSelected: (action) => action.onInvoke?.call(),
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.more_horiz),
        ),
      ],
    ),
  );
}
