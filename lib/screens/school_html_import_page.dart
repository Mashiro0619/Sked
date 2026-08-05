import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../providers/timetable_provider.dart';
import '../services/school_import_api.dart';
import '../services/school_import_content_sanitizer.dart';
import '../services/school_import_http_consent.dart';
import '../services/school_import_workflow.dart';
import '../utils/text_input_limits.dart';
import '../widgets/app_modal_sheet.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/school_import_stream_dialog.dart';
import '../widgets/school_import_http_consent_dialog.dart';
import '../widgets/school_web_import_result_sheet.dart';
import 'school_import_parser_settings_page.dart';

class SchoolHtmlImportPage extends StatefulWidget {
  const SchoolHtmlImportPage({
    super.key,
    this.initialContent = '',
    this.initialUrl = '',
    this.initialTitle = '',
    this.initialContentTruncated = false,
    this.showReturnToWebPageButton = false,
    this.api,
    this.httpConsentStore,
    this.httpClientFactory,
  });

  final String initialContent;
  final String initialUrl;
  final String initialTitle;
  final bool initialContentTruncated;
  final bool showReturnToWebPageButton;
  final SchoolImportApi? api;
  final SchoolImportHttpConsentStore? httpConsentStore;
  final http.Client Function()? httpClientFactory;

  @override
  State<SchoolHtmlImportPage> createState() => _SchoolHtmlImportPageState();
}

class _SchoolHtmlImportPageState extends State<SchoolHtmlImportPage> {
  static const int _maxRememberedTruncatedContents = 8;

  late final SchoolImportWorkflow _workflow;
  final TextEditingController _htmlController = TextEditingController();

  bool _isSubmitting = false;
  bool _isContentPrepared = false;
  bool _parserSettingsPageOpen = false;
  bool _returnToWebPagePopped = false;
  late bool _contentWasTruncated;
  late final TextInputFormatter _boundedInputFormatter;
  late final Utf16CodeUnitLimitingTextInputFormatter _codeUnitInputFormatter;
  final List<String> _rememberedTruncatedContents = [];
  bool _lastFormattedContentWasTruncated = false;
  bool _truncationUpdateScheduled = false;
  int _submissionGeneration = 0;

  bool _isConfigured(TimetableProvider provider) {
    return isValidCustomOpenAiBaseUrl(provider.customSchoolImportBaseUrl) &&
        provider.customSchoolImportApiKey.trim().isNotEmpty &&
        provider.customSchoolImportModel.trim().isNotEmpty;
  }

  String _buildParserSummary(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final model = provider.customSchoolImportModel.trim();
    return model.isEmpty
        ? l10n.schoolImportParserSourceCustomOpenAi
        : l10n.schoolImportParserCurrentSourceCustom(model);
  }

  String _buildConfigMessage(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final baseUrl = provider.customSchoolImportBaseUrl.trim();
    if (baseUrl.isNotEmpty && !isValidCustomOpenAiBaseUrl(baseUrl)) {
      return l10n.schoolImportParserBaseUrlInvalid;
    }
    return l10n.schoolImportParserCustomConfigIncomplete;
  }

  @override
  void initState() {
    super.initState();
    _workflow = SchoolImportWorkflow(
      api: widget.api ?? const SchoolImportApi(),
      httpClientFactory: widget.httpClientFactory,
    );
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
  void dispose() {
    _submissionGeneration += 1;
    _workflow.cancelActiveParse();
    _htmlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<TimetableProvider>();
    final isConfigured = _isConfigured(provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.schoolHtmlImportPageTitle),
        actions: [
          if (widget.showReturnToWebPageButton)
            TextButton(
              onPressed: _returnToWebPagePopped ? null : _returnToWebPageOnce,
              child: Text(l10n.schoolHtmlImportReturnToWebPage),
            ),
        ],
      ),
      body: !isConfigured
          ? _buildConfigMissingState(provider, l10n)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ParserSettingsTile(
                  summary: _buildParserSummary(provider, l10n),
                  enabled: !_parserSettingsPageOpen,
                  onTap: _parserSettingsPageOpen
                      ? null
                      : _openParserSettingsPage,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _htmlController,
                  enabled: !_isSubmitting,
                  inputFormatters: [_boundedInputFormatter],
                  onChanged: _handleContentChanged,
                  minLines: 12,
                  maxLines: 20,
                  decoration: InputDecoration(
                    labelText: l10n.schoolHtmlImportHtmlLabel,
                    hintText: l10n.schoolHtmlImportHtmlHint,
                    prefixIcon: const Icon(Icons.code),
                    alignLabelWithHint: true,
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
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.schoolImportContentTruncated,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.schoolHtmlImportNonHtmlHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: _isSubmitting ? null : _prepareContent,
                  icon: Icon(
                    _isContentPrepared
                        ? Icons.check_circle_outline
                        : Icons.auto_fix_high_outlined,
                  ),
                  label: Text(
                    _isContentPrepared
                        ? l10n.schoolHtmlImportCompressed
                        : l10n.schoolHtmlImportCompress,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined),
                  label: Text(l10n.schoolHtmlImportSubmit),
                ),
              ],
            ),
    );
  }

  Widget _buildConfigMissingState(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    return ExpressiveEmptyState(
      icon: Icons.tune_outlined,
      title: l10n.schoolImportParserSettingsTitle,
      message: _buildConfigMessage(provider, l10n),
      actions: [
        FilledButton.icon(
          onPressed: _parserSettingsPageOpen ? null : _openParserSettingsPage,
          icon: const Icon(Icons.tune_outlined),
          label: Text(l10n.schoolImportParserSettingsTitle),
        ),
      ],
    );
  }

  bool _prepareContent() {
    final l10n = AppLocalizations.of(context);
    final sourceContent = _htmlController.text.trim();
    if (sourceContent.isEmpty) {
      _showMessage(l10n.schoolHtmlImportEmpty);
      return false;
    }
    final sanitization = _workflow.prepareContent(sourceContent);
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
        _contentWasTruncated = _lastFormattedContentWasTruncated;
      });
    }
  }

  Future<void> _openParserSettingsPage() async {
    if (_parserSettingsPageOpen) {
      return;
    }
    setState(() => _parserSettingsPageOpen = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SchoolImportParserSettingsPage(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _parserSettingsPageOpen = false);
      }
    }
  }

  void _returnToWebPageOnce() {
    if (_returnToWebPagePopped) {
      return;
    }
    setState(() => _returnToWebPagePopped = true);
    Navigator.of(context).pop();
  }

  String? _validateBeforeSubmit(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final html = _htmlController.text.trim();
    if (html.isEmpty) {
      return l10n.schoolHtmlImportEmpty;
    }
    if (!_isConfigured(provider)) {
      return _buildConfigMessage(provider, l10n);
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final submissionGeneration = ++_submissionGeneration;
    final l10n = AppLocalizations.of(context);
    final provider = context.read<TimetableProvider>();
    final validationMessage = _validateBeforeSubmit(provider, l10n);
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }
    if (!_isContentPrepared && !_prepareContent()) {
      return;
    }

    final localeCode = provider.localeCode;
    final canReplaceCurrent = provider.activeTimetableOrNull != null;
    final parserSettings = provider.schoolImportParserSettings;
    final sanitizedContent = _htmlController.text.trim();

    setState(() => _isSubmitting = true);

    final confirmed = await confirmSchoolImportHttpEndpoint(
      context: context,
      baseUrl: parserSettings.customBaseUrl,
      consentStore:
          widget.httpConsentStore ?? SchoolImportHttpConsentStore.session,
    );
    if (!confirmed ||
        !mounted ||
        submissionGeneration != _submissionGeneration) {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      return;
    }

    SchoolImportResponse? response;
    Object? streamError;
    try {
      response = await _workflow.parse(
        payload: SchoolImportPagePayload(
          url: widget.initialUrl,
          title: widget.initialTitle,
          html: sanitizedContent,
          locale: localeCode,
          sourceHint: parserSettings.source,
        ),
        parserSettings: parserSettings,
        presentStream: (stream) {
          if (!mounted || submissionGeneration != _submissionGeneration) {
            return Future<SchoolImportResponse?>.value();
          }
          return showDialog<SchoolImportResponse>(
            context: context,
            barrierDismissible: false,
            builder: (_) => SchoolImportStreamDialog(stream: stream),
          );
        },
      );
    } catch (error) {
      streamError = error;
    }

    if (!mounted || submissionGeneration != _submissionGeneration) return;
    setState(() => _isSubmitting = false);

    if (streamError != null) {
      _showMessage(mapSchoolImportApplyError(streamError, l10n));
      return;
    }

    if (response == null) {
      return;
    }
    final finalResponse = response;

    final periodTimeSets = provider.periodTimeSets;
    final selectedPeriodTimeSetId =
        provider.activePeriodTimeSetOrNull?.id ??
        (periodTimeSets.isEmpty ? '' : periodTimeSets.first.id);
    final importResult = await showAppModalSheet<SchoolImportApplyRequest>(
      context: context,
      maxWidth: appSheetWidthMedium,
      builder: (_) => SchoolWebImportResultSheet(
        response: finalResponse,
        canReplaceCurrent: canReplaceCurrent,
        periodTimeSets: periodTimeSets,
        initialPeriodTimeSetId: selectedPeriodTimeSetId,
        provider: provider,
      ),
    );
    if (importResult == null ||
        !mounted ||
        submissionGeneration != _submissionGeneration) {
      return;
    }
    setState(() => _isSubmitting = true);
    Object? applyError;
    try {
      await _workflow.apply(provider, importResult);
    } catch (error) {
      applyError = error;
    }
    if (!mounted || submissionGeneration != _submissionGeneration) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (applyError != null) {
      _showMessage(mapSchoolImportApplyError(applyError, l10n));
      return;
    }
    _showMessage(l10n.schoolWebImportSuccess);
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

@visibleForTesting
String mapSchoolImportApplyError(Object error, AppLocalizations l10n) {
  if (error is FormatException) {
    return error.message;
  }
  return l10n.importFailedCheckContent;
}

class _ParserSettingsTile extends StatelessWidget {
  const _ParserSettingsTile({
    required this.summary,
    required this.enabled,
    required this.onTap,
  });

  final String summary;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final contentColor = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: ShapeDecoration(
                  color: colors.primary.withValues(
                    alpha: enabled ? 0.10 : 0.05,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Icon(
                  Icons.tune_outlined,
                  color: enabled ? colors.primary : secondaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.schoolImportParserSettingsTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: contentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: secondaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
