import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_empty_state.dart';

class SchoolWebImportPage extends StatefulWidget {
  const SchoolWebImportPage({super.key, required this.site});

  final SchoolSite site;

  @override
  State<SchoolWebImportPage> createState() => _SchoolWebImportPageState();
}

class _SchoolWebImportPageState extends State<SchoolWebImportPage> {
  static const _pageLoadTimeout = Duration(seconds: 15);

  final SchoolSiteService _siteService = SchoolSiteService();
  final SchoolWebImportPageService _pageService =
      const SchoolWebImportPageService();

  InAppWebViewController? _controller;
  Timer? _pageLoadWatchdog;
  int _pageLoadGeneration = 0;
  bool _pageLoadTimedOut = false;
  bool _awaitingPageLoadStart = false;
  bool _hasSuccessfulPageLoad = false;
  bool _isLoadingPage = false;
  bool _isParsing = false;
  bool _isLoadingSchools = true;
  bool _canGoBack = false;
  bool _hasRequestedSchoolsLoad = false;
  bool _hasStartedInitialLoad = false;
  bool _hasApprovedInitialNavigation = false;
  String _currentUrl = '';
  String _currentTitle = '';
  String _entryUrl = '';
  List<SchoolSite> _sites = const [];
  SchoolSite? _selectedSite;
  String? _schoolLoadError;
  final Set<String> _approvedNavigationOrigins = <String>{};
  late final SchoolWebImportNavigationDecisionQueue _navigationDecisionQueue;
  NavigatorState? _activeSecurityDialogNavigator;
  ModalRoute<dynamic>? _activeSecurityDialogRoute;
  Object? _activeSecurityDialogToken;

  bool get _supportsWebView => supportsInAppWebView;

  @override
  void initState() {
    super.initState();
    _navigationDecisionQueue = SchoolWebImportNavigationDecisionQueue(
      decide: _confirmNavigationOrigin,
    );
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
    _pageLoadGeneration += 1;
    _cancelPageLoadWatchdog();
    _navigationDecisionQueue.dispose();
    final dialogNavigator = _activeSecurityDialogNavigator;
    if (dialogNavigator != null &&
        dialogNavigator.mounted &&
        _activeSecurityDialogRoute?.isCurrent == true) {
      dialogNavigator.pop(false);
    }
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
            onPressed: _canGoBack && !_isLoadingPage && !_isParsing
                ? _goBackInWebView
                : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.schoolWebImportGoBack,
          ),
          IconButton(
            onPressed: _controller == null || _isLoadingPage || _isParsing
                ? null
                : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: MaterialLocalizations.of(
              context,
            ).refreshIndicatorSemanticLabel,
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
          : _sites.isEmpty || _selectedSite == null
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
                          initialUserScripts: UnmodifiableListView<UserScript>([
                            UserScript(
                              source: SchoolWebImportPageService
                                  .formNavigationGuardScript,
                              injectionTime:
                                  UserScriptInjectionTime.AT_DOCUMENT_START,
                              contentWorld: ContentWorld.PAGE,
                            ),
                          ]),
                          initialSettings: InAppWebViewSettings(
                            javaScriptEnabled: true,
                            javaScriptCanOpenWindowsAutomatically: false,
                            useShouldOverrideUrlLoading: true,
                          ),
                          onWebViewCreated: (controller) {
                            _controller = controller;
                            controller.addJavaScriptHandler(
                              handlerName: SchoolWebImportPageService
                                  .navigationApprovalHandlerName,
                              callback: (arguments) async {
                                if (!mounted ||
                                    arguments.isEmpty ||
                                    arguments.first is! String) {
                                  return false;
                                }
                                final origin = schoolWebImportOrigin(
                                  arguments.first as String,
                                );
                                if (origin == null) return false;
                                return _requestNavigationOriginApproval(origin);
                              },
                            );
                            _scheduleInitialSchoolOpen();
                          },
                          onLoadStart: (_, url) {
                            _startPageLoadWatchdog();
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _awaitingPageLoadStart = false;
                              _hasSuccessfulPageLoad = false;
                              _isLoadingPage = true;
                              _pageLoadTimedOut = false;
                              _currentTitle = '';
                              _currentUrl = url?.toString() ?? _currentUrl;
                            });
                          },
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
                          shouldOverrideUrlLoading: (_, navigationAction) {
                            return _handleNavigation(navigationAction);
                          },
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
                                AppLocalizations.of(
                                  context,
                                ).schoolWebImportLoadFailed,
                              ),
                            );
                          },
                          onReceivedHttpError: (controller, request, _) {
                            if (request.isForMainFrame == false) {
                              return;
                            }
                            unawaited(
                              _handlePageLoadFailure(
                                controller,
                                request.url,
                                AppLocalizations.of(
                                  context,
                                ).schoolWebImportLoadFailed,
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
    final initialOrigin = schoolWebImportOrigin(site.loginUrl);
    if (initialOrigin == null) {
      _hasStartedInitialLoad = false;
      return;
    }
    if (!_hasApprovedInitialNavigation) {
      final approved = await _confirmInitialNavigation(initialOrigin);
      if (!mounted || !approved) {
        _hasStartedInitialLoad = false;
        if (mounted) {
          setState(() {
            _hasSuccessfulPageLoad = false;
            _isLoadingPage = false;
          });
        }
        return;
      }
      _hasApprovedInitialNavigation = true;
      _approvedNavigationOrigins.add(initialOrigin);
    }
    final loadFailedMessage = AppLocalizations.of(
      context,
    ).schoolWebImportLoadFailed;
    _startPageLoadWatchdog();
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
    if (controller == null || _isLoadingPage) {
      return;
    }
    if (!_hasApprovedInitialNavigation) {
      _hasStartedInitialLoad = true;
      await _openSelectedSchool();
      return;
    }
    final loadFailedMessage = AppLocalizations.of(
      context,
    ).schoolWebImportLoadFailed;
    _startPageLoadWatchdog();
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
    if (controller == null || !_canGoBack || _isLoadingPage) {
      return;
    }
    final loadFailedMessage = AppLocalizations.of(
      context,
    ).schoolWebImportLoadFailed;
    _startPageLoadWatchdog();
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

  Future<NavigationActionPolicy> _handleNavigation(
    NavigationAction navigationAction,
  ) async {
    if (!navigationAction.isForMainFrame) {
      return NavigationActionPolicy.ALLOW;
    }
    final targetUrl = navigationAction.request.url?.toString() ?? '';
    final targetOrigin = schoolWebImportOrigin(targetUrl);
    if (targetOrigin == null) {
      return NavigationActionPolicy.CANCEL;
    }
    return await _requestNavigationOriginApproval(targetOrigin)
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  Future<bool> _requestNavigationOriginApproval(String targetOrigin) async {
    if (_approvedNavigationOrigins.contains(targetOrigin)) return true;
    final approved = await _navigationDecisionQueue.request(targetOrigin);
    if (!mounted || !approved) return false;
    _approvedNavigationOrigins.add(targetOrigin);
    return true;
  }

  Future<bool> _confirmInitialNavigation(String origin) async {
    if (!requiresSchoolWebImportSignInDisclosure()) return true;
    if (!mounted) return false;
    final dialogToken = Object();
    _activeSecurityDialogNavigator = Navigator.of(context, rootNavigator: true);
    _activeSecurityDialogToken = dialogToken;
    try {
      return await showSchoolWebImportSecurityConsentDialog(
        context: context,
        origin: origin,
        isInitialNavigation: true,
        onShown: (route) {
          if (identical(_activeSecurityDialogToken, dialogToken)) {
            _activeSecurityDialogRoute = route;
          }
        },
      );
    } finally {
      if (identical(_activeSecurityDialogToken, dialogToken)) {
        _activeSecurityDialogNavigator = null;
        _activeSecurityDialogRoute = null;
        _activeSecurityDialogToken = null;
      }
    }
  }

  Future<bool> _confirmNavigationOrigin(String targetOrigin) async {
    if (!mounted) return false;
    final dialogToken = Object();
    _activeSecurityDialogNavigator = Navigator.of(context, rootNavigator: true);
    _activeSecurityDialogToken = dialogToken;
    try {
      return await showSchoolWebImportSecurityConsentDialog(
        context: context,
        origin: targetOrigin,
        isInitialNavigation: false,
        onShown: (route) {
          if (identical(_activeSecurityDialogToken, dialogToken)) {
            _activeSecurityDialogRoute = route;
          }
        },
      );
    } finally {
      if (identical(_activeSecurityDialogToken, dialogToken)) {
        _activeSecurityDialogNavigator = null;
        _activeSecurityDialogRoute = null;
        _activeSecurityDialogToken = null;
      }
    }
  }

  void _startPageLoadWatchdog() {
    _cancelPageLoadWatchdog();
    final generation = ++_pageLoadGeneration;
    _pageLoadTimedOut = false;
    _pageLoadWatchdog = Timer(
      _pageLoadTimeout,
      () => unawaited(_handlePageLoadTimeout(generation)),
    );
  }

  Future<void> _handlePageLoadTimeout(int generation) async {
    if (!mounted || !_isLoadingPage || generation != _pageLoadGeneration) {
      return;
    }
    _pageLoadTimedOut = true;
    setState(() {
      _awaitingPageLoadStart = false;
      _hasSuccessfulPageLoad = false;
      _isLoadingPage = false;
    });
    try {
      await _controller?.stopLoading();
    } catch (_) {}
    if (!mounted || generation != _pageLoadGeneration) {
      return;
    }
    _showMessage(AppLocalizations.of(context).schoolWebImportLoadTimedOut);
  }

  void _cancelPageLoadWatchdog() {
    _pageLoadWatchdog?.cancel();
    _pageLoadWatchdog = null;
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
          timedOut: _pageLoadTimedOut,
          awaitingLoadStart: _awaitingPageLoadStart,
          callbackUrl: callbackUrl,
          controllerUrl: controllerUrl?.toString() ?? '',
          progress: progress,
        )) {
      return;
    }
    _cancelPageLoadWatchdog();
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
    _cancelPageLoadWatchdog();
    if (_pageLoadTimedOut) return;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importFailedCheckContent)));
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
  required bool timedOut,
  required bool awaitingLoadStart,
  required String callbackUrl,
  required String controllerUrl,
  required int? progress,
}) {
  return isLoading &&
      !timedOut &&
      !awaitingLoadStart &&
      callbackUrl.isNotEmpty &&
      callbackUrl == controllerUrl &&
      (progress == null || progress >= 100);
}

@visibleForTesting
bool requiresSchoolWebImportSignInDisclosure({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  return !(isWeb ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.android;
}

@visibleForTesting
String schoolWebImportSignInConsentMessage(
  AppLocalizations l10n,
  String origin,
) {
  return Uri.tryParse(origin)?.scheme == 'http'
      ? l10n.schoolWebImportInsecureSignInConsentMessage(origin)
      : l10n.schoolWebImportSignInConsentMessage(origin);
}

@visibleForTesting
String schoolWebImportNavigationConsentMessage(
  AppLocalizations l10n,
  String origin,
) {
  return Uri.tryParse(origin)?.scheme == 'http'
      ? l10n.schoolWebImportInsecureSignInConsentMessage(origin)
      : l10n.schoolWebImportCrossOriginMessage(origin);
}

typedef SchoolWebImportSecurityDialogShown =
    void Function(ModalRoute<dynamic>? route);

@visibleForTesting
Future<bool> showSchoolWebImportSecurityConsentDialog({
  required BuildContext context,
  required String origin,
  required bool isInitialNavigation,
  SchoolWebImportSecurityDialogShown? onShown,
}) async {
  var popped = false;
  ModalRoute<dynamic>? dialogRoute;
  final confirmed = await showExpressiveDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      dialogRoute ??= ModalRoute.of(dialogContext);
      onShown?.call(dialogRoute);
      final l10n = AppLocalizations.of(dialogContext);
      final isInsecure = Uri.tryParse(origin)?.scheme == 'http';
      void close(bool value) {
        if (popped || dialogRoute?.isCurrent != true) return;
        popped = true;
        Navigator.of(dialogContext).pop(value);
      }

      return PopScope(
        canPop: false,
        child: AlertDialog(
          icon: Icon(
            isInsecure ? Icons.warning_amber_rounded : Icons.login_outlined,
          ),
          title: Text(
            isInsecure
                ? l10n.schoolWebImportInsecureSignInConsentTitle
                : isInitialNavigation
                ? l10n.schoolWebImportSignInConsentTitle
                : l10n.schoolWebImportCrossOriginTitle,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              isInitialNavigation
                  ? schoolWebImportSignInConsentMessage(l10n, origin)
                  : schoolWebImportNavigationConsentMessage(l10n, origin),
            ),
          ),
          actions: [
            TextButton(onPressed: () => close(false), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () => close(true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    },
  );
  return confirmed == true;
}

typedef SchoolWebImportNavigationDecision =
    Future<bool> Function(String origin);

@visibleForTesting
class SchoolWebImportNavigationDecisionQueue {
  SchoolWebImportNavigationDecisionQueue({
    required SchoolWebImportNavigationDecision decide,
    this.maxPendingOrigins = 8,
  }) : assert(maxPendingOrigins > 0),
       _decide = decide;

  final SchoolWebImportNavigationDecision _decide;
  final int maxPendingOrigins;
  final Queue<_SchoolWebImportNavigationDecisionEntry> _queue = Queue();
  final Map<String, _SchoolWebImportNavigationDecisionEntry> _pending = {};
  bool _isDraining = false;
  bool _isDisposed = false;

  Future<bool> request(String origin) {
    if (_isDisposed) return Future.value(false);
    final existing = _pending[origin];
    if (existing != null) return existing.result.future;
    if (_pending.length >= maxPendingOrigins) return Future.value(false);

    final entry = _SchoolWebImportNavigationDecisionEntry(origin);
    _pending[origin] = entry;
    _queue.addLast(entry);
    unawaited(_drain());
    return entry.result.future;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final entry in _pending.values) {
      if (!entry.result.isCompleted) entry.result.complete(false);
    }
    _pending.clear();
    _queue.clear();
  }

  Future<void> _drain() async {
    if (_isDraining || _isDisposed) return;
    _isDraining = true;
    try {
      while (!_isDisposed && _queue.isNotEmpty) {
        final entry = _queue.removeFirst();
        var approved = false;
        try {
          approved = await _decide(entry.origin);
        } catch (_) {
          approved = false;
        }
        if (_isDisposed) return;
        if (identical(_pending[entry.origin], entry)) {
          _pending.remove(entry.origin);
        }
        if (!entry.result.isCompleted) entry.result.complete(approved);
      }
    } finally {
      _isDraining = false;
    }
  }
}

class _SchoolWebImportNavigationDecisionEntry {
  _SchoolWebImportNavigationDecisionEntry(this.origin);

  final String origin;
  final Completer<bool> result = Completer<bool>();
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

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
