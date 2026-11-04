import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../agent/agent_application.dart';
import '../agent/imports/school_web_handoff.dart';
import '../application/operation_contracts.dart';
import '../controllers/app_data_clear_controller.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import '../l10n/app_localizations.dart';
import '../models/app_mode.dart';
import '../providers/app_scope.dart';
import '../services/school_import_content_sanitizer.dart';
import '../utils/text_input_limits.dart';
import '../widgets/adaptive_form_columns.dart';
import '../widgets/adaptive_navigation_scope.dart';
import '../widgets/desktop_window_host.dart';
import '../widgets/sked_task_route.dart';
import '../widgets/sked_task_session.dart';
import '../widgets/workspace_route_lifecycle.dart';
import 'agent_settings_page.dart';
import 'workspace_features_page.dart';

class SchoolHtmlImportPage extends StatefulWidget {
  const SchoolHtmlImportPage({
    super.key,
    this.initialContent = '',
    this.initialUrl = '',
    this.initialTitle = '',
    this.initialContentTruncated = false,
    this.showReturnToWebPageButton = false,
    this.contentPreparer,
    this.handoffController,
    this.openConversation,
    this.openConfiguration,
    this.initialCapturedAt,
    this.initialDatasetGeneration,
    this.targetTimetableId,
  });

  final String initialContent;
  final String initialUrl;
  final String initialTitle;
  final bool initialContentTruncated;
  final bool showReturnToWebPageButton;
  final SchoolWebContentPreparer? contentPreparer;
  final SchoolWebHandoffController? handoffController;
  final Future<void> Function(BuildContext context, String conversationId)?
  openConversation;
  final Future<void> Function(
    BuildContext context,
    SchoolWebHandoffReadiness readiness,
  )?
  openConfiguration;
  final DateTime? initialCapturedAt;
  final String? initialDatasetGeneration;
  final String? targetTimetableId;

  @override
  State<SchoolHtmlImportPage> createState() => _SchoolHtmlImportPageState();
}

class _SchoolHtmlImportPageState extends State<SchoolHtmlImportPage>
    with WorkspaceRouteLifecycle<SchoolHtmlImportPage> {
  @override
  AppMode get routeWorkspace => AppMode.student;
  @override
  void workspaceDisabled() {
    _submissionGeneration += 1;
  }

  @override
  Future<bool> prepareWorkspaceDisable() async =>
      (_htmlController.text.trim().isEmpty ||
      await confirmWorkspaceDraftDiscard(context));

  static const int _maxRememberedTruncatedContents = 8;

  SchoolWebHandoffController? _handoff;
  String? _datasetGeneration;
  late final DateTime _capturedAt;
  final TextEditingController _htmlController = TextEditingController();

  bool _isSubmitting = false;
  bool _isPreparingContent = false;
  bool _isContentPrepared = false;
  bool _returnToWebPagePopped = false;
  late bool _contentWasTruncated;
  late final TextInputFormatter _boundedInputFormatter;
  late final Utf16CodeUnitLimitingTextInputFormatter _codeUnitInputFormatter;
  final List<String> _rememberedTruncatedContents = [];
  bool _lastFormattedContentWasTruncated = false;
  bool _truncationUpdateScheduled = false;
  int _submissionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _capturedAt = widget.initialCapturedAt ?? DateTime.now().toUtc();
    _codeUnitInputFormatter = const Utf16CodeUnitLimitingTextInputFormatter(
      SchoolImportContentSanitizer.maxInputLength,
    );
    _boundedInputFormatter = TextInputFormatter.withFunction(
      _formatBoundedInput,
    );
    _contentWasTruncated = widget.initialContentTruncated;
    if (widget.initialContent.isNotEmpty) {
      final initialContent = widget.initialContent;
      if (initialContent.length > SchoolImportContentSanitizer.maxInputLength) {
        _htmlController.text = truncateUtf16CodeUnits(
          initialContent,
          SchoolImportContentSanitizer.maxInputLength,
        );
        _contentWasTruncated = true;
      } else {
        _htmlController.text = initialContent;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handoff != null) return;
    final application = context.read<AgentApplication?>();
    _handoff =
        widget.handoffController ??
        (application == null
            ? null
            : SchoolWebHandoffController(
                repository: application.conversations,
                readSettings: () => application.settings,
                initialize: application.initialize,
                startHandoff: application.runtime.startHandoff,
                readGeneration: () => application.mutations.generation,
              ));
    _datasetGeneration ??=
        widget.initialDatasetGeneration ?? _handoff?.readGeneration();
  }

  @override
  void dispose() {
    _submissionGeneration += 1;
    _htmlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!routeWorkspaceEnabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    context.watch<AgentApplication?>();
    return PopScope<SchoolWebHandoffRouteResult>(
      canPop: true,
      child: Scaffold(
        appBar: WorkbenchAppBar(
          automaticallyImplyLeading: !AdaptiveNavigationScope.isWide(context),
          title: Text(l10n.schoolWebAgentReviewTitle),
          actions: [
            if (widget.showReturnToWebPageButton)
              TextButton(
                onPressed: _returnToWebPagePopped ? null : _returnToWebPageOnce,
                child: Text(l10n.schoolHtmlImportReturnToWebPage),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 600
                  ? 16.0
                  : 24.0;
              // Scaffold has already removed the keyboard from these
              // constraints; subtracting viewInsets again wastes editor space.
              final availableHeight = constraints.maxHeight;
              final editorHeight = _editorHeight(
                availableHeight: availableHeight,
                isNarrow: constraints.maxWidth < 600,
              );
              final maxContentWidth = constraints.maxWidth < 840
                  ? 720.0
                  : 1280.0;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  24,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: AdaptiveFormColumns(
                        primary: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: editorHeight,
                              child: TextField(
                                key: const ValueKey('school-web-source-editor'),
                                controller: _htmlController,
                                enabled: !_isSubmitting && !_isPreparingContent,
                                inputFormatters: [_boundedInputFormatter],
                                onChanged: _handleContentChanged,
                                expands: true,
                                maxLines: null,
                                minLines: null,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: InputDecoration(
                                  labelText: l10n.schoolHtmlImportHtmlLabel,
                                  hintText: l10n.schoolHtmlImportHtmlHint,
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 48,
                                    maxWidth: 48,
                                    minHeight: 48,
                                  ),
                                  prefixIcon: const Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 12),
                                      child: Icon(Icons.code),
                                    ),
                                  ),
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ),
                            if (_contentWasTruncated) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .tertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.schoolImportContentTruncated,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              l10n.schoolWebAgentReviewHint,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        secondary: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.initialTitle.isNotEmpty)
                              Text(
                                widget.initialTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            if (widget.initialUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 16,
                                ),
                                child: SelectableText(
                                  redactSchoolWebSourceUrl(widget.initialUrl) ??
                                      '',
                                ),
                              ),
                            if (_handoff?.readiness !=
                                SchoolWebHandoffReadiness.ready) ...[
                              Text(
                                _handoff?.readiness ==
                                        SchoolWebHandoffReadiness.unconfigured
                                    ? l10n.agentConfigureFirst
                                    : l10n.agentDisabled,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : _openConfiguration,
                                child: Text(
                                  _handoff?.readiness ==
                                          SchoolWebHandoffReadiness.unconfigured
                                      ? l10n.agentModelSettings
                                      : l10n.workspaceFeatures,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_handoff?.readiness ==
                                SchoolWebHandoffReadiness.ready) ...[
                              Text(l10n.agentEndpoint),
                              SelectableText(
                                redactSchoolWebSourceUrl(
                                      _handoff!.readSettings().endpoint,
                                    ) ??
                                    '',
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildImportActions(
                              l10n,
                              useHorizontalLayout: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _editorHeight({
    required double availableHeight,
    required bool isNarrow,
  }) {
    final minimum = isNarrow ? 200.0 : 240.0;
    final maximum = isNarrow ? 420.0 : 520.0;
    if (availableHeight <= 0) {
      return minimum;
    }
    // Keep the actions in the initial viewport when possible, while leaving
    // enough room for real-world pasted HTML and text.
    final preferred = availableHeight * (isNarrow ? 0.45 : 0.55);
    final spaceAware = availableHeight - 230;
    return preferred
        .clamp(minimum, math.max(minimum, maximum))
        .clamp(minimum, math.max(minimum, spaceAware))
        .toDouble();
  }

  Widget _buildImportActions(
    AppLocalizations l10n, {
    required bool useHorizontalLayout,
  }) {
    final maintenance = context.watch<AppDataMaintenance>();
    final dataClear = context.watch<AppDataClearController>();
    final workspaceView = context.watch<WorkspaceViewState>();
    final prepareButton = FilledButton.tonalIcon(
      key: const ValueKey('school-web-compress'),
      onPressed: _isSubmitting || _isPreparingContent ? null : _prepareContent,
      icon: _isPreparingContent
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _isContentPrepared
                  ? Icons.check_circle_outline
                  : Icons.auto_fix_high_outlined,
            ),
      label: Text(
        _isContentPrepared
            ? l10n.schoolHtmlImportCompressed
            : l10n.schoolHtmlImportCompress,
      ),
    );
    final submitButton = FilledButton.icon(
      key: const ValueKey('school-web-handoff'),
      onPressed:
          !_isContentPrepared ||
              _isSubmitting ||
              _isPreparingContent ||
              maintenance.isReserved ||
              dataClear.isActive ||
              !workspaceView.isEnabled(AppMode.student)
          ? null
          : _submit,
      icon: _isSubmitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined),
      label: Text(l10n.schoolWebAgentHandoff),
    );
    final Widget actions;
    if (useHorizontalLayout) {
      actions = Row(
        children: [
          Expanded(child: prepareButton),
          const SizedBox(width: 12),
          Expanded(child: submitButton),
        ],
      );
    } else {
      actions = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [prepareButton, const SizedBox(height: 12), submitButton],
      );
    }
    return actions;
  }

  Future<bool> _prepareContent() async {
    if (_isPreparingContent) return false;
    final l10n = AppLocalizations.of(context);
    final sourceContent = _htmlController.text.trim();
    if (sourceContent.isEmpty) {
      _showMessage(l10n.schoolHtmlImportEmpty);
      return false;
    }
    final maintenance = context.read<AppDataMaintenance>();
    final workspaceView = context.read<WorkspaceViewState>();
    final workspaces = context.read<WorkspaceCommands>();
    final generation = _submissionGeneration;
    final owner = SkedTaskSession(
      maintenance: maintenance,
      workspaceView: workspaceView,
      workspaces: workspaces,
      workspace: AppMode.student,
      ownerRoute: ModalRoute.of(context),
      isOwnerActive: () => mounted && generation == _submissionGeneration,
    );
    setState(() => _isPreparingContent = true);
    try {
      final sanitization =
          await (widget.contentPreparer ?? prepareSchoolWebContent)(
            sourceContent,
          );
      if (!mounted ||
          !owner.isCurrent ||
          sourceContent != _htmlController.text.trim()) {
        return false;
      }
      final sanitizedContent = sanitization.content;
      if (sanitizedContent.isEmpty) {
        _showMessage(l10n.schoolHtmlImportEmpty);
        return false;
      }
      _htmlController.value = TextEditingValue(
        text: sanitizedContent,
        selection: TextSelection.collapsed(offset: sanitizedContent.length),
      );
      final wasTruncated = sanitization.wasTruncated;
      if (!_isContentPrepared || (wasTruncated && !_contentWasTruncated)) {
        setState(() {
          _isContentPrepared = true;
          _contentWasTruncated = _contentWasTruncated || wasTruncated;
        });
      }
      return true;
    } catch (_) {
      if (mounted && owner.isCurrent) {
        _showMessage(l10n.importFailedCheckContent);
      }
      return false;
    } finally {
      owner.dispose();
      if (mounted) setState(() => _isPreparingContent = false);
    }
  }

  TextEditingValue _formatBoundedInput(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final limited = _codeUnitInputFormatter.formatEditUpdate(
      oldValue,
      newValue,
    );
    if (oldValue.text != newValue.text) {
      final inputWasTruncated = limited.text.length != newValue.text.length;
      final oldSelection = oldValue.selection;
      final replacesAllExistingContent =
          oldValue.text.isNotEmpty &&
          oldSelection.isValid &&
          oldSelection.start == 0 &&
          oldSelection.end == oldValue.text.length;
      final canClearTruncation =
          newValue.text.isEmpty || replacesAllExistingContent;
      if (_contentWasTruncated && canClearTruncation) {
        _rememberTruncatedContent(oldValue.text);
      }
      if (inputWasTruncated) {
        _rememberTruncatedContent(limited.text);
      }
      _lastFormattedContentWasTruncated =
          inputWasTruncated ||
          _isRememberedTruncatedContent(limited.text) ||
          (_contentWasTruncated && !canClearTruncation);
      if (inputWasTruncated) _scheduleTruncationIndicator();
    }
    return limited;
  }

  void _rememberTruncatedContent(String content) {
    if (content.isEmpty) return;
    _rememberedTruncatedContents.remove(content);
    _rememberedTruncatedContents.add(content);
    if (_rememberedTruncatedContents.length > _maxRememberedTruncatedContents) {
      _rememberedTruncatedContents.removeAt(0);
    }
  }

  bool _isRememberedTruncatedContent(String content) {
    if (content.isEmpty) return false;
    return _rememberedTruncatedContents.any(
      (remembered) =>
          remembered.length == content.length && remembered == content,
    );
  }

  void _scheduleTruncationIndicator() {
    if (_truncationUpdateScheduled) return;
    _truncationUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _truncationUpdateScheduled = false;
      if (mounted &&
          _lastFormattedContentWasTruncated &&
          !_contentWasTruncated) {
        setState(() => _contentWasTruncated = true);
      }
    });
  }

  void _handleContentChanged(String _) {
    if (_isContentPrepared ||
        _contentWasTruncated != _lastFormattedContentWasTruncated) {
      setState(() {
        _isContentPrepared = false;
        _contentWasTruncated =
            widget.initialContentTruncated || _lastFormattedContentWasTruncated;
      });
    }
  }

  void _returnToWebPageOnce() {
    if (_returnToWebPagePopped) {
      return;
    }
    setState(() => _returnToWebPagePopped = true);
    completeSkedTaskRoute<SchoolWebHandoffRouteResult>(context);
  }

  Future<void> _openConfiguration() async {
    if (_isSubmitting) return;
    final readiness = _handoff?.readiness ?? SchoolWebHandoffReadiness.disabled;
    if (widget.openConfiguration != null) {
      await widget.openConfiguration!(context, readiness);
    } else if (readiness == SchoolWebHandoffReadiness.disabled) {
      final scope = AppScope.capture(context);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              scope?.wrap(const WorkspaceFeaturesPage()) ??
              const WorkspaceFeaturesPage(),
        ),
      );
    } else {
      await AgentSettingsPage.open(context);
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isPreparingContent || !_isContentPrepared) return;
    final handoff = _handoff;
    if (handoff == null ||
        handoff.readiness != SchoolWebHandoffReadiness.ready) {
      await _openConfiguration();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final maintenance = context.read<AppDataMaintenance>();
    final dataClear = context.read<AppDataClearController>();
    final workspaceView = context.read<WorkspaceViewState>();
    if (maintenance.isReserved || dataClear.isActive) {
      _showMessage(l10n.backupRestoreInProgressMessage);
      return;
    }
    final submissionGeneration = ++_submissionGeneration;
    final owner = SkedTaskSession(
      maintenance: maintenance,
      workspaceView: workspaceView,
      workspaces: context.read<WorkspaceCommands>(),
      workspace: AppMode.student,
      ownerRoute: ModalRoute.of(context),
      isOwnerActive: () =>
          mounted && submissionGeneration == _submissionGeneration,
    );
    setState(() => _isSubmitting = true);
    try {
      final result = await handoff.handoff(
        SchoolWebReviewedDraft(
          content: _htmlController.text.trim(),
          datasetGeneration: _datasetGeneration!,
          capturedAt: _capturedAt,
          localeCode: context.read<SettingsViewState>().localeCode,
          title: widget.initialTitle,
          url: widget.initialUrl,
          targetTimetableId: widget.targetTimetableId,
          truncated: _contentWasTruncated,
        ),
        isCurrent: () => owner.isCurrent,
      );
      if (!mounted || !owner.isCurrent) return;
      if (owner.ownerRoute?.isCurrent == true) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
      if (widget.openConversation != null) {
        await widget.openConversation!(context, result.conversationId);
      } else {
        completeSkedTaskRoute(
          context,
          SchoolWebHandoffRouteResult(conversationId: result.conversationId),
        );
      }
    } on OperationProblem catch (error) {
      if (mounted) {
        _showMessage(
          error.code == OperationErrorCode.disabled
              ? l10n.agentDisabled
              : l10n.agentOperationFailed,
        );
      }
    } catch (_) {
      if (mounted) _showMessage(l10n.agentOperationFailed);
    } finally {
      owner.dispose();
      if (mounted) setState(() => _isSubmitting = false);
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
