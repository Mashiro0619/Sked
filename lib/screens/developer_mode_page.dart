import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart' as app_locale;
import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../services/developer_sample_data_service.dart';
import '../widgets/settings_list.dart';
import '../widgets/ui_command.dart';

/// A deliberately unlinked toolbox for visual and interaction testing.
///
/// The route is only reachable through the long-press affordance in Settings;
/// no unlock state is stored in app data.
class DeveloperModePage extends StatefulWidget {
  const DeveloperModePage({super.key});

  @override
  State<DeveloperModePage> createState() => _DeveloperModePageState();
}

class _DeveloperModePageState extends State<DeveloperModePage>
    with UiCommandRunner<DeveloperModePage> {
  late DeveloperSampleLanguage _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final code = app_locale.normalizeLocaleCode(
      context.read<TimetableProvider>().localeCode,
    );
    _language = code == 'zh' || code.startsWith('zh-')
        ? DeveloperSampleLanguage.simplifiedChinese
        : DeveloperSampleLanguage.english;
    _initialized = true;
  }

  var _initialized = false;

  Future<void> _addSamples() async {
    final provider = context.read<TimetableProvider>();
    final completed = await runUiCommand(
      debugLabel: 'Add developer sample data',
      command: () => provider.addDeveloperSampleData(_language),
    );
    if (!completed || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).developerSampleDataAdded),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope<void>(
      canPop: !uiCommandBusy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.developerModeTitle)),
        body: Column(
          children: [
            UiCommandBusyIndicator(
              busy: uiCommandBusy,
              semanticsKey: const ValueKey('developer-mode-busy'),
            ),
            Expanded(
              child: ResponsiveSettingsSingleColumnBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        l10n.developerModeDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SettingsSectionHeader(title: l10n.developerSampleLanguage),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<DeveloperSampleLanguage>(
                        key: const ValueKey('developer-sample-language'),
                        segments: [
                          ButtonSegment(
                            value: DeveloperSampleLanguage.simplifiedChinese,
                            label: Text(l10n.developerSampleChinese),
                          ),
                          ButtonSegment(
                            value: DeveloperSampleLanguage.english,
                            label: Text(l10n.developerSampleEnglish),
                          ),
                        ],
                        selected: {_language},
                        expandedInsets: EdgeInsets.zero,
                        onSelectionChanged: uiCommandBusy
                            ? null
                            : (selection) {
                                if (selection.isEmpty) return;
                                setState(() => _language = selection.first);
                              },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.developerSampleDataDescription,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey('developer-add-sample-data'),
                            onPressed: uiCommandBusy ? null : _addSamples,
                            icon: const Icon(Icons.dataset_outlined),
                            label: Text(l10n.developerAddSampleData),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
