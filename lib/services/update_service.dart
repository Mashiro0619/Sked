import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../utils/update_version.dart';
import 'app_version_service.dart';

export '../utils/update_version.dart';

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.localVersion,
    required this.remoteVersion,
    required this.releaseUrl,
    required this.updateContent,
    required this.hasUpdate,
  });

  final String localVersion;
  final String remoteVersion;
  final String releaseUrl;
  final String updateContent;
  final bool hasUpdate;
}

class _RemoteUpdateInfo {
  const _RemoteUpdateInfo({
    required this.version,
    required this.releaseUrl,
    required this.isPrerelease,
    this.updateContent = '',
  });

  final String version;
  final String releaseUrl;
  final bool isPrerelease;
  final String updateContent;
}

class UpdateService {
  const UpdateService({
    this._client,
    this._requestTimeout = const Duration(seconds: 10),
    this._updateVersionUrl,
    this._packageInfoLoader,
  });

  static const _githubReleasesApi =
      'https://api.github.com/repos/Mashiro0619/Sked/releases';
  static const releasesUrl = 'https://github.com/Mashiro0619/Sked/releases';
  static const latestReleaseUrl = '$releasesUrl/latest';

  final http.Client? _client;
  final Duration _requestTimeout;
  final String? _updateVersionUrl;
  final Future<PackageInfo> Function()? _packageInfoLoader;

  Future<UpdateCheckResult> checkForUpdates({
    bool includePrereleases = false,
  }) async {
    final localVersion = await loadCurrentAppVersion(
      packageInfoLoader: _packageInfoLoader,
    );
    final remoteInfo = await _getRemoteUpdateInfo(includePrereleases);
    return UpdateCheckResult(
      localVersion: localVersion,
      remoteVersion: remoteInfo?.version ?? localVersion,
      releaseUrl:
          remoteInfo?.releaseUrl ??
          (includePrereleases ? releasesUrl : latestReleaseUrl),
      updateContent: remoteInfo?.updateContent ?? '',
      hasUpdate:
          remoteInfo != null &&
          compareUpdateVersions(remoteInfo.version, localVersion) > 0,
    );
  }

  Future<_RemoteUpdateInfo?> _getRemoteUpdateInfo(
    bool includePrereleases,
  ) async {
    final configuredUrl = (_updateVersionUrl ?? AppConfig.updateVersionUrl)
        .trim();
    final client = _client ?? http.Client();
    try {
      if (configuredUrl.isEmpty) {
        return await _getGithubReleaseInfo(client, includePrereleases);
      }
      return await _getCustomUpdateInfo(
        client,
        configuredUrl,
        includePrereleases,
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<_RemoteUpdateInfo?> _getGithubReleaseInfo(
    http.Client client,
    bool includePrereleases,
  ) async {
    _RemoteUpdateInfo? latest;
    var page = 1;
    while (true) {
      final response = await client
          .get(
            Uri.parse(_githubReleasesApi)
                .replace(queryParameters: {'per_page': '100', 'page': '$page'}),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException('Unable to fetch release versions.');
      }
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! List) {
        throw const FormatException('Invalid release list response.');
      }
      for (final entry in decoded) {
        // A historical/non-versioned release must not hide other valid tags.
        if (entry is! Map<String, dynamic>) continue;
        _RemoteUpdateInfo? candidate;
        try {
          candidate = _readGithubRelease(entry);
        } on FormatException {
          continue;
        }
        latest = _newestEligibleRelease(latest, candidate, includePrereleases);
      }
      final hasNextPage =
          response.headers['link']
              ?.split(',')
              .any((link) => RegExp(r';\s*rel="next"').hasMatch(link)) ??
          false;
      if (!hasNextPage) return latest;
      // Build the next URL locally rather than following an arbitrary Link URL.
      // GitHub orders releases by creation date, not by SemVer precedence.
      page += 1;
    }
  }

  Future<_RemoteUpdateInfo?> _getCustomUpdateInfo(
    http.Client client,
    String url,
    bool includePrereleases,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.trim().isEmpty) {
      throw const FormatException('Invalid custom update URL.');
    }
    final response = await client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException('Unable to fetch custom update version.');
    }
    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid custom update response.');
    }
    // A legacy single-release feed still works. A releases array lets one
    // configured endpoint serve both stable and prerelease channels.
    final Object? entries = decoded.containsKey('releases')
        ? decoded['releases']
        : [decoded];
    if (entries is! List) {
      throw const FormatException('Invalid custom update response.');
    }
    _RemoteUpdateInfo? latest;
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid custom update response.');
      }
      latest = _newestEligibleRelease(
        latest,
        _readCustomRelease(entry),
        includePrereleases,
      );
    }
    return latest;
  }
}

_RemoteUpdateInfo? _newestEligibleRelease(
  _RemoteUpdateInfo? current,
  _RemoteUpdateInfo? candidate,
  bool includePrereleases,
) {
  if (candidate == null || (!includePrereleases && candidate.isPrerelease)) {
    return current;
  }
  if (current == null) return candidate;
  final comparison = compareUpdateVersions(candidate.version, current.version);
  if (comparison > 0 ||
      (comparison == 0 && current.isPrerelease && !candidate.isPrerelease)) {
    return candidate;
  }
  return current;
}

_RemoteUpdateInfo? _readGithubRelease(Map<String, dynamic> json) {
  if (_releaseFlag(json, 'draft')) return null;
  final version = _readRemoteVersionField(
    json,
    'tag_name',
    invalidMessage: 'Invalid release response.',
    emptyMessage: 'Release version is empty.',
  );
  return _RemoteUpdateInfo(
    version: version,
    releaseUrl: _githubReleaseUrlOrFallback(
      _optionalStringField(json, 'html_url'),
      tag: (json['tag_name'] as String).trim(),
    ),
    isPrerelease:
        _releaseFlag(json, 'prerelease') || isPrereleaseUpdateVersion(version),
    updateContent: _optionalStringField(json, 'body'),
  );
}

_RemoteUpdateInfo? _readCustomRelease(Map<String, dynamic> json) {
  if (_releaseFlag(json, 'draft')) return null;
  final version = _readFirstRemoteVersionField(
    json,
    const ['version', 'tag_name'],
    invalidMessage: 'Invalid custom update response.',
    emptyMessage: 'Custom update version is empty.',
  );
  final isPrerelease =
      _releaseFlag(json, 'prerelease') || isPrereleaseUpdateVersion(version);
  return _RemoteUpdateInfo(
    version: version,
    releaseUrl: _safeHttpsUrlOrFallback(
      _optionalFirstStringField(json, const [
        'releaseUrl',
        'release_url',
        'html_url',
        'url',
      ]),
      fallback: isPrerelease
          ? UpdateService.releasesUrl
          : UpdateService.latestReleaseUrl,
    ),
    isPrerelease: isPrerelease,
    updateContent: _optionalFirstStringField(json, const [
      'updateContent',
      'update_content',
      'body',
      'notes',
      'changelog',
    ]),
  );
}

bool _releaseFlag(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) return false;
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid release flag: $key.');
  return value;
}

String _readFirstRemoteVersionField(
  Map<String, dynamic> json,
  List<String> keys, {
  required String invalidMessage,
  required String emptyMessage,
}) {
  for (final key in keys) {
    if (json.containsKey(key)) {
      return _readRemoteVersionField(
        json,
        key,
        invalidMessage: invalidMessage,
        emptyMessage: emptyMessage,
      );
    }
  }
  throw FormatException(invalidMessage);
}

String _readRemoteVersionField(
  Map<String, dynamic> json,
  String key, {
  required String invalidMessage,
  required String emptyMessage,
}) {
  final raw = json[key];
  if (raw is! String) throw FormatException(invalidMessage);
  if (raw.trim().isEmpty) throw FormatException(emptyMessage);
  final version = normalizeUpdateVersion(raw);
  if (version.isEmpty) throw FormatException(invalidMessage);
  return version;
}

String _optionalStringField(Map<String, dynamic> json, String key) {
  final raw = json[key];
  return raw is String ? raw.trim() : '';
}

String _optionalFirstStringField(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _optionalStringField(json, key);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _safeHttpsUrlOrFallback(String value, {required String fallback}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.trim().isEmpty) {
    return fallback;
  }
  return uri.toString();
}

String _githubReleaseUrlOrFallback(String value, {required String tag}) {
  final fallback = Uri.https(
    'github.com',
    '/Mashiro0619/Sked/releases/tag/$tag',
  ).toString();
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.toLowerCase() != 'github.com') {
    return fallback;
  }
  final segments = uri.pathSegments;
  if (segments.length < 4 ||
      segments[0] != 'Mashiro0619' ||
      segments[1] != 'Sked' ||
      segments[2] != 'releases') {
    return fallback;
  }
  return uri.toString();
}
