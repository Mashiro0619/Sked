import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/school_import_api.dart';
import '../utils/text_input_limits.dart';

Map<String, dynamic>? _decodeSchoolImportObject(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      return null;
    }
    final result = <String, dynamic>{};
    for (final entry in decoded.entries) {
      if (entry.key is String) {
        result[entry.key as String] = entry.value;
      }
    }
    return result;
  } catch (_) {
    return null;
  }
}

/// Full-screen editor for the JSON returned by the school import parser.
///
/// The page intentionally owns only a draft. Cancelling or navigating back
/// leaves the parsed response in the underlying stream dialog untouched.
class SchoolImportResultEditorPage extends StatefulWidget {
  const SchoolImportResultEditorPage({
    super.key,
    required this.initialText,
    this.maxEditableCodeUnits = 64 * 1024,
  });

  final String initialText;
  final int maxEditableCodeUnits;

  @override
  State<SchoolImportResultEditorPage> createState() =>
      _SchoolImportResultEditorPageState();
}

class _SchoolImportResultEditorPageState
    extends State<SchoolImportResultEditorPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode(debugLabel: 'school-import-result-editor');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);

    final l10n = AppLocalizations.of(context);
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) {
      _showError(l10n.jsonContentEmpty);
      return;
    }

    final json = _decodeSchoolImportObject(rawText);
    if (json == null) {
      _showError(l10n.importFailedCheckContent);
      return;
    }

    if (!json.containsKey('timetable') &&
        !json.containsKey('name') &&
        !json.containsKey('courses')) {
      _showError(l10n.noImportableTimetables);
      return;
    }

    try {
      final response = SchoolImportApi.buildResponseFromDoneEvent(json);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(response);
    } catch (error) {
      _showError('${l10n.importFailedCheckContent}\n\n$error');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _error = message;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(l10n.schoolImportResultEditorTitle),
          actions: [
            IconButton(
              tooltip: l10n.confirm,
              onPressed: _isSubmitting ? null : _confirm,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 144),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !_isSubmitting,
                      autofocus: false,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      inputFormatters: [
                        Utf16CodeUnitLimitingTextInputFormatter(
                          widget.maxEditableCodeUnits,
                        ),
                      ],
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        labelText: l10n.schoolImportResultEditorTitle,
                        alignLabelWithHint: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
