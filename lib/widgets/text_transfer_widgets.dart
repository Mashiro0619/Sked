import 'sked_confirmation_dialog.dart';
import 'sked_task_route.dart';
import 'adaptive_navigation_scope.dart';

import 'desktop_window_host.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'expressive_dialog.dart';

typedef TextImportSubmit = Future<bool> Function(
  BuildContext context,
  String content,
);

class TextImportPage extends StatefulWidget {
  const TextImportPage({
    super.key,
    required this.title,
    required this.onSubmit,
    this.labelText,
    this.hintText,
    this.initialContent = '',
    this.submitText,
    this.secondaryActionText,
    this.onSecondaryAction,
  }) : assert(onSecondaryAction == null || secondaryActionText != null);

  final String title;
  final String? labelText;
  final String? hintText;
  final String initialContent;
  final String? submitText;
  final TextImportSubmit onSubmit;
  final String? secondaryActionText;
  final Future<void> Function(BuildContext context, String content)?
  onSecondaryAction;

  @override
  State<TextImportPage> createState() => _TextImportPageState();
}

class _TextImportPageState extends State<TextImportPage> {
  late final TextEditingController _controller;
  var _isSubmitting = false;
  var _isContinuing = false;
  bool get _busy => _isSubmitting || _isContinuing;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: WorkbenchAppBar(
          automaticallyImplyLeading: !AdaptiveNavigationScope.isWide(context),
          title: Text(widget.title),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  TextField(
                    controller: _controller,
                    enabled: !_busy,
                    minLines: 12,
                    maxLines: 20,
                    decoration: InputDecoration(
                      labelText: widget.labelText ?? l10n.jsonContent,
                      hintText: widget.hintText ?? l10n.pasteJsonContentHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_outlined),
                    label: Text(widget.submitText ?? l10n.importAction),
                  ),
                  if (widget.onSecondaryAction != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('text-import-secondary-action'),
                      onPressed: _busy ? null : _continue,
                      icon: _isContinuing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      label: Text(widget.secondaryActionText!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final content = _controller.text.trim();
    if (content.isEmpty) {
      _showMessage(l10n.jsonContentEmpty);
      return;
    }

    setState(() => _isSubmitting = true);
    var shouldResetSubmitting = true;
    try {
      final imported = await widget.onSubmit(context, content);
      if (imported && mounted) {
        shouldResetSubmitting = false;
        completeSkedTaskRoute(context);
      }
    } finally {
      if (shouldResetSubmitting && mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _continue() async {
    final action = widget.onSecondaryAction;
    if (_busy || action == null) return;
    setState(() => _isContinuing = true);
    try {
      // The destination owns its review and validation. Keep the exact input
      // here so cancellation or a failed handoff returns to the same draft.
      await action(context, _controller.text);
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<void> showTextExportDialog(
  BuildContext context, {
  required String title,
  required String content,
}) {
  return showExpressiveDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      var popped = false;
      void popOnce() {
        if (popped) return;
        popped = true;
        Navigator.of(dialogContext).pop();
      }

      return SkedConfirmationDialog(
        title: Text(title),
        content: ExpressiveDialogContent(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(dialogContext).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(content),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: popOnce, child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
              }
            },
            child: Text(l10n.copyText),
          ),
        ],
      );
    },
  );
}
