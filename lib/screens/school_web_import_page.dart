import 'dart:async';

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

class SchoolWebImportPage extends StatefulWidget {
  const SchoolWebImportPage({super.key, required this.site, this.windowId});

  final SchoolSite site;
  final int? windowId;

  bool get isPopupWindow => windowId != null;

  @override
  State<SchoolWebImportPage> createState() => _SchoolWebImportPageState();
}

class _SchoolWebImportPageState extends State<SchoolWebImportPage> {
  final SchoolSiteService _siteService = SchoolSiteService();
  final SchoolWebImportPageService _pageService =
      const SchoolWebImportPageService();

  InAppWebViewController? _controller;
  int _pageLoadGeneration = 0;
  bool _awaitingPageLoadStart = false;
  bool _hasSuccessfulPageLoad = false;
  bool _isLoadingPage = false;
  bool _isParsing = false;
  bool _isLoadingSchools = true;
  bool _canGoBack = false;
  bool _hasRequestedSchoolsLoad = false;
  bool _hasStartedInitialLoad = false;
  bool _isClosingPopupWindow = false;
  String _currentUrl = '';
  String _currentTitle = '';
  String _entryUrl = '';
  List<SchoolSite> _sites = const [];
  SchoolSite? _selectedSite;
  String? _schoolLoadError;
  final Set<int> _openPopupWindowIds = <int>{};

  bool get _supportsWebView => supportsInAppWebView;

  bool get _supportsPopupWindows => schoolWebImportSupportsPopupWindows();

  @override
  void initState() {
    super.initState();
    if (widget.isPopupWindow) {
      _selectedSite = widget.site;
      _isLoadingSchools = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isPopupWindow) {
      return;
    }
    if (!_hasRequestedSchoolsLoad) {
      _hasRequestedSchoolsLoad = true;
      unawaited(_loadSchools());
    }
  }

  @override
  void dispose() {
    _pageLoadGeneration += 1;
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.stopLoading().catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<TimetableProvider?>();
    final isConfigured = isSchoolImportParserConfigured(provider);
    // The in-app browser owns the system back gesture: a stray back swipe in the
    // middle of a sign-in flow would otherwise drop the whole session.
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_confirmExit());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // Replaced by the explicit confirm-to-leave flow above.
          automaticallyImplyLeading: false,
          title: _buildOriginTitle(l10n),
          // Tracks the WebView's own page loads. Deliberately not tied to the
          // school-list load, which has its own spinner in the body and would
          // otherwise show a loading bar over the configuration prompt.
          bottom: _isLoadingPage
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    semanticsLabel: l10n.schoolWebImportLoadingPage,
                  ),
                )
              : null,
          actions: [
            IconButton(
              onPressed: _canGoBack && !_isParsing ? _goBackInWebView : null,
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.schoolWebImportGoBack,
            ),
            IconButton(
              onPressed: _controller == null || _isParsing ? null : _reload,
              icon: const Icon(Icons.refresh),
              tooltip: MaterialLocalizations.of(context)
                  .refreshIndicatorSemanticLabel,
            ),
            IconButton(
              onPressed:
                  !isConfigured ||
                      _controller == null ||
                      !_hasSuccessfulPageLoad ||
                      _isLoadingPage ||
                      _isParsing
                  ? null
                  : _importCurrentPage,
              icon: _isParsing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              tooltip: l10n.schoolWebImportImportCurrentPage,
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
            : !widget.isPopupWindow && (_sites.isEmpty || _selectedSite == null)
            ? _buildMessage(l10n.schoolWebImportNoSchools)
            : _isLoadingSchools
            ? const Center(child: CircularProgressIndicator())
            : InAppWebView(
                windowId: widget.windowId,
                initialSettings: schoolWebImportWebViewSettings(
                  supportsPopups: _supportsPopupWindows,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                  if (!widget.isPopupWindow) {
                    _scheduleInitialSchoolOpen();
                  }
                },
                onLoadStart: _handlePageLoadStart,
                onLoadStop: (controller, url) {
                  unawaited(_handlePageLoadStop(controller, url));
                },
                onUpdateVisitedHistory: (_, url, _) {
                  final nextUrl = url?.toString() ?? _currentUrl;
                  final entryUrl = _entryUrl.isEmpty && nextUrl.isNotEmpty
                      ? nextUrl
                      : _entryUrl;
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _currentUrl = nextUrl;
                    _entryUrl = entryUrl;
                    _canGoBack = entryUrl.isNotEmpty && nextUrl != entryUrl;
                  });
                },
                onCreateWindow: _supportsPopupWindows
                    ? _handleCreateWindow
                    : null,
                onCloseWindow: (_) => _handlePopupWindowClosed(),
                onTitleChanged: (_, title) {
                  if (!mounted || title == null || title == _currentTitle) {
                    return;
                  }
                  setState(() => _currentTitle = title);
                },
                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame == false) {
                    return;
                  }
                  unawaited(
                    _handlePageLoadFailure(
                      controller,
                      request.url,
                      AppLocalizations.of(context).schoolWebImportLoadFailed,
                    ),
                  );
                },
              ),
      ),
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

  /// Origin of the page actually on screen, or null when it is not known yet.
  ///
  /// A popup window opens with no URL of its own, so falling back to the parent
  /// site here would label the new page with the wrong domain next to a lock
  /// icon — worse than admitting the origin is unknown.
  String? _resolveCurrentOrigin() {
    if (_currentUrl.isNotEmpty) {
      return schoolWebImportOrigin(_currentUrl);
    }
    if (widget.isPopupWindow) {
      return null;
    }
    return schoolWebImportOrigin(
      _selectedSite?.loginUrl ?? widget.site.loginUrl,
    );
  }

  Widget _buildOriginTitle(AppLocalizations l10n) {
    final origin = _resolveCurrentOrigin();
    final isSecure = origin?.startsWith('https://') ?? false;
    final colors = Theme.of(context).colorScheme;
    // A closed lock already states "https", so drop the scheme there to leave
    // room for the host. Insecure origins keep the visible http:// prefix.
    final display = origin == null
        ? l10n.schoolWebImportUnknownOrigin
        : isSecure
        ? origin.substring('https://'.length)
        : origin;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSecure ? Icons.lock_outline : Icons.lock_open_outlined,
          size: 18,
          color: isSecure ? colors.primary : colors.error,
        ),
        const SizedBox(width: 8),
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
    );
  }

  Future<void> _confirmExit() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final shouldExit = await showExpressiveDialog<bool>(
      context: context,
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
              onPressed: () => popWith(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(l10n.schoolWebImportExitConfirm),
            ),
          ],
        );
      },
    );
    if (shouldExit == true && mounted) {
      navigator.pop();
    }
  }

  void _handlePageLoadStart(InAppWebViewController _, WebUri? url) {
    final nextUrl = url?.toString() ?? '';
    _pageLoadGeneration += 1;
    if (!mounted) {
      return;
    }
    setState(() {
      _awaitingPageLoadStart = false;
      _hasSuccessfulPageLoad = false;
      _isLoadingPage = true;
      _currentTitle = '';
      _currentUrl = nextUrl.isEmpty ? _currentUrl : nextUrl;
    });
  }

  Future<bool?> _handleCreateWindow(
    InAppWebViewController _,
    CreateWindowAction action,
  ) async {
    if (!mounted) {
      return false;
    }
    // Only wired up when the platform reports windowId support, so there is no
    // unsupported case to handle here.
    final windowId = action.windowId;
    if (!_openPopupWindowIds.add(windowId)) {
      return false;
    }
    unawaited(
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  SchoolWebImportPage(site: widget.site, windowId: windowId),
            ),
          )
          .whenComplete(() {
            _openPopupWindowIds.remove(windowId);
          }),
    );
    return true;
  }

  void _handlePopupWindowClosed() {
    if (!widget.isPopupWindow || !mounted || _isClosingPopupWindow) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route == null) {
      return;
    }
    // Latch only once the pop is actually going through, so a missing route
    // does not permanently swallow later close requests.
    _isClosingPopupWindow = true;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
      return;
    }
    navigator.removeRoute(route);
  }

  Future<void> _loadSchools() async {
    final l10n = AppLocalizations.of(context);
    try {
      final sites = await _siteService.loadSites();
      if (!mounted) {
        return;
      }
      final selected = sites
          .where((item) => item.loginUrl == widget.site.loginUrl)
          .firstOrNull;
      final selectedSite = selected ?? widget.site;
      setState(() {
        _sites = sites;
        _selectedSite = selectedSite;
        _isLoadingSchools = false;
      });
      await _ensureController();
      _scheduleInitialSchoolOpen();
    } catch (e, st) {
      debugPrint('Failed to load schools for web import: $e\n$st');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingSchools = false;
        _schoolLoadError = l10n.schoolWebImportSchoolLoadFailed;
      });
    }
  }

  Future<void> _ensureController() async {
    if (_controller != null || !_supportsWebView) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingPage = true;
      });
    }
  }

  void _scheduleInitialSchoolOpen() {
    if (_hasStartedInitialLoad) {
      return;
    }
    if (_controller == null || _selectedSite == null) {
      return;
    }
    _hasStartedInitialLoad = true;
    unawaited(_openSelectedSchool());
  }

  Future<void> _openSelectedSchool() async {
    final site = _selectedSite;
    final controller = _controller;
    if (site == null || controller == null) {
      _hasStartedInitialLoad = false;
      return;
    }
    final loadFailedMessage = AppLocalizations.of(context)
        .schoolWebImportLoadFailed;
    _pageLoadGeneration += 1;
    if (mounted) {
      setState(() {
        _awaitingPageLoadStart = true;
        _hasSuccessfulPageLoad = false;
        _isLoadingPage = true;
        _currentUrl = site.loginUrl;
        _entryUrl = '';
        _canGoBack = false;
      });
    }
    try {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(site.loginUrl)),
      );
    } catch (_) {
      _hasStartedInitialLoad = false;
      await _handlePageLoadFailure(controller, null, loadFailedMessage);
    }
  }

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final loadFailedMessage = AppLocalizations.of(context)
        .schoolWebImportLoadFailed;
    _pageLoadGeneration += 1;
    if (mounted) {
      setState(() {
        _awaitingPageLoadStart = true;
        _hasSuccessfulPageLoad = false;
        _isLoadingPage = true;
      });
    }
    try {
      await controller.reload();
    } catch (_) {
      await _handlePageLoadFailure(controller, null, loadFailedMessage);
    }
  }

  Future<void> _goBackInWebView() async {
    final controller = _controller;
    if (controller == null || !_canGoBack) {
      return;
    }
    final loadFailedMessage = AppLocalizations.of(context)
        .schoolWebImportLoadFailed;
    _pageLoadGeneration += 1;
    if (mounted) {
      setState(() {
        _awaitingPageLoadStart = true;
        _hasSuccessfulPageLoad = false;
        _isLoadingPage = true;
      });
    }
    try {
      await controller.goBack();
    } catch (_) {
      await _handlePageLoadFailure(controller, null, loadFailedMessage);
    }
  }

  Future<void> _handlePageLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    final generation = _pageLoadGeneration;
    final callbackUrl = url?.toString() ?? '';
    WebUri? controllerUrl;
    int? progress;
    try {
      controllerUrl = await controller.getUrl();
      progress = await controller.getProgress();
    } catch (_) {
      return;
    }
    if (!mounted ||
        generation != _pageLoadGeneration ||
        !shouldAcceptSchoolWebImportLoadCompletion(
          isLoading: _isLoadingPage,
          awaitingLoadStart: _awaitingPageLoadStart,
          callbackUrl: callbackUrl,
          controllerUrl: controllerUrl?.toString() ?? '',
          progress: progress,
        )) {
      return;
    }
    final nextUrl = callbackUrl.isEmpty ? _currentUrl : callbackUrl;
    final entryUrl = _entryUrl.isEmpty && nextUrl.isNotEmpty
        ? nextUrl
        : _entryUrl;
    setState(() {
      _hasSuccessfulPageLoad = true;
      _isLoadingPage = false;
      _currentUrl = nextUrl;
      _entryUrl = entryUrl;
      _canGoBack = entryUrl.isNotEmpty && nextUrl != entryUrl;
    });
  }

  Future<void> _handlePageLoadFailure(
    InAppWebViewController controller,
    WebUri? failedUrl,
    String message,
  ) async {
    final generation = _pageLoadGeneration;
    var controllerUrl = '';
    try {
      controllerUrl = (await controller.getUrl())?.toString() ?? '';
    } catch (_) {}
    if (!mounted || generation != _pageLoadGeneration) {
      return;
    }
    final failedUrlText = failedUrl?.toString() ?? '';
    if (failedUrlText.isNotEmpty &&
        controllerUrl.isNotEmpty &&
        failedUrlText != controllerUrl) {
      return;
    }
    if (_awaitingPageLoadStart || _hasSuccessfulPageLoad || _isLoadingPage) {
      setState(() {
        _awaitingPageLoadStart = false;
        _hasSuccessfulPageLoad = false;
        _isLoadingPage = false;
      });
    }
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _importCurrentPage() async {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    final selectedSite = _selectedSite;
    if (_isParsing ||
        !_hasSuccessfulPageLoad ||
        _isLoadingPage ||
        controller == null ||
        selectedSite == null) {
      return;
    }
    final extractionGeneration = _pageLoadGeneration;
    setState(() => _isParsing = true);
    try {
      final source = await _pageService.extractSource(
        controller,
        fallbackUrl: _currentUrl,
        fallbackTitle: _currentTitle,
      );
      if (!mounted) {
        return;
      }
      if (!shouldUseSchoolWebImportExtraction(
        extractionGeneration: extractionGeneration,
        currentGeneration: _pageLoadGeneration,
        hasSuccessfulPageLoad: _hasSuccessfulPageLoad,
        isLoadingPage: _isLoadingPage,
      )) {
        _showMessage(l10n.schoolWebImportOpenPageHint);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importFailedCheckContent)));
    } finally {
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }
}

@visibleForTesting
bool shouldUseSchoolWebImportExtraction({
  required int extractionGeneration,
  required int currentGeneration,
  required bool hasSuccessfulPageLoad,
  required bool isLoadingPage,
}) {
  return extractionGeneration == currentGeneration &&
      hasSuccessfulPageLoad &&
      !isLoadingPage;
}

@visibleForTesting
bool shouldAcceptSchoolWebImportLoadCompletion({
  required bool isLoading,
  required bool awaitingLoadStart,
  required String callbackUrl,
  required String controllerUrl,
  required int? progress,
}) {
  return isLoading &&
      !awaitingLoadStart &&
      callbackUrl.isNotEmpty &&
      callbackUrl == controllerUrl &&
      (progress == null || progress >= 100);
}

@visibleForTesting
String? schoolWebImportOrigin(String source) {
  final uri = Uri.tryParse(source.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.trim().isEmpty) {
    return null;
  }
  final isDefaultPort =
      (uri.scheme == 'http' && uri.port == 80) ||
      (uri.scheme == 'https' && uri.port == 443);
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort && !isDefaultPort ? uri.port : null,
  ).toString();
}

@visibleForTesting
bool schoolWebImportSupportsPopupWindows() => InAppWebView.isPropertySupported(
  PlatformWebViewCreationParamsProperty.windowId,
);

@visibleForTesting
InAppWebViewSettings schoolWebImportWebViewSettings({
  required bool supportsPopups,
}) {
  // Routing target=_blank through onCreateWindow only works when a handler is
  // attached. Both derive from the same flag so a platform without windowId
  // support keeps opening links in place instead of dropping the tap.
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: supportsPopups,
    supportMultipleWindows: supportsPopups,
    // Campus single sign-on commonly nests the identity provider in an iframe,
    // which needs third-party cookies to keep its session. Turning this off
    // breaks those logins.
    thirdPartyCookiesEnabled: true,
    // Let the platform WebView own the whole navigation session, including
    // redirects and form POSTs used by campus authentication systems.
    useShouldOverrideUrlLoading: false,
  );
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
