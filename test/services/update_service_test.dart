import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sked/services/update_service.dart';

void _setLocalVersion(String version) {
  PackageInfo.setMockInitialValues(
    appName: 'Sked',
    packageName: 'com.mashiro.sked',
    version: version,
    buildNumber: '1',
    buildSignature: '',
  );
}

http.Response _json(Object? value, {Map<String, String> headers = const {}}) {
  return http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  );
}

Map<String, Object?> _release(
  String tag, {
  bool prerelease = false,
  bool draft = false,
}) => {
  'tag_name': tag,
  'prerelease': prerelease,
  'draft': draft,
  'html_url': 'https://github.com/Mashiro0619/Sked/releases/tag/$tag',
  'body': 'Notes for $tag',
};

UpdateService _service(
  FutureOr<http.Response> Function(http.Request) respond, {
  String? updateVersionUrl,
  Duration requestTimeout = const Duration(seconds: 10),
}) => UpdateService(
  client: MockClient((request) async => respond(request)),
  updateVersionUrl: updateVersionUrl,
  requestTimeout: requestTimeout,
  packageInfoLoader: PackageInfo.fromPlatform,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => _setLocalVersion('1.9.9'));

  group('GitHub update channels', () {
    test('uses the release list and compares numeric versions', () async {
      final service = _service((request) {
        expect(request.url.host, 'api.github.com');
        expect(request.url.path, '/repos/Mashiro0619/Sked/releases');
        expect(request.url.queryParameters, {'per_page': '100', 'page': '1'});
        expect(request.headers['Accept'], 'application/vnd.github+json');
        return _json([_release('v1.10.0+2'), _release('v1.9.9')]);
      });
      final result = await service.checkForUpdates();
      expect(result.localVersion, '1.9.9');
      expect(result.remoteVersion, '1.10.0');
      expect(result.updateContent, 'Notes for v1.10.0+2');
      expect(result.hasUpdate, isTrue);
    });

    test(
      'stable is the default and filters both flags and SemVer suffixes',
      () async {
        final service = _service(
          (_) => _json([
            _release('v9.0.0', draft: true),
            _release('v4.0.0', prerelease: true),
            _release('v3.0.0-alpha.1'),
            _release('v1.9.10'),
            _release('v1.10.0'),
          ]),
        );
        final result = await service.checkForUpdates();
        expect(result.remoteVersion, '1.10.0');
        expect(result.hasUpdate, isTrue);
      },
    );

    test('opt-in picks the highest SemVer, not the first release', () async {
      final service = _service(
        (_) => _json([
          _release('v2.0.0-rc.2', prerelease: true),
          _release('v2.0.0-beta.11', prerelease: true),
          _release('v2.0.0-rc.10', prerelease: true),
          _release('v9.0.0', draft: true),
          _release('v1.10.0'),
        ]),
      );
      final result = await service.checkForUpdates(includePrereleases: true);
      expect(result.remoteVersion, '2.0.0-rc.10');
      expect(result.releaseUrl, endsWith('/tag/v2.0.0-rc.10'));
      expect(result.updateContent, 'Notes for v2.0.0-rc.10');
      expect(result.hasUpdate, isTrue);
    });

    test(
      'prefers a stable release when a flagged prerelease has equal precedence',
      () async {
        final result = await _service(
          (_) =>
              _json([_release('v2.0.0', prerelease: true), _release('2.0.0')]),
        ).checkForUpdates(includePrereleases: true);
        expect(result.releaseUrl, endsWith('/tag/2.0.0'));
      },
    );

    for (final includePrereleases in [false, true]) {
      test(
        'RC upgrades to the same-core final release (opt-in: $includePrereleases)',
        () async {
          _setLocalVersion('2.0.0-rc.10');
          final service = _service(
            (_) => _json([
              _release('v2.0.0-rc.11', prerelease: true),
              _release('v2.0.0'),
            ]),
          );
          final result = await service.checkForUpdates(
            includePrereleases: includePrereleases,
          );
          expect(result.remoteVersion, '2.0.0');
          expect(result.hasUpdate, isTrue);
        },
      );

      test(
        'scans pagination before choosing a release (opt-in: $includePrereleases)',
        () async {
          final requestedPages = <String>[];
          final service = _service((request) {
            expect(request.url.host, 'api.github.com');
            final page = request.url.queryParameters['page']!;
            requestedPages.add(page);
            return switch (page) {
              '1' => _json(
                [_release('v2.0.0-rc.1', prerelease: true)],
                headers: {
                  'link':
                      '<https://untrusted.example/releases?page=2>; rel="next"',
                },
              ),
              '2' => _json(
                [_release('v1.10.0')],
                headers: {
                  'link': '<https://api.github.com/repos/Mashiro0619/Sked/releases?page=3>; rel="next", <https://api.github.com/repos/Mashiro0619/Sked/releases?page=1>; rel="prev"',
                },
              ),
              '3' => _json([
                _release('v1.11.0'),
                _release('v2.0.0-rc.2', prerelease: true),
              ]),
              _ => throw StateError('Unexpected page $page'),
            };
          });
          final result = await service.checkForUpdates(
            includePrereleases: includePrereleases,
          );
          expect(requestedPages, ['1', '2', '3']);
          expect(
            result.remoteVersion,
            includePrereleases ? '2.0.0-rc.2' : '1.11.0',
          );
        },
      );
    }

    for (final scenario in [
      (local: '2.0.0-alpha.1', remote: '2.0.0-alpha.2', update: true),
      (local: '2.0.0-alpha.2', remote: '2.0.0-rc.1', update: true),
      (local: '2.0.0-rc.2', remote: '2.0.0-rc.10', update: true),
      (local: '2.0.0', remote: '2.0.0-rc.10', update: false),
      (local: '2.0.0-rc.1', remote: '1.10.0', update: false),
      (local: '2.0.0-rc.2', remote: '2.0.0-rc.1', update: false),
      (local: '2.0.0-rc.1+1', remote: '2.0.0-rc.1+2', update: false),
      (local: '2.0.0+1', remote: '2.0.0+2', update: false),
    ]) {
      test('update eligibility for $scenario', () async {
        _setLocalVersion(scenario.local);
        final service = _service((_) => _json([_release(scenario.remote)]));
        final result = await service.checkForUpdates(includePrereleases: true);
        expect(result.hasUpdate, scenario.update);
      });
    }

    test('empty and fully filtered lists mean no eligible update', () async {
      for (final releases in [
        <Object?>[],
        [_release('2.0.0-rc.1', prerelease: true)],
        [_release('2.0.0', draft: true)],
      ]) {
        final result = await _service((_) => _json(releases)).checkForUpdates();
        expect(result.hasUpdate, isFalse);
        expect(result.remoteVersion, result.localVersion);
        expect(result.updateContent, isEmpty);
      }
    });

    test('invalid historical entries do not hide valid releases', () async {
      final service = _service(
        (_) => _json([
          null,
          'invalid',
          {
            'tag_name': {'version': 'v9.0.0'},
          },
          _release('nightly'),
          _release('v3.0.0-rc.'),
          {..._release('v5.0.0'), 'prerelease': 'false'},
          {..._release('v6.0.0'), 'draft': 'false'},
          _release('v1.10.0'),
        ]),
      );
      final result = await service.checkForUpdates();
      expect(result.remoteVersion, '1.10.0');
    });

    test(
      'ignores malformed optional fields and falls back to the selected tag',
      () async {
        final result = await _service(
          (_) => _json([
            {
              ..._release('v2.0.0-rc.1'),
              'html_url': ['invalid'],
              'body': {'notes': 'bad'},
            },
          ]),
        ).checkForUpdates(includePrereleases: true);
        expect(
          result.releaseUrl,
          'https://github.com/Mashiro0619/Sked/releases/tag/v2.0.0-rc.1',
        );
        expect(result.updateContent, isEmpty);
      },
    );

    for (final url in [
      'http://example.test/update',
      'https://example.test/releases/2.0.0',
      'https://github.com/Other/Repo/releases/tag/v2.0.0',
    ]) {
      test('rejects a non-project GitHub release URL: $url', () async {
        final result = await _service(
          (_) => _json([
            {..._release('v2.0.0'), 'html_url': url},
          ]),
        ).checkForUpdates();
        expect(
          result.releaseUrl,
          'https://github.com/Mashiro0619/Sked/releases/tag/v2.0.0',
        );
      });
    }

    test('rejects a malformed top-level response', () async {
      await expectLater(
        _service((_) => _json({'tag_name': '2.0.0'})).checkForUpdates(),
        throwsFormatException,
      );
    });

    test('request failure is not reported as up to date', () async {
      await expectLater(
        _service((_) => http.Response('not found', 404)).checkForUpdates(),
        throwsFormatException,
      );
    });

    test('a failed later page does not report a partial result', () async {
      final service = _service(
        (request) => request.url.queryParameters['page'] == '1'
            ? _json(
                [_release('2.0.0')],
                headers: {
                  'link': '<https://api.github.com/repos/Mashiro0619/Sked/releases?page=2>; rel="next"',
                },
              )
            : http.Response('rate limit', 403),
      );
      await expectLater(service.checkForUpdates(), throwsFormatException);
    });

    test('times out stalled release requests', () async {
      final service = _service(
        (_) => Completer<http.Response>().future,
        requestTimeout: const Duration(milliseconds: 1),
      );
      await expectLater(
        service.checkForUpdates(),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('custom update feed', () {
    const url = 'https://updates.example.test/sked.json';
    test('keeps the legacy single-release format', () async {
      final result = await _service((request) {
        expect(request.url.toString(), url);
        return _json({
          'version': 'v2.0.0+7',
          'releaseUrl': 'https://updates.example.test/releases/2.0.0',
          'updateContent': 'custom notes',
        });
      }, updateVersionUrl: url).checkForUpdates();
      expect(result.remoteVersion, '2.0.0');
      expect(result.releaseUrl, 'https://updates.example.test/releases/2.0.0');
      expect(result.updateContent, 'custom notes');
      expect(result.hasUpdate, isTrue);
    });

    test(
      'applies the channel to suffixes and explicit prerelease flags',
      () async {
        for (final release in [
          {'version': '2.0.0-rc.1'},
          {'tag_name': '2.0.0', 'prerelease': true},
        ]) {
          final service = _service(
            (_) => _json(release),
            updateVersionUrl: url,
          );
          expect((await service.checkForUpdates()).hasUpdate, isFalse);
          final preview = await service.checkForUpdates(
            includePrereleases: true,
          );
          expect(preview.hasUpdate, isTrue);
          expect(preview.releaseUrl, UpdateService.releasesUrl);
        }
      },
    );

    test('one release array can serve stable and prerelease users', () async {
      final service = _service(
        (_) => _json({
          'releases': [
            _release('v3.0.0', draft: true),
            _release('v2.0.0-beta.2', prerelease: true),
            _release('v1.11.0'),
            _release('v2.0.0-rc.1', prerelease: true),
          ],
        }),
        updateVersionUrl: url,
      );
      expect((await service.checkForUpdates()).remoteVersion, '1.11.0');
      expect(
        (await service.checkForUpdates(includePrereleases: true)).remoteVersion,
        '2.0.0-rc.1',
      );
    });

    test(
      'never offers draft releases, including to prerelease users',
      () async {
        final service = _service(
          (_) => _json({'version': '9.0.0', 'draft': true}),
          updateVersionUrl: url,
        );
        expect(
          (await service.checkForUpdates(includePrereleases: true)).hasUpdate,
          isFalse,
        );
      },
    );

    test(
      'rejects insecure custom update URLs without making a request',
      () async {
        final service = _service(
          (_) => throw StateError('Must not request'),
          updateVersionUrl: 'http://example.test/v',
        );
        await expectLater(service.checkForUpdates(), throwsFormatException);
      },
    );

    for (final payload in [
      <Object?>[],
      <String, Object?>{},
      {'version': ''},
      {'version': 'future'},
      {
        'version': {'value': '2.0.0'},
      },
      {'version': '2.0.0-rc.'},
      {'version': '2.0.0', 'prerelease': 'true'},
      {'version': '2.0.0', 'prerelease': null},
      {'version': '2.0.0', 'draft': null},
      {'releases': {}},
      {
        'releases': [null],
      },
    ]) {
      test('rejects malformed custom payload $payload', () async {
        final service = _service((_) => _json(payload), updateVersionUrl: url);
        await expectLater(service.checkForUpdates(), throwsFormatException);
      });
    }

    test('rejects unsuccessful custom requests', () async {
      final service = _service(
        (_) => http.Response('error', 500),
        updateVersionUrl: url,
      );
      await expectLater(service.checkForUpdates(), throwsFormatException);
    });
  });
}
