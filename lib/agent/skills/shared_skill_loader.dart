import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

typedef SkillAssetLoader = Future<String> Function(String assetPath);

enum SkillStatus {
  available,
  disabled,
  loaded,
  notFound,
  missingDependencies,
  incompatible,
  invalidAsset,
  budgetExceeded,
}

enum SkillPackError { unavailable, invalidManifest, manifestBudgetExceeded }

class SkillPackException implements Exception {
  const SkillPackException(this.code);
  final SkillPackError code;
  @override
  String toString() => 'SkillPackException(${code.name})';
}

class SkillBudgets {
  const SkillBudgets({
    this.maxManifestBytes = 128 * 1024,
    this.maxSkillBytes = 24 * 1024,
    this.maxLoadedBytes = 64 * 1024,
    this.maxLoadedSkills = 8,
  });
  final int maxManifestBytes;
  final int maxSkillBytes;
  final int maxLoadedBytes;
  final int maxLoadedSkills;
}

class SkillDescriptor {
  const SkillDescriptor._({
    required this.id,
    required this.version,
    required this.title,
    required this.summary,
    required this.asset,
    required this.contentSha256,
    required this.triggers,
    required this.sourceKinds,
    required this.requiredTools,
    required this.optionalTools,
  });
  final String id;
  final String version;
  final String title;
  final String summary;
  final String asset;
  final String contentSha256;
  final List<String> triggers;
  final List<String> sourceKinds;
  final List<String> requiredTools;
  final List<String> optionalTools;

  /// Editable local text is data, not an application-signed asset or plugin.
  factory SkillDescriptor.editable({
    required String id,
    required String title,
    required String summary,
    required String body,
    required int revision,
    Iterable<String> triggers = const [],
    Iterable<String> sourceKinds = const [],
    Iterable<String> requiredTools = const [],
    Iterable<String> optionalTools = const [],
  }) => SkillDescriptor._(
    id: id,
    version: '0.0.$revision',
    title: title,
    summary: summary,
    asset: '',
    contentSha256: sha256.convert(utf8.encode(body)).toString(),
    triggers: List.unmodifiable(triggers),
    sourceKinds: List.unmodifiable(sourceKinds),
    requiredTools: List.unmodifiable(requiredTools),
    optionalTools: List.unmodifiable(optionalTools),
  );

  Map<String, Object?> toSummary() => {
    'id': id,
    'version': version,
    'title': title,
    'summary': summary,
    'sourceKinds': sourceKinds,
  };
}

class SkillOverlay {
  const SkillOverlay({
    required this.skill,
    required this.enabled,
    required this.builtIn,
    this.body,
  });
  final SkillDescriptor skill;
  final bool enabled;
  final bool builtIn;

  /// Null means the currently installed original, with an independent switch.
  final String? body;
}

class SkillOverlaySnapshot {
  SkillOverlaySnapshot(Iterable<SkillOverlay> overlays)
    : entries = Map.unmodifiable({
        for (final overlay in overlays) overlay.skill.id: overlay,
      });
  final Map<String, SkillOverlay> entries;
}

class SkillAvailability {
  SkillAvailability({
    required this.skill,
    required this.status,
    List<String> missingTools = const [],
  }) : missingTools = List.unmodifiable(missingTools);
  final SkillDescriptor skill;
  final SkillStatus status;
  final List<String> missingTools;
}

class SkillLoadResult {
  SkillLoadResult({
    required this.id,
    required this.status,
    this.skill,
    this.body,
    List<String> missingTools = const [],
  }) : missingTools = List.unmodifiable(missingTools);
  final String id;
  final SkillStatus status;
  final SkillDescriptor? skill;
  final String? body;
  final List<String> missingTools;
  bool get isLoaded => status == SkillStatus.loaded;

  Map<String, Object?> toRecord() => {
    'id': id,
    'status': status.name,
    if (skill != null) 'version': skill!.version,
    if (skill != null) 'contentSha256': skill!.contentSha256,
    if (missingTools.isNotEmpty) 'missingTools': missingTools,
  };
}

/// One loader is a frozen run snapshot: tools, contract versions and loaded
/// content never change mid-run. All runs use the same application asset pack.
/// Only catalog IDs are accepted; links in skill text are never followed.
class SharedSkillLoader {
  SharedSkillLoader({
    required this.loadString,
    required Set<String> registeredTools,
    this.runtimeContractVersion = 1,
    this.toolApiVersion = '1.0.0',
    this.budgets = const SkillBudgets(),
    SkillOverlaySnapshot? overlays,
  }) : _registeredTools = Set.unmodifiable(registeredTools),
       _overlays = overlays?.entries ?? const {} {
    _Version.parse(toolApiVersion);
    if (runtimeContractVersion <= 0 ||
        [
          budgets.maxManifestBytes,
          budgets.maxSkillBytes,
          budgets.maxLoadedBytes,
          budgets.maxLoadedSkills,
        ].any((value) => value <= 0)) {
      throw const SkillPackException(SkillPackError.invalidManifest);
    }
  }

  static const assetRoot = 'assets/agent/skills/';
  static const manifestAsset = '${assetRoot}manifest.json';
  final SkillAssetLoader loadString;
  final Set<String> _registeredTools;
  final Map<String, SkillOverlay> _overlays;
  final int runtimeContractVersion;
  final String toolApiVersion;
  final SkillBudgets budgets;
  final Map<String, SkillLoadResult> _loaded = {};
  Future<_Manifest>? _manifestFuture;
  Future<void> _tail = Future.value();
  int _loadedBytes = 0;

  int get loadedBytes => _loadedBytes;
  List<SkillLoadResult> get loadedSkills => List.unmodifiable(_loaded.values);

  Future<List<SkillAvailability>> catalog() async {
    final manifest = await _manifest();
    return List.unmodifiable(
      manifest.skills.map((skill) => _availability(manifest, skill)),
    );
  }

  /// Search receives the actual user request or a trusted route hint. Source
  /// bodies are data and must not be passed here as substitute user intent.
  Future<List<SkillAvailability>> search({
    required String userRequest,
    Set<String> sourceKinds = const {},
    int? limit = 5,
  }) async {
    // The host requests all matching metadata to paginate against one frozen
    // catalog. Ordinary callers keep the existing bounded result.
    if (limit != null && (limit < 1 || limit > 24)) return const [];
    final request = userRequest.trim().toLowerCase();
    if (request.isEmpty) return const [];
    final candidates = <({SkillAvailability entry, int score})>[];
    for (final entry in await catalog()) {
      final skill = entry.skill;
      if (sourceKinds.isNotEmpty &&
          skill.sourceKinds.isNotEmpty &&
          !skill.sourceKinds.any(sourceKinds.contains)) {
        continue;
      }
      var score = request.contains(skill.id) ? 100 : 0;
      final searchable = '${skill.title} ${skill.summary}'.toLowerCase();
      if (searchable.contains(request)) score += request.length;
      for (final term in request.split(RegExp(r'\s+'))) {
        if (term.length >= 2 && searchable.contains(term)) score += term.length;
      }
      for (final trigger in skill.triggers) {
        if (request.contains(trigger.toLowerCase())) score += trigger.length;
      }
      if (score > 0) candidates.add((entry: entry, score: score));
    }
    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.entry.skill.id.compareTo(b.entry.skill.id);
    });
    final ranked = candidates.map((value) => value.entry);
    return List.unmodifiable(limit == null ? ranked : ranked.take(limit));
  }

  Future<SkillLoadResult> load(
    String id, {
    String? expectedVersion,
    String? expectedSha256,
  }) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await _load(id, expectedVersion, expectedSha256);
    } finally {
      done.complete();
    }
  }

  Future<SkillLoadResult> _load(
    String id,
    String? expectedVersion,
    String? expectedSha256,
  ) async {
    final manifest = await _manifest();
    final matches = manifest.skills.where((skill) => skill.id == id);
    if (matches.isEmpty) {
      return SkillLoadResult(id: id, status: SkillStatus.notFound);
    }
    final skill = matches.single;
    if ((expectedVersion != null && expectedVersion != skill.version) ||
        (expectedSha256 != null && expectedSha256 != skill.contentSha256)) {
      return SkillLoadResult(
        id: id,
        status: SkillStatus.incompatible,
        skill: skill,
      );
    }
    final availability = _availability(manifest, skill);
    if (availability.status != SkillStatus.available) {
      return SkillLoadResult(
        id: id,
        skill: skill,
        status: availability.status,
        missingTools: availability.missingTools,
      );
    }
    if (_loaded[id] case final cached?) return cached;
    if (_loaded.length >= budgets.maxLoadedSkills) {
      return SkillLoadResult(
        id: id,
        skill: skill,
        status: SkillStatus.budgetExceeded,
      );
    }
    String body;
    try {
      body =
          _overlay(skill)?.body ?? await loadString('$assetRoot${skill.asset}');
    } catch (_) {
      return SkillLoadResult(
        id: id,
        skill: skill,
        status: SkillStatus.invalidAsset,
      );
    }
    final bytes = utf8.encode(body);
    if (bytes.length > budgets.maxSkillBytes ||
        _loadedBytes + bytes.length > budgets.maxLoadedBytes) {
      return SkillLoadResult(
        id: id,
        skill: skill,
        status: SkillStatus.budgetExceeded,
      );
    }
    if (sha256.convert(bytes).toString() != skill.contentSha256 ||
        (_overlay(skill)?.body == null && !_validBody(body, skill))) {
      return SkillLoadResult(
        id: id,
        skill: skill,
        status: SkillStatus.invalidAsset,
      );
    }
    final result = SkillLoadResult(
      id: id,
      skill: skill,
      status: SkillStatus.loaded,
      body: body,
    );
    _loaded[id] = result;
    _loadedBytes += bytes.length;
    return result;
  }

  SkillAvailability _availability(_Manifest manifest, SkillDescriptor skill) {
    if (_overlay(skill)?.enabled == false) {
      return SkillAvailability(skill: skill, status: SkillStatus.disabled);
    }
    if (manifest.runtimeContractVersion != runtimeContractVersion ||
        !manifest.compatibility.includes(_Version.parse(toolApiVersion))) {
      return SkillAvailability(skill: skill, status: SkillStatus.incompatible);
    }
    final missing = skill.requiredTools
        .where((tool) => !_registeredTools.contains(tool))
        .toList();
    return SkillAvailability(
      skill: skill,
      status: missing.isEmpty
          ? SkillStatus.available
          : SkillStatus.missingDependencies,
      missingTools: missing,
    );
  }

  Future<_Manifest> _manifest() => _manifestFuture ??= _readManifest();

  SkillOverlay? _overlay(SkillDescriptor skill) {
    final overlay = _overlays[skill.id];
    if (overlay != null && !overlay.builtIn && skill.asset.isNotEmpty) {
      return null;
    }
    return overlay;
  }

  Future<_Manifest> _readManifest() async {
    String body;
    try {
      body = await loadString(manifestAsset);
    } catch (_) {
      throw const SkillPackException(SkillPackError.unavailable);
    }
    if (utf8.encode(body).length > budgets.maxManifestBytes) {
      throw const SkillPackException(SkillPackError.manifestBudgetExceeded);
    }
    try {
      final value = jsonDecode(body);
      if (value is! Map<String, dynamic> ||
          value['schemaVersion'] != 1 ||
          value['runtimeContractVersion'] is! int ||
          value['runtimeContractVersion'] <= 0) {
        throw const FormatException();
      }
      _Version.parse(_string(value['packVersion']));
      final compatibility = _Compatibility.parse(
        _string(value['toolApiCompatibility']),
      );
      final raw = value['skills'];
      if (raw is! List || raw.isEmpty || raw.length > 128) {
        throw const FormatException();
      }
      final ids = <String>{};
      final skills = <SkillDescriptor>[];
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) throw const FormatException();
        final id = _string(entry['id']);
        final asset = _string(entry['asset']);
        final version = _string(entry['version']);
        _Version.parse(version);
        if (!RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$').hasMatch(id) ||
            !ids.add(id) ||
            asset != '$id/SKILL.md' ||
            !RegExp(r'^[0-9a-f]{64}$')
                .hasMatch(_string(entry['contentSha256']))) {
          throw const FormatException();
        }
        final required = _strings(entry['requiredTools']);
        final optional = _strings(entry['optionalTools']);
        final tools = [...required, ...optional];
        if (tools.toSet().length != tools.length ||
            tools.any(
              (tool) =>
                  !RegExp(r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$')
                      .hasMatch(tool),
            )) {
          throw const FormatException();
        }
        skills.add(
          SkillDescriptor._(
            id: id,
            version: version,
            title: _string(entry['title']),
            summary: _string(entry['summary']),
            asset: asset,
            contentSha256: _string(entry['contentSha256']),
            triggers: _strings(entry['triggers']),
            sourceKinds: _strings(entry['sourceKinds']),
            requiredTools: required,
            optionalTools: optional,
          ),
        );
      }
      final effective = [
        for (final entry in _overlays.values)
          if (!entry.builtIn && !ids.contains(entry.skill.id)) entry.skill,
        for (final skill in skills)
          if (_overlays[skill.id]?.builtIn == true &&
              _overlays[skill.id]?.body != null)
            _overlays[skill.id]!.skill
          else
            skill,
      ];
      return _Manifest(
        value['runtimeContractVersion'] as int,
        compatibility,
        List.unmodifiable(effective),
      );
    } catch (_) {
      throw const SkillPackException(SkillPackError.invalidManifest);
    }
  }
}

bool _validBody(String body, SkillDescriptor skill) {
  final match = RegExp(
    r'^---\r?\n(.*?)\r?\n---\r?\n',
    dotAll: true,
  ).firstMatch(body);
  if (match == null) return false;
  final metadata = <String, String>{};
  for (final line in match.group(1)!.split(RegExp(r'\r?\n'))) {
    final colon = line.indexOf(': ');
    if (colon < 1) return false;
    final key = line.substring(0, colon);
    if (metadata.containsKey(key)) return false;
    metadata[key] = line.substring(colon + 2);
  }
  if (metadata['id'] != skill.id ||
      metadata['version'] != skill.version ||
      metadata['summary'] != skill.summary) {
    return false;
  }
  return [
    '适用任务',
    '何时不使用',
    '输入',
    '依赖工具',
    '操作步骤',
    '业务注意事项',
    '完成条件',
    '失败处理',
  ].every(
    (heading) =>
        body.contains('## $heading\n') || body.contains('## $heading\r\n'),
  );
}

String _string(Object? value) {
  if (value is! String || value.trim().isEmpty || value.length > 4096) {
    throw const FormatException();
  }
  return value;
}

List<String> _strings(Object? value) {
  if (value is! List || value.length > 128) throw const FormatException();
  final result = value.map(_string).toList();
  if (result.toSet().length != result.length) throw const FormatException();
  return List.unmodifiable(result);
}

class _Manifest {
  const _Manifest(this.runtimeContractVersion, this.compatibility, this.skills);
  final int runtimeContractVersion;
  final _Compatibility compatibility;
  final List<SkillDescriptor> skills;
}

class _Version implements Comparable<_Version> {
  const _Version(this.parts);
  factory _Version.parse(String value) {
    if (!RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$')
        .hasMatch(value)) {
      throw const FormatException();
    }
    return _Version(value.split('.').map(int.parse).toList());
  }
  final List<int> parts;
  @override
  int compareTo(_Version other) {
    for (var i = 0; i < 3; i++) {
      final result = parts[i].compareTo(other.parts[i]);
      if (result != 0) return result;
    }
    return 0;
  }
}

class _Compatibility {
  const _Compatibility(this.minimum, this.maximum);
  factory _Compatibility.parse(String value) {
    final match = RegExp(r'^>=([0-9.]+) <([0-9.]+)$').firstMatch(value);
    if (match == null) throw const FormatException();
    final minimum = _Version.parse(match.group(1)!);
    final maximum = _Version.parse(match.group(2)!);
    if (minimum.compareTo(maximum) >= 0) throw const FormatException();
    return _Compatibility(minimum, maximum);
  }
  final _Version minimum;
  final _Version maximum;
  bool includes(_Version version) =>
      minimum.compareTo(version) <= 0 && version.compareTo(maximum) < 0;
}
