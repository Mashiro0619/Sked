import 'package:path/path.dart' as paths;

import '../bridge/generated/api/file_contracts.dart';
import '../execution/execution_evidence.dart' show pythonExecutionAction;
import '../files/file_evidence.dart' show fileWriteAction;
import '../operations/tool_outcome.dart';

/// A read-only view of the original tool result. Its receipt remains the
/// persisted source of truth for reopening the conversation and reconciliation.
class AgentDelivery {
  AgentDelivery._({
    required Iterable<AgentDeliveryFile> files,
    required Iterable<AgentDeliverySource> sources,
    required Iterable<Map<String, Object?>> businessChanges,
  }) : files = List.unmodifiable(files),
       sources = List.unmodifiable(sources),
       businessChanges = List.unmodifiable(businessChanges);

  factory AgentDelivery.fromToolResult({
    required String toolName,
    required ToolOutcome outcome,
  }) {
    final result = outcome.payload;
    final action = result['action'];
    final isFileWrite =
        toolName == 'files.new' ||
        toolName == 'files.write' ||
        action == fileWriteAction;
    final isExecution =
        toolName == 'python.execute' || action == pythonExecutionAction;
    final files = <AgentDeliveryFile>[];
    final sources = <AgentDeliverySource>[];
    if (outcome.kind != ToolOutcomeKind.preview) {
      final effect = _object(result['effectResult']);
      if (isFileWrite) {
        final receipt = _object(effect?['file']);
        if (receipt != null) {
          files.addAll(_fileWriteDeliveries(receipt, outcome));
        }
      }
      if (isExecution || toolName == 'office.read') {
        final receipt = _object(
          toolName == 'office.read'
              ? result['execution']
              : effect?['execution'],
        );
        if (receipt != null) {
          files.addAll(_executionDeliveries(receipt, outcome));
        }
      }
      if (toolName == 'web.fetch') {
        final source = _webSource(result['source']);
        if (source != null) sources.add(source);
      }
    }
    return AgentDelivery._(
      files: files,
      sources: sources,
      businessChanges: isFileWrite || isExecution
          ? const []
          : [
              for (final change in _objects(result['changes']))
                Map.unmodifiable(change),
            ],
    );
  }

  final List<AgentDeliveryFile> files;
  final List<AgentDeliverySource> sources;
  final List<Map<String, Object?>> businessChanges;

  bool get hasItems =>
      files.isNotEmpty || sources.isNotEmpty || businessChanges.isNotEmpty;
}

enum AgentDeliveryFileState { saved, observed, recovery }

class AgentDeliveryFileVersion {
  const AgentDeliveryFileVersion({
    required this.resourceId,
    required this.version,
    this.sha256,
    this.byteLength,
  });

  final String resourceId;
  final String version;
  final String? sha256;
  final int? byteLength;
}

/// Every row has an observed file version. Proposed destinations and output
/// paths mentioned in model text do not produce file actions.
class AgentDeliveryFile {
  const AgentDeliveryFile({
    required this.id,
    required this.name,
    required this.resource,
    required this.version,
    required this.state,
    this.mediaType,
  });

  final String id;
  final String name;
  final FileResourceRef resource;
  final AgentDeliveryFileVersion version;
  final AgentDeliveryFileState state;
  final String? mediaType;

  bool get canOpen => true;
}

class AgentDeliveryPublication {
  const AgentDeliveryPublication({required this.value, required this.evidence});

  final String value;
  final String evidence;
}

class AgentDeliverySource {
  AgentDeliverySource({
    required this.id,
    required this.url,
    required Iterable<AgentDeliveryPublication> publications,
    this.title,
    this.originalUrl,
    this.fetchedAt,
    this.contentType,
    this.byteLength,
    this.sha256,
  }) : publications = List.unmodifiable(publications);

  final String id;
  final String? title;
  final Uri url;
  final Uri? originalUrl;
  final DateTime? fetchedAt;
  final List<AgentDeliveryPublication> publications;
  final String? contentType;
  final int? byteLength;
  final String? sha256;
}

Iterable<AgentDeliveryFile> _fileWriteDeliveries(
  Map<String, Object?> receipt,
  ToolOutcome outcome,
) sync* {
  final identity = _object(receipt['identity']);
  final writeId = _text(identity?['writeId']);
  if (writeId == null) return;
  if (receipt['state'] == 'published' &&
      receipt['effect'] == 'observed' &&
      receipt['settled'] == true) {
    final file = _file(
      owner: writeId,
      resource: receipt['target'],
      version: receipt['currentVersion'],
      state: outcome.kind == ToolOutcomeKind.saved
          ? AgentDeliveryFileState.saved
          : AgentDeliveryFileState.observed,
    );
    if (file != null) yield file;
  }
  for (final entry in _objects(receipt['recoveryResources'])) {
    if (entry['kind'] != 'file') continue;
    final file = _file(
      owner: writeId,
      resource: entry['resource'],
      version: entry['version'],
      name: _text(entry['name']),
      state: AgentDeliveryFileState.recovery,
    );
    if (file != null) yield file;
  }
}

Iterable<AgentDeliveryFile> _executionDeliveries(
  Map<String, Object?> receipt,
  ToolOutcome outcome,
) sync* {
  final executionId = _text(receipt['executionId']);
  if (executionId == null || receipt['terminal'] == 'notStarted') return;
  final effects = _object(receipt['effects']);
  final detail = _object(effects?['detail']);
  final saved =
      outcome.kind == ToolOutcomeKind.saved &&
      receipt['terminal'] == 'exited' &&
      receipt['exitCode'] == 0 &&
      receipt['error'] == null &&
      effects?['state'] == 'observed' &&
      detail?['readerId'] == null;
  for (final entry in _objects(detail?['files'])) {
    final file = _file(
      owner: executionId,
      resource: entry['file'],
      version: entry['version'],
      name: _text(entry['name']),
      mediaType: _text(entry['mediaType']),
      state: saved
          ? AgentDeliveryFileState.saved
          : AgentDeliveryFileState.observed,
    );
    if (file != null) yield file;
  }
}

AgentDeliveryFile? _file({
  required String owner,
  required Object? resource,
  required Object? version,
  required AgentDeliveryFileState state,
  String? name,
  String? mediaType,
}) {
  final location = _object(resource);
  final value = _text(location?['value']);
  final kind = switch (location?['kind']) {
    'windowsPath' => FileResourceKind.windowsPath,
    'androidPath' => FileResourceKind.androidPath,
    'contentUri' => FileResourceKind.contentUri,
    _ => null,
  };
  final observed = _object(version);
  final resourceId = _text(observed?['resourceId']);
  final revision = _text(observed?['version']);
  if (kind == null || value == null || resourceId == null || revision == null) {
    return null;
  }
  final file = FileResourceRef(kind: kind, value: value);
  return AgentDeliveryFile(
    id: '$owner:$resourceId:$revision',
    name: name ?? _fileName(file),
    resource: file,
    version: AgentDeliveryFileVersion(
      resourceId: resourceId,
      version: revision,
      sha256: _text(observed?['sha256'] ?? observed?['digest']),
      byteLength: observed?['byteLength'] as int?,
    ),
    state: state,
    mediaType: mediaType,
  );
}

String _fileName(FileResourceRef resource) => switch (resource.kind) {
  FileResourceKind.windowsPath => paths.windows.basename(resource.value),
  FileResourceKind.androidPath => paths.posix.basename(resource.value),
  FileResourceKind.contentUri => resource.value,
};

AgentDeliverySource? _webSource(Object? value) {
  final source = _object(value);
  if (source == null) return null;
  final url = _webUrl(source['finalUrl']);
  if (url == null) return null;
  final fetchedAtMs = source['fetchedAtMs'] as int?;
  return AgentDeliverySource(
    id: '$url:${fetchedAtMs ?? ''}',
    title: _text(source['title']) ?? _text(source['name']),
    url: url,
    originalUrl: _webUrl(source['originalUrl']),
    fetchedAt: fetchedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(fetchedAtMs, isUtc: true),
    publications: [
      for (final publication in _objects(source['publications']))
        if (publication['value'] case final String value)
          if (publication['evidence'] case final String evidence)
            AgentDeliveryPublication(value: value, evidence: evidence),
    ],
    contentType: _text(source['contentType']),
    byteLength: source['byteLength'] as int?,
    sha256: _text(source['sha256']),
  );
}

Uri? _webUrl(Object? value) {
  if (value is! String) return null;
  final url = Uri.tryParse(value);
  return url != null &&
          (url.scheme == 'https' || url.scheme == 'http') &&
          url.host.isNotEmpty
      ? url
      : null;
}

Map<String, Object?>? _object(Object? value) =>
    value is Map<String, Object?> ? value : null;

Iterable<Map<String, Object?>> _objects(Object? value) =>
    value is List ? value.whereType<Map<String, Object?>>() : const [];

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
