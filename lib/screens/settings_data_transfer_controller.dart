import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../widgets/app_modal_sheet.dart';
import '../widgets/settings_list.dart';
import '../widgets/workbench_chrome_metrics.dart';

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

enum SettingsTransferDirection { import, export }

class SettingsDataTransferController {
  const SettingsDataTransferController();

  Future<void> runAppDataFlow(
    BuildContext context, {
    required bool Function() hasRecoveryArtifacts,
    required Future<void> Function(SettingsAppDataAction action) onAction,
    bool restoreEnabled = true,
  }) async {
    final action = await _showActions<SettingsAppDataAction>(
      context,
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
                enabled: restoreEnabled,
                icon: Icons.restore_page_outlined,
                title: l10n.restoreBackupFileTitle,
                subtitle: l10n.restoreBackupFileSubtitle,
              ),
              _TransferAction(
                value: SettingsAppDataAction.restoreBackupText,
                enabled: restoreEnabled,
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

  _TransferSheetSpec<SettingsStudentDataAction> _studentSpec(
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context);
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
  }

  _TransferSheetSpec<SettingsGeneralDataAction> _generalSpec(
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context);
    return _TransferSheetSpec(
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
    );
  }

  Widget studentPageContent(
    BuildContext context, {
    required ValueChanged<SettingsStudentDataAction> onAction,
    required bool busy,
    bool importEnabled = true,
    List<Widget> additionalImports = const [],
    List<Widget> importConfiguration = const [],
    SettingsTransferDirection? direction,
    Widget? headerSliver,
  }) => _TransferPageContent(
    spec: _studentSpec(context),
    onAction: onAction,
    busy: busy,
    importEnabled: importEnabled,
    additionalImports: additionalImports,
    importConfiguration: importConfiguration,
    direction: direction,
    headerSliver: headerSliver,
  );
  Widget generalPageContent(
    BuildContext context, {
    required ValueChanged<SettingsGeneralDataAction> onAction,
    required bool busy,
    bool importEnabled = true,
    SettingsTransferDirection? direction,
    Widget? headerSliver,
  }) => _TransferPageContent(
    spec: _generalSpec(context),
    direction: direction,
    headerSliver: headerSliver,
    onAction: onAction,
    busy: busy,
    importEnabled: importEnabled,
  );

  Future<T?> _showActions<T>(
    BuildContext context, {
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

        return AppSheetScaffold(
          title: Text(spec.title),
          subtitle: Text(spec.subtitle),
          heightFactor: constrainHeight ? .85 : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < spec.groups.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                _ActionSheetGroup(
                  children: [
                    for (final action in spec.groups[index])
                      _ActionSheetTile(
                        icon: action.icon,
                        title: action.title,
                        subtitle: action.subtitle,
                        onTap: action.enabled
                            ? () => popWith(action.value)
                            : null,
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
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
    this.enabled = true,
  });

  final T value;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
}

class _ActionSheetGroup extends StatelessWidget {
  const _ActionSheetGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SettingsConnectedGroup(
    tonal: true,
    margin: EdgeInsets.zero,
    children: children,
  );
}

class _ActionSheetTile extends StatelessWidget {
  const _ActionSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SettingsTransferPageTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: onTap,
  );
}

/// Transfer and configuration links use the same settings row. Business action
/// keys and the owning page remain stable while density and text wrapping agree.
class SettingsTransferPageTile extends StatelessWidget {
  const SettingsTransferPageTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SettingsConnectedTile(
    leading: Icon(icon),
    title: title,
    subtitle: subtitle,
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

/// A direct task page, not a settings intermediary followed by another modal.
class _TransferPageContent<T> extends StatelessWidget {
  const _TransferPageContent({
    required this.spec,
    required this.onAction,
    required this.busy,
    this.importEnabled = true,
    this.additionalImports = const [],
    this.importConfiguration = const [],
    this.direction,
    this.headerSliver,
  });
  final _TransferSheetSpec<T> spec;
  final ValueChanged<T> onAction;
  final bool busy;
  final bool importEnabled;
  final List<Widget> additionalImports;
  final List<Widget> importConfiguration;
  final SettingsTransferDirection? direction;
  final Widget? headerSliver;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final l = AppLocalizations.of(context);
      final metrics = WorkbenchChromeMetrics.of(context);
      final inset = constraints.maxWidth < 600 ? 16.0 : 24.0;
      // Decide from the actual content budget, after outer padding and the
      // column gap. A large-font or narrow page keeps one readable column.
      final available = math.max(0.0, constraints.maxWidth - inset * 2);
      final splitWidth = math.min(1040.0, available);
      final split =
          direction == null && splitWidth >= 360 * metrics.textScale * 2 + 24;
      Widget group(int index) => SettingsConnectedGroup(
        tonal: true,
        margin: EdgeInsets.zero,
        key: ValueKey(
          index == 0 ? 'transfer-import-group' : 'transfer-export-group',
        ),
        title: index == 0 ? l.importAction : l.exportAction,
        children: [
          for (final action in spec.groups[index])
            SettingsTransferPageTile(
              key: ValueKey('transfer-action-${action.value}'),
              icon: action.icon,
              title: action.title,
              subtitle: action.subtitle,
              onTap: busy || (index == 0 && !importEnabled)
                  ? null
                  : () => onAction(action.value),
            ),
          if (index == 0) ...additionalImports,
        ],
      );
      final imports = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          group(0),
          if (importConfiguration.isNotEmpty) ...[
            const SizedBox(height: 24),
            SettingsConnectedGroup(
              tonal: true,
              margin: EdgeInsets.zero,
              key: const ValueKey('transfer-configuration-group'),
              title: l.settingsAdvanced,
              children: importConfiguration,
            ),
          ],
        ],
      );
      final content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          key: const ValueKey('transfer-page-content'),
          constraints: BoxConstraints(maxWidth: split ? 1040 : 680),
          child: direction != null
              ? (direction == SettingsTransferDirection.import
                    ? imports
                    : group(1))
              : split
              ? Row(
                  key: const ValueKey('transfer-two-columns'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: imports),
                    const SizedBox(width: 24),
                    Expanded(child: group(1)),
                  ],
                )
              : Column(
                  key: const ValueKey('transfer-single-column'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [imports, const SizedBox(height: 24), group(1)],
                ),
        ),
      );
      final padding = EdgeInsets.fromLTRB(inset, 24, inset, 32);
      return headerSliver == null
          ? SingleChildScrollView(
              key: const PageStorageKey('transfer-page-scroll'),
              padding: padding,
              child: content,
            )
          : CustomScrollView(
              key: const PageStorageKey('transfer-page-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                headerSliver!,
                SliverPadding(
                  padding: padding,
                  sliver: SliverToBoxAdapter(child: content),
                ),
              ],
            );
    },
  );
}
