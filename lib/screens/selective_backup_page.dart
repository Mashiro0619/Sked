import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../backup/selective_backup_app_data.dart';
import '../backup/selective_backup_device_data.dart';
import '../backup/selective_backup_models.dart';
import '../backup/selective_backup_service.dart';
import '../controllers/app_backup_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/export_service.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/settings_page_header.dart';
import '../widgets/sked_confirmation_dialog.dart';

/// One selector for current data, ZIP archives and legacy complete JSON.
/// Selection remains a page draft until the application owner admits a plan.
class SelectiveBackupPage extends StatefulWidget {
  const SelectiveBackupPage({
    super.key,
    required this.service,
    this.exportService = const ExportService(),
    this.pickBackup = pickSelectiveBackupBytes,
    this.initialSource,
    this.closeAfterRestore = false,
    this.shareOnExport = false,
  });

  final SelectiveBackupService service;
  final ExportService exportService;
  final Future<Uint8List?> Function() pickBackup;
  final SelectiveBackupBundle? initialSource;
  final bool closeAfterRestore;
  final bool shareOnExport;

  @override
  State<SelectiveBackupPage> createState() => _SelectiveBackupPageState();
}

class _SelectiveBackupPageState extends State<SelectiveBackupPage> {
  SelectiveBackupBundle? _bundle;
  final _objects = <BackupObjectKey>{};
  final _files = <String>{};
  String _search = '';
  bool _restoring = false, _working = false, _reviewing = false;
  BackupCancellation? _exportCancellation;
  SelectiveBackupError? _error;
  List<BackupObjectKey> _conflicts = const [];
  bool get _busy => _working || _reviewing || widget.service.isBusy;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
    final source = widget.initialSource;
    if (source == null) {
      unawaited(_loadCurrent());
    } else {
      _display(source, restoring: true);
    }
  }

  @override
  void dispose() {
    _exportCancellation?.cancel();
    widget.service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  BackupSelection get _selection =>
      BackupSelection(objects: _objects, attachmentBytes: _files);

  void _display(SelectiveBackupBundle bundle, {required bool restoring}) {
    final records = bundle.byKey;
    _bundle = bundle;
    _restoring = restoring;
    _objects
      ..clear()
      ..addAll(
        bundle.roots.where(
          (key) =>
              key.kind != BackupObjectKind.attachment &&
              (!restoring ||
                  widget.service.supportsDeviceGroup(records[key]!)) &&
              (restoring ||
                  key.kind != BackupObjectKind.deviceSettings &&
                      key.kind != BackupObjectKind.skill &&
                      key.kind != BackupObjectKind.memory &&
                      key.kind != BackupObjectKind.conversation &&
                      key !=
                          const BackupObjectKey(
                            BackupObjectKind.settings,
                            'agentConnection',
                          ) &&
                      key !=
                          const BackupObjectKey(
                            BackupObjectKind.settings,
                            'agentPreferences',
                          )),
        ),
      );
    _files.clear();
    _search = '';
    _error = null;
    _conflicts = const [];
  }

  Future<void> _loadCurrent() async {
    if (_busy) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (!await widget.service.refreshRecoveryStatus()) {
        final bundle = await widget.service.inventory();
        if (mounted) setState(() => _display(bundle, restoring: false));
      }
    } catch (error) {
      _recordError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openBackup() async {
    if (_busy) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final bytes = await widget.pickBackup();
      if (bytes == null || !mounted) return;
      final bundle = widget.service.decode(bytes);
      setState(() => _display(bundle, restoring: true));
    } catch (error) {
      _recordError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _recordError(Object error) {
    if (!mounted || error is WorkspaceChangeCancelledException) return;
    setState(() {
      _error = error is SelectiveBackupException
          ? error.code
          : SelectiveBackupError.unavailable;
      _conflicts = error is SelectiveBackupException ? error.targets : const [];
    });
  }

  Future<void> _save() async {
    final bundle = _bundle;
    if (bundle == null || _busy || _selection.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    final cancellation = BackupCancellation();
    _exportCancellation = cancellation;
    try {
      final bytes = await widget.service.export(
        bundle,
        _selection,
        cancellation: cancellation,
      );
      if (!mounted) return;
      final fileName =
          'sked-backup-${DateTime.now().toIso8601String().substring(0, 10)}.zip';
      if (widget.shareOnExport) {
        await widget.exportService.shareBytes(
          fileName: fileName,
          bytes: bytes,
          mimeType: 'application/zip',
        );
        return;
      }
      final result = await widget.exportService.saveBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/zip',
      );
      if (!mounted || result.status == ExportSaveStatus.cancelled) return;
      if (!result.isSuccess) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unavailable,
          'The selected destination did not confirm the saved file.',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).selectiveBackupSaved),
        ),
      );
    } catch (error) {
      _recordError(error);
    } finally {
      if (identical(_exportCancellation, cancellation)) {
        _exportCancellation = null;
      }
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    final bundle = _bundle;
    if (bundle == null || _busy || _selection.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final plan = await widget.service.prepareRestore(bundle, _selection);
      if (!mounted) return;
      setState(() {
        _working = false;
        _reviewing = true;
      });
      final accepted = await showExpressiveDialog<bool>(
        context: context,
        builder: (context) {
          final l = AppLocalizations.of(context);
          final actual = plan.changes
              .where(
                (change) =>
                    change.needsWrite &&
                    change.after.key.kind != BackupObjectKind.attachment,
              )
              .toList();
          final copied = plan.mapping.entries
              .where((entry) => entry.key != entry.value)
              .length;
          return SkedConfirmationDialog(
            title: Text(l.selectiveBackupConfirmTitle),
            scrollable: true,
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.selectiveBackupConfirmBody),
                  if (!plan.changes.any(
                    (change) =>
                        change.needsWrite &&
                        change.after.key ==
                            const BackupObjectKey(
                              BackupObjectKind.settings,
                              'agentConnection',
                            ),
                  )) ...[
                    const SizedBox(height: 12),
                    Text(
                      l.agentBackupConnectionPreserved,
                      key: const ValueKey(
                        'restore-backup-agent-settings-summary',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    l.selectiveBackupRestoreCounts(
                      actual.where((change) => change.isNew).length,
                      actual.where((change) => !change.isNew).length,
                    ),
                  ),
                  if (copied > 0)
                    Text(l.selectiveBackupCopiedDependencies(copied)),
                  if (plan.unsupportedGroups.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l.selectiveBackupUnsupportedGroups(
                        plan.unsupportedGroups.length,
                      ),
                    ),
                    for (final record in plan.unsupportedGroups)
                      Text(
                        '${_recordLabel(record, l)}: ${l.selectiveBackupDeviceUnsupported(devicePreferencePlatformLabel(devicePreferencePlatform(record)))}',
                      ),
                  ],
                  const SizedBox(height: 12),
                  ...actual.map(
                    (change) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '${change.isNew ? l.selectiveBackupAdd : l.selectiveBackupReplace}: ${_recordLabel(change.after, l)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.selectiveBackupRestore),
              ),
            ],
          );
        },
      );
      if (accepted != true || !mounted) return;
      setState(() {
        _reviewing = false;
        _working = true;
      });
      final RestoredBackupInventory? current;
      if (widget.closeAfterRestore) {
        await widget.service.restore(plan);
        current = null;
      } else {
        current = await widget.service.restoreAndReadInventory(plan);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).selectiveBackupRestored),
        ),
      );
      if (widget.closeAfterRestore) {
        Navigator.of(context).pop(true);
        return;
      }
      if (mounted) setState(() => _displayRestored(current!));
    } catch (error) {
      _recordError(error);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _reviewing = false;
        });
      }
    }
  }

  Future<void> _resume() async {
    if (_busy) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final RestoredBackupInventory? bundle;
      if (widget.closeAfterRestore) {
        await widget.service.resume();
        bundle = null;
      } else {
        bundle = await widget.service.resumeAndReadInventory();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).selectiveBackupRestored),
        ),
      );
      if (widget.closeAfterRestore) {
        Navigator.of(context).pop(true);
        return;
      }
      if (mounted) setState(() => _displayRestored(bundle!));
    } catch (error) {
      _recordError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _displayRestored(RestoredBackupInventory result) {
    if (result.inventory case final inventory?) {
      _display(inventory, restoring: false);
    } else {
      _bundle = null;
      _objects.clear();
      _files.clear();
      _restoring = false;
      _error = result.refreshError;
      _conflicts = const [];
    }
  }

  List<BackupRecord> _includedFiles() {
    final bundle = _bundle;
    if (bundle == null || _objects.isEmpty) return const [];
    final included = bundle
        .select(BackupSelection(objects: _objects))
        .records
        .where((record) => record.key.kind == BackupObjectKind.attachment)
        .map((record) => record.key)
        .toSet();
    return bundle.records
        .where((record) => included.contains(record.key))
        .toList();
  }

  void _toggleObject(BackupObjectKey key, bool selected) {
    setState(() {
      if (selected) {
        _objects.add(key);
      } else {
        _objects.remove(key);
      }
      final includedIds = _includedFiles()
          .map((record) => record.key.id)
          .toSet();
      _files.removeWhere((id) => !includedIds.contains(id));
      _error = null;
      _conflicts = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bundle = _bundle;
    final pending = widget.service.recoveryPending;
    final rows = <Widget>[
      Text(l.selectiveBackupDescription),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy || pending ? null : _loadCurrent,
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(l.selectiveBackupCurrentData),
          ),
          OutlinedButton.icon(
            onPressed: _busy || pending ? null : _openBackup,
            icon: const Icon(Icons.folder_open),
            label: Text(l.selectiveBackupOpenFile),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (pending) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.selectiveBackupRecoveryPending),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _resume,
                  icon: const Icon(Icons.refresh),
                  label: Text(l.selectiveBackupResume),
                ),
              ],
            ),
          ),
        ),
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            [
              _errorText(l, _error!),
              if (_conflicts.isNotEmpty)
                _conflicts
                    .map((key) => bundle?.byKey[key]?.label ?? key.id)
                    .join(', '),
            ].join('\n'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_working || widget.service.isBusy)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(),
        ),
      if (bundle != null && !pending) ...[
        Text(
          _restoring
              ? l.selectiveBackupRestoreSelection
              : l.selectiveBackupExportSelection,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          key: ValueKey('backup-search-$_restoring-${bundle.fingerprint}'),
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: l.selectiveBackupSearch,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) =>
              setState(() => _search = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l.selectiveBackupSelectedCount(_objects.length)),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _objects.addAll(
                        bundle.records
                            .where(
                              (record) =>
                                  record.key.kind !=
                                      BackupObjectKind.attachment &&
                                  (!_restoring ||
                                      widget.service.supportsDeviceGroup(
                                        record,
                                      )),
                            )
                            .map((record) => record.key),
                      );
                    }),
              child: Text(l.selectiveBackupSelectAll),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _objects.clear();
                      _files.clear();
                    }),
              child: Text(l.selectiveBackupClearSelection),
            ),
          ],
        ),
        for (final kind in BackupObjectKind.values.where(
          (kind) => kind != BackupObjectKind.attachment,
        ))
          ..._objectGroup(bundle, kind, l),
        const SizedBox(height: 12),
        Text(l.selectiveBackupDependencies),
        ..._fileRows(l),
        const SizedBox(height: 16),
        Text(
          l.selectiveBackupExclusions,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            key: const ValueKey('selective-backup-primary'),
            onPressed: _busy || _objects.isEmpty
                ? null
                : _restoring
                ? _restore
                : _save,
            icon: Icon(
              _restoring
                  ? Icons.restore
                  : widget.shareOnExport
                  ? Icons.share_outlined
                  : Icons.save_alt,
            ),
            label: Text(
              _restoring
                  ? l.selectiveBackupReviewRestore
                  : widget.shareOnExport
                  ? l.shareBackupTitle
                  : l.selectiveBackupSave,
            ),
          ),
        ),
      ],
      const SizedBox(height: 32),
    ];
    return PopScope<Object?>(
      canPop: !_working || widget.service.isBusy,
      child: SettingsPageScaffold(
        title: l.selectiveBackupTitle,
        bodyBuilder: (context, header) => CustomScrollView(
          slivers: [
            ?header,
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) => Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: SizedBox(width: double.infinity, child: rows[index]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _objectGroup(
    SelectiveBackupBundle bundle,
    BackupObjectKind kind,
    AppLocalizations l,
  ) {
    final group = _kindLabel(kind, l);
    final records = bundle.records
        .where(
          (record) =>
              record.key.kind == kind &&
              (_search.isEmpty ||
                  _recordLabel(record, l).toLowerCase().contains(_search) ||
                  group.toLowerCase().contains(_search)),
        )
        .toList();
    if (records.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(group, style: Theme.of(context).textTheme.titleMedium),
      ),
      for (final record in records)
        CheckboxListTile(
          key: ValueKey('backup-object-${record.key}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: _objects.contains(record.key),
          title: Text(_recordLabel(record, l)),
          subtitle: _restoring && !widget.service.supportsDeviceGroup(record)
              ? Text(
                  l.selectiveBackupDeviceUnsupported(
                    devicePreferencePlatformLabel(
                      devicePreferencePlatform(record),
                    ),
                  ),
                )
              : null,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged:
              _busy || _restoring && !widget.service.supportsDeviceGroup(record)
              ? null
              : (value) => _toggleObject(record.key, value == true),
        ),
    ];
  }

  List<Widget> _fileRows(AppLocalizations l) {
    final files = _includedFiles();
    if (files.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          l.selectiveBackupFiles,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Text(l.selectiveBackupFilesDescription),
      for (final record in files)
        CheckboxListTile(
          key: ValueKey('backup-file-${record.key.id}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: _files.contains(record.key.id),
          title: Text(record.label),
          subtitle: Text(
            _restoring && record.binaryDigest == null
                ? l.selectiveBackupFileMissing
                : l.selectiveBackupFileSize(
                    (record.data['byteLength'] as int?) ?? 0,
                  ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: _busy || _restoring && record.binaryDigest == null
              ? null
              : (value) => setState(() {
                  if (value == true) {
                    _files.add(record.key.id);
                  } else {
                    _files.remove(record.key.id);
                  }
                }),
        ),
    ];
  }
}

String _recordLabel(BackupRecord record, AppLocalizations l) {
  if (record.key.kind == BackupObjectKind.deviceSettings) {
    final group = switch (devicePreferenceGroup(record)) {
      DevicePreferenceGroup.desktopLayout => l.selectiveBackupDeviceLayout,
      DevicePreferenceGroup.developerUi => l.selectiveBackupDeviceDeveloperUi,
    };
    return l.selectiveBackupDeviceGroupPlatform(
      group,
      devicePreferencePlatformLabel(devicePreferencePlatform(record)),
    );
  }
  if (record.key.kind != BackupObjectKind.settings) return record.label;
  final group = BackupSettingsGroup.values
      .where((group) => group.name == record.key.id)
      .firstOrNull;
  return switch (group) {
    BackupSettingsGroup.application => l.selectiveBackupApplicationSettings,
    BackupSettingsGroup.workspaces => l.selectiveBackupWorkspaceSettings,
    BackupSettingsGroup.student => l.selectiveBackupTimetableSettings,
    BackupSettingsGroup.general => l.selectiveBackupCalendarSettings,
    BackupSettingsGroup.notifications => l.selectiveBackupNotificationSettings,
    BackupSettingsGroup.agentConnection => l.selectiveBackupAgentConnection,
    BackupSettingsGroup.agentPreferences => l.selectiveBackupAgentPreferences,
    null => record.label,
  };
}

String _kindLabel(BackupObjectKind kind, AppLocalizations l) => switch (kind) {
  BackupObjectKind.timetable => l.selectiveBackupTimetables,
  BackupObjectKind.periodTimeSet => l.selectiveBackupPeriodTimes,
  BackupObjectKind.calendar => l.selectiveBackupCalendars,
  BackupObjectKind.schoolSite => l.selectiveBackupSchoolSites,
  BackupObjectKind.skill => l.selectiveBackupSkills,
  BackupObjectKind.memory => l.selectiveBackupMemories,
  BackupObjectKind.conversation => l.selectiveBackupConversations,
  BackupObjectKind.attachment => l.selectiveBackupFiles,
  BackupObjectKind.settings => l.selectiveBackupSettings,
  BackupObjectKind.deviceSettings => l.selectiveBackupDeviceSettings,
};

String _errorText(AppLocalizations l, SelectiveBackupError error) =>
    switch (error) {
      SelectiveBackupError.conflict => l.selectiveBackupConflict,
      SelectiveBackupError.unsupportedVersion => l.selectiveBackupNewerVersion,
      SelectiveBackupError.limit => l.selectiveBackupLimit,
      SelectiveBackupError.invalid => l.selectiveBackupInvalid,
      SelectiveBackupError.cancelled => l.selectiveBackupCancelled,
      SelectiveBackupError.unknown ||
      SelectiveBackupError.unavailable => l.selectiveBackupUnavailable,
    };

Future<Uint8List?> pickSelectiveBackupBytes() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Sked',
        extensions: ['zip', 'json'],
        mimeTypes: ['application/zip', 'application/json'],
        uniformTypeIdentifiers: ['public.zip-archive', 'public.json'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > SelectiveBackupLimits.archiveBytes) {
    backupLimit('The backup file is too large.');
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (bytes.length + chunk.length > SelectiveBackupLimits.archiveBytes) {
      backupLimit('The backup file is too large.');
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
