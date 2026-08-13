import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../services/export_service.dart';
import '../services/text_file_picker.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/sked_popup_menu.dart';
import '../widgets/settings_list.dart';
import '../widgets/text_transfer_widgets.dart';
import '../widgets/ui_command.dart';

enum _PeriodTimesMenuAction {
  importTemplate,
  importTemplateText,
  exportTemplate,
  saveTemplate,
  exportTemplateText,
  deleteSet,
}

/// 这块单独拆页，不塞进设置弹窗里，不然一口气改多节时间会很难操作。
class PeriodTimesPage extends StatefulWidget {
  const PeriodTimesPage({
    super.key,
    required this.periodTimeSetId,
    ExportService? exportService,
  }) : exportService = exportService ?? const ExportService();

  final String periodTimeSetId;
  final ExportService exportService;

  @override
  State<PeriodTimesPage> createState() => _PeriodTimesPageState();
}

class _PeriodTimesPageState extends State<PeriodTimesPage> {
  late final TextEditingController _nameController;
  late List<CoursePeriodTime> _periodTimes;
  var _loading = true;
  var _timePickerOpen = false;
  var _menuActionInProgress = false;
  var _saveInProgress = false;

  bool get _interactionBlocked => _menuActionInProgress || _saveInProgress;

  ExportService get _exportService => widget.exportService;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      final provider = context.read<TimetableProvider>();
      final periodTimeSet = provider.periodTimeSetForId(widget.periodTimeSetId);
      if (periodTimeSet != null) {
        _nameController.text = periodTimeSet.name;
        _periodTimes = periodTimeSet.periodTimes
            .map((item) => item.copyWith())
            .toList();
      } else {
        _nameController.text = AppLocalizations.of(context).periodTimesTitle;
        _periodTimes = buildPeriodTimesForCount(10);
      }
      _loading = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final page = Scaffold(
      appBar: AppBar(
        title: Text(l10n.periodTimesTitle),
        actions: [
          SkedPopupMenuButton<_PeriodTimesMenuAction>(
            tooltip: l10n.importExport,
            enabled: !_interactionBlocked,
            onSelected: (action) {
              unawaited(_handleMenuAction(action));
            },
            itemBuilder: (context) => [
              SkedPopupMenuItem(
                value: _PeriodTimesMenuAction.importTemplate,
                child: Text(l10n.importPeriodTemplate),
              ),
              SkedPopupMenuItem(
                value: _PeriodTimesMenuAction.importTemplateText,
                child: Text(l10n.importPeriodTemplateText),
              ),
              SkedPopupMenuItem(
                value: _PeriodTimesMenuAction.exportTemplate,
                child: Text(l10n.sharePeriodTemplate),
              ),
              SkedPopupMenuItem(
                value: _PeriodTimesMenuAction.saveTemplate,
                child: Text(l10n.saveTemplateToFile),
              ),
              SkedPopupMenuItem(
                value: _PeriodTimesMenuAction.exportTemplateText,
                child: Text(l10n.exportPeriodTemplateText),
              ),
              SkedPopupMenuDivider(),
              SkedPopupMenuItem(
                value: _PeriodTimesMenuAction.deleteSet,
                child: Text(l10n.deletePeriodTimeSet),
              ),
            ],
          ),
          IconButton(
            tooltip: l10n.save,
            onPressed: _interactionBlocked
                ? null
                : () {
                    unawaited(_save());
                  },
            icon: _saveInProgress
                ? Semantics(
                    liveRegion: true,
                    label: l10n.savingChanges,
                    child: const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            UiCommandBusyIndicator(busy: _interactionBlocked),
            Expanded(
              child: AbsorbPointer(
                key: const ValueKey('period-times-editor-guard'),
                absorbing: _interactionBlocked,
                child: ResponsiveSettingsSingleColumnBody(
                  topPadding: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.periodTimeSetName,
                          prefixIcon: const Icon(Icons.schedule_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (
                        var index = 0;
                        index < _periodTimes.length;
                        index++
                      ) ...[
                        _buildPeriodCard(index),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        onPressed: _addPeriod,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addOnePeriod),
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
    return PopScope<void>(canPop: !_interactionBlocked, child: page);
  }

  Widget _buildPeriodCard(int index) {
    final l10n = AppLocalizations.of(context);
    final period = _periodTimes[index];
    final previous = index == 0 ? null : _periodTimes[index - 1];
    final duration = period.endMinutes - period.startMinutes;
    final gap = previous == null
        ? null
        : period.startMinutes - previous.endMinutes;
    final invalid = duration <= 0 || (previous != null && gap! < 0);

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: ShapeDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.periodNumberLabel(period.index),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_periodTimes.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.deleteThisPeriod,
                    onPressed: () => _removePeriod(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final start = _TimeCell(
                  label: l10n.startTime,
                  value: formatMinutes(period.startMinutes),
                  onTap: _timePickerOpen
                      ? null
                      : () => _pickPeriodTime(index, isStart: true),
                );
                final end = _TimeCell(
                  label: l10n.endTime,
                  value: formatMinutes(period.endMinutes),
                  onTap: _timePickerOpen
                      ? null
                      : () => _pickPeriodTime(index, isStart: false),
                );
                if (constraints.maxWidth < 360 || textScale > 1.3) {
                  return Column(
                    children: [start, const SizedBox(height: 8), end],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: start),
                    const SizedBox(width: 12),
                    Expanded(child: end),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  label: l10n.durationMinutes(duration > 0 ? duration : 0),
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurfaceVariant,
                ),
                if (gap != null)
                  _MetaChip(
                    label: l10n.gapFromPrevious(gap > 0 ? gap : 0),
                    backgroundColor: colors.surfaceContainerHighest,
                    foregroundColor: colors.onSurfaceVariant,
                  ),
              ],
            ),
            if (invalid) ...[
              const SizedBox(height: 10),
              Text(
                duration <= 0
                    ? l10n.endTimeMustBeLater
                    : l10n.periodOverlapPrevious,
                style: TextStyle(color: colors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(_PeriodTimesMenuAction action) async {
    if (_interactionBlocked) {
      return;
    }
    _setMenuActionInProgress(true);
    try {
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Run period time menu action ${action.name}',
        command: () async {
          switch (action) {
            case _PeriodTimesMenuAction.importTemplate:
              await _importTemplate();
              return;
            case _PeriodTimesMenuAction.importTemplateText:
              await _importTemplateFromText();
              return;
            case _PeriodTimesMenuAction.exportTemplate:
              await _shareTemplate();
              return;
            case _PeriodTimesMenuAction.saveTemplate:
              await _saveTemplateToFile();
              return;
            case _PeriodTimesMenuAction.exportTemplateText:
              await _exportTemplateAsText();
              return;
            case _PeriodTimesMenuAction.deleteSet:
              await _deleteSet();
              return;
          }
        },
      );
    } finally {
      _setMenuActionInProgress(false);
    }
  }

  void _setMenuActionInProgress(bool value) {
    if (mounted) {
      setState(() => _menuActionInProgress = value);
    } else {
      _menuActionInProgress = value;
    }
  }

  void _addPeriod() {
    setState(() {
      _periodTimes = buildPeriodTimesForCount(
        _periodTimes.length + 1,
        source: _periodTimes,
      );
    });
  }

  void _removePeriod(int index) {
    setState(() {
      final next = [..._periodTimes]..removeAt(index);
      _periodTimes = List.generate(
        next.length,
        (itemIndex) => next[itemIndex].copyWith(index: itemIndex + 1),
      );
    });
  }

  Future<void> _save() async {
    if (_interactionBlocked) {
      return;
    }
    setState(() => _saveInProgress = true);
    final provider = context.read<TimetableProvider>();
    try {
      final saved = await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Save period time set',
        command: () async {
          final normalized = buildPeriodTimesForCount(
            _periodTimes.length,
            source: _periodTimes,
          );
          await provider.updatePeriodTimeSet(
            PeriodTimeSet(
              id: widget.periodTimeSetId,
              name: _nameController.text.trim(),
              periodTimes: normalized,
            ),
          );
        },
      );
      if (saved && mounted) {
        _showMessage(AppLocalizations.of(context).periodTimesSaved);
      }
    } finally {
      if (mounted) {
        setState(() => _saveInProgress = false);
      } else {
        _saveInProgress = false;
      }
    }
  }

  Future<void> _deleteSet() async {
    final provider = context.read<TimetableProvider>();
    final navigator = Navigator.of(context);
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final name = _nameController.text.trim().isEmpty
            ? l10n.currentPeriodTimeSet
            : _nameController.text.trim();
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(l10n.deletePeriodTimeSetTitle),
          content: Text(l10n.deletePeriodTimeSetMessage(name)),
          actions: [
            TextButton(
              onPressed: () => popWith(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await provider.deletePeriodTimeSet(widget.periodTimeSetId);
      if (mounted) {
        navigator.pop(true);
      }
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _importTemplate() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context);
    final source = await TextFilePicker.pickText(
      allowedExtensions: const ['json'],
    );
    if (!mounted) {
      return;
    }
    if (source == null) {
      return;
    }
    try {
      final imported = provider.importPeriodTimesJson(source);
      final count = imported.length;
      if (count == 0) {
        throw FormatException(
          noPeriodTimesInImportMessage(localeCode: provider.localeCode),
        );
      }
      setState(() {
        _periodTimes = imported;
      });
      _showMessage(l10n.importedPeriodTimesCount(count));
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(l10n.importFailedCheckContent);
    }
  }

  Future<void> _importTemplateFromText() async {
    final l10n = AppLocalizations.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextImportPage(
          title: l10n.importPeriodTemplateText,
          onSubmit: (_, content) async {
            if (!mounted) {
              return false;
            }
            final provider = context.read<TimetableProvider>();
            try {
              final imported = provider.importPeriodTimesJson(content);
              final count = imported.length;
              if (count == 0) {
                throw FormatException(
                  noPeriodTimesInImportMessage(localeCode: provider.localeCode),
                );
              }
              if (!mounted) {
                return false;
              }
              setState(() {
                _periodTimes = imported;
              });
              _showMessage(l10n.importedPeriodTimesCount(count));
              return true;
            } on FormatException catch (error) {
              _showMessage(error.message);
              return false;
            } catch (_) {
              _showMessage(l10n.importFailedCheckContent);
              return false;
            }
          },
        ),
      ),
    );
  }

  Future<void> _shareTemplate() async {
    await _exportService.shareFile(
      ExportPayload(
        fileName: 'Sked_period_times.json',
        content: encodePeriodTimesEnvelope(_periodTimes),
      ),
    );
  }

  Future<void> _exportTemplateAsText() async {
    final l10n = AppLocalizations.of(context);
    await showTextExportDialog(
      context,
      title: l10n.exportPeriodTemplateText,
      content: encodePeriodTimesEnvelope(_periodTimes),
    );
  }

  Future<void> _saveTemplateToFile() async {
    final l10n = AppLocalizations.of(context);
    final result = await _exportService.saveFile(
      ExportPayload(
        fileName: 'Sked_period_times.json',
        content: encodePeriodTimesEnvelope(_periodTimes),
      ),
    );
    if (!mounted) {
      return;
    }

    switch (result.status) {
      case ExportSaveStatus.saved:
        _showMessage(l10n.savedToPath(result.path ?? 'Sked_period_times.json'));
        return;
      case ExportSaveStatus.cancelled:
        _showMessage(l10n.saveCancelled);
        return;
      case ExportSaveStatus.permissionDenied:
        final retry = await _showPermissionDialog(
          title: l10n.periodFilePermissionTitle,
          message: l10n.androidFilePermissionMessage,
          confirmText: l10n.reauthorize,
        );
        if (retry == true && mounted) {
          await _saveTemplateToFile();
        }
        return;
      case ExportSaveStatus.permissionPermanentlyDenied:
        final openSettings = await _showPermissionDialog(
          title: l10n.permissionPermanentlyDeniedTitle,
          message: l10n.permissionSettingsExportMessage,
          confirmText: l10n.openSettings,
        );
        if (openSettings == true) {
          await _exportService.openSettings();
        }
        return;
      case ExportSaveStatus.unsupported:
        final shouldShare = await _showFailureDialog(
          title: l10n.browserDownloadRestrictedTitle,
          message: l10n.browserDownloadRestrictedMessage,
        );
        if (shouldShare == true) {
          await _shareTemplate();
          _showMessage(l10n.exportSwitchedToShare);
        }
        return;
      case ExportSaveStatus.failed:
        final shouldShare = await _showFailureDialog(
          title: _exportService.usesDesktopFileSaveErrors
              ? l10n.fileSaveFailedTitle
              : l10n.fileSaveRestrictedTitle,
          message: _exportService.usesDesktopFileSaveErrors
              ? l10n.fileSaveFailedWindowsMessage
              : l10n.fileSaveFailedGenericMessage,
        );
        if (shouldShare == true) {
          await _shareTemplate();
          _showMessage(l10n.exportSwitchedToShare);
        } else {
          _showMessage(l10n.saveFailedRetry);
        }
        return;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _showPermissionDialog({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => popWith(false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showFailureDialog({
    required String title,
    required String message,
  }) {
    return showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => popWith(false),
              child: Text(AppLocalizations.of(context).retryLater),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(AppLocalizations.of(context).switchToShare),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickPeriodTime(int index, {required bool isStart}) async {
    if (_timePickerOpen || index < 0 || index >= _periodTimes.length) {
      return;
    }
    setState(() => _timePickerOpen = true);
    // 这里先只改草稿，等用户点保存时再整体写回，避免改到一半就影响正在用的课表。
    final period = _periodTimes[index];
    final initialMinutes = normalizeMinuteOfDay(
      isStart ? period.startMinutes : period.endMinutes,
    );
    try {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: initialMinutes ~/ 60,
          minute: initialMinutes % 60,
        ),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );
      if (!mounted ||
          picked == null ||
          index < 0 ||
          index >= _periodTimes.length) {
        return;
      }
      final minutes = (picked.hour * 60) + picked.minute;
      setState(() {
        final currentPeriod = _periodTimes[index];
        _periodTimes[index] = isStart
            ? currentPeriod.copyWith(startMinutes: minutes)
            : currentPeriod.copyWith(endMinutes: minutes);
      });
    } finally {
      if (mounted) {
        setState(() => _timePickerOpen = false);
      } else {
        _timePickerOpen = false;
      }
    }
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor ?? colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
