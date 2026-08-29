import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/school_site_models.dart';
import '../providers/timetable_provider.dart';
import '../screens/school_html_import_page.dart';
import '../services/school_site_service.dart';
import '../services/school_web_import_page_service.dart';
import '../utils/platform_capabilities.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/school_import_config_required_view.dart';

/// Factory seam for driving the real browser callbacks in widget tests.
///
/// Production callers do not supply this. The default branch below still
/// constructs [InAppWebView] directly, so the native session has exactly the
/// same lifecycle and configuration as before.
@visibleForTesting
typedef SchoolWebImportWebViewBuilder = Widget Function(
  SchoolWebImportWebViewConfiguration configuration,
);

/// The subset of native WebView wiring owned by the school import browser.
///
/// Keeping this as a value object lets a test host deliver the same callbacks
/// as a platform WebView without creating a PlatformView. It is deliberately
/// not a browser abstraction: controller operations and settings remain the
/// plugin's concrete types, preserving the production integration boundary.
@visibleForTesting
class SchoolWebImportWebViewConfiguration {
  const SchoolWebImportWebViewConfiguration({
    required this.key,
    required this.windowId,
    required this.initialSettings,
    required this.onWebViewCreated,
    required this.onLoadStart,
    required this.onLoadStop,
    required this.onDOMContentLoaded,
    required this.onProgressChanged,
    required this.onUpdateVisitedHistory,
    required this.onCreateWindow,
    required this.onCloseWindow,
    required this.onTitleChanged,
    required this.onReceivedError,
  });

  final Key key;
  final int? windowId;
  final InAppWebViewSettings initialSettings;
  final void Function(InAppWebViewController controller) onWebViewCreated;
  final void Function(InAppWebViewController controller, WebUri? url)
  onLoadStart;
  final void Function(InAppWebViewController controller, WebUri? url)
  onLoadStop;
  final void Function(InAppWebViewController controller, WebUri? url)
  onDOMContentLoaded;
  final void Function(InAppWebViewController controller, int progress)
  onProgressChanged;
  final void Function(
    InAppWebViewController controller,
    WebUri? url,
    bool? isReload,
  )
  onUpdateVisitedHistory;
  final Future<bool?> Function(
    InAppWebViewController controller,
    CreateWindowAction action,
  )
  onCreateWindow;
  final void Function(InAppWebViewController controller) onCloseWindow;
  final void Function(InAppWebViewController controller, String? title)
  onTitleChanged;
  final void Function(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  )
  onReceivedError;
}

/// The in-app browser used to import the timetable page from a school site.
///
/// A school sign-in flow is one browser session, even when it opens auxiliary
/// windows. Keeping those windows as panes in this one route is important:
/// routing a [windowId] to a second Flutter page breaks the normal browser
/// Back behaviour on desktop and makes a popup look like a separate import
/// flow. Offstage panes stay alive so WebView keeps `window.opener`, cookies,
/// form state, and native window ownership intact.
class SchoolWebImportPage extends StatefulWidget {
  const SchoolWebImportPage({
    super.key,
    required this.site,
    @visibleForTesting this.loadSites,
    @visibleForTesting this.webViewBuilder,
    @visibleForTesting this.supportsPopupWindows,
  });

  final SchoolSite site;

  /// Test-only substitute for persistent school-site loading.
  @visibleForTesting
  final Future<List<SchoolSite>> Function()? loadSites;

  /// Test-only substitute for the native PlatformView host.
  @visibleForTesting
  final SchoolWebImportWebViewBuilder? webViewBuilder;

  /// Test-only platform capability override for popup-pane coverage.
  @visibleForTesting
  final bool? supportsPopupWindows;

  @override
  State<SchoolWebImportPage> createState() => _SchoolWebImportPageState();
}

class _SchoolWebImportPageState extends State<SchoolWebImportPage> {
  /// Releases a missing native load-start acknowledgement after a command.
  ///
  /// This only keeps the callback bookkeeping bounded. It never controls a
  /// visible progress affordance or whether the user can refresh or import.
  static const _loadIndicatorTimeout = Duration(seconds: 30);

  final SchoolSiteService _siteService = SchoolSiteService();
  final SchoolWebImportPageService _pageService =
      const SchoolWebImportPageService();
  final List<_SchoolWebPane> _panes = <_SchoolWebPane>[];
  final Set<String> _navigationPaneIds = <String>{};

  late String _activePaneId;
  bool _isParsing = false;
  bool _isLoadingSchools = true;
  bool _hasRequestedSchoolsLoad = false;
  bool _hasStartedInitialLoad = false;
  bool _isHandlingSystemBack = false;
  bool _isExitConfirmationOpen = false;
  bool _isAddressEditorOpen = false;
  bool _allowRouteExit = false;
  List<SchoolSite> _sites = const [];
  SchoolSite? _selectedSite;
  String? _schoolLoadError;

  bool get _supportsWebView => supportsInAppWebView;

  bool get _supportsPopupWindows =>
      widget.supportsPopupWindows ?? schoolWebImportSupportsPopupWindows();

  _SchoolWebPane get _rootPane => _panes.first;

  _SchoolWebPane get _activePane => _paneById(_activePaneId) ?? _rootPane;

  bool get _hasBlockingDialog =>
      _isExitConfirmationOpen || _isAddressEditorOpen;

  @override
  void initState() {
    super.initState();
    const rootPaneId = 'school-web-import-root';
    _panes.add(_SchoolWebPane(id: rootPaneId));
    _activePaneId = rootPaneId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasRequestedSchoolsLoad) {
      _hasRequestedSchoolsLoad = true;
      unawaited(_loadSchools());
    }
  }

  @override
  void dispose() {
    for (final pane in List<_SchoolWebPane>.of(_panes)) {
      pane.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<TimetableProvider?>();
    final isConfigured = isSchoolImportParserConfigured(provider);
    final pane = _activePane;
    return PopScope<void>(
      canPop: _allowRouteExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_handleSystemBack());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: schoolWebImportShowsCloseButton()
              ? SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: _hasBlockingDialog || _isParsing
                        ? null
                        : _confirmExit,
                    icon: const Icon(Icons.close),
                    tooltip: l10n.schoolWebImportExitBrowser,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(48),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                )
              : null,
          title: _buildAddressTitle(l10n, pane),
          actions: [
            if (schoolWebImportShowsDesktopBackButton())
              IconButton(
                // A Windows window has no Android-style system Back action.
                // It follows browser semantics: history first, then close a
                // popup at its history root. The leading close button remains
                // the explicit way to leave the root browser.
                onPressed:
                    pane.controller == null ||
                        (pane.parentId == null && !pane.canGoBack) ||
                        _isParsing ||
                        _hasBlockingDialog
                    ? null
                    : () => unawaited(_handleDesktopBack()),
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(48),
                  padding: EdgeInsets.zero,
                ),
              ),
            IconButton(
              onPressed: pane.controller == null || _hasBlockingDialog
                  ? null
                  : () => _reload(pane),
              icon: const Icon(Icons.refresh),
              tooltip: MaterialLocalizations.of(context)
                  .refreshIndicatorSemanticLabel,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(48),
                padding: EdgeInsets.zero,
              ),
            ),
            IconButton(
              // A page which changes during extraction is rejected after the
              // fact by the generation check below. A browser load must never
              // make the user's Import action unavailable.
              onPressed:
                  !isConfigured ||
                      pane.controller == null ||
                      _isParsing ||
                      _hasBlockingDialog
                  ? null
                  : () => _importCurrentPage(pane),
              icon: _isParsing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              tooltip: l10n.schoolWebImportImportCurrentPage,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(48),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        body: !isConfigured
            ? SchoolImportConfigRequiredView(
                message: schoolImportConfigMessage(provider, l10n),
              )
            : !_supportsWebView
            ? _buildMessage(l10n.schoolWebImportUnsupportedPlatform)
            : _schoolLoadError != null
            ? _buildMessage(_schoolLoadError!)
            : _isLoadingSchools
            ? const Center(child: CircularProgressIndicator())
            : _sites.isEmpty || _selectedSite == null
            ? _buildMessage(l10n.schoolWebImportNoSchools)
            : _buildBrowserPanes(),
      ),
    );
  }

  Widget _buildBrowserPanes() {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final pane in _panes)
          _buildBrowserPane(pane, isActive: pane.id == _activePaneId),
      ],
    );
  }

  Widget _buildBrowserPane(_SchoolWebPane pane, {required bool isActive}) {
    // Do not unmount an inactive popup. In particular, WebView2 and Android
    // WebView need the child instance to stay alive for window.opener callbacks
    // issued while the parent pane is visible again.
    return Offstage(
      offstage: !isActive,
      child: IgnorePointer(
        ignoring: !isActive,
        child: ExcludeSemantics(
          excluding: !isActive,
          child: _buildWebView(
            SchoolWebImportWebViewConfiguration(
              key: ValueKey<String>('school-web-import-pane-${pane.id}'),
              windowId: pane.windowId,
              initialSettings: schoolWebImportWebViewSettings(
                supportsPopups: _supportsPopupWindows,
              ),
              onWebViewCreated: (controller) {
                pane.controller = controller;
                unawaited(_refreshPaneCanGoBack(pane, controller: controller));
                if (pane == _rootPane) {
                  _scheduleInitialSchoolOpen();
                } else if (pane.awaitingLoadStart) {
                  // A native popup owns its first navigation. Arm the watchdog
                  // only after its child PlatformView has a controller.
                  _armPaneLoadIndicatorWatchdog(pane);
                }
                _refreshIfMounted();
              },
              onLoadStart: (_, url) => _handlePageLoadStart(pane, url),
              onLoadStop: (controller, url) {
                unawaited(_handlePageLoadStop(pane, controller, url));
              },
              onDOMContentLoaded: (controller, url) {
                _handlePageDomContentLoaded(pane, controller, url);
              },
              onProgressChanged: (controller, progress) {
                _handlePageLoadProgress(pane, controller, progress);
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                _handleHistoryUpdate(
                  pane,
                  controller,
                  url,
                  isReload: isReload ?? false,
                );
              },
              onCreateWindow: (controller, action) =>
                  _handleCreateWindow(pane, controller, action),
              onCloseWindow: (_) => _handlePaneCloseRequest(pane),
              onTitleChanged: (_, title) => _handleTitleChanged(pane, title),
              onReceivedError: (controller, request, _) {
                if (request.isForMainFrame == false) {
                  return;
                }
                unawaited(
                  _handlePageLoadFailure(
                    pane,
                    controller,
                    request.url,
                    AppLocalizations.of(context).schoolWebImportLoadFailed,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebView(SchoolWebImportWebViewConfiguration configuration) {
    final builder = widget.webViewBuilder;
    if (builder != null) {
      return builder(configuration);
    }
    return InAppWebView(
      key: configuration.key,
      windowId: configuration.windowId,
      initialSettings: configuration.initialSettings,
      onWebViewCreated: configuration.onWebViewCreated,
      onLoadStart: configuration.onLoadStart,
      onLoadStop: configuration.onLoadStop,
      onDOMContentLoaded: configuration.onDOMContentLoaded,
      onProgressChanged: configuration.onProgressChanged,
      onUpdateVisitedHistory: configuration.onUpdateVisitedHistory,
      onCreateWindow: configuration.onCreateWindow,
      onCloseWindow: configuration.onCloseWindow,
      onTitleChanged: configuration.onTitleChanged,
      onReceivedError: configuration.onReceivedError,
    );
  }

  Widget _buildMessage(String message) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ExpressiveEmptyState(
            icon: Icons.language_outlined,
            title: message,
          ),
        ),
      ),
    );
  }

  Widget _buildAddressTitle(AppLocalizations l10n, _SchoolWebPane pane) {
    final address = _displayAddressFor(pane);
    final origin = schoolWebImportOrigin(address);
    final isSecure = origin?.startsWith('https://') ?? false;
    final display = origin == null
        ? l10n.schoolWebImportUnknownOrigin
        : isSecure
        ? origin.substring('https://'.length)
        : origin;
    final colors = Theme.of(context).colorScheme;
    // The address remains editable while the native WebView is navigating.
    // Authentication pages routinely keep a request open after their document
    // is usable, so load callbacks must never turn this into a dead control.
    final enabled =
        pane.controller != null && !_hasBlockingDialog && !_isParsing;
    final securityText = isSecure
        ? l10n.schoolWebImportSecureConnection
        : l10n.schoolWebImportInsecureConnection;

    final addressControl = Semantics(
      button: enabled,
      enabled: enabled,
      label: '$display, $securityText',
      hint: enabled ? l10n.schoolWebImportEditAddress : null,
      onTap: enabled ? () => unawaited(_editAddress(pane)) : null,
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: enabled ? () => unawaited(_editAddress(pane)) : null,
            borderRadius: BorderRadius.circular(24),
            excludeFromSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isSecure) ...[
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: colors.error,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: isSecure ? null : colors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return enabled
        ? Tooltip(
            message: l10n.schoolWebImportEditAddress,
            excludeFromSemantics: true,
            child: addressControl,
          )
        : addressControl;
  }

  String _displayAddressFor(_SchoolWebPane pane) {
    if (pane.currentUrl.isNotEmpty) {
      return pane.currentUrl;
    }
    if (pane == _rootPane) {
      return _selectedSite?.loginUrl ?? widget.site.loginUrl;
    }
    return '';
  }

  String _editableAddressFor(_SchoolWebPane pane) =>
      schoolWebImportAddress(_displayAddressFor(pane)) ?? '';

  Future<void> _handleSystemBack() async {
    if (_isHandlingSystemBack || _hasBlockingDialog || _isParsing) {
      return;
    }
    _isHandlingSystemBack = true;
    try {
      final pane = _activePane;
      // Native navigation may still be loading when the user presses Back.
      // It must remain a browser Back action in that case: preventing it would
      // make a redirecting school site feel like a dead end. Keep only the
      // short imperative-command gate so we never issue two controller calls
      // at the same time.
      if (_isNavigating(pane)) {
        return;
      }
      final controller = pane.controller;
      final canGoBack = controller == null
          ? false
          : await controller.canGoBack();
      if (!mounted ||
          _hasBlockingDialog ||
          _isParsing ||
          !_containsPane(pane) ||
          pane.id != _activePaneId ||
          !identical(pane.controller, controller)) {
        return;
      }
      switch (schoolWebImportBackAction(
        canGoBack: canGoBack,
        isPopupPane: pane.parentId != null,
      )) {
        case SchoolWebImportBackAction.webHistory:
          await _goBackInWebView(pane);
        case SchoolWebImportBackAction.closePopup:
          _closePane(pane.id);
        case SchoolWebImportBackAction.exitBrowser:
          await _confirmExit();
      }
    } catch (_) {
      if (mounted) {
        await _confirmExit();
      }
    } finally {
      _isHandlingSystemBack = false;
    }
  }

  /// Handles the explicit desktop browser Back action.
  ///
  /// Unlike the system Back path, the root browser is intentionally kept open
  /// when its WebView has no history. Closing it is reserved for the leading
  /// close affordance, but a popup at its own history root returns to its
  /// parent pane just like a native browser popup would.
  Future<void> _handleDesktopBack() async {
    if (_isHandlingSystemBack || _hasBlockingDialog || _isParsing) {
      return;
    }
    _isHandlingSystemBack = true;
    try {
      final pane = _activePane;
      if (_isNavigating(pane)) {
        return;
      }
      final controller = pane.controller;
      if (controller == null) {
        return;
      }
      final canGoBack = await controller.canGoBack();
      if (!mounted ||
          _hasBlockingDialog ||
          _isParsing ||
          !_containsPane(pane) ||
          pane.id != _activePaneId ||
          !identical(pane.controller, controller)) {
        return;
      }
      if (pane.canGoBack != canGoBack) {
        pane.canGoBack = canGoBack;
        _refreshIfMounted();
      }
      if (canGoBack) {
        await _goBackInWebView(pane);
      } else if (pane.parentId != null) {
        _closePane(pane.id);
      }
    } catch (_) {
      // A failed history query must not make the desktop browser exit. The
      // user can retry or explicitly use the close button.
    } finally {
      _isHandlingSystemBack = false;
    }
  }

  Future<void> _confirmExit() async {
    if (!mounted ||
        _isParsing ||
        _isExitConfirmationOpen ||
        _isAddressEditorOpen) {
      return;
    }
    setState(() => _isExitConfirmationOpen = true);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      final shouldExit = await showExpressiveDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          var popped = false;
          void popWith(bool value) {
            if (popped) {
              return;
            }
            popped = true;
            Navigator.of(dialogContext).pop(value);
          }

          return AlertDialog(
            title: Text(l10n.schoolWebImportExitTitle),
            content: Text(l10n.schoolWebImportExitMessage),
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => popWith(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => popWith(true),
                child: Text(l10n.schoolWebImportExitConfirm),
              ),
            ],
          );
        },
      );
      if (shouldExit == true && mounted) {
        setState(() => _allowRouteExit = true);
        navigator.pop();
      }
    } finally {
      if (mounted && !_allowRouteExit) {
        setState(() => _isExitConfirmationOpen = false);
      }
    }
  }

  Future<void> _editAddress(_SchoolWebPane pane) async {
    if (!mounted ||
        _isAddressEditorOpen ||
        _isExitConfirmationOpen ||
        _isParsing ||
        pane.controller == null) {
      return;
    }
    setState(() => _isAddressEditorOpen = true);
    final controller = TextEditingController(text: _editableAddressFor(pane));
    final l10n = AppLocalizations.of(context);
    try {
      final address = await showExpressiveDialog<String>(
        context: context,
        barrierDismissible: false,
        waitForTransitionComplete: true,
        builder: (dialogContext) {
          String? validationError;
          var submitting = false;
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> submit() async {
                if (submitting) {
                  return;
                }
                final normalized = schoolWebImportAddress(controller.text);
                if (normalized == null) {
                  setDialogState(
                    () => validationError = l10n.schoolWebImportAddressInvalid,
                  );
                  return;
                }
                submitting = true;
                Navigator.of(dialogContext).pop(normalized);
              }

              return AlertDialog(
                title: Text(l10n.schoolWebImportEditAddress),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() => validationError = null);
                    }
                  },
                  onSubmitted: (_) => unawaited(submit()),
                  decoration: InputDecoration(
                    labelText: l10n.schoolWebImportAddressLabel,
                    errorText: validationError,
                    errorMaxLines: 3,
                  ),
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: submitting ? null : () => unawaited(submit()),
                    child: Text(l10n.schoolWebImportOpenAddress),
                  ),
                ],
              );
            },
          );
        },
      );
      if (address != null && mounted && _containsPane(pane)) {
        await _loadAddress(pane, address);
      }
    } finally {
      controller.dispose();
      if (mounted) {
        setState(() => _isAddressEditorOpen = false);
      }
    }
  }

  void _handlePageLoadStart(_SchoolWebPane pane, WebUri? url) {
    if (!_containsPane(pane)) {
      return;
    }
    final nextUrl = url?.toString();
    if (pane.awaitingLoadStart) {
      // An explicit reload/back/address command has already invalidated the
      // current document. Acknowledge its native load-start instead of making
      // a second generation that could let a late callback look current.
      pane.awaitingLoadStart = false;
      if (nextUrl != null && nextUrl.isNotEmpty) {
        pane.currentUrl = nextUrl;
        pane.latestLoadStartAddress = schoolWebImportCompletionAddress(nextUrl);
      }
      _armPaneLoadIndicatorWatchdog(pane);
      _refreshIfMounted();
      return;
    }
    _beginPaneLoad(pane, nextUrl: nextUrl, didObserveNativeLoadStart: true);
  }

  Future<bool?> _handleCreateWindow(
    _SchoolWebPane parentPane,
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    if (!mounted || !_containsPane(parentPane)) {
      return false;
    }
    final existing = _panes.where((pane) => pane.windowId == action.windowId);
    if (existing.isNotEmpty) {
      setState(() => _activePaneId = existing.first.id);
      return true;
    }
    if (_supportsPopupWindows) {
      final pane =
          _SchoolWebPane(
              id: 'school-web-import-popup-${action.windowId}',
              windowId: action.windowId,
              parentId: parentPane.id,
            )
            ..awaitingLoadStart = true
            ..isLoadingPage = true
            ..currentUrl =
                schoolWebImportAddress(action.request.url?.toString() ?? '') ??
                '';
      setState(() {
        _panes.add(pane);
        _activePaneId = pane.id;
      });
      return true;
    }

    // No native child WebView is available. A URL-backed request can still be
    // useful, but loading it in the current pane is deliberately a GET-only
    // fallback: platform plugins may not expose the original POST body here.
    final fallbackAddress = schoolWebImportAddress(
      action.request.url?.toString() ?? '',
    );
    if (fallbackAddress != null) {
      await _loadAddress(parentPane, fallbackAddress, controller: controller);
      return true;
    }
    _showMessage(
      AppLocalizations.of(context).schoolWebImportNewWindowUnsupported,
    );
    return false;
  }

  void _handlePaneCloseRequest(_SchoolWebPane pane) {
    if (!mounted || !_containsPane(pane)) {
      return;
    }
    if (pane.parentId == null) {
      unawaited(_confirmExit());
      return;
    }
    _closePane(pane.id);
  }

  void _closePane(String paneId) {
    final pane = _paneById(paneId);
    if (pane == null || pane.parentId == null) {
      return;
    }
    final removed = <_SchoolWebPane>[];
    void collect(String id) {
      final current = _paneById(id);
      if (current == null) {
        return;
      }
      for (final child
          in _panes.where((item) => item.parentId == id).toList()) {
        collect(child.id);
      }
      removed.add(current);
    }

    collect(paneId);
    final parentId = pane.parentId!;
    final wasActive = removed.any((item) => item.id == _activePaneId);
    setState(() {
      _panes.removeWhere(removed.contains);
      _navigationPaneIds.removeAll(removed.map((item) => item.id));
      if (wasActive) {
        _activePaneId = _paneById(parentId)?.id ?? _rootPane.id;
      }
    });
    for (final removedPane in removed) {
      removedPane.dispose();
    }
  }

  void _handleHistoryUpdate(
    _SchoolWebPane pane,
    InAppWebViewController controller,
    WebUri? url, {
    required bool isReload,
  }) {
    if (!_containsPane(pane) || !identical(pane.controller, controller)) {
      return;
    }
    final nextUrl = url?.toString() ?? '';
    final changedUrl = nextUrl.isNotEmpty && nextUrl != pane.currentUrl;
    if (!changedUrl && !isReload) {
      return;
    }
    if (changedUrl) {
      pane.currentUrl = nextUrl;
    }
    // History API navigation and hash changes often do not emit a matching
    // load-start/stop pair. The visible document still changed, so invalidate
    // an extraction that might currently be evaluating the previous page.
    // There is no subsequent completion callback to re-enable importing for a
    // pure SPA/history change, so the newly visible revision is importable
    // immediately after the old extraction is invalidated.
    if (!pane.isLoadingPage && changedUrl) {
      pane.documentRevision += 1;
      pane.hasSuccessfulPageLoad = true;
    }
    unawaited(_refreshPaneCanGoBack(pane, controller: controller));
    _refreshIfMounted();
  }

  void _handleTitleChanged(_SchoolWebPane pane, String? title) {
    if (!_containsPane(pane) || title == null || title == pane.currentTitle) {
      return;
    }
    pane.currentTitle = title;
    _refreshIfMounted();
  }

  Future<void> _loadSchools() async {
    final l10n = AppLocalizations.of(context);
    try {
      final sites =
          await (widget.loadSites?.call() ?? _siteService.loadSites());
      if (!mounted) {
        return;
      }
      final selected = sites
          .where((item) => item.loginUrl == widget.site.loginUrl)
          .firstOrNull;
      setState(() {
        _sites = sites;
        _selectedSite = selected ?? widget.site;
        _isLoadingSchools = false;
      });
      _scheduleInitialSchoolOpen();
    } catch (error, stackTrace) {
      debugPrint('Failed to load schools for web import: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingSchools = false;
        _schoolLoadError = l10n.schoolWebImportSchoolLoadFailed;
      });
    }
  }

  void _scheduleInitialSchoolOpen() {
    if (_hasStartedInitialLoad ||
        _rootPane.controller == null ||
        _selectedSite == null) {
      return;
    }
    _hasStartedInitialLoad = true;
    unawaited(_openSelectedSchool());
  }

  Future<void> _openSelectedSchool() async {
    final site = _selectedSite;
    if (site == null || _rootPane.controller == null) {
      _hasStartedInitialLoad = false;
      return;
    }
    // School-site data is validated when it is saved, but it can still come
    // from an older backup. Normalize it again before handing it to the
    // platform WebView so credentials in a legacy URL never enter the browser
    // session or address state.
    final initialAddress = schoolWebImportAddress(site.loginUrl);
    if (initialAddress == null) {
      _hasStartedInitialLoad = false;
      _showMessage(AppLocalizations.of(context).schoolWebImportAddressInvalid);
      return;
    }
    await _loadAddress(_rootPane, initialAddress);
  }

  Future<void> _reload(_SchoolWebPane pane) async {
    final controller = pane.controller;
    final loadFailedMessage = AppLocalizations.of(context)
        .schoolWebImportLoadFailed;
    if (controller == null || !_beginNavigationGate(pane)) {
      return;
    }
    _beginPaneLoad(pane, awaitingLoadStart: true);
    try {
      await controller.reload();
    } catch (_) {
      await _handlePageLoadFailure(pane, controller, null, loadFailedMessage);
    } finally {
      _endNavigationGate(pane);
    }
  }

  Future<void> _goBackInWebView(
    _SchoolWebPane pane, {
    bool checkCanGoBack = false,
  }) async {
    final controller = pane.controller;
    final loadFailedMessage = AppLocalizations.of(context)
        .schoolWebImportLoadFailed;
    if (controller == null || !_beginNavigationGate(pane)) {
      return;
    }
    try {
      // System Back has already queried history so it can close a popup or
      // leave the browser when appropriate. The desktop AppBar action must
      // stay inside the WebView history and simply do nothing at its root.
      if (checkCanGoBack && !await controller.canGoBack()) {
        return;
      }
      _beginPaneLoad(pane, awaitingLoadStart: true);
      await controller.goBack();
    } catch (_) {
      await _handlePageLoadFailure(pane, controller, null, loadFailedMessage);
    } finally {
      _endNavigationGate(pane);
    }
  }

  Future<void> _loadAddress(
    _SchoolWebPane pane,
    String address, {
    InAppWebViewController? controller,
  }) async {
    final targetController = controller ?? pane.controller;
    final loadFailedMessage = AppLocalizations.of(context)
        .schoolWebImportLoadFailed;
    if (targetController == null || !_beginNavigationGate(pane)) {
      return;
    }
    _beginPaneLoad(pane, nextUrl: address, awaitingLoadStart: true);
    try {
      await targetController.loadUrl(
        urlRequest: URLRequest(url: WebUri(address)),
      );
    } catch (_) {
      await _handlePageLoadFailure(
        pane,
        targetController,
        null,
        loadFailedMessage,
      );
    } finally {
      _endNavigationGate(pane);
    }
  }

  void _beginPaneLoad(
    _SchoolWebPane pane, {
    String? nextUrl,
    bool awaitingLoadStart = false,
    bool didObserveNativeLoadStart = false,
  }) {
    if (!_containsPane(pane)) {
      return;
    }
    pane.previousDocumentAddress = schoolWebImportCompletionAddress(
      pane.currentUrl,
    );
    pane.latestLoadStartAddress = didObserveNativeLoadStart
        ? schoolWebImportCompletionAddress(nextUrl ?? '')
        : null;
    pane.loadGeneration += 1;
    pane.documentRevision += 1;
    pane.failedLoadGeneration = null;
    pane.cancelLoadIndicatorWatchdog();
    pane.awaitingLoadStart = awaitingLoadStart;
    pane.hasSuccessfulPageLoad = false;
    pane.isLoadingPage = true;
    pane.currentTitle = '';
    if (nextUrl != null && nextUrl.isNotEmpty) {
      pane.currentUrl = nextUrl;
    }
    _armPaneLoadIndicatorWatchdog(pane);
    _refreshIfMounted();
  }

  void _armPaneLoadIndicatorWatchdog(_SchoolWebPane pane) {
    pane.cancelLoadIndicatorWatchdog();
    final generation = pane.loadGeneration;
    final documentRevision = pane.documentRevision;
    pane.loadIndicatorWatchdog = Timer(_loadIndicatorTimeout, () {
      if (!mounted ||
          !_containsPane(pane) ||
          generation != pane.loadGeneration ||
          documentRevision != pane.documentRevision) {
        return;
      }
      // Do not invalidate a late onLoadStop. Some CAS pages continue loading
      // after a long script round-trip, and their final callback is authoritative.
      // If native code never supplied a load-start, the acknowledgement fence
      // must also expire here; otherwise that late completion would be rejected
      // forever even after the visual progress indicator disappeared.
      pane.awaitingLoadStart = false;
      pane.isLoadingPage = false;
      _refreshIfMounted();
    });
  }

  /// Main-frame error callbacks carry a request URL instead of WebView2's
  /// current document URL. If a newer observed navigation has left the prior
  /// document, an error for that prior address must not invalidate the page
  /// now on screen.
  ///
  /// Successful terminal callbacks are different: the Windows plugin obtains
  /// their URL from `ICoreWebView2::get_Source` at callback time. That is the
  /// current rendered source, so it remains authoritative even when a login
  /// flow redirects back to the same address it left.
  bool _isCurrentWindowsLoadFailure(_SchoolWebPane pane, String callbackUrl) {
    final callbackAddress = schoolWebImportCompletionAddress(callbackUrl);
    if (callbackAddress == null) {
      return false;
    }
    final previousAddress = pane.previousDocumentAddress;
    final latestLoadStartAddress = pane.latestLoadStartAddress;
    if (previousAddress == null ||
        latestLoadStartAddress == null ||
        latestLoadStartAddress == previousAddress) {
      return true;
    }
    return callbackAddress != previousAddress;
  }

  void _clearPaneNavigationTracking(_SchoolWebPane pane) {
    pane.previousDocumentAddress = null;
    pane.latestLoadStartAddress = null;
  }

  /// Publishes a verified document as ready for extraction.
  ///
  /// WebView2 can keep its network navigation open for an arbitrary time after
  /// the document is already interactive. Both native `onLoadStop` and the
  /// Windows `onDOMContentLoaded` callback use this single transition so the
  /// progress indicator and import affordance can never disagree.
  void _completePaneLoad(_SchoolWebPane pane, String finalAddress) {
    pane.cancelLoadIndicatorWatchdog();
    pane.awaitingLoadStart = false;
    pane.hasSuccessfulPageLoad = true;
    pane.isLoadingPage = false;
    pane.currentUrl = finalAddress;
    _clearPaneNavigationTracking(pane);
    unawaited(_refreshPaneCanGoBack(pane));
    _refreshIfMounted();
  }

  /// Windows WebView2 reports a document-level DOMContentLoaded event even
  /// for pages which never deliver the plugin's terminal `onLoadStop` callback.
  ///
  /// It is deliberately a Windows-only completion signal. Other platforms
  /// retain their existing terminal load semantics, while Windows treats this
  /// native document event as sufficient proof that extraction can inspect the
  /// page currently on screen. The Windows plugin supplies the URL from
  /// `ICoreWebView2::get_Source` when this event is delivered, so do not reject
  /// a callback merely because its rendered address matches the document that
  /// the redirect chain started from. Progress and the visual watchdog remain
  /// non-authoritative and can never call this transition.
  void _handlePageDomContentLoaded(
    _SchoolWebPane pane,
    InAppWebViewController controller,
    WebUri? url,
  ) {
    if (!schoolWebImportTreatsTerminalLoadStopAsAuthoritative() ||
        !_containsPane(pane) ||
        !identical(pane.controller, controller) ||
        pane.failedLoadGeneration == pane.loadGeneration ||
        (!pane.isLoadingPage && pane.hasSuccessfulPageLoad)) {
      return;
    }
    final callbackUrl = url?.toString() ?? '';
    final finalAddress = schoolWebImportAddress(callbackUrl);
    if (finalAddress == null) {
      return;
    }
    _completePaneLoad(pane, finalAddress);
  }

  Future<void> _handlePageLoadStop(
    _SchoolWebPane pane,
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (!_containsPane(pane) || !identical(pane.controller, controller)) {
      return;
    }
    if (pane.failedLoadGeneration == pane.loadGeneration) {
      return;
    }
    // A terminal callback after a native success belongs to an already-settled
    // earlier navigation. A watchdog expiry does not set this flag, so its late
    // valid terminal callback remains eligible to complete the page.
    if (!pane.isLoadingPage && pane.hasSuccessfulPageLoad) {
      return;
    }
    final generation = pane.loadGeneration;
    final documentRevision = pane.documentRevision;
    final callbackUrl = url?.toString() ?? '';
    final terminalCallbackIsAuthoritative =
        schoolWebImportTreatsTerminalLoadStopAsAuthoritative();
    final finalAddress = schoolWebImportAddress(callbackUrl);
    if (finalAddress == null) {
      return;
    }
    var controllerUrl = callbackUrl;
    if (!terminalCallbackIsAuthoritative) {
      try {
        controllerUrl = (await controller.getUrl())?.toString() ?? callbackUrl;
      } catch (_) {
        // A terminal load-stop is still the best signal available on a platform
        // that cannot synchronously report its current URL. This does not replay
        // navigation and keeps its POST/Cookie session entirely native.
      }
    }
    if (!mounted ||
        !_containsPane(pane) ||
        !identical(pane.controller, controller) ||
        generation != pane.loadGeneration ||
        documentRevision != pane.documentRevision ||
        !shouldAcceptSchoolWebImportLoadCompletion(
          callbackUrl: callbackUrl,
          controllerUrl: controllerUrl,
          expectedUrl: pane.currentUrl,
          terminalCallbackIsAuthoritative: terminalCallbackIsAuthoritative,
        )) {
      return;
    }
    // On Windows the terminal native callback describes the rendered document
    // more reliably than the plugin's lagging controller URL or a pre-redirect
    // load-start URL. Always publish that final, sanitized HTTP(S) address.
    _completePaneLoad(pane, finalAddress);
  }

  /// Native progress is not a terminal navigation signal on Windows: WebView2
  /// can emit `100` for a navigation which later fails. There, only a valid
  /// native document callback can make a document importable. Other platforms
  /// retain their existing progress fallback.
  void _handlePageLoadProgress(
    _SchoolWebPane pane,
    InAppWebViewController controller,
    int progress,
  ) {
    if (schoolWebImportTreatsTerminalLoadStopAsAuthoritative() ||
        progress < 100 ||
        !mounted ||
        !_containsPane(pane) ||
        !identical(pane.controller, controller) ||
        !pane.isLoadingPage ||
        pane.awaitingLoadStart) {
      return;
    }
    pane.cancelLoadIndicatorWatchdog();
    pane.hasSuccessfulPageLoad = true;
    pane.isLoadingPage = false;
    _refreshIfMounted();
  }

  Future<void> _handlePageLoadFailure(
    _SchoolWebPane pane,
    InAppWebViewController controller,
    WebUri? failedUrl,
    String message,
  ) async {
    if (!_containsPane(pane)) {
      return;
    }
    if (!pane.isLoadingPage && pane.hasSuccessfulPageLoad) {
      return;
    }
    // A native controller can omit the matching onLoadStart before a terminal
    // error, especially around redirecting authentication pages. Identity,
    // generation, and the reported URL below are the reliable stale-callback
    // fence, so do not leave the UI loading forever merely because start was
    // not delivered.
    final generation = pane.loadGeneration;
    final documentRevision = pane.documentRevision;
    final terminalCallbackIsAuthoritative =
        schoolWebImportTreatsTerminalLoadStopAsAuthoritative();
    var controllerUrl = '';
    if (!terminalCallbackIsAuthoritative) {
      try {
        controllerUrl = (await controller.getUrl())?.toString() ?? '';
      } catch (_) {}
    }
    if (!mounted ||
        !_containsPane(pane) ||
        !identical(pane.controller, controller) ||
        generation != pane.loadGeneration ||
        documentRevision != pane.documentRevision) {
      return;
    }
    final failedUrlText = failedUrl?.toString() ?? '';
    // A Windows main-frame error identifies the failed request, not necessarily
    // the source currently rendered by WebView2. Keep the observed-start check
    // above so an older failure cannot invalidate a document that has already
    // completed on screen.
    if (terminalCallbackIsAuthoritative &&
        failedUrlText.isNotEmpty &&
        !_isCurrentWindowsLoadFailure(pane, failedUrlText)) {
      return;
    }
    if (!terminalCallbackIsAuthoritative &&
        failedUrlText.isNotEmpty &&
        controllerUrl.isNotEmpty &&
        failedUrlText != controllerUrl) {
      return;
    }
    pane.cancelLoadIndicatorWatchdog();
    pane.awaitingLoadStart = false;
    pane.hasSuccessfulPageLoad = false;
    pane.isLoadingPage = false;
    pane.failedLoadGeneration = generation;
    _clearPaneNavigationTracking(pane);
    _refreshIfMounted();
    if (pane.id == _activePaneId) {
      _showMessage(message);
    }
  }

  Future<void> _importCurrentPage(_SchoolWebPane pane) async {
    final l10n = AppLocalizations.of(context);
    final controller = pane.controller;
    final selectedSite = _selectedSite;
    if (_isParsing ||
        pane.id != _activePaneId ||
        controller == null ||
        selectedSite == null) {
      return;
    }
    final extractionGeneration = pane.loadGeneration;
    final extractionDocumentRevision = pane.documentRevision;
    setState(() => _isParsing = true);
    try {
      final source = await _pageService.extractSource(
        controller,
        fallbackUrl: pane.currentUrl,
        fallbackTitle: pane.currentTitle,
      );
      if (!mounted) {
        return;
      }
      if (pane.id != _activePaneId ||
          _hasBlockingDialog ||
          !shouldUseSchoolWebImportExtraction(
            extractionGeneration: extractionGeneration,
            currentGeneration: pane.loadGeneration,
          ) ||
          extractionDocumentRevision != pane.documentRevision) {
        _showMessage(l10n.schoolWebImportOpenPageHint);
        return;
      }
      if (!mounted || _hasBlockingDialog || _isExitConfirmationOpen) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SchoolHtmlImportPage(
            initialContent: source.content,
            initialUrl: source.url,
            initialTitle: source.title,
            initialContentTruncated: source.wasTruncated,
            showReturnToWebPageButton: true,
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.message == 'Import content is empty.'
          ? l10n.schoolWebImportEmptyPage
          : error.message;
      _showMessage(message);
    } catch (_) {
      if (mounted) {
        _showMessage(l10n.importFailedCheckContent);
      }
    } finally {
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }

  bool _beginNavigationGate(_SchoolWebPane pane) {
    if (!_containsPane(pane) || !_navigationPaneIds.add(pane.id)) {
      return false;
    }
    _refreshIfMounted();
    return true;
  }

  void _endNavigationGate(_SchoolWebPane pane) {
    if (_navigationPaneIds.remove(pane.id)) {
      _refreshIfMounted();
    }
  }

  bool _isNavigating(_SchoolWebPane pane) =>
      _navigationPaneIds.contains(pane.id);

  /// Updates the desktop Back affordance from WebView's real history rather
  /// than inferring history from addresses. Redirects, POST callbacks, and SPA
  /// navigations cannot be represented safely by a Dart-side URL stack.
  Future<void> _refreshPaneCanGoBack(
    _SchoolWebPane pane, {
    InAppWebViewController? controller,
  }) async {
    final targetController = controller ?? pane.controller;
    if (targetController == null || !_containsPane(pane)) {
      return;
    }
    final loadGeneration = pane.loadGeneration;
    final documentRevision = pane.documentRevision;
    bool canGoBack;
    try {
      canGoBack = await targetController.canGoBack();
    } catch (_) {
      // Keep the last native value when a transient query fails. In
      // particular, do not manufacture a history entry or route exit.
      return;
    }
    if (!mounted ||
        !_containsPane(pane) ||
        !identical(pane.controller, targetController) ||
        loadGeneration != pane.loadGeneration ||
        documentRevision != pane.documentRevision ||
        pane.canGoBack == canGoBack) {
      return;
    }
    pane.canGoBack = canGoBack;
    _refreshIfMounted();
  }

  _SchoolWebPane? _paneById(String id) {
    for (final pane in _panes) {
      if (pane.id == id) {
        return pane;
      }
    }
    return null;
  }

  bool _containsPane(_SchoolWebPane pane) => _panes.contains(pane);

  void _refreshIfMounted() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SchoolWebPane {
  _SchoolWebPane({required this.id, this.windowId, this.parentId});

  final String id;
  final int? windowId;
  final String? parentId;
  InAppWebViewController? controller;
  Timer? loadIndicatorWatchdog;
  int loadGeneration = 0;
  int documentRevision = 0;
  bool awaitingLoadStart = false;
  bool hasSuccessfulPageLoad = false;
  bool isLoadingPage = false;
  bool canGoBack = false;
  String? previousDocumentAddress;
  String? latestLoadStartAddress;
  int? failedLoadGeneration;
  String currentUrl = '';
  String currentTitle = '';

  void cancelLoadIndicatorWatchdog() {
    loadIndicatorWatchdog?.cancel();
    loadIndicatorWatchdog = null;
  }

  void dispose() {
    loadGeneration += 1;
    documentRevision += 1;
    cancelLoadIndicatorWatchdog();
    final webViewController = controller;
    if (webViewController != null) {
      unawaited(webViewController.stopLoading().catchError((_) {}));
    }
  }
}

/// Whether an extraction that already ran still describes the page on screen.
@visibleForTesting
bool shouldUseSchoolWebImportExtraction({
  required int extractionGeneration,
  required int currentGeneration,
}) {
  return extractionGeneration == currentGeneration;
}

/// The system Back action for the active browser pane.
@visibleForTesting
enum SchoolWebImportBackAction { webHistory, closePopup, exitBrowser }

@visibleForTesting
SchoolWebImportBackAction schoolWebImportBackAction({
  required bool canGoBack,
  required bool isPopupPane,
}) {
  if (canGoBack) {
    return SchoolWebImportBackAction.webHistory;
  }
  return isPopupPane
      ? SchoolWebImportBackAction.closePopup
      : SchoolWebImportBackAction.exitBrowser;
}

/// Whether a load completion belongs to the current document.
///
/// This intentionally does not depend on a progress poll or a preceding
/// `onLoadStart`. The Windows WebView plugin can report a previous URL from
/// [InAppWebViewController.getUrl] and a pre-redirect load-start URL while
/// delivering the terminal `onLoadStop` URL for the document actually on
/// screen. Once the caller has confirmed the pane/controller/generation, that
/// native HTTP(S) callback is authoritative.
@visibleForTesting
bool shouldAcceptSchoolWebImportLoadCompletion({
  required String callbackUrl,
  required String controllerUrl,
  String expectedUrl = '',
  bool terminalCallbackIsAuthoritative = false,
}) {
  final callback = schoolWebImportCompletionAddress(callbackUrl);
  if (callback == null) {
    return false;
  }
  if (terminalCallbackIsAuthoritative) {
    return true;
  }
  final expected = schoolWebImportCompletionAddress(expectedUrl);
  // The callback does not carry the native navigation generation. A load-stop
  // from the old document can therefore arrive after a newer address has
  // started. Do not let the Windows controller-URL tolerance turn that stale
  // completion into an importable page.
  if (expected != null && callback != expected) {
    return false;
  }
  return callback == schoolWebImportCompletionAddress(controllerUrl);
}

/// Canonical HTTP(S) address used solely to associate native load callbacks.
///
/// Fragments do not represent a new document, and a host root with or without
/// a trailing slash resolves to the same page. Removing both differences keeps
/// normal redirects from looking stale while still distinguishing a different
/// page or query from the latest request.
@visibleForTesting
String? schoolWebImportCompletionAddress(String source) {
  final normalized = schoolWebImportAddress(source);
  if (normalized == null) {
    return null;
  }
  final uri = Uri.parse(normalized);
  final port = uri.hasPort ? uri.port : null;
  final isDefaultPort =
      (uri.scheme == 'http' && port == 80) ||
      (uri.scheme == 'https' && port == 443);
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: isDefaultPort ? null : port,
    path: uri.path.isEmpty ? '/' : uri.path,
    query: uri.hasQuery ? uri.query : null,
  ).toString();
}

/// WebView2 may expose a stale [InAppWebViewController.getUrl] at
/// `onLoadStop`, while the callback URL is the final rendered document.
@visibleForTesting
bool schoolWebImportTreatsTerminalLoadStopAsAuthoritative({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  return !(isWeb ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.windows;
}

/// Every embedded browser session has an explicit close affordance in the
/// leading app-bar slot. System Back still follows web history on platforms
/// that provide it; this action always leaves the browser session.
@visibleForTesting
bool schoolWebImportShowsCloseButton({bool? isWeb}) {
  // The embedded browser is also used by the compatibility Web build. Keeping
  // the action present there makes the session exit predictable across every
  // platform instead of relying on a platform-specific app-bar convention.
  return true;
}

/// The native browser is currently shipped on Windows as the supported desktop
/// target. It needs an explicit in-WebView Back affordance because it has no
/// Android/iOS system Back gesture or button.
@visibleForTesting
bool schoolWebImportShowsDesktopBackButton({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  return !(isWeb ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.windows;
}

/// Returns a safe browser address or null when [source] is not an HTTP(S) URL.
///
/// Bare domains are interpreted as HTTPS. User info is intentionally dropped
/// before it ever reaches the visible address bar or a platform WebView.
@visibleForTesting
String? schoolWebImportAddress(String source) {
  var value = source.trim();
  if (value.isEmpty || value.contains(RegExp(r'\s'))) {
    return null;
  }
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(value);
  if (!hasScheme) {
    value = 'https://$value';
  }
  try {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty) {
      return null;
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  } on FormatException {
    // Uri defers malformed-port validation until [Uri.port] is accessed.
    return null;
  }
}

/// Origin of the page actually on screen, or null when it is not known yet.
@visibleForTesting
String? schoolWebImportOrigin(String source) {
  final value = source.trim();
  if (value.isEmpty || value.contains(RegExp(r'\s'))) {
    return null;
  }
  try {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty) {
      return null;
    }
    final port = uri.hasPort ? uri.port : null;
    final isDefaultPort =
        (uri.scheme == 'http' && port == 80) ||
        (uri.scheme == 'https' && port == 443);
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: port != null && !isDefaultPort ? port : null,
    ).toString();
  } on FormatException {
    return null;
  }
}

@visibleForTesting
bool schoolWebImportSupportsPopupWindows() => InAppWebView.isPropertySupported(
  PlatformWebViewCreationParamsProperty.windowId,
);

@visibleForTesting
InAppWebViewSettings schoolWebImportWebViewSettings({
  required bool supportsPopups,
}) {
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: supportsPopups,
    supportMultipleWindows: supportsPopups,
    // Campus single sign-on often nests the identity provider in an iframe.
    thirdPartyCookiesEnabled: true,
    // Let the platform WebView own redirects, form POSTs, cookies, and every
    // normal HTTP(S) navigation. Cancelling then replaying these requests loses
    // Android POST bodies and breaks CAS / OAuth / SAML login chains.
    useShouldOverrideUrlLoading: false,
  );
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
