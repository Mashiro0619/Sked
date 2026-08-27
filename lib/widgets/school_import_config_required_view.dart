import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../screens/school_import_parser_settings_page.dart';
import '../services/school_import_api.dart';

/// Explains why the custom parser cannot run yet and offers the shortcut to fix
/// it.
///
/// Both school import entry points (HTML paste and in-app web import) gate on
/// the same parser configuration, so they share this view instead of keeping
/// two prompts that drift apart in wording and layout.
class SchoolImportConfigRequiredView extends StatelessWidget {
  const SchoolImportConfigRequiredView({super.key, required this.message});

  /// Built with [schoolImportConfigMessage].
  final String message;

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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.tune_outlined, size: 28, color: colors.primary),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // FilledButton is 40dp tall by default; hold the 48dp
                    // minimum touch target this prompt's only action needs.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const SchoolImportParserSettingsPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined),
                        label: Text(l10n.openSettings),
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
bool isSchoolImportParserConfigured(TimetableProvider? provider) {
  if (provider == null) {
    return false;
  }
  return isValidCustomOpenAiBaseUrl(
        provider.customSchoolImportBaseUrl.trim(),
      ) &&
      provider.customSchoolImportApiKey.trim().isNotEmpty &&
      provider.customSchoolImportModel.trim().isNotEmpty;
}

/// Picks the reason to show when [isSchoolImportParserConfigured] is false.
String schoolImportConfigMessage(
  TimetableProvider? provider,
  AppLocalizations l10n,
) {
  final baseUrl = provider?.customSchoolImportBaseUrl.trim() ?? '';
  if (baseUrl.isNotEmpty && !isValidCustomOpenAiBaseUrl(baseUrl)) {
    return l10n.schoolImportParserBaseUrlInvalid;
  }
  return l10n.schoolImportParserCustomConfigIncomplete;
}
