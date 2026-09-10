import '../widgets/desktop_window_host.dart';
import '../widgets/editor_exit_guard.dart';
import '../widgets/school_import_summary_preview.dart';
import '../widgets/workbench_layout_policy.dart';
import '../widgets/workspace_route_lifecycle.dart';
import '../models/app_mode.dart';

import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
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

/// The validated value returned by the full-screen parsed-result editor.
///
/// [rawText] deliberately keeps the user's exact draft (including whitespace
/// and unknown fields).  The parsed [response] is used by the import flow,
/// while the original text can be shown again or retained for diagnostics.
class SchoolImportResultEditorOutcome extends SchoolImportResponse {
  SchoolImportResultEditorOutcome({
    required SchoolImportResponse response,
    required this.rawText,
  }) : response = response,
       super(meta: response.meta, timetable: response.timetable);

  final SchoolImportResponse response;
  final String rawText;
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
    extends State<SchoolImportResultEditorPage>
    with
        WorkspaceRouteLifecycle<SchoolImportResultEditorPage>,
        EditorExitGuard<SchoolImportResultEditorPage> {
  @override
  AppMode get routeWorkspace => AppMode.student;

  @override
  Future<bool> prepareWorkspaceDisable() async => !_isSubmitting;

  @override
  AppMode get editorWorkspace => AppMode.student;
  @override
  String get draftFingerprint => _controller.text;
  @override
  bool get exitBlocked => _isSubmitting || _closing;
  @override
  void closeEditor() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _error;
  bool _isSubmitting = false;
  bool _closing = false;
  Timer? _previewTimer;
  SchoolImportResponse? _preview;

  SchoolImportResponse? _parsePreview() {
    final json = _decodeSchoolImportObject(_controller.text);
    if (json == null) return null;
    try {
      return SchoolImportApi.buildResponseFromDoneEvent(json);
    } catch (_) {
      return null;
    }
  }

  void _updatePreview(String _) {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && routeWorkspaceEnabled) {
        setState(() => _preview = _parsePreview());
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _preview = _parsePreview();
    initializeDraftGuard();
    _focusNode = FocusNode(debugLabel: 'school-import-result-editor');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
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
      _closing = true;
      Navigator.of(context).pop(
        SchoolImportResultEditorOutcome(
          response: response,
          rawText: _controller.text,
        ),
      );
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
    if (!routeWorkspaceEnabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSubmitting) unawaited(requestEditorExit());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: WorkbenchAppBar(
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      final split = WorkbenchLayoutPolicy.formCanSplit(
                        constraints.maxWidth,
                        scale,
                        navigation: 360,
                        content: 624,
                      );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                enabled: !_isSubmitting,
                                autofocus: false,
                                onChanged: _updatePreview,
                                expands: true,
                                maxLines: null,
                                minLines: null,
                                inputFormatters: [
                                  Utf16CodeUnitLimitingTextInputFormatter(
                                    widget.maxEditableCodeUnits,
                                  ),
                                ],
                                style: theme.textTheme.bodyMedium?.copyWith(
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
                          SizedBox(width: split ? 24 : 0),
                          SizedBox(
                            width: split
                                ? 360 * WorkbenchLayoutPolicy.textFactor(scale)
                                : 0,
                            child: Offstage(
                              offstage: !split,
                              child: ExcludeFocus(
                                excluding: !split,
                                child: SingleChildScrollView(
                                  key: const ValueKey(
                                    'school-import-json-preview',
                                  ),
                                  child: _preview == null
                                      ? Text(l10n.noImportableTimetables)
                                      : SchoolImportSummaryPreview(
                                          response: _preview!,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
