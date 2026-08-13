import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../widgets/app_modal_sheet.dart';
import '../widgets/expressive_motion.dart';

enum SettingsStudentDataAction {
  importTimetables,
  importTimetablesText,
  importSchoolHtml,
  exportTimetablesShare,
  exportTimetablesSave,
  exportTimetablesText,
}

enum SettingsGeneralDataAction {
  importSchedulesJsonFile,
  importSchedulesJsonText,
  importSchedulesIcsFile,
  importSchedulesIcsText,
  exportSchedulesJsonShare,
  exportSchedulesJsonSave,
  exportSchedulesJsonText,
  exportSchedulesIcsShare,
  exportSchedulesIcsSave,
  exportSchedulesIcsText,
}

enum SettingsAppDataAction {
  restoreBackupFile,
  restoreBackupText,
  shareBackupFile,
  saveBackupFile,
  copyBackupText,
  showRecoveryArtifacts,
}

class SettingsDataTransferController {
  const SettingsDataTransferController();

  Future<void> runStudentFlow(
    BuildContext context, {
    required Future<void> Function(SettingsStudentDataAction action) onAction,
  }) async {
    final action = await _showActions<SettingsStudentDataAction>(
      context,
      icon: Icons.import_export,
      buildSpec: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        return _TransferSheetSpec(
          title: l10n.dataImportExport,
          subtitle: l10n.dataImportExportDesc,
          groups: [
            [
              _TransferAction(
                value: SettingsStudentDataAction.importTimetables,
                icon: Icons.file_download_outlined,
                title: l10n.importTimetableFiles,
                subtitle: l10n.importTimetableFilesDesc,
              ),
              _TransferAction(
                value: SettingsStudentDataAction.importTimetablesText,
                icon: Icons.paste_outlined,
                title: l10n.importTimetableText,
                subtitle: l10n.importTimetableTextDesc,
              ),
              _TransferAction(
                value: SettingsStudentDataAction.importSchoolHtml,
                icon: Icons.html_outlined,
                title: l10n.schoolHtmlImportEntry,
                subtitle: l10n.schoolHtmlImportEntryDesc,
              ),
            ],
            [
              _TransferAction(
                value: SettingsStudentDataAction.exportTimetablesShare,
                icon: Icons.share_outlined,
                title: l10n.shareTimetableFiles,
                subtitle: l10n.shareTimetableFilesDesc,
              ),
              _TransferAction(
                value: SettingsStudentDataAction.exportTimetablesSave,
                icon: Icons.save_alt_outlined,
                title: l10n.saveTimetableFiles,
                subtitle: l10n.saveTimetableFilesDesc,
              ),
              _TransferAction(
                value: SettingsStudentDataAction.exportTimetablesText,
                icon: Icons.text_snippet_outlined,
                title: l10n.exportTimetableText,
                subtitle: l10n.exportTimetableTextDesc,
              ),
            ],
          ],
        );
      },
    );
    if (action != null && context.mounted) {
      await onAction(action);
    }
  }

  Future<void> runAppDataFlow(
    BuildContext context, {
    required bool Function() hasRecoveryArtifacts,
    required Future<void> Function(SettingsAppDataAction action) onAction,
  }) async {
    final action = await _showActions<SettingsAppDataAction>(
      context,
      icon: Icons.inventory_2_outlined,
      constrainHeight: true,
      buildSpec: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        return _TransferSheetSpec(
          title: l10n.appBackupTitle,
          subtitle: l10n.appBackupSheetSubtitle,
          groups: [
            [
              _TransferAction(
                value: SettingsAppDataAction.restoreBackupFile,
                icon: Icons.restore_page_outlined,
                title: l10n.restoreBackupFileTitle,
                subtitle: l10n.restoreBackupFileSubtitle,
              ),
              _TransferAction(
                value: SettingsAppDataAction.restoreBackupText,
                icon: Icons.content_paste_go_outlined,
                title: l10n.restoreBackupTextTitle,
                subtitle: l10n.restoreBackupTextSubtitle,
              ),
            ],
            [
              _TransferAction(
                value: SettingsAppDataAction.shareBackupFile,
                icon: Icons.share_outlined,
                title: l10n.shareBackupTitle,
                subtitle: l10n.shareBackupSubtitle,
              ),
              _TransferAction(
                value: SettingsAppDataAction.saveBackupFile,
                icon: Icons.save_alt_outlined,
                title: l10n.saveBackupTitle,
                subtitle: l10n.saveBackupSubtitle,
              ),
              _TransferAction(
                value: SettingsAppDataAction.copyBackupText,
                icon: Icons.text_snippet_outlined,
                title: l10n.copyBackupTitle,
                subtitle: l10n.copyBackupSubtitle,
              ),
            ],
            if (hasRecoveryArtifacts())
              [
                _TransferAction(
                  value: SettingsAppDataAction.showRecoveryArtifacts,
                  icon: Icons.restore_from_trash_outlined,
                  title: l10n.dataRecoveryArtifactsAction,
                  subtitle: l10n.dataRecoveryArtifactsHint,
                ),
              ],
          ],
        );
      },
    );
    if (action != null && context.mounted) {
      await onAction(action);
    }
  }

  Future<void> runGeneralFlow(
    BuildContext context, {
    required Future<void> Function(SettingsGeneralDataAction action) onAction,
  }) async {
    final l10n = AppLocalizations.of(context);
    final action = await _showActions<SettingsGeneralDataAction>(
      context,
      icon: Icons.event_note_outlined,
      constrainHeight: true,
      buildSpec: (_) => _TransferSheetSpec(
        title: l10n.generalScheduleImportExport,
        subtitle: l10n.generalScheduleImportExportDesc,
        groups: [
          [
            _TransferAction(
              value: SettingsGeneralDataAction.importSchedulesJsonFile,
              icon: Icons.file_download_outlined,
              title: l10n.importJsonFile,
              subtitle: l10n.importGeneralSchedulesDesc,
            ),
            _TransferAction(
              value: SettingsGeneralDataAction.importSchedulesJsonText,
              icon: Icons.paste_outlined,
              title: l10n.pasteJson,
              subtitle: l10n.importGeneralSchedulesJsonTextDesc,
            ),
            _TransferAction(
              value: SettingsGeneralDataAction.importSchedulesIcsFile,
              icon: Icons.calendar_month_outlined,
              title: l10n.importIcsFile,
              subtitle: l10n.importIcsFileDesc,
            ),
            _TransferAction(
              value: SettingsGeneralDataAction.importSchedulesIcsText,
              icon: Icons.event_note_outlined,
              title: l10n.pasteIcs,
              subtitle: l10n.pasteIcsDesc,
            ),
          ],
          [
            _TransferAction(
              value: SettingsGeneralDataAction.exportSchedulesJsonShare,
              icon: Icons.share_outlined,
              title: '${l10n.shareGeneralSchedules} JSON',
              subtitle: l10n.shareGeneralSchedulesDesc,
            ),
            _TransferAction(
              value: SettingsGeneralDataAction.exportSchedulesJsonSave,
              icon: Icons.save_alt_outlined,
              title: '${l10n.saveGeneralSchedules} JSON',
              subtitle: l10n.saveGeneralSchedulesDesc,
            ),
            _TransferAction(
              value: SettingsGeneralDataAction.exportSchedulesJsonText,
              icon: Icons.text_snippet_outlined,
              title: l10n.copyJson,
              subtitle: l10n.copyJsonDesc,
            ),
            _TransferAction(
              value: SettingsGeneralDataAction.exportSchedulesIcsShare,
              icon: Icons.ios_share_outlined,
              title: l10n.shareIcs,
              subtitle: l10n.shareIcsDesc,
            ),
            _TransferAction(
              value: SettingsGeneralDataAction.exportSchedulesIcsSave,
              icon: Icons.event_available_outlined,
              title: l10n.saveIcs,
              subtitle: l10n.saveIcsDesc,
            ),
            _TransferAction(
              value: SettingsGeneralDataAction.exportSchedulesIcsText,
              icon: Icons.event_note_outlined,
              title: l10n.copyIcs,
              subtitle: l10n.copyIcsDesc,
            ),
          ],
        ],
      ),
    );
    if (action != null && context.mounted) {
      await onAction(action);
    }
  }

  Future<T?> _showActions<T>(
    BuildContext context, {
    required IconData icon,
    required _TransferSheetSpec<T> Function(BuildContext context) buildSpec,
    bool constrainHeight = false,
  }) {
    return showAppModalSheet<T>(
      context: context,
      maxWidth: appSheetWidthMedium,
      builder: (sheetContext) {
        final spec = buildSpec(sheetContext);
        var popped = false;
        void popWith(T action) {
          if (popped) return;
          popped = true;
          Navigator.of(sheetContext).pop(action);
        }

        final list = ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            _ActionSheetHeader(
              icon: icon,
              title: spec.title,
              subtitle: spec.subtitle,
            ),
            for (var index = 0; index < spec.groups.length; index++) ...[
              const SizedBox(height: 12),
              _ActionSheetGroup(
                children: [
                  for (final action in spec.groups[index])
                    _ActionSheetTile(
                      icon: action.icon,
                      title: action.title,
                      subtitle: action.subtitle,
                      onTap: () => popWith(action.value),
                    ),
                ],
              ),
            ],
          ],
        );
        final content = constrainHeight
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
                ),
                child: list,
              )
            : list;
        return SafeArea(top: false, child: content);
      },
    );
  }
}

class _TransferSheetSpec<T> {
  const _TransferSheetSpec({
    required this.title,
    required this.subtitle,
    required this.groups,
  });

  final String title;
  final String subtitle;
  final List<List<_TransferAction<T>>> groups;
}

class _TransferAction<T> {
  const _TransferAction({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final T value;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _ActionSheetHeader extends StatelessWidget {
  const _ActionSheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 40,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionSheetGroup extends StatelessWidget {
  const _ActionSheetGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                color: colors.outlineVariant.withValues(alpha: 0.48),
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _ActionSheetTile extends StatelessWidget {
  const _ActionSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ExpressiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(icon, color: colors.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                height: 48,
                child: Icon(
                  Icons.chevron_right,
                  size: 28,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
