import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../services/text_file_picker.dart';
import '../services/timetable_json_import_service.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/period_time_set_picker_dialog.dart';
import 'school_sites_page.dart';

class _TimetableImportChoice {
  const _TimetableImportChoice({
    required this.importBundledPeriodTimeSets,
    this.targetPeriodTimeSetId,
  });

  final bool importBundledPeriodTimeSets;
  final String? targetPeriodTimeSetId;
}

class TimetableImportFlow {
  const TimetableImportFlow._();

  static const TimetableJsonImportService _jsonImportService =
      TimetableJsonImportService();
  static var _importTimetablesInProgress = false;

  static Future<void> importTimetables(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    if (_importTimetablesInProgress) {
      return;
    }
    _importTimetablesInProgress = true;
    try {
      final source = await _pickJsonSource();
      if (source == null || !context.mounted) {
        return;
      }
      await importTimetablesFromSource(context, provider, source);
    } finally {
      _importTimetablesInProgress = false;
    }
  }

  static Future<bool> importTimetablesFromSource(
    BuildContext context,
    TimetableProvider provider,
    String source,
  ) async {
    final l10n = AppLocalizations.of(context);

    TimetableJsonImportPreview preview;
    try {
      preview = _jsonImportService.preview(provider, source);
    } on FormatException catch (error) {
      final message = error.message == 'Unsupported import file type.'
          ? importFileTypeMismatchMessage(localeCode: provider.localeCode)
          : error.message;
      _showMessage(context, message);
      return false;
    } catch (_) {
      _showMessage(context, l10n.importFailedCheckContent);
      return false;
    }

    final candidates = preview.candidates;
    if (candidates.isEmpty) {
      _showMessage(context, l10n.noImportableTimetables);
      return false;
    }

    final selectedIds = candidates.length == 1
        ? [candidates.first.id]
        : await _pickTimetableIds(
            context,
            timetables: candidates,
            title: l10n.selectTimetablesToImport,
            confirmText: l10n.importAction,
            initialSelectedIds: candidates.map((item) => item.id).toList(),
          );
    if (selectedIds == null || selectedIds.isEmpty || !context.mounted) {
      return false;
    }

    var mode = TimetableImportMode.addAsNew;
    if (selectedIds.length == 1 && provider.activeTimetableOrNull != null) {
      final pickedMode = await showExpressiveDialog<TimetableImportMode>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          var popped = false;
          void popOnce(TimetableImportMode value) {
            if (popped) return;
            popped = true;
            Navigator.of(context).pop(value);
          }

          return AlertDialog(
            title: Text(l10n.importTimetableDialogTitle),
            content: Text(l10n.chooseImportMethod),
            actions: [
              TextButton(
                onPressed: () => popOnce(TimetableImportMode.addAsNew),
                child: Text(l10n.importAsNewTimetable),
              ),
              FilledButton(
                onPressed: () => popOnce(TimetableImportMode.replaceActive),
                child: Text(l10n.replaceCurrentTimetable),
              ),
            ],
          );
        },
      );
      if (pickedMode == null) {
        return false;
      }
      mode = pickedMode;
    }

    if (!context.mounted) {
      return false;
    }
    final importChoice = await _pickImportBundledPeriodTimeSets(
      context,
      provider,
      hasBundledPeriodTimeSets: preview.hasBundledPeriodTimeSets,
    );
    if (importChoice == null) {
      return false;
    }

    try {
      final count = await _jsonImportService.apply(
        provider,
        TimetableJsonImportRequest(
          source: source,
          timetableIds: selectedIds,
          mode: mode,
          importBundledPeriodTimeSets: importChoice.importBundledPeriodTimeSets,
          targetPeriodTimeSetId: importChoice.targetPeriodTimeSetId,
        ),
      );
      if (context.mounted) {
        _showMessage(context, l10n.importedTimetablesCount(count));
      }
      return true;
    } on FormatException catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message);
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, l10n.importFailedCheckContent);
      }
      return false;
    }
  }

  static Future<void> openSchoolSitesPage(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: const SchoolSitesPage(),
        ),
      ),
    );
  }

  static Future<_TimetableImportChoice?> _pickImportBundledPeriodTimeSets(
    BuildContext context,
    TimetableProvider provider, {
    required bool hasBundledPeriodTimeSets,
  }) async {
    if (!hasBundledPeriodTimeSets) {
      return const _TimetableImportChoice(importBundledPeriodTimeSets: true);
    }
    if (!context.mounted) {
      return null;
    }
    final l10n = AppLocalizations.of(context);
    final canDiscardBundledSets = provider.periodTimeSets.isNotEmpty;
    final dialogBody = canDiscardBundledSets
        ? l10n.importPeriodTimeSetDialogBody
        : '${l10n.importPeriodTimeSetDialogBody}\n\n${l10n.importDiscardPeriodTimeSetUnavailable}';
    final result = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        var popped = false;
        void popOnce(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(l10n.importPeriodTimeSetDialogTitle),
          content: Text(dialogBody),
          actions: [
            TextButton(
              onPressed: canDiscardBundledSets ? () => popOnce(false) : null,
              child: Text(l10n.discardBundledPeriodTimeSets),
            ),
            FilledButton(
              onPressed: () => popOnce(true),
              child: Text(l10n.importBundledPeriodTimeSets),
            ),
          ],
        );
      },
    );
    if (result == null) {
      return null;
    }
    if (result) {
      return const _TimetableImportChoice(importBundledPeriodTimeSets: true);
    }
    if (!context.mounted) {
      return null;
    }
    final selectedPeriodTimeSetId = await showPeriodTimeSetPickerDialog(
      context,
      provider: provider,
      selectedPeriodTimeSetId:
          provider.activePeriodTimeSetOrNull?.id ??
          provider.periodTimeSets.first.id,
    );
    if (selectedPeriodTimeSetId == null || selectedPeriodTimeSetId.isEmpty) {
      return null;
    }
    return _TimetableImportChoice(
      importBundledPeriodTimeSets: false,
      targetPeriodTimeSetId: selectedPeriodTimeSetId,
    );
  }

  static Future<List<String>?> _pickTimetableIds(
    BuildContext context, {
    required List<TimetableData> timetables,
    required String title,
    required String confirmText,
    List<String> initialSelectedIds = const [],
  }) {
    final draft = <String>{
      ...initialSelectedIds.where(
        (id) => timetables.any((item) => item.id == id),
      ),
    };
    if (draft.isEmpty && timetables.isNotEmpty) {
      draft.add(timetables.first.id);
    }
    return showExpressiveDialog<List<String>>(
      context: context,
      builder: (context) {
        var popped = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context);
            void popOnce(List<String>? result) {
              if (popped) return;
              popped = true;
              Navigator.of(context).pop(result);
            }

            return AlertDialog(
              title: Text(title),
              content: ExpressiveDialogContent(
                maxWidth: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              draft
                                ..clear()
                                ..addAll(timetables.map((item) => item.id));
                            }),
                            child: Text(l10n.selectAll),
                          ),
                          TextButton(
                            onPressed: () => setState(draft.clear),
                            child: Text(l10n.clear),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: timetables.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final timetable = timetables[index];
                          final selected = draft.contains(timetable.id);
                          return ExpressiveDialogOption(
                            selected: selected,
                            leading: const Icon(Icons.table_chart_outlined),
                            title: Text(timetable.config.name),
                            subtitle: Text(
                              l10n.timetableCourseCount(
                                timetable.courses.length,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  draft.remove(timetable.id);
                                } else {
                                  draft.add(timetable.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => popOnce(null),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: draft.isEmpty
                      ? null
                      : () => popOnce(
                          timetables
                              .where((item) => draft.contains(item.id))
                              .map((item) => item.id)
                              .toList(),
                        ),
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<String?> _pickJsonSource() async {
    return TextFilePicker.pickText(allowedExtensions: const ['json']);
  }

  static void _showMessage(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
