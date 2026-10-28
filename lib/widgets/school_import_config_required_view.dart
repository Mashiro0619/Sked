import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/app_scope.dart';
import '../screens/school_import_parser_settings_page.dart';
import '../screens/timetable_import_flow.dart';
import '../services/school_import_api.dart';

/// Offers local timetable paths before explaining the optional parser setup.
///
/// Both school import entry points (HTML paste and in-app web import) gate on
/// the same parser configuration, so they share this view instead of keeping
/// two prompts that drift apart in wording and layout.
class SchoolImportConfigRequiredView extends StatefulWidget {
  const SchoolImportConfigRequiredView({super.key, required this.message});

  /// Built with [schoolImportConfigMessage].
  final String message;

  @override
  State<SchoolImportConfigRequiredView> createState() =>
      _SchoolImportConfigRequiredViewState();
}

class _SchoolImportConfigRequiredViewState
    extends State<SchoolImportConfigRequiredView> {
  bool _isBusy = false;

  Future<void> _importFile() =>
      _runAction(() => TimetableImportFlow.importTimetables(context));

  Future<void> _openSettings() => _runAction(() async {
    final scope = AppScope.capture(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            scope?.wrap(const SchoolImportParserSettingsPage()) ??
            const SchoolImportParserSettingsPage(),
      ),
    );
  });

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            // Subtract the padding this scroll view adds, otherwise the content
            // is always taller than the viewport and the page scrolls by 48px
            // with nothing to reveal.
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 48),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.schoolImportWithoutApiTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.schoolImportManualHint,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: FilledButton.icon(
                          onPressed: _isBusy ? null : _importFile,
                          icon: _isBusy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_open_outlined),
                          label: Text(l10n.schoolImportFileAction),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 24),
                    Text(
                      l10n.schoolImportParserSettingsTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.schoolImportAiHint,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: OutlinedButton.icon(
                          onPressed: _isBusy ? null : _openSettings,
                          icon: const Icon(Icons.settings_outlined),
                          label: Text(l10n.schoolImportConfigureAction),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Whether the custom parser has everything it needs to run.
bool isSchoolImportParserConfigured(AiApiSettings? settings) {
  if (settings == null) return false;
  return isValidCustomOpenAiBaseUrl(settings.customBaseUrl.trim()) &&
      settings.customApiKey.trim().isNotEmpty &&
      settings.customModel.trim().isNotEmpty;
}

/// Picks the reason to show when [isSchoolImportParserConfigured] is false.
String schoolImportConfigMessage(
  AiApiSettings? settings,
  AppLocalizations l10n,
) {
  final baseUrl = settings?.customBaseUrl.trim() ?? '';
  if (baseUrl.isNotEmpty && !isValidCustomOpenAiBaseUrl(baseUrl)) {
    return l10n.schoolImportParserBaseUrlInvalid;
  }
  return l10n.schoolImportParserCustomConfigIncomplete;
}
