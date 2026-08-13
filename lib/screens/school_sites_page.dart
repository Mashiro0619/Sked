import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/school_site_models.dart';
import '../providers/timetable_provider.dart';
import '../services/export_service.dart';
import '../services/school_site_service.dart';
import '../services/school_site_store.dart';
import '../services/text_file_picker.dart';
import '../utils/platform_capabilities.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/expressive_motion.dart';
import '../widgets/sked_popup_menu.dart';
import '../widgets/settings_list.dart';
import 'school_html_import_page.dart';
import 'school_web_import_page.dart';

enum _SchoolSitesMenuAction {
  toggleEditMode,
  importJson,
  shareJson,
  saveJson,
  recoveryArtifacts,
}

enum _SchoolSiteItemAction { edit, delete }

enum _SchoolSiteImportAction { merge, replace }

Future<String?> _pickSchoolSiteJson() {
  return TextFilePicker.pickText(allowedExtensions: const ['json']);
}

class SchoolSitesPage extends StatefulWidget {
  SchoolSitesPage({
    super.key,
    SchoolSiteService? siteService,
    ExportService? exportService,
    Future<String?> Function()? pickJsonSource,
  }) : siteService = siteService ?? SchoolSiteService(),
       exportService = exportService ?? const ExportService(),
       pickJsonSource = pickJsonSource ?? _pickSchoolSiteJson;

  final SchoolSiteService siteService;
  final ExportService exportService;
  final Future<String?> Function() pickJsonSource;

  @override
  State<SchoolSitesPage> createState() => _SchoolSitesPageState();
}

class _SchoolSitesPageState extends State<SchoolSitesPage> {
  var _loading = true;
  var _isEditMode = false;
  var _editorDialogOpen = false;
  var _htmlImportOpen = false;
  var _webImportOpen = false;
  var _jsonImportInProgress = false;
  var _jsonShareInProgress = false;
  var _jsonSaveInProgress = false;
  var _siteMutationInProgress = false;
  var _recoveryActionInProgress = false;
  List<SchoolSite> _sites = const [];
  List<String> _recoveryPaths = const [];
  SchoolSiteLoadResult? _loadResult;

  bool get _supportsWebImport => supportsInAppWebView;

  ExportService get _exportService => widget.exportService;
  SchoolSiteService get _siteService => widget.siteService;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSites());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loadResult = _loadResult;
    final canUsePageActions = !_loading && loadResult?.canWrite == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.schoolSitesPageTitle),
        actions: [
          IconButton(
            tooltip: l10n.schoolSitesAdd,
            onPressed:
                !canUsePageActions ||
                    _editorDialogOpen ||
                    _siteMutationInProgress
                ? null
                : _addSite,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: l10n.schoolHtmlImportEntry,
            onPressed: !canUsePageActions || _htmlImportOpen
                ? null
                : _openHtmlImport,
            icon: const Icon(Icons.code),
          ),
          SkedPopupMenuButton<_SchoolSitesMenuAction>(
            tooltip: l10n.importExport,
            enabled: canUsePageActions,
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              SkedPopupMenuItem(
                value: _SchoolSitesMenuAction.toggleEditMode,
                child: Text(_isEditMode ? l10n.confirm : l10n.schoolSitesEdit),
              ),
              SkedPopupMenuItem(
                value: _SchoolSitesMenuAction.importJson,
                enabled: !_jsonImportInProgress,
                child: Text(l10n.schoolSitesImportJson),
              ),
              SkedPopupMenuItem(
                value: _SchoolSitesMenuAction.shareJson,
                enabled: !_jsonShareInProgress,
                child: Text(l10n.schoolSitesShareJson),
              ),
              SkedPopupMenuItem(
                value: _SchoolSitesMenuAction.saveJson,
                enabled: !_jsonSaveInProgress,
                child: Text(l10n.schoolSitesSaveJson),
              ),
              if (_recoveryPaths.isNotEmpty)
                SkedPopupMenuItem(
                  value: _SchoolSitesMenuAction.recoveryArtifacts,
                  child: Text(l10n.dataRecoveryArtifactsAction),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : loadResult?.canWrite == false
            ? _SchoolSitesRecoveryView(
                status: loadResult!.recoveryStatus,
                hasArtifacts: _recoveryPaths.isNotEmpty,
                canReplace: loadResult.canReplaceAfterRecovery,
                isBusy: _recoveryActionInProgress,
                onRetry: _retryRecovery,
                onShowArtifacts: _recoveryPaths.isEmpty
                    ? null
                    : _showRecoveryArtifacts,
                onImportReplacement: loadResult.canReplaceAfterRecovery
                    ? _importRecoveryJson
                    : null,
                onStartFresh: loadResult.canReplaceAfterRecovery
                    ? _confirmStartFresh
                    : null,
              )
            : _sites.isEmpty
            ? _SchoolSitesEmptyState(
                onAdd: (_editorDialogOpen || _siteMutationInProgress)
                    ? null
                    : _addSite,
                onHtmlImport: _htmlImportOpen ? null : _openHtmlImport,
              )
            : ResponsiveSettingsSingleColumnBody(
                topPadding: 16,
                child: Column(
                  children: [
                    for (var index = 0; index < _sites.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _SchoolSiteRow(
                        site: _sites[index],
                        enabled: _supportsWebImport && !_webImportOpen,
                        onTap: _supportsWebImport && !_webImportOpen
                            ? () => _openWebImportForSite(_sites[index])
                            : null,
                        trailing: _isEditMode
                            ? SkedPopupMenuButton<_SchoolSiteItemAction>(
                                onSelected: (action) async {
                                  switch (action) {
                                    case _SchoolSiteItemAction.edit:
                                      await _editSite(index);
                                      return;
                                    case _SchoolSiteItemAction.delete:
                                      await _deleteSite(index);
                                      return;
                                  }
                                },
                                itemBuilder: (context) => [
                                  SkedPopupMenuItem(
                                    value: _SchoolSiteItemAction.edit,
                                    child: Text(l10n.schoolSitesEdit),
                                  ),
                                  SkedPopupMenuItem(
                                    value: _SchoolSiteItemAction.delete,
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _loadSites() async {
    try {
      final result = await _siteService.loadSitesResult();
      final recoveryPaths = await _resolveRecoveryPaths(result);
      if (!mounted) {
        return;
      }
      setState(() {
        _sites = result.sites;
        _loadResult = result;
        _recoveryPaths = recoveryPaths;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to load school sites: $e\n$st');
      if (!mounted) {
        return;
      }
      setState(() {
        _sites = const [];
        _loadResult = SchoolSiteLoadResult(
          sites: const [],
          recoveryStatus: SchoolSiteRecoveryStatus.storageReadFailed,
          canWrite: false,
          error: e,
          stackTrace: st,
        );
        _recoveryPaths = const [];
        _loading = false;
      });
    }
  }

  Future<List<String>> _resolveRecoveryPaths(
    SchoolSiteLoadResult result,
  ) async {
    return List.unmodifiable(result.recoveryArtifacts);
  }

  Future<void> _retryRecovery() async {
    await _runRecoveryAction(_loadSites);
  }

  Future<void> _confirmStartFresh() async {
    final result = _loadResult;
    if (result == null || !result.canReplaceAfterRecovery || !mounted) return;
    final confirmed = await _showRecoveryReplacementConfirmation();
    if (confirmed != true || !mounted) return;
    await _runRecoveryAction(() async {
      await _siteService.replaceSitesAfterRecovery(result.sites);
      await _loadSites();
    });
  }

  Future<void> _importRecoveryJson() async {
    final result = _loadResult;
    if (result == null || !result.canReplaceAfterRecovery || !mounted) return;
    final source = await widget.pickJsonSource();
    if (source == null || !mounted) return;
    late final SchoolSiteImportPreview preview;
    try {
      preview = decodeSchoolSitesForImport(source);
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }
    final action = await _showImportPreview(preview, allowMerge: false);
    if (action != _SchoolSiteImportAction.replace || !mounted) return;
    final confirmed = await _confirmReplaceImport(preview.sites.length);
    if (confirmed != true || !mounted) return;
    await _runRecoveryAction(() async {
      await _siteService.replaceSitesAfterRecovery(preview.sites);
      await _loadSites();
      if (mounted) {
        _showMessage(AppLocalizations.of(context).schoolSitesImported);
      }
    });
  }

  Future<bool?> _showRecoveryReplacementConfirmation() {
    return showExpressiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.schoolSitesRecoveryStartFreshConfirmTitle),
          content: Text(l10n.schoolSitesRecoveryStartFreshConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const ValueKey('school-sites-recovery-confirm-start-fresh'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.schoolSitesRecoveryStartFreshAction),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRecoveryArtifacts() async {
    if (_recoveryPaths.isEmpty || !mounted) return;
    final exportableArtifacts = <String>{};
    for (final artifact in _recoveryPaths) {
      if (await _siteService.readRecoveryArtifact(artifact) != null) {
        exportableArtifacts.add(artifact);
      }
    }
    if (!mounted) return;
    final content = _recoveryPaths.join('\n');
    final action =
        await showExpressiveDialog<_SchoolSiteRecoveryArtifactDialogAction>(
          context: context,
          builder: (dialogContext) {
            final l10n = AppLocalizations.of(dialogContext);
            return AlertDialog(
              title: Text(l10n.dataRecoveryArtifactsAction),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                  maxHeight: 360,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < _recoveryPaths.length;
                        index++
                      ) ...[
                        if (index > 0) const Divider(height: 1),
                        _SchoolSiteRecoveryArtifactRow(
                          artifact: _recoveryPaths[index],
                          isWeb: _exportService.isWeb,
                          onExport:
                              exportableArtifacts.contains(
                                _recoveryPaths[index],
                              )
                              ? () => Navigator.of(dialogContext).pop(
                                  _SchoolSiteRecoveryArtifactDialogAction.export(
                                    _recoveryPaths[index],
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    const _SchoolSiteRecoveryArtifactDialogAction.copyPaths(),
                  ),
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(l10n.copyText),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        );
    if (!mounted || action == null) return;
    if (action.type == _SchoolSiteRecoveryArtifactDialogActionType.copyPaths) {
      await Clipboard.setData(ClipboardData(text: content));
      if (!mounted) return;
      _showMessage(AppLocalizations.of(context).copiedToClipboard);
      return;
    }
    final artifactPath = action.artifactPath;
    if (artifactPath != null) {
      await _exportRecoveryArtifact(artifactPath);
    }
  }

  Future<void> _exportRecoveryArtifact(String artifactPath) async {
    await _runRecoveryAction(() async {
      final bytes = await _siteService.readRecoveryArtifact(artifactPath);
      if (bytes == null) {
        throw StateError('Recovery artifact is no longer available.');
      }
      final fileName = _schoolSiteRecoveryArtifactFileName(artifactPath);
      final result = await _exportService.saveBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (!mounted) return;
      if (result.status == ExportSaveStatus.saved) {
        _showMessage(
          AppLocalizations.of(context).savedToPath(result.path ?? fileName),
        );
        return;
      }
      if (result.status == ExportSaveStatus.cancelled) return;
      await _exportService.shareBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );
    });
  }

  Future<void> _runRecoveryAction(Future<void> Function() action) async {
    if (_recoveryActionInProgress || !mounted) return;
    setState(() => _recoveryActionInProgress = true);
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('School-site recovery action failed: $error\n$stackTrace');
      if (mounted) {
        _showMessage(AppLocalizations.of(context).saveFailedRetry);
      }
    } finally {
      if (mounted) {
        setState(() => _recoveryActionInProgress = false);
      }
    }
  }

  Future<void> _handleMenuAction(_SchoolSitesMenuAction action) async {
    if (_loadResult?.canWrite != true) return;
    switch (action) {
      case _SchoolSitesMenuAction.toggleEditMode:
        setState(() => _isEditMode = !_isEditMode);
        return;
      case _SchoolSitesMenuAction.importJson:
        await _importJson();
        return;
      case _SchoolSitesMenuAction.shareJson:
        await _shareJson();
        return;
      case _SchoolSitesMenuAction.saveJson:
        await _saveJsonToFile();
        return;
      case _SchoolSitesMenuAction.recoveryArtifacts:
        await _showRecoveryArtifacts();
        return;
    }
  }

  void _setEditorDialogOpen(bool value) {
    if (_editorDialogOpen == value) return;
    if (mounted) {
      setState(() => _editorDialogOpen = value);
    } else {
      _editorDialogOpen = value;
    }
  }

  void _setHtmlImportOpen(bool value) {
    if (_htmlImportOpen == value) return;
    if (mounted) {
      setState(() => _htmlImportOpen = value);
    } else {
      _htmlImportOpen = value;
    }
  }

  void _setWebImportOpen(bool value) {
    if (_webImportOpen == value) return;
    if (mounted) {
      setState(() => _webImportOpen = value);
    } else {
      _webImportOpen = value;
    }
  }

  void _setJsonImportInProgress(bool value) {
    if (_jsonImportInProgress == value) return;
    if (mounted) {
      setState(() => _jsonImportInProgress = value);
    } else {
      _jsonImportInProgress = value;
    }
  }

  void _setJsonShareInProgress(bool value) {
    if (_jsonShareInProgress == value) return;
    if (mounted) {
      setState(() => _jsonShareInProgress = value);
    } else {
      _jsonShareInProgress = value;
    }
  }

  void _setJsonSaveInProgress(bool value) {
    if (_jsonSaveInProgress == value) return;
    if (mounted) {
      setState(() => _jsonSaveInProgress = value);
    } else {
      _jsonSaveInProgress = value;
    }
  }

  Future<void> _openHtmlImport() async {
    if (_htmlImportOpen || !mounted) {
      return;
    }
    _setHtmlImportOpen(true);
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SchoolHtmlImportPage()));
    } finally {
      _setHtmlImportOpen(false);
    }
  }

  Future<void> _openWebImportForSite(SchoolSite site) async {
    if (_webImportOpen || !mounted) {
      return;
    }
    _setWebImportOpen(true);
    final provider = context.read<TimetableProvider>();
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: SchoolWebImportPage(site: site),
          ),
        ),
      );
    } finally {
      _setWebImportOpen(false);
    }
  }

  Future<void> _addSite() async {
    if (_editorDialogOpen || _siteMutationInProgress || !mounted) {
      return;
    }
    _setEditorDialogOpen(true);
    try {
      final created = await _showEditorDialog();
      if (!mounted || created == null) {
        return;
      }
      await _persistSites([..._sites, created]);
    } finally {
      _setEditorDialogOpen(false);
    }
  }

  Future<void> _editSite(int index) async {
    if (_editorDialogOpen || _siteMutationInProgress || !mounted) {
      return;
    }
    _setEditorDialogOpen(true);
    try {
      final updated = await _showEditorDialog(initialSite: _sites[index]);
      if (!mounted || updated == null) {
        return;
      }
      final nextSites = [..._sites];
      nextSites[index] = updated;
      await _persistSites(nextSites);
    } finally {
      _setEditorDialogOpen(false);
    }
  }

  Future<void> _deleteSite(int index) async {
    if (_siteMutationInProgress || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final site = _sites[index];
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(l10n.schoolSitesDeleteTitle),
          content: Text(l10n.schoolSitesDeleteMessage(site.name)),
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
    final nextSites = [..._sites]..removeAt(index);
    await _persistSites(nextSites);
  }

  Future<SchoolSite?> _showEditorDialog({SchoolSite? initialSite}) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: initialSite?.name ?? '');
    final urlController = TextEditingController(
      text: initialSite?.loginUrl ?? '',
    );

    final future = showExpressiveDialog<SchoolSite>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(SchoolSite? value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(
            initialSite == null ? l10n.schoolSitesAdd : l10n.schoolSitesEdit,
          ),
          content: ExpressiveDialogContent(
            maxWidth: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.schoolSitesNameLabel,
                    prefixIcon: const Icon(Icons.school_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.schoolSitesLoginUrlLabel,
                    prefixIcon: const Icon(Icons.link),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => popWith(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (popped) return;
                final site = SchoolSite(
                  name: nameController.text.trim(),
                  loginUrl: urlController.text.trim(),
                );
                if (!site.isValid) {
                  _showMessage(l10n.schoolSitesFormInvalid);
                  return;
                }
                popWith(site);
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    return future.whenComplete(() {
      nameController.dispose();
      urlController.dispose();
    });
  }

  Future<bool> _persistSites(
    List<SchoolSite> sites, {
    String? successMessage,
  }) async {
    if (_siteMutationInProgress || !mounted) {
      return false;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _siteMutationInProgress = true);
    try {
      await _siteService.saveSites(sites);
      if (!mounted) {
        return false;
      }
      setState(() {
        _sites = sites;
      });
      _showMessage(successMessage ?? l10n.schoolSitesSaved);
      return true;
    } on SchoolSiteStaleWriteException {
      await _reloadAfterRejectedMutation();
      if (mounted) {
        _showMessage(l10n.saveFailedRetry);
      }
      return false;
    } on SchoolSiteWriteBlockedException {
      await _reloadAfterRejectedMutation();
      if (mounted) {
        _showMessage(l10n.saveFailedRetry);
      }
      return false;
    } on SchoolSiteStoreRecoveryBlockedException {
      await _reloadAfterRejectedMutation();
      if (mounted) {
        _showMessage(l10n.saveFailedRetry);
      }
      return false;
    } catch (_) {
      _showMessage(l10n.saveFailedRetry);
      return false;
    } finally {
      if (mounted) {
        setState(() => _siteMutationInProgress = false);
      }
    }
  }

  Future<void> _reloadAfterRejectedMutation() async {
    if (!mounted) return;
    await _loadSites();
  }

  Future<void> _importJson() async {
    if (_jsonImportInProgress || !mounted) {
      return;
    }
    _setJsonImportInProgress(true);
    final l10n = AppLocalizations.of(context);
    try {
      final source = await widget.pickJsonSource();
      if (!mounted) {
        return;
      }
      if (source == null) {
        return;
      }
      try {
        final preview = decodeSchoolSitesForImport(source);
        final action = await _showImportPreview(preview);
        if (!mounted || action == null) return;
        if (action == _SchoolSiteImportAction.replace) {
          final confirmed = await _confirmReplaceImport(preview.sites.length);
          if (!mounted || confirmed != true) return;
        }
        final nextSites = action == _SchoolSiteImportAction.replace
            ? preview.sites
            : _mergeImportedSites(_sites, preview.sites);
        final saved = await _persistSites(
          nextSites,
          successMessage: l10n.schoolSitesImported,
        );
        if (saved && mounted) setState(() => _isEditMode = false);
      } on FormatException catch (error) {
        _showMessage(error.message);
      } catch (_) {
        _showMessage(l10n.importFailedCheckContent);
      }
    } finally {
      _setJsonImportInProgress(false);
    }
  }

  Future<_SchoolSiteImportAction?> _showImportPreview(
    SchoolSiteImportPreview preview, {
    bool allowMerge = true,
  }) {
    return showExpressiveDialog<_SchoolSiteImportAction>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        final rowCount = preview.sites.length + preview.issues.length;
        final listHeight = (rowCount * 64.0).clamp(0.0, 300.0).toDouble();
        final canReplace = preview.sites.isNotEmpty || preview.issues.isEmpty;
        return AlertDialog(
          title: Text(l10n.schoolSitesImportPreviewTitle),
          content: ExpressiveDialogContent(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.schoolSitesImportPreviewSummary(
                    preview.sites.length,
                    preview.issues.length,
                  ),
                ),
                if (rowCount == 0) ...[
                  const SizedBox(height: 12),
                  Text(l10n.schoolSitesImportEmptyPreview),
                ] else ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: listHeight,
                    child: ListView(
                      children: [
                        for (final site in preview.sites)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text(site.name),
                            subtitle: Text(site.loginUrl),
                          ),
                        for (final issue in preview.issues)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.error_outline,
                              color: Theme.of(dialogContext).colorScheme.error,
                            ),
                            title: Text(
                              l10n.schoolSitesImportInvalidEntry(
                                issue.index + 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            if (allowMerge)
              TextButton(
                key: const ValueKey('school-sites-import-merge'),
                onPressed: preview.sites.isEmpty
                    ? null
                    : () =>
                          Navigator.of(dialogContext)
                              .pop(_SchoolSiteImportAction.merge),
                child: Text(l10n.schoolSitesImportMerge),
              ),
            FilledButton(
              key: const ValueKey('school-sites-import-replace'),
              onPressed: canReplace
                  ? () =>
                        Navigator.of(dialogContext)
                            .pop(_SchoolSiteImportAction.replace)
                  : null,
              child: Text(l10n.schoolSitesImportReplace),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmReplaceImport(int importedCount) {
    return showExpressiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.schoolSitesImportReplaceConfirmTitle),
          content: Text(
            l10n.schoolSitesImportReplaceConfirmMessage(
              _sites.length,
              importedCount,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const ValueKey('school-sites-import-confirm-replace'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.schoolSitesImportReplace),
            ),
          ],
        );
      },
    );
  }

  List<SchoolSite> _mergeImportedSites(
    List<SchoolSite> current,
    List<SchoolSite> imported,
  ) {
    final merged = [...current];
    final seen = {for (final site in current) _schoolSiteIdentity(site)};
    for (final site in imported) {
      if (seen.add(_schoolSiteIdentity(site))) merged.add(site);
    }
    return merged;
  }

  Future<void> _shareJson() async {
    if (_jsonShareInProgress || !mounted) {
      return;
    }
    _setJsonShareInProgress(true);
    final l10n = AppLocalizations.of(context);
    try {
      final content = await _siteService.exportSites(_sites);
      if (!mounted) {
        return;
      }
      await _exportService.shareFile(
        ExportPayload(fileName: l10n.schoolSitesJsonFileName, content: content),
      );
    } finally {
      _setJsonShareInProgress(false);
    }
  }

  Future<void> _saveJsonToFile() async {
    if (_jsonSaveInProgress || !mounted) {
      return;
    }
    _setJsonSaveInProgress(true);
    try {
      await _saveJsonToFileInner();
    } finally {
      _setJsonSaveInProgress(false);
    }
  }

  Future<void> _saveJsonToFileInner() async {
    final l10n = AppLocalizations.of(context);
    final result = await _exportService.saveFile(
      ExportPayload(
        fileName: l10n.schoolSitesJsonFileName,
        content: await _siteService.exportSites(_sites),
      ),
    );
    if (!mounted) {
      return;
    }

    switch (result.status) {
      case ExportSaveStatus.saved:
        _showMessage(
          l10n.savedToPath(result.path ?? l10n.schoolSitesJsonFileName),
        );
        return;
      case ExportSaveStatus.cancelled:
        _showMessage(l10n.saveCancelled);
        return;
      case ExportSaveStatus.permissionDenied:
        final retry = await _showPermissionDialog(
          title: l10n.fileSaveRestrictedTitle,
          message: l10n.fileSaveRestrictedRetryMessage,
          confirmText: l10n.retrySave,
        );
        if (retry == true && mounted) {
          await _saveJsonToFileInner();
        }
        return;
      case ExportSaveStatus.permissionPermanentlyDenied:
        final openSettings = await _showPermissionDialog(
          title: l10n.fileSaveRestrictedTitle,
          message: l10n.fileSaveRestrictedSettingsMessage,
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
          await _shareJson();
          if (mounted) {
            _showMessage(l10n.exportSwitchedToShare);
          }
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
          await _shareJson();
          if (mounted) {
            _showMessage(l10n.exportSwitchedToShare);
          }
        } else if (mounted) {
          _showMessage(l10n.saveFailedRetry);
        }
        return;
    }
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _SchoolSiteRecoveryArtifactDialogActionType { copyPaths, export }

class _SchoolSiteRecoveryArtifactDialogAction {
  const _SchoolSiteRecoveryArtifactDialogAction.copyPaths()
    : type = _SchoolSiteRecoveryArtifactDialogActionType.copyPaths,
      artifactPath = null;

  const _SchoolSiteRecoveryArtifactDialogAction.export(this.artifactPath)
    : type = _SchoolSiteRecoveryArtifactDialogActionType.export;

  final _SchoolSiteRecoveryArtifactDialogActionType type;
  final String? artifactPath;
}

class _SchoolSiteRecoveryArtifactRow extends StatelessWidget {
  const _SchoolSiteRecoveryArtifactRow({
    required this.artifact,
    required this.isWeb,
    required this.onExport,
  });

  final String artifact;
  final bool isWeb;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: SelectionArea(child: Text(artifact))),
        if (onExport != null)
          IconButton(
            tooltip: isWeb ? l10n.save : l10n.share,
            onPressed: onExport,
            icon: Icon(isWeb ? Icons.download_outlined : Icons.ios_share),
          ),
      ],
    );
  }
}

String _schoolSiteRecoveryArtifactFileName(String artifactPath) {
  final segments = artifactPath.replaceAll('\\', '/').split('/');
  final rawName = segments.isEmpty ? '' : segments.last.trim();
  var fileName = rawName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (fileName.isEmpty) fileName = 'Sked_school_sites_recovery.json';
  if (!fileName.contains('.')) fileName = '$fileName.json';
  return fileName;
}

String _schoolSiteIdentity(SchoolSite site) {
  return '${site.name.trim()}\x00${site.loginUrl.trim()}';
}

class _SchoolSitesRecoveryView extends StatelessWidget {
  const _SchoolSitesRecoveryView({
    required this.status,
    required this.hasArtifacts,
    required this.canReplace,
    required this.isBusy,
    required this.onRetry,
    required this.onShowArtifacts,
    required this.onImportReplacement,
    required this.onStartFresh,
  });

  final SchoolSiteRecoveryStatus status;
  final bool hasArtifacts;
  final bool canReplace;
  final bool isBusy;
  final VoidCallback onRetry;
  final VoidCallback? onShowArtifacts;
  final VoidCallback? onImportReplacement;
  final VoidCallback? onStartFresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, message, icon) = switch (status) {
      SchoolSiteRecoveryStatus.storedDataCorrupt => (
        l10n.schoolSitesRecoveryCorruptTitle,
        l10n.schoolSitesRecoveryCorruptMessage,
        Icons.folder_off_outlined,
      ),
      SchoolSiteRecoveryStatus.storageReadFailed ||
      SchoolSiteRecoveryStatus.recoveryWriteFailed => (
        l10n.schoolSitesRecoveryIoFailureTitle,
        l10n.schoolSitesRecoveryIoFailureMessage,
        Icons.storage_outlined,
      ),
      SchoolSiteRecoveryStatus.unsupportedVersion => (
        l10n.dataRecoveryUnsupportedVersionTitle,
        l10n.dataRecoveryUnsupportedVersionMessage,
        Icons.system_update_outlined,
      ),
      SchoolSiteRecoveryStatus.none ||
      SchoolSiteRecoveryStatus.restoredFromTemporary ||
      SchoolSiteRecoveryStatus.restoredFromBackup => (
        l10n.schoolSitesRecoveryIoFailureTitle,
        l10n.schoolSitesRecoveryIoFailureMessage,
        Icons.storage_outlined,
      ),
    };
    final resolvedMessage = hasArtifacts
        ? '$message\n\n${l10n.schoolSitesRecoveryArtifactsHint}'
        : message;
    final content = ExpressiveEmptyState(
      icon: icon,
      title: title,
      message: resolvedMessage,
      actions: [
        FilledButton.tonalIcon(
          key: const ValueKey('school-sites-recovery-retry'),
          onPressed: isBusy ? null : onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.dataRecoveryRetryAction),
        ),
        if (onShowArtifacts != null)
          OutlinedButton.icon(
            key: const ValueKey('school-sites-recovery-artifacts'),
            onPressed: isBusy ? null : onShowArtifacts,
            icon: const Icon(Icons.folder_copy_outlined),
            label: Text(l10n.dataRecoveryArtifactsAction),
          ),
        if (canReplace && onImportReplacement != null)
          OutlinedButton.icon(
            key: const ValueKey('school-sites-recovery-import'),
            onPressed: isBusy ? null : onImportReplacement,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(l10n.schoolSitesImportJson),
          ),
        if (canReplace && onStartFresh != null)
          FilledButton.icon(
            key: const ValueKey('school-sites-recovery-start-fresh'),
            onPressed: isBusy ? null : onStartFresh,
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.schoolSitesRecoveryStartFreshAction),
          ),
      ],
    );
    return LayoutBuilder(
      key: const ValueKey('school-sites-recovery-view'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}

class _SchoolSitesEmptyState extends StatelessWidget {
  const _SchoolSitesEmptyState({
    required this.onAdd,
    required this.onHtmlImport,
  });

  final VoidCallback? onAdd;
  final VoidCallback? onHtmlImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExpressiveEmptyState(
      icon: Icons.school_outlined,
      title: l10n.schoolSitesPageTitle,
      message: l10n.schoolSitesEmpty,
      actions: [
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(l10n.schoolSitesAdd),
        ),
        FilledButton.tonalIcon(
          onPressed: onHtmlImport,
          icon: const Icon(Icons.code),
          label: Text(l10n.schoolHtmlImportEntry),
        ),
      ],
    );
  }
}

class _SchoolSiteRow extends StatelessWidget {
  const _SchoolSiteRow({
    required this.site,
    required this.enabled,
    required this.onTap,
    required this.trailing,
  });

  final SchoolSite site;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final contentColor = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);

    return ExpressiveTap(
      onTap: onTap,
      enabled: enabled,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: ShapeDecoration(
          color: enabled
              ? colors.surfaceContainerLow
              : colors.surfaceContainerLow.withValues(alpha: 0.66),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final leading = Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: colors.primary.withValues(
                    alpha: enabled ? 0.10 : 0.05,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: enabled ? colors.primary : secondaryColor,
                ),
              );
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    site.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: contentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    site.loginUrl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryColor,
                    ),
                  ),
                ],
              );
              final trailingWidget = trailing == null
                  ? null
                  : IconTheme.merge(
                      data: IconThemeData(color: secondaryColor),
                      child: trailing!,
                    );

              if (constraints.maxWidth < 320 && trailingWidget != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leading,
                        const SizedBox(width: 14),
                        Expanded(child: content),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: trailingWidget,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(child: content),
                  if (trailingWidget != null) ...[
                    const SizedBox(width: 8),
                    trailingWidget,
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
