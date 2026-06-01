import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../providers/timetable_provider.dart';
import '../services/school_import_api.dart';
import '../services/school_import_apply_service.dart';
import '../services/school_import_content_sanitizer.dart';
import '../theme/app_motion.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/school_import_stream_dialog.dart';
import '../widgets/school_web_import_result_sheet.dart';
import 'school_import_parser_settings_page.dart';

class SchoolHtmlImportPage extends StatefulWidget {
  const SchoolHtmlImportPage({
    super.key,
    this.initialContent = '',
    this.initialUrl = '',
    this.initialTitle = '',
    this.showReturnToWebPageButton = false,
    this.api,
  });

  final String initialContent;
  final String initialUrl;
  final String initialTitle;
  final bool showReturnToWebPageButton;
  final SchoolImportApi? api;

  @override
  State<SchoolHtmlImportPage> createState() => _SchoolHtmlImportPageState();
}

class _SchoolHtmlImportPageState extends State<SchoolHtmlImportPage> {
  late final SchoolImportApi _api;
  final SchoolImportApplyService _applyService =
      const SchoolImportApplyService();
  final TextEditingController _htmlController = TextEditingController();

  bool _isSubmitting = false;
  bool _isCompressed = false;
  bool _parserSettingsPageOpen = false;
  bool _returnToWebPagePopped = false;

  bool _isConfigured(TimetableProvider provider) {
    return provider.customSchoolImportBaseUrl.trim().isNotEmpty &&
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
    return l10n.schoolImportParserCustomConfigIncomplete;
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? const SchoolImportApi();
    if (widget.initialContent.isNotEmpty) {
      _htmlController.text = widget.initialContent;
    }
  }

  @override
  void dispose() {
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
                  onChanged: (_) {
                    if (_isCompressed) {
                      setState(() => _isCompressed = false);
                    }
                  },
                  minLines: 12,
                  maxLines: 20,
                  decoration: InputDecoration(
                    labelText: l10n.schoolHtmlImportHtmlLabel,
                    hintText: l10n.schoolHtmlImportHtmlHint,
                    prefixIcon: const Icon(Icons.code),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.schoolHtmlImportNonHtmlHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: _isSubmitting ? null : _compressContent,
                  icon: Icon(
                    _isCompressed ? Icons.check_circle_outline : Icons.compress,
                  ),
                  label: Text(
                    _isCompressed
                        ? l10n.schoolHtmlImportCompressed
                        : l10n.schoolHtmlImportCompress,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSubmitting || !_isCompressed ? null : _submit,
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

  Future<void> _compressContent() async {
    final l10n = AppLocalizations.of(context);
    final html = _htmlController.text.trim();
    if (html.isEmpty) {
      _showMessage(l10n.schoolHtmlImportEmpty);
      return;
    }
    final sanitizedContent = SchoolImportContentSanitizer.sanitize(html);
    if (sanitizedContent.isEmpty) {
      _showMessage(l10n.schoolHtmlImportEmpty);
      return;
    }
    _htmlController.value = TextEditingValue(
      text: sanitizedContent,
      selection: TextSelection.collapsed(offset: sanitizedContent.length),
    );
    setState(() => _isCompressed = true);
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
    if (!_isCompressed) {
      return l10n.schoolHtmlImportCompressFirst;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final provider = context.read<TimetableProvider>();
    final validationMessage = _validateBeforeSubmit(provider, l10n);
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    final localeCode = provider.localeCode;
    final canReplaceCurrent = provider.activeTimetableOrNull != null;
    final parserSettings = provider.schoolImportParserSettings;
    final sanitizedContent = _htmlController.text.trim();

    setState(() => _isSubmitting = true);

    final httpClient = http.Client();
    SchoolImportResponse? response;
    Object? streamError;
    try {
      try {
        final stream = _api.importCurrentPageStream(
          SchoolImportPagePayload(
            url: widget.initialUrl,
            title: widget.initialTitle,
            html: sanitizedContent,
            locale: localeCode,
            sourceHint: parserSettings.source,
          ),
          parserSettings: parserSettings,
          client: httpClient,
        );

        if (!mounted) return;
        response = await showDialog<SchoolImportResponse>(
          context: context,
          barrierDismissible: false,
          builder: (_) => SchoolImportStreamDialog(stream: stream),
        );
      } finally {
        httpClient.close();
      }
    } catch (error) {
      streamError = error;
    }

    if (!mounted) return;
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
    final importResult = await showModalBottomSheet<SchoolImportApplyRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      sheetAnimationStyle: AppMotion.sheetAnimationStyle,
      builder: (_) => SchoolWebImportResultSheet(
        response: finalResponse,
        canReplaceCurrent: canReplaceCurrent,
        periodTimeSets: periodTimeSets,
        initialPeriodTimeSetId: selectedPeriodTimeSetId,
        provider: provider,
      ),
    );
    if (importResult == null || !mounted) {
      return;
    }
    setState(() => _isSubmitting = true);
    Object? applyError;
    try {
      await _applyService.apply(provider, importResult);
    } catch (error) {
      applyError = error;
    }
    if (!mounted) {
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
