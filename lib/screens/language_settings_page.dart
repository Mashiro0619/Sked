import '../widgets/desktop_window_host.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
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
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context);
        final languageOptions = supportedLanguageOptions(l10n);
        final currentCode = normalizeLocaleCode(provider.localeCode);
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
                                      _languageSelectionPopped
                                  ? null
                                  : () {
                                      unawaited(
                                        _selectLanguage(provider, option.code),
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

  Future<void> _selectLanguage(
    TimetableProvider provider,
    String localeCode,
  ) async {
    if (_isSelectingLanguage || _languageSelectionPopped) {
      return;
    }
    final normalizedCode = normalizeLocaleCode(localeCode);
    if (normalizedCode == normalizeLocaleCode(provider.localeCode)) {
      return;
    }
    setState(() => _isSelectingLanguage = true);
    try {
      final saved = await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Update application language',
        command: () => provider.updateLocaleCode(normalizedCode),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected ? colorScheme.primary : colorScheme.onSurface;
    final subtitleColor = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return Semantics(
      key: ValueKey('language-option-semantics-${option.code}'),
      container: true,
      button: true,
      enabled: onTap != null,
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final text = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.nativeName,
                        softWrap: true,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (option.localizedName != option.nativeName) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.localizedName,
                          softWrap: true,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ],
                  );
                  final check = selected
                      ? Icon(Icons.check, color: colorScheme.primary)
                      : null;
                  final stack =
                      selected &&
                      (constraints.maxWidth < 360 || textScale > 1.3);
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        text,
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: check,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: text),
                      if (check != null) ...[const SizedBox(width: 12), check],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
