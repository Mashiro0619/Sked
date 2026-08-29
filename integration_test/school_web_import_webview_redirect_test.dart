import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sked/screens/school_web_import_page.dart'
    show schoolWebImportSupportsPopupWindows, schoolWebImportWebViewSettings;

const _webViewTimeout = Duration(seconds: 20);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android WebView preserves form POSTs, redirects, and session cookies',
    (tester) async {
      final fixture = await _SchoolWebRedirectFixture.start();
      addTearDown(fixture.close);
      await CookieManager.instance().deleteAllCookies();
      addTearDown(CookieManager.instance().deleteAllCookies);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final controllerReady = Completer<InAppWebViewController>();
      await tester.pumpWidget(
        MaterialApp(
          home: _SingleRouteHarness(
            child: _SchoolWebViewHarness(
              onParentCreated: controllerReady.complete,
            ),
          ),
        ),
      );

      final controller = await _waitFor(
        controllerReady.future,
        'the initial WebView to be created',
      );
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(fixture.schoolStartUrl)),
      );

      final observation = await _waitFor(
        fixture.redirectComplete.future,
        'the school callback POST after the identity redirect',
      );

      expect(fixture.identityRequestMethod, 'POST');
      expect(fixture.identityRequestBody, 'grant=source-grant');
      expect(fixture.identityRequestCount, 1);
      expect(
        fixture.identityContinueCookie,
        contains('identity_session=issued'),
      );
      expect(observation.callbackMethod, 'POST');
      expect(observation.callbackBody, 'ticket=issued-ticket');
      expect(fixture.callbackRequestCount, 1);
      expect(observation.callbackCookie, contains('school_session=accepted'));
    },
    skip: !io.Platform.isAndroid,
    timeout: const Timeout(Duration(seconds: 45)),
  );

  testWidgets(
    'Android WebView attaches a window.open child through windowId',
    (tester) async {
      if (!InAppWebView.isPropertySupported(
        PlatformWebViewCreationParamsProperty.windowId,
      )) {
        return;
      }

      final fixture = await _SchoolWebRedirectFixture.start();
      addTearDown(fixture.close);
      await CookieManager.instance().deleteAllCookies();
      addTearDown(CookieManager.instance().deleteAllCookies);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final controllerReady = Completer<InAppWebViewController>();
      final popupRequested = Completer<CreateWindowAction>();
      final childCreated = Completer<InAppWebViewController>();
      final childClosed = Completer<void>();
      final routeObserver = _RouteCountObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routeObserver],
          home: _SingleRouteHarness(
            child: _SchoolWebViewHarness(
              onParentCreated: controllerReady.complete,
              onPopupRequested: popupRequested.complete,
              onChildCreated: childCreated.complete,
              onChildClosed: () {
                if (!childClosed.isCompleted) {
                  childClosed.complete();
                }
              },
            ),
          ),
        ),
      );

      final controller = await _waitFor(
        controllerReady.future,
        'the parent WebView to be created',
      );
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(fixture.popupStartUrl)),
      );

      final action = await _waitFor(
        popupRequested.future,
        'window.open to request a child window',
      );
      expect(action.windowId, greaterThan(0));
      await _waitForCompleterWithPumps(
        tester,
        childCreated,
        'the windowId child WebView',
      );
      final callback = await _waitFor(
        fixture.popupComplete.future,
        'the popup opener callback',
      );

      expect(callback['opener'], 'preserved');
      expect(fixture.popupTargetWasRequested, isTrue);
      await _waitFor(childClosed.future, 'the child window to close');
      expect(
        routeObserver.routePushes,
        1,
        reason:
            'A native windowId child must stay in the one Flutter browser '
            'route rather than pushing a second SchoolWebImportPage.',
      );
    },
    skip: !io.Platform.isAndroid,
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

Future<T> _waitFor<T>(Future<T> future, String operation) {
  return future.timeout(
    _webViewTimeout,
    onTimeout: () => throw StateError('Timed out waiting for $operation.'),
  );
}

Future<T> _waitForCompleterWithPumps<T>(
  WidgetTester tester,
  Completer<T> completer,
  String operation,
) async {
  final stopwatch = Stopwatch()..start();
  while (!completer.isCompleted && stopwatch.elapsed < _webViewTimeout) {
    await tester.pump(const Duration(milliseconds: 16));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return _waitFor(completer.future, operation);
}

class _SchoolWebViewHarness extends StatefulWidget {
  const _SchoolWebViewHarness({
    required this.onParentCreated,
    this.onPopupRequested,
    this.onChildCreated,
    this.onChildClosed,
  });

  final ValueChanged<InAppWebViewController> onParentCreated;
  final ValueChanged<CreateWindowAction>? onPopupRequested;
  final ValueChanged<InAppWebViewController>? onChildCreated;
  final VoidCallback? onChildClosed;

  @override
  State<_SchoolWebViewHarness> createState() => _SchoolWebViewHarnessState();
}

class _SchoolWebViewHarnessState extends State<_SchoolWebViewHarness> {
  int? _childWindowId;

  Future<bool?> _handleCreateWindow(
    InAppWebViewController _,
    CreateWindowAction action,
  ) async {
    if (!mounted || _childWindowId != null) {
      return false;
    }
    widget.onPopupRequested?.call(action);
    setState(() => _childWindowId = action.windowId);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InAppWebView(
          key: const ValueKey('school-web-import-parent-webview'),
          initialSettings: schoolWebImportWebViewSettings(
            supportsPopups: schoolWebImportSupportsPopupWindows(),
          ),
          onWebViewCreated: widget.onParentCreated,
          onCreateWindow: _handleCreateWindow,
        ),
        if (_childWindowId case final childWindowId?)
          Offstage(
            // The child is rendered on top while keeping the parent mounted:
            // this is the same one-route pane strategy as the production
            // browser, and preserves the native opener relationship.
            offstage: false,
            child: InAppWebView(
              key: ValueKey('school-web-import-child-$childWindowId'),
              windowId: childWindowId,
              initialSettings: schoolWebImportWebViewSettings(
                supportsPopups: schoolWebImportSupportsPopupWindows(),
              ),
              onWebViewCreated: (controller) {
                widget.onChildCreated?.call(controller);
              },
              onCloseWindow: (_) {
                widget.onChildClosed?.call();
                if (mounted) {
                  setState(() => _childWindowId = null);
                }
              },
            ),
          ),
      ],
    );
  }
}

/// Counts Flutter routes without turning a native popup into another route.
class _SingleRouteHarness extends StatefulWidget {
  const _SingleRouteHarness({required this.child});

  final Widget child;

  @override
  State<_SingleRouteHarness> createState() => _SingleRouteHarnessState();
}

class _SingleRouteHarnessState extends State<_SingleRouteHarness> {
  @override
  Widget build(BuildContext context) => Scaffold(body: widget.child);
}

class _RouteCountObserver extends NavigatorObserver {
  int routePushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routePushes += 1;
    super.didPush(route, previousRoute);
  }
}

class _SchoolWebRedirectFixture {
  _SchoolWebRedirectFixture(this._schoolServer, this._identityServer);

  final io.HttpServer _schoolServer;
  final io.HttpServer _identityServer;
  final Completer<_RedirectObservation> redirectComplete =
      Completer<_RedirectObservation>();
  final Completer<Map<String, String>> popupComplete =
      Completer<Map<String, String>>();

  String? identityRequestMethod;
  String? identityRequestBody;
  String? identityContinueCookie;
  int identityRequestCount = 0;
  int callbackRequestCount = 0;
  bool popupTargetWasRequested = false;

  String get schoolOrigin => _originFor(_schoolServer);
  String get identityOrigin => _originFor(_identityServer);
  String get schoolStartUrl => '$schoolOrigin/start';
  String get schoolCallbackUrl => '$schoolOrigin/callback';
  String get popupStartUrl => '$schoolOrigin/popup-start';

  static Future<_SchoolWebRedirectFixture> start() async {
    final schoolServer = await io.HttpServer.bind(
      io.InternetAddress.loopbackIPv4,
      0,
    );
    final identityServer = await io.HttpServer.bind(
      io.InternetAddress.loopbackIPv4,
      0,
    );
    final fixture = _SchoolWebRedirectFixture(schoolServer, identityServer);
    schoolServer.listen(fixture._handleSchoolRequest);
    identityServer.listen(fixture._handleIdentityRequest);
    return fixture;
  }

  Future<void> close() async {
    await Future.wait([
      _schoolServer.close(force: true),
      _identityServer.close(force: true),
    ]);
  }

  Future<void> _handleSchoolRequest(io.HttpRequest request) async {
    switch (request.uri.path) {
      case '/start':
        request.response.cookies.add(
          _sessionCookie('school_session', 'accepted'),
        );
        await _respondHtml(request, '''<!doctype html>
<html><body>
<form id="identity" method="post" action="$identityOrigin/identity">
  <input type="hidden" name="grant" value="source-grant">
</form>
<script>document.getElementById('identity').submit();</script>
</body></html>''');
      case '/callback':
        callbackRequestCount += 1;
        final callbackBody = await utf8.decoder.bind(request).join();
        final observation = _RedirectObservation(
          callbackMethod: request.method,
          callbackBody: callbackBody,
          callbackCookie: request.headers.value(io.HttpHeaders.cookieHeader),
        );
        if (!redirectComplete.isCompleted) {
          redirectComplete.complete(observation);
        }
        await _respondHtml(
          request,
          '<html><body>redirect complete</body></html>',
        );
      case '/popup-start':
        await _respondHtml(request, '''<!doctype html>
<html><body>
<script>
window.addEventListener('load', function () {
  window.open('$identityOrigin/popup-target', 'school-auth');
});
</script>
</body></html>''');
      case '/popup-callback':
        if (!popupComplete.isCompleted) {
          popupComplete.complete(request.uri.queryParameters);
        }
        await _respondHtml(request, '<html><body>popup callback</body></html>');
      default:
        request.response.statusCode = io.HttpStatus.notFound;
        await request.response.close();
    }
  }

  Future<void> _handleIdentityRequest(io.HttpRequest request) async {
    switch (request.uri.path) {
      case '/identity':
        identityRequestCount += 1;
        identityRequestMethod = request.method;
        identityRequestBody = await utf8.decoder.bind(request).join();
        request.response.cookies.add(
          _sessionCookie('identity_session', 'issued'),
        );
        request.response.statusCode = io.HttpStatus.found;
        request.response.headers.set(
          io.HttpHeaders.locationHeader,
          '$identityOrigin/continue',
        );
        await request.response.close();
      case '/continue':
        identityContinueCookie = request.headers.value(
          io.HttpHeaders.cookieHeader,
        );
        await _respondHtml(request, '''<!doctype html>
<html><body>
<form id="callback" method="post" action="$schoolCallbackUrl">
  <input type="hidden" name="ticket" value="issued-ticket">
</form>
<script>document.getElementById('callback').submit();</script>
</body></html>''');
      case '/popup-target':
        popupTargetWasRequested = true;
        await _respondHtml(request, '''<!doctype html>
<html><body>
<script>
if (window.opener) {
  window.opener.location.href = '$schoolOrigin/popup-callback?opener=preserved';
}
window.setTimeout(function () { window.close(); }, 30);
</script>
</body></html>''');
      default:
        request.response.statusCode = io.HttpStatus.notFound;
        await request.response.close();
    }
  }

  static io.Cookie _sessionCookie(String name, String value) {
    return io.Cookie(name, value)..path = '/';
  }

  static Future<void> _respondHtml(io.HttpRequest request, String body) async {
    request.response.headers.contentType = io.ContentType(
      'text',
      'html',
      charset: 'utf-8',
    );
    request.response.write(body);
    await request.response.close();
  }

  static String _originFor(io.HttpServer server) {
    return 'http://${server.address.address}:${server.port}';
  }
}

class _RedirectObservation {
  const _RedirectObservation({
    required this.callbackMethod,
    required this.callbackBody,
    required this.callbackCookie,
  });

  final String callbackMethod;
  final String callbackBody;
  final String? callbackCookie;
}
