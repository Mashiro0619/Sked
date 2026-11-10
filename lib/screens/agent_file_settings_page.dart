import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../agent/agent_application.dart';
import '../agent/bridge/generated/api/file_contracts.dart';
import '../agent/files/agent_file_access_bridge.dart';
import '../agent/ui/contributions/agent_ui_contribution_host.dart';
import '../agent/ui/contributions/agent_ui_contribution_registry.dart';
import '../l10n/app_localizations.dart';
import '../utils/unique_id.dart';
import '../widgets/settings_list.dart';
import '../widgets/settings_page_header.dart';
import '../widgets/sked_task_session.dart';

class AgentFileSettingsPage extends StatefulWidget {
  const AgentFileSettingsPage({super.key});

  @override
  State<AgentFileSettingsPage> createState() => _AgentFileSettingsPageState();
}

class _AgentFileSettingsPageState extends State<AgentFileSettingsPage>
    with WidgetsBindingObserver {
  AgentApplication? _application;
  AgentUiContributionLease? _lease;
  SkedTaskSession? _parent;
  SkedTaskSession? _source;
  String _ownerId = generateUuidV4();
  AgentFileAccessStatus? _status;
  bool _busy = false;
  bool _failed = false;
  bool _refreshAgain = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final application = context.watch<AgentApplication>();
    final lease = AgentUiContributionScope.maybeOf(context);
    final parent = SkedTaskSessionScope.maybeOf(context)?.session;
    if (identical(_application, application) &&
        identical(_lease, lease) &&
        identical(_parent, parent)) {
      return;
    }
    _retireSource();
    _application = application;
    _lease = lease;
    _parent = parent;
    _ownerId = generateUuidV4();
    _status = null;
    _busy = false;
    _failed = false;
    _refreshAgain = false;
    _source = SkedTaskSession(
      ownerRoute: ModalRoute.of(context),
      parent: parent,
      targetChanges: Listenable.merge([application, lease]),
      isOwnerActive: () => mounted,
      isTargetCurrent: () =>
          identical(_application, application) &&
          lease?.isCurrent != false &&
          application.fileAccess.isAvailable,
    )..addListener(_sourceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  bool get _canStart =>
      mounted &&
      _source?.isCurrent == true &&
      ModalRoute.of(context)?.isCurrent == true;

  bool _ownsOperation(SkedTaskSession source, int revision) =>
      mounted && identical(_source, source) && revision == _revision;

  bool _canPublish(SkedTaskSession source, int revision) =>
      _ownsOperation(source, revision) && _canStart;

  void _sourceChanged() {
    if (_source?.isCurrent == true) return;
    _revision++;
    final bridge = _application?.fileAccess;
    if (bridge != null) _cancelPicker(bridge, _ownerId);
  }

  void _retireSource() {
    _revision++;
    final bridge = _application?.fileAccess;
    if (bridge != null) _cancelPicker(bridge, _ownerId);
    _source?.removeListener(_sourceChanged);
    _source?.dispose();
  }

  void _cancelPicker(AgentFileAccessBridge bridge, String ownerId) {
    unawaited(
      bridge.cancelPending(ownerId).catchError((Object error) {
        debugPrint('Retiring file access picker failed: $error');
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_canStart) return;
    if (_busy) {
      _refreshAgain = true;
    } else {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() => _run(() => _application!.fileAccess.status());

  Future<void> _run(Future<AgentFileAccessStatus> Function() action) async {
    if (_busy || !_canStart) return;
    final source = _source!;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final status = await action();
      if (_canPublish(source, revision)) setState(() => _status = status);
    } catch (error) {
      if (_canPublish(source, revision)) {
        setState(() {
          _status = null;
          _failed = true;
        });
        debugPrint('Reading or updating file access failed: $error');
      }
    } finally {
      if (_ownsOperation(source, revision)) {
        setState(() => _busy = false);
        if (_refreshAgain && _canStart) {
          _refreshAgain = false;
          unawaited(_refresh());
        }
      }
    }
  }

  Future<void> _requestAccess() => _run(
    () async => (await _application!.fileAccess.requestAccess(_ownerId)).status,
  );

  Future<void> _pickDocument() => _run(
    () async => (await _application!.fileAccess.pickDocument(_ownerId)).status,
  );

  Future<void> _pickDirectory() => _run(
    () async => (await _application!.fileAccess.pickDirectory(_ownerId)).status,
  );

  Future<void> _remove(AgentFileGrant grant) =>
      _run(() => _application!.fileAccess.releaseGrant(grant.grantId));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retireSource();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = _status;
    final enabled = !_busy && _source?.isCurrent == true;
    final page = SettingsPageScaffold(
      title: l.agentFileAccessTitle,
      bodyBuilder: (_, header) => ResponsiveSettingsSingleColumnBody(
        headerSliver: header,
        scrollViewKey: const PageStorageKey('agent-file-access-scroll'),
        children: [
          SettingsSectionNote(l.agentFileAccessDescription),
          if (_busy) const LinearProgressIndicator(),
          SettingsConnectedGroup(
            tonal: true,
            children: [
              SettingsConnectedTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: status != null && status.sdkInt < 30
                    ? l.agentFileAccessStoragePermission
                    : l.agentFileAccessAllFiles,
                value: status == null
                    ? (_failed
                          ? l.agentFileAccessUnavailable
                          : l.agentFileAccessChecking)
                    : _accessLabel(l, status.pathRead, status.pathWrite),
                subtitle: l.agentFileAccessPathHint,
                trailing: const Icon(Icons.open_in_new),
                onTap: enabled ? () => unawaited(_requestAccess()) : null,
                onTapHint: l.agentFileAccessManage,
              ),
              SettingsConnectedTile(
                leading: const Icon(Icons.refresh),
                title: l.agentFileAccessRefresh,
                onTap: enabled ? () => unawaited(_refresh()) : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionHeader(title: l.agentFileAccessSelections),
          SettingsConnectedGroup(
            tonal: true,
            children: [
              SettingsConnectedTile(
                leading: const Icon(Icons.note_add_outlined),
                title: l.agentFileAccessPickFile,
                trailing: const Icon(Icons.add),
                onTap: enabled ? () => unawaited(_pickDocument()) : null,
              ),
              SettingsConnectedTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: l.agentFileAccessPickDirectory,
                trailing: const Icon(Icons.add),
                onTap: enabled ? () => unawaited(_pickDirectory()) : null,
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 12),
            if (status.resources.isEmpty)
              SettingsSectionNote(l.agentFileAccessEmpty)
            else
              SettingsConnectedGroup(
                tonal: true,
                children: [
                  for (final grant in status.resources)
                    _FileGrantTile(
                      key: ValueKey(grant.grantId),
                      grant: grant,
                      onRemove: enabled
                          ? () => unawaited(_remove(grant))
                          : null,
                    ),
                ],
              ),
          ],
          if (_failed)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l.agentFileAccessFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
    return SkedTaskRouteGuard(
      key: ObjectKey(_source),
      parent: _source,
      child: page,
    );
  }
}

class _FileGrantTile extends StatelessWidget {
  const _FileGrantTile({super.key, required this.grant, this.onRemove});
  final AgentFileGrant grant;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, end: 12),
            child: Icon(
              grant.kind == FileKind.directory
                  ? Icons.folder_outlined
                  : Icons.description_outlined,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grant.name?.isNotEmpty == true
                      ? grant.name!
                      : grant.resource.value,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  grant.available
                      ? _accessLabel(l, grant.read, grant.write)
                      : l.agentFileAccessUnavailable,
                ),
                Text(
                  grant.persisted
                      ? l.agentFileAccessPersistent
                      : l.agentFileAccessSessionOnly,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  grant.resource.value,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                if (!grant.available && grant.errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    grant.errorMessage!,
                    style: TextStyle(color: colors.error),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: l.agentFileAccessRemove,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

String _accessLabel(AppLocalizations l, bool read, bool write) =>
    switch ((read, write)) {
      (true, true) => l.agentFileAccessReadWrite,
      (true, false) => l.agentFileAccessReadOnly,
      (false, true) => l.agentFileAccessWriteOnly,
      _ => l.agentFileAccessDenied,
    };
