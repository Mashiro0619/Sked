import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../services/school_import_api.dart';
import '../utils/text_input_limits.dart';
import 'expressive_dialog.dart';

Map<String, dynamic>? _tryDecodeJsonObject(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      return null;
    }
    final result = <String, dynamic>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key is String) {
        result[key] = entry.value;
      }
    }
    return result;
  } catch (_) {
    return null;
  }
}

class SchoolImportStreamDialog extends StatefulWidget {
  const SchoolImportStreamDialog({super.key, required this.stream});

  static const int maxPreviewCodeUnits = 4096;
  static const int maxEditableCodeUnits = 64 * 1024;

  final Stream<SchoolImportStreamEvent> stream;

  @override
  State<SchoolImportStreamDialog> createState() =>
      _SchoolImportStreamDialogState();
}

class _SchoolImportStreamDialogState extends State<SchoolImportStreamDialog> {
  final _textBuffer = StringBuffer();
  String _previewText = '';
  final _scrollController = ScrollController();
  late final TextEditingController _editController;
  StreamSubscription<SchoolImportStreamEvent>? _subscription;
  bool _isDone = false;
  bool _isEditing = false;
  String? _error;
  SchoolImportResponse? _response;
  bool _hasPopped = false;

  bool get _canEdit =>
      _isDone &&
      _textBuffer.length <= SchoolImportStreamDialog.maxEditableCodeUnits;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _subscription = widget.stream.listen(
      (event) {
        switch (event) {
          case ParseDelta(:final text):
            _textBuffer.write(text);
            _appendPreview(text);
            break;
          case ParseDone(:final response):
            _response = response;
            _isDone = true;
            break;
          case ParseError(:final message):
            _error = message;
            break;
        }
        if (mounted) {
          setState(() {});
          _scrollToBottom();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _error = '$error');
        }
      },
    );
  }

  @override
  void dispose() {
    unawaited(_cancelSubscription());
    _scrollController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _cancelSubscription() async {
    final subscription = _subscription;
    _subscription = null;
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } catch (error, stackTrace) {
      debugPrint(
        'School import stream cancellation failed: '
        '$error\n$stackTrace',
      );
    }
  }

  void _scrollToBottom() {
    if (_isEditing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(_animateScrollToBottom());
      }
    });
  }

  Future<void> _animateScrollToBottom() async {
    try {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'School import preview scrolling failed: '
        '$error\n$stackTrace',
      );
    }
  }

  void _appendPreview(String text) {
    if (text.isEmpty) {
      return;
    }
    final limit = SchoolImportStreamDialog.maxPreviewCodeUnits;
    if (text.length >= limit) {
      _previewText = text.substring(_safeTailStart(text, text.length - limit));
      return;
    }

    final overflow = _previewText.length + text.length - limit;
    final retainedPreview = overflow > 0
        ? _previewText.substring(_safeTailStart(_previewText, overflow))
        : _previewText;
    _previewText = '$retainedPreview$text';
  }

  int _safeTailStart(String value, int start) {
    if (start <= 0) {
      return 0;
    }
    if (start >= value.length) {
      return value.length;
    }
    final codeUnit = value.codeUnitAt(start);
    return codeUnit >= 0xdc00 && codeUnit <= 0xdfff ? start + 1 : start;
  }

  void _enterEditMode() {
    if (!_canEdit) {
      return;
    }
    _editController.text = _textBuffer.toString();
    setState(() => _isEditing = true);
  }

  void _confirmEdit() {
    final l10n = AppLocalizations.of(context);
    final rawText = _editController.text.trim();
    if (rawText.isEmpty) {
      setState(() => _error = l10n.jsonContentEmpty);
      return;
    }

    final json = _tryDecodeJsonObject(rawText);
    if (json == null) {
      setState(() => _error = l10n.importFailedCheckContent);
      return;
    }

    try {
      if (json.containsKey('timetable')) {
        _response = SchoolImportApi.buildResponseFromDoneEvent(json);
      } else if (json.containsKey('name') || json.containsKey('courses')) {
        _response = SchoolImportApi.buildResponseFromDoneEvent(json);
      } else {
        setState(() => _error = l10n.noImportableTimetables);
        return;
      }
    } catch (e) {
      setState(() => _error = '${l10n.importFailedCheckContent}\n\n$e');
      return;
    }

    _error = null;
    _popOnce(_response);
  }

  void _cancelEdit() {
    _editController.text = _textBuffer.toString();
    setState(() {
      _isEditing = false;
      _error = null;
    });
  }

  void _popOnce([SchoolImportResponse? result]) {
    if (_hasPopped) {
      return;
    }
    _hasPopped = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = _isEditing
        ? '${l10n.schoolWebImportParsing} - ${l10n.editTimetable}'
        : l10n.schoolWebImportParsing;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            if (_isEditing) ...[
              Icon(Icons.edit_outlined, color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
            ] else if (_error != null) ...[
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: 8),
            ] else if (_isDone) ...[
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
            ] else ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(title)),
          ],
        ),
        content: ExpressiveDialogContent(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              Container(
                constraints: const BoxConstraints(maxHeight: 360),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isEditing
                    ? TextField(
                        controller: _editController,
                        inputFormatters: const [
                          Utf16CodeUnitLimitingTextInputFormatter(
                            SchoolImportStreamDialog.maxEditableCodeUnits,
                          ),
                        ],
                        maxLines: null,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _previewText.isNotEmpty
                              ? _previewText
                              : (_error != null
                                    ? l10n.importFailedCheckContent
                                    : l10n.schoolWebImportParsing),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              ExpressiveDialogActions(
                children: [
                  TextButton(
                    onPressed: () {
                      unawaited(_cancelSubscription());
                      _popOnce();
                    },
                    child: Text(l10n.cancel),
                  ),
                  if (_isEditing) ...[
                    OutlinedButton(
                      onPressed: _cancelEdit,
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: _confirmEdit,
                      child: Text(l10n.confirm),
                    ),
                  ] else ...[
                    OutlinedButton(
                      onPressed: _canEdit ? _enterEditMode : null,
                      child: Text(l10n.editTimetable),
                    ),
                    FilledButton(
                      onPressed: _isDone ? () => _popOnce(_response) : null,
                      child: Text(l10n.confirm),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
