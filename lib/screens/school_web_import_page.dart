import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/school_site_models.dart';
import '../providers/timetable_provider.dart';
import '../screens/school_html_import_page.dart';
import '../services/school_import_api.dart';
import '../services/school_site_service.dart';
import '../services/school_web_import_page_service.dart';
import '../utils/platform_capabilities.dart';
import '../widgets/expressive_empty_state.dart';

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

  bool get _supportsPopupWindows => InAppWebView.isPropertySupported(
    PlatformWebViewCreationParamsProperty.windowId,
  );

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
    final baseUrl = provider?.customSchoolImportBaseUrl.trim() ?? '';
    final isConfigured =
        provider != null &&
        isValidCustomOpenAiBaseUrl(baseUrl) &&
        provider.customSchoolImportApiKey.trim().isNotEmpty &&
        provider.customSchoolImportModel.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedSite?.name ?? widget.site.name),
        actions: [
          IconButton(
            onPressed: _canGoBack && !_isParsing
                ? _goBackInWebView
                : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.schoolWebImportGoBack,
          ),
          IconButton(
            onPressed: _controller == null || _isParsing
                ? null
                : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: MaterialLocalizations.of(context)
                .refreshIndicatorSemanticLabel,
          ),
          IconButton(
            onPressed:
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
          ? _buildMessage(_buildConfigMessage(provider, l10n))
          : !_supportsWebView
          ? _buildMessage(l10n.schoolWebImportUnsupportedPlatform)
          : _schoolLoadError != null
          ? _buildMessage(_schoolLoadError!)
          : !widget.isPopupWindow && (_sites.isEmpty || _selectedSite == null)
          ? _buildMessage(l10n.schoolWebImportNoSchools)
          : Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingSchools
                              ? l10n.schoolWebImportLoadingPage
                              : _isParsing
                              ? l10n.schoolWebImportParsing
                              : _isLoadingPage
                              ? l10n.schoolWebImportLoadingPage
                              : l10n.schoolWebImportOpenPageHint,
                        ),
                        const SizedBox(height: 8),
                        _buildOriginStatus(l10n),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoadingSchools
                      ? const Center(child: CircularProgressIndicator())
                      : InAppWebView(
                          windowId: widget.windowId,
                          initialSettings: schoolWebImportWebViewSettings(),
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
                            final entryUrl =
                                _entryUrl.isEmpty && nextUrl.isNotEmpty
                                ? nextUrl
                                : _entryUrl;
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _currentUrl = nextUrl;
                              _entryUrl = entryUrl;
                              _canGoBack =
                                  entryUrl.isNotEmpty && nextUrl != entryUrl;
                            });
                          },
                          onCreateWindow: _supportsPopupWindows
                              ? _handleCreateWindow
                              : null,
                          onCloseWindow: (_) => _handlePopupWindowClosed(),
                          onTitleChanged: (_, title) {
                            if (!mounted ||
                                title == null ||
                                title == _currentTitle) {
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
                                AppLocalizations.of(context)
                                    .schoolWebImportLoadFailed,
                              ),
                            );
                          },
                        ),
                ),
              ],
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

  Widget _buildOriginStatus(AppLocalizations l10n) {
    final fallbackUrl = _selectedSite?.loginUrl ?? widget.site.loginUrl;
    final origin = schoolWebImportOrigin(
      _currentUrl.isEmpty ? fallbackUrl : _currentUrl,
    );
    final isSecure = origin?.startsWith('https://') ?? false;
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isSecure ? Icons.lock_outline : Icons.lock_open_outlined,
          size: 18,
          color: isSecure ? colors.primary : colors.error,
        ),
        const SizedBox(width: 8),
        Text(
          isSecure ? 'HTTPS' : 'HTTP',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSecure ? colors.primary : colors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            origin ?? l10n.schoolWebImportUnknownOrigin,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  String _buildConfigMessage(
    TimetableProvider? provider,
    AppLocalizations l10n,
  ) {
    final baseUrl = provider?.customSchoolImportBaseUrl.trim() ?? '';
    if (baseUrl.isNotEmpty && !isValidCustomOpenAiBaseUrl(baseUrl)) {
      return l10n.schoolImportParserBaseUrlInvalid;
    }
    return l10n.schoolImportParserCustomConfigIncomplete;
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

    final windowId = action.windowId;
    if (_supportsPopupWindows) {
      if (_openPopupWindowIds.add(windowId)) {
        unawaited(
          Navigator.of(context)
              .push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SchoolWebImportPage(
                    site: widget.site,
                    windowId: windowId,
                  ),
                ),
              )
              .whenComplete(() {
                _openPopupWindowIds.remove(windowId);
              }),
        );
        return true;
      }
      return false;
    }
    // A support change during a route transition is handled by the platform's
    // native callback without a Dart-side URL replay.
    return false;
  }

  void _handlePopupWindowClosed() {
    if (!widget.isPopupWindow || !mounted || _isClosingPopupWindow) {
      return;
    }
    _isClosingPopupWindow = true;
    final route = ModalRoute.of(context);
    if (route == null) {
      return;
    }
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
InAppWebViewSettings schoolWebImportWebViewSettings() {
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    supportMultipleWindows: true,
    thirdPartyCookiesEnabled: true,
    // Let the platform WebView own the whole navigation session, including
    // redirects and form POSTs used by campus authentication systems.
    useShouldOverrideUrlLoading: false,
  );
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
