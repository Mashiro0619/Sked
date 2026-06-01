import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/school_site_models.dart';
import '../providers/timetable_provider.dart';
import '../services/export_service.dart';
import '../services/school_site_service.dart';
import '../services/text_file_picker.dart';
import '../utils/platform_capabilities.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/expressive_motion.dart';
import 'school_html_import_page.dart';
import 'school_web_import_page.dart';

enum _SchoolSitesMenuAction { toggleEditMode, importJson, shareJson, saveJson }

enum _SchoolSiteItemAction { edit, delete }

class SchoolSitesPage extends StatefulWidget {
  const SchoolSitesPage({
    super.key,
    SchoolSiteService? siteService,
    ExportService? exportService,
  }) : siteService = siteService ?? const SchoolSiteService(),
       exportService = exportService ?? const ExportService();

  final SchoolSiteService siteService;
  final ExportService exportService;

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
  List<SchoolSite> _sites = const [];

  bool get _supportsWebImport => supportsInAppWebView;

  ExportService get _exportService => widget.exportService;
  SchoolSiteService get _siteService => widget.siteService;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.schoolSitesPageTitle),
        actions: [
          IconButton(
            tooltip: l10n.schoolSitesAdd,
            onPressed: (_editorDialogOpen || _siteMutationInProgress)
                ? null
                : _addSite,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: l10n.schoolHtmlImportEntry,
            onPressed: _htmlImportOpen ? null : _openHtmlImport,
            icon: const Icon(Icons.code),
          ),
          PopupMenuButton<_SchoolSitesMenuAction>(
            tooltip: l10n.importExport,
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SchoolSitesMenuAction.toggleEditMode,
                child: Text(_isEditMode ? l10n.confirm : l10n.schoolSitesEdit),
              ),
              PopupMenuItem(
                value: _SchoolSitesMenuAction.importJson,
                enabled: !_jsonImportInProgress,
                child: Text(l10n.schoolSitesImportJson),
              ),
              PopupMenuItem(
                value: _SchoolSitesMenuAction.shareJson,
                enabled: !_jsonShareInProgress,
                child: Text(l10n.schoolSitesShareJson),
              ),
              PopupMenuItem(
                value: _SchoolSitesMenuAction.saveJson,
                enabled: !_jsonSaveInProgress,
                child: Text(l10n.schoolSitesSaveJson),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sites.isEmpty
          ? _SchoolSitesEmptyState(
              onAdd: (_editorDialogOpen || _siteMutationInProgress)
                  ? null
                  : _addSite,
              onHtmlImport: _htmlImportOpen ? null : _openHtmlImport,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _sites.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final site = _sites[index];
                return _SchoolSiteRow(
                  site: site,
                  enabled: _supportsWebImport && !_webImportOpen,
                  onTap: _supportsWebImport && !_webImportOpen
                      ? () => _openWebImportForSite(site)
                      : null,
                  trailing: _isEditMode
                      ? PopupMenuButton<_SchoolSiteItemAction>(
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
                            PopupMenuItem(
                              value: _SchoolSiteItemAction.edit,
                              child: Text(l10n.schoolSitesEdit),
                            ),
                            PopupMenuItem(
                              value: _SchoolSiteItemAction.delete,
                              child: Text(l10n.delete),
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
    );
  }

  Future<void> _loadSites() async {
    try {
      final sites = await _siteService.loadSites();
      if (!mounted) {
        return;
      }
      setState(() {
        _sites = sites;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to load school sites: $e\n$st');
      if (!mounted) {
        return;
      }
      setState(() {
        _sites = const [];
        _loading = false;
      });
      _showMessage(
        AppLocalizations.of(context).schoolWebImportSchoolLoadFailed,
      );
    }
  }

  Future<void> _handleMenuAction(_SchoolSitesMenuAction action) async {
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
    future.whenComplete(() {
      nameController.dispose();
      urlController.dispose();
    });
    return future;
  }

  Future<void> _persistSites(List<SchoolSite> sites) async {
    if (_siteMutationInProgress || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _siteMutationInProgress = true);
    try {
      await _siteService.saveSites(sites);
      if (!mounted) {
        return;
      }
      setState(() {
        _sites = sites;
      });
      _showMessage(l10n.schoolSitesSaved);
    } catch (_) {
      _showMessage(l10n.saveFailedRetry);
    } finally {
      if (mounted) {
        setState(() => _siteMutationInProgress = false);
      }
    }
  }

  Future<void> _importJson() async {
    if (_jsonImportInProgress || !mounted) {
      return;
    }
    _setJsonImportInProgress(true);
    final l10n = AppLocalizations.of(context);
    try {
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
        final imported = await _siteService.importSites(source);
        if (!mounted) {
          return;
        }
        setState(() {
          _sites = imported;
          _isEditMode = false;
        });
        _showMessage(l10n.schoolSitesImported);
      } on FormatException catch (error) {
        _showMessage(error.message);
      } catch (_) {
        _showMessage(l10n.importFailedCheckContent);
      }
    } finally {
      _setJsonImportInProgress(false);
    }
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
