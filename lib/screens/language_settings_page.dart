import '../widgets/expressive_dialog.dart';

import '../widgets/desktop_window_host.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../controllers/app_data_maintenance.dart';
import '../controllers/settings_commands.dart';
import '../controllers/settings_view_state.dart';
import '../l10n/app_locale.dart';
import '../l10n/app_localizations.dart';
import '../widgets/settings_list.dart';
import '../widgets/ui_command.dart';
import '../widgets/adaptive_navigation_scope.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String _query = '';
  bool _isSelectingLanguage = false;
  bool _languageSelectionPopped = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsViewState, AppDataMaintenance>(
      builder: (context, settings, maintenance, child) {
        final commands = context.read<SettingsCommands>();
        final l10n = AppLocalizations.of(context);
        final languageOptions = supportedLanguageOptions(l10n);
        final currentCode = normalizeLocaleCode(settings.localeCode);
        return PopScope(
          canPop: !_isSelectingLanguage,
          child: Scaffold(
            appBar: WorkbenchAppBar(
              automaticallyImplyLeading: !AdaptiveNavigationScope.isWide(
                context,
              ),
              title: Text(l10n.language),
            ),
            body: Column(
              children: [
                UiCommandBusyIndicator(busy: _isSelectingLanguage),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: TextField(
                      key: const ValueKey('language-search'),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: MaterialLocalizations.of(context)
                            .searchFieldLabel,
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: ResponsiveSettingsSingleColumnBody(
                      child: Column(
                        children: [
                          for (final option in _filterLanguageOptions(
                            languageOptions,
                            _query,
                          ))
                            _LanguageOptionTile(
                              key: ValueKey('language-option-${option.code}'),
                              option: option,
                              selected: option.code == currentCode,
                              onTap:
                                  _isSelectingLanguage ||
                                      _languageSelectionPopped ||
                                      maintenance.isReserved
                                  ? null
                                  : () {
                                      unawaited(
                                        _selectLanguage(
                                          commands: commands,
                                          settings: settings,
                                          maintenance: maintenance,
                                          localeCode: option.code,
                                        ),
                                      );
                                    },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<AppLanguageOption> _filterLanguageOptions(
    List<AppLanguageOption> options,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return options;
    }
    return options.where((option) {
      return option.nativeName.toLowerCase().contains(normalizedQuery) ||
          option.localizedName.toLowerCase().contains(normalizedQuery) ||
          option.englishName.toLowerCase().contains(normalizedQuery) ||
          option.code.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  Future<void> _selectLanguage({
    required SettingsCommands commands,
    required SettingsViewState settings,
    required AppDataMaintenance maintenance,
    required String localeCode,
  }) async {
    if (_isSelectingLanguage ||
        _languageSelectionPopped ||
        maintenance.isReserved) {
      return;
    }
    final normalizedCode = normalizeLocaleCode(localeCode);
    if (normalizedCode == normalizeLocaleCode(settings.localeCode)) {
      return;
    }
    setState(() => _isSelectingLanguage = true);
    try {
      final saved = await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Update application language',
        command: () => commands.updateLocaleCode(normalizedCode),
      );
      if (!saved || !mounted) {
        return;
      }
      final closePage = !AdaptiveNavigationScope.isWide(context);
      setState(() {
        _isSelectingLanguage = false;
        _languageSelectionPopped = closePage;
      });
      if (closePage) Navigator.of(context).pop();
    } finally {
      if (mounted && !_languageSelectionPopped) {
        setState(() => _isSelectingLanguage = false);
      }
    }
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppLanguageOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('language-option-semantics-${option.code}'),
    container: true,
    button: true,
    enabled: onTap != null,
    selected: selected,
    onTap: onTap,
    label: option.localizedName == option.nativeName
        ? option.nativeName
        : '${option.nativeName}, ${option.localizedName}',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ExpressiveDialogOption(
          selected: selected,
          enabled: onTap != null,
          onTap: onTap,
          title: Text(option.nativeName),
          subtitle: option.localizedName == option.nativeName
              ? null
              : Text(option.localizedName),
          titleMaxLines: null,
          subtitleMaxLines: null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    ),
  );
}
