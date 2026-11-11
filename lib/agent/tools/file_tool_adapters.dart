import 'dart:convert';

import 'package:flutter/services.dart' show PlatformException;

import '../../application/operation_contracts.dart';
import '../attachments/attachment_media_types.dart';
import '../bridge/generated/api/contracts.dart' as native;
import '../bridge/generated/api/file_contracts.dart';
import '../bridge/generated/api/models.dart' show ViewToolContentRange;
import '../files/agent_file_coordinator.dart';
import '../files/agent_file_access_bridge.dart';
import '../files/file_evidence.dart';
import '../provider/provider_models.dart';
import 'application_tool_host.dart';
import 'application_tool_result.dart';

class FileToolAdapters {
  FileToolAdapters({
    required this._host,
    required this._files,
    required this._fileAccess,
  });

  final ApplicationToolHost _host;
  final AgentFileCoordinator _files;
  final AgentFileAccessBridge _fileAccess;
  Set<FileResourceKind> _resourceKinds = {};
  bool _registered = false;

  /// Called after core initialization and before publishing the host catalog.
  void registerAvailable(FileAvailability availability) {
    _resourceKinds = availability.available
        ? availability.resourceKinds.toSet()
        : {};
    if (_registered || _resourceKinds.isEmpty) return;
    _registered = true;
    final resource = {
      'type': 'object',
      'additionalProperties': false,
      'required': ['kind', 'value'],
      'properties': {
        'kind': {
          'type': 'string',
          'enum': _resourceKinds.map((kind) => kind.name).toList(),
        },
        'value': _string,
      },
    };
    if (_fileAccess.isSupported) {
      _add(
        'files.access',
        'Read the current Android storage permissions and real resources chosen with the system picker. To grant access, the user opens Settings > Agent > File access. This query does not open a permission prompt or picker.',
        {},
        [],
        (args, scope) async {
          _keys(args, {});
          scope.checkActive();
          try {
            final status = await _fileAccess.status();
            scope.checkActive();
            return {
              ...status.toJson(),
              'authorizationEntry': 'Settings > Agent > File access',
              'pathAccessScope': 'Shared storage permissions are shown here. Other application private directories remain subject to Android isolation.',
            };
          } on PlatformException catch (error) {
            throw OperationProblem(
              OperationErrorCode.storageFailure,
              error.message ??
                  'The current file permissions could not be read.',
            );
          }
        },
        readOnly: true,
      );
    }
    _add(
      'files.info',
      'Read the current capabilities of a real file or directory. Use create/modify and writeGuarantees to determine the supported save behavior.',
      {'resource': resource},
      ['resource'],
      (args, scope) async {
        _keys(args, {'resource'});
        final value = _resource(args['resource'], 'resource');
        return {
          'resource': fileResourceJson(value),
          'capabilities': fileCapabilitiesJson(
            await _files.capabilities(scope: scope, resource: value),
          ),
        };
      },
      readOnly: true,
    );
    _add(
      'files.list',
      'Browse a real directory. Continue with nextCursor and the same directory; pageSize controls one page, not the total directory size. Close nextCursor with files.close_cursor when finished browsing.',
      {'directory': resource, 'cursor': _string, 'pageSize': _pageSize},
      ['directory'],
      (args, scope) async {
        _keys(args, {'directory', 'cursor', 'pageSize'});
        return fileDirectoryPageJson(
          await _files.list(
            scope: scope,
            directory: _resource(args['directory'], 'directory'),
            cursor: _optionalText(args, 'cursor'),
            pageSize: _number(
              args,
              'pageSize',
              fallback: 100,
              minimum: 1,
              maximum: _u32Max,
            ),
          ),
        );
      },
      readOnly: true,
    );
    _add(
      'files.search',
      'Search file names or UTF-8 text under a real directory. Continue with nextCursor and the same search parameters. Individual inaccessible resources are reported in issues. Close nextCursor with files.close_cursor before writing a searched file or once you have the results you need.',
      {
        'root': resource,
        'query': _string,
        'text': {'type': 'boolean', 'default': false},
        'recursive': {'type': 'boolean', 'default': true},
        'cursor': _string,
        'pageSize': _pageSize,
      },
      ['root', 'query'],
      (args, scope) async {
        _keys(args, {
          'root',
          'query',
          'text',
          'recursive',
          'cursor',
          'pageSize',
        });
        return fileSearchPageJson(
          await _files.search(
            scope: scope,
            request: FileSearchRequest(
              root: _resource(args['root'], 'root'),
              query: _query(args['query']),
              text: _boolean(args, 'text', false),
              recursive: _boolean(args, 'recursive', true),
            ),
            cursor: _optionalText(args, 'cursor'),
            pageSize: _number(
              args,
              'pageSize',
              fallback: 100,
              minimum: 1,
              maximum: _u32Max,
            ),
          ),
        );
      },
      readOnly: true,
    );
    _add(
      'files.close_cursor',
      'Close a directory or search cursor from this run and release its file handles. Use the returned nextCursor. Repeated closes are harmless.',
      {'cursor': _string},
      ['cursor'],
      (args, scope) async {
        _keys(args, {'cursor'});
        final cursor = _text(args, 'cursor');
        await _files.closeCursor(scope: scope, cursor: cursor);
        return {'cursor': cursor, 'closed': true};
      },
      readOnly: true,
    );
    _add(
      'files.read',
      'Read immutable file content. Supply resource to capture a file, or snapshotId to continue the same snapshot. Text returns strict UTF-8 pages; continue with nextOffset. Native sends the complete file as a model content block, subject to the current protocol. Supply name or mediaType only when the captured metadata cannot identify them. The returned sourceVersion is required when modifying that file.',
      {
        'resource': resource,
        'snapshotId': _string,
        'offset': {
          'type': 'integer',
          'minimum': 0,
          'default': 0,
          'description': 'Byte offset for text pages.',
        },
        'length': {
          'type': 'integer',
          'minimum': 1,
          'maximum': _u32Max,
          'default': 32768,
          'description':
              'Requested page length for text. Omit for native content.',
        },
        'format': {
          'type': 'string',
          'enum': ['text', 'native'],
          'default': 'text',
        },
        'name': _string,
        'mediaType': _string,
      },
      [],
      _read,
      readOnly: true,
    );
    for (final create in [true, false]) {
      _add(
        create ? 'files.new' : 'files.write',
        create
            ? 'Create a file. Supply a path target, or destination with a real parent resource, name and mimeType. For document providers, use destination; the provider returns the new URI after creation. Supply exactly one of text (UTF-8) or contentSnapshotId. The preview reports the actual save guarantees.'
            : 'Modify the original resource using the sourceVersion from files.read as expected. Supply exactly one of text (UTF-8) or contentSnapshotId. A changed source is a conflict. The preview states the platform save guarantees and the receipt reports actual effects and recovery resources.',
        {
          'target': resource,
          if (create)
            'destination': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'parent': resource,
                'name': _string,
                'mimeType': _string,
              },
              'required': ['parent', 'name', 'mimeType'],
            },
          if (!create) 'expected': _versionSchema,
          'text': {'type': 'string'},
          'contentSnapshotId': _string,
          // The host strips this marker from the public schema and assigns the
          // operation identity through its existing single-call executor.
          'operationId': _string,
        },
        create ? [] : ['target', 'expected'],
        (args, scope) => _write(args, scope, create: create),
      );
    }
  }

  void _add(
    String name,
    String description,
    Map<String, Object?> properties,
    List<String> required,
    Future<Map<String, Object?>> Function(Map<String, Object?>, OperationScope)
    action, {
    bool readOnly = false,
  }) {
    _host.register(
      ToolDefinition(
        name: name,
        description: description,
        parameters: {
          'type': 'object',
          'additionalProperties': false,
          'properties': properties,
          'required': required,
        },
      ),
      (args, scope, _) => _fileCall(() {
        if (_resourceKinds.isEmpty) {
          throw const OperationProblem(
            OperationErrorCode.unsupported,
            'No file provider is available.',
          );
        }
        return action(args, scope);
      }),
      readOnly: readOnly,
    );
  }

  Future<Map<String, Object?>> _read(
    Map<String, Object?> args,
    OperationScope scope,
  ) async {
    _keys(args, {
      'resource',
      'snapshotId',
      'offset',
      'length',
      'format',
      'name',
      'mediaType',
    });
    if (args.containsKey('resource') == args.containsKey('snapshotId')) {
      _invalid('Supply exactly one of resource or snapshotId.');
    }
    final offset = _number(args, 'offset', fallback: 0, minimum: 0);
    final length = _number(
      args,
      'length',
      fallback: 32768,
      minimum: 1,
      maximum: _u32Max,
    );
    final format = _optionalText(args, 'format') ?? 'text';
    if (format == 'base64') {
      _invalid(
        'format base64 has been replaced by native for complete file content.',
      );
    }
    if (format != 'text' && format != 'native') {
      _invalid('format must be text or native.');
    }
    if (format == 'native' && (offset != 0 || args.containsKey('length'))) {
      _invalid(
        'Native content uses the complete file. Omit offset and length.',
      );
    }
    final snapshot = args.containsKey('resource')
        ? await _files.snapshot(
            scope: scope,
            source: _resource(args['resource'], 'resource'),
          )
        : await _files.snapshotInfo(
            scope: scope,
            snapshotId: _text(args, 'snapshotId'),
          );
    final (name, mediaType) = _contentMetadata(snapshot, args, format: format);
    final byteLength = snapshot.contentVersion.byteLength;
    final digest = snapshot.contentVersion.sha256;
    if (byteLength == null ||
        byteLength < 0 ||
        digest == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const OperationProblem(
        OperationErrorCode.storageFailure,
        'The file snapshot has no verified content length or digest.',
      );
    }
    if (format == 'native') {
      return _contentResult(
        snapshot,
        name: name,
        mediaType: mediaType,
        byteLength: byteLength,
        digest: digest,
        format: format,
        offset: 0,
      );
    }
    // Four bytes are sufficient for at least one complete UTF-8 character.
    final chunk = await _files.readSnapshot(
      scope: scope,
      snapshotId: snapshot.id,
      offset: offset,
      length: length < 4 ? 4 : length,
    );
    if (chunk.snapshotId != snapshot.id ||
        chunk.offset != offset ||
        offset > byteLength ||
        chunk.bytes.length > byteLength - offset ||
        (chunk.nextOffset != null &&
            (chunk.bytes.isEmpty ||
                chunk.nextOffset != offset + chunk.bytes.length))) {
      throw const OperationProblem(
        OperationErrorCode.storageFailure,
        'The file snapshot page has inconsistent identity or offsets.',
      );
    }
    final end = _utf8Boundary(chunk.bytes, hasMore: chunk.nextOffset != null);
    if (end == 0 && chunk.nextOffset != null) {
      throw const OperationProblem(
        OperationErrorCode.storageFailure,
        'The file snapshot page ended before one complete character.',
      );
    }
    try {
      // Validate this exact range; native resolves it from the saved snapshot
      // and preserves all original characters, including a leading U+FEFF.
      utf8.decode(chunk.bytes.sublist(0, end));
      return _contentResult(
        snapshot,
        name: name,
        mediaType: mediaType,
        byteLength: byteLength,
        digest: digest,
        format: format,
        offset: offset,
        textLength: end,
        nextOffset: end < chunk.bytes.length ? offset + end : chunk.nextOffset,
      );
    } on FormatException {
      return {
        'status': 'failed',
        'snapshot': fileSnapshotJson(snapshot),
        'offset': offset,
        'error': {
          'code': 'invalidArgument',
          'message': 'This range is not valid UTF-8. Continue with an exact returned nextOffset, or use format native for the complete file.',
        },
      };
    }
  }

  Future<Map<String, Object?>> _write(
    Map<String, Object?> args,
    OperationScope scope, {
    required bool create,
  }) async {
    _keys(args, {
      'target',
      if (create) 'destination',
      if (!create) 'expected',
      'text',
      'contentSnapshotId',
    });
    if (args.containsKey('text') == args.containsKey('contentSnapshotId')) {
      _invalid('Supply exactly one of text or contentSnapshotId.');
    }
    if (create &&
        args.containsKey('target') == args.containsKey('destination')) {
      _invalid('Supply exactly one of target or destination for a new file.');
    }
    final target = args.containsKey('target')
        ? _resource(args['target'], 'target')
        : null;
    if (create && target?.kind == FileResourceKind.contentUri) {
      _invalid('Create a document with destination parent, name and mimeType.');
    }
    if (!create && target == null) {
      _invalid('target is required for a file write.');
    }
    final destination = args.containsKey('destination')
        ? _destination(args['destination'])
        : null;
    final expected = create ? null : _version(args['expected']);
    final text = args['text'];
    if (args.containsKey('text') && text is! String) {
      _invalid('text must be a string.');
    }
    final snapshot = text is String
        ? await _files.createTextSnapshot(scope: scope, text: text)
        : await _files.snapshotInfo(
            scope: scope,
            snapshotId: _text(args, 'contentSnapshotId'),
          );
    return _files.prepareWrite(
      scope: scope,
      request: FileWriteRequest(
        target: target,
        destination: destination,
        expected: expected,
        contentSnapshotId: snapshot.id,
      ),
      textPreview: text as String?,
    );
  }

  FileChildDestination _destination(Object? value) {
    if (value is! Map<String, Object?>) {
      _invalid('destination must identify a parent, name and MIME type.');
    }
    _keys(value, {'parent', 'name', 'mimeType'});
    final name = value['name'];
    if (name is! String ||
        name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains('\\') ||
        name.contains('\u0000')) {
      _invalid('destination.name must be a single nonempty file name.');
    }
    return FileChildDestination(
      parent: _resource(value['parent'], 'destination.parent'),
      name: name,
      mimeType: _text(value, 'mimeType'),
    );
  }

  FileResourceRef _resource(Object? value, String field) {
    if (value is! Map<String, Object?>) {
      _invalid('$field must identify a native resource.');
    }
    _keys(value, {'kind', 'value'});
    final kind = FileResourceKind.values
        .where((kind) => kind.name == value['kind'])
        .firstOrNull;
    if (kind == null || !_resourceKinds.contains(kind)) {
      throw OperationProblem(
        OperationErrorCode.unsupported,
        'The file provider does not support this resource kind.',
        field: field,
      );
    }
    return FileResourceRef(kind: kind, value: _text(value, 'value'));
  }
}

Future<Map<String, Object?>> _fileCall(
  Future<Map<String, Object?>> Function() action,
) async {
  try {
    return await action();
  } catch (error) {
    final decoded = fileErrorFromException(error);
    if (decoded == null) rethrow;
    return {
      'status': switch (decoded['code']) {
        'cancelled' => 'cancelled',
        'outcomeUnknown' => 'outcome_unknown',
        _ => 'failed',
      },
      'error': decoded,
    };
  }
}

(String, String) _contentMetadata(
  FileSnapshot snapshot,
  Map<String, Object?> args, {
  required String format,
}) {
  final providedName = _optionalText(args, 'name');
  final source = snapshot.source;
  final sourceName =
      snapshot.name ??
      (source != null && source.kind != FileResourceKind.contentUri
          ? source.value.split(RegExp(r'[/\\]')).last
          : null);
  final name = sourceName ?? providedName ?? 'file';
  for (final candidate in [name, ?providedName]) {
    if (candidate.isEmpty ||
        candidate == '.' ||
        candidate == '..' ||
        candidate.contains(RegExp(r'[\x00-\x1f/\\]'))) {
      _invalid(
        'Content requires a file name without path separators or control characters.',
      );
    }
  }
  final captured = snapshot.mediaType == null
      ? null
      : _mediaType(snapshot.mediaType!);
  final guessed = attachmentMediaType(name);
  final known = captured != null && captured != 'application/octet-stream'
      ? captured
      : guessed != 'application/octet-stream'
      ? guessed
      : null;
  final supplied = _optionalText(args, 'mediaType');
  final declared = supplied == null ? null : _mediaType(supplied);
  if (known != null && declared != null && declared != known) {
    _invalid(
      'mediaType conflicts with the captured file metadata or file extension.',
    );
  }
  final mediaType =
      known ?? declared ?? (format == 'text' ? 'text/plain' : null);
  if (mediaType == null || mediaType == 'application/octet-stream') {
    throw const OperationProblem(
      OperationErrorCode.unsupported,
      'Native content requires a known media type. Supply mediaType for this file.',
    );
  }
  return (name, mediaType);
}

String _mediaType(String value) {
  final normalized = value.split(';').first.trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$')
      .hasMatch(normalized)) {
    _invalid('mediaType must be a valid MIME type.');
  }
  return normalized;
}

ApplicationToolResult _contentResult(
  FileSnapshot snapshot, {
  required String name,
  required String mediaType,
  required int byteLength,
  required String digest,
  required String format,
  required int offset,
  int? textLength,
  int? nextOffset,
}) => ApplicationToolResult(
  {
    'snapshot': fileSnapshotJson(snapshot),
    'offset': offset,
    'format': format,
    'nextOffset': nextOffset,
  },
  modelContent: [
    native.HostModelContent(
      kind: native.HostContentKind.snapshot,
      name: name,
      snapshotId: snapshot.id,
      mediaType: mediaType,
      byteLength: byteLength,
      sha256: digest,
      textRange: textLength == null
          ? null
          : ViewToolContentRange(offset: offset, length: textLength),
    ),
  ],
);

FileVersion _version(Object? value) {
  if (value is! Map<String, Object?>) {
    _invalid('expected must be the sourceVersion returned by files.read.');
  }
  _keys(value, {
    'resourceId',
    'version',
    'sha256',
    'byteLength',
    'modifiedAtMs',
  });
  final digest = _text(value, 'sha256');
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
    _invalid('expected.sha256 must identify the actual file content.');
  }
  return FileVersion(
    resourceId: _text(value, 'resourceId'),
    version: _text(value, 'version'),
    sha256: digest,
    byteLength:
        _optionalNumber(value, 'byteLength', minimum: 0) ??
        _invalid(
          'expected.byteLength is required from the file sourceVersion.',
        ),
    modifiedAtMs: _optionalNumber(value, 'modifiedAtMs'),
  );
}

int _utf8Boundary(List<int> bytes, {required bool hasMore}) {
  if (!hasMore || bytes.isEmpty) return bytes.length;
  var start = bytes.length - 1;
  while (start >= 0 && bytes[start] & 0xc0 == 0x80) {
    start--;
  }
  if (start < 0) return bytes.length;
  final lead = bytes[start];
  final width = lead >= 0xc2 && lead <= 0xdf
      ? 2
      : lead >= 0xe0 && lead <= 0xef
      ? 3
      : lead >= 0xf0 && lead <= 0xf4
      ? 4
      : 1;
  return bytes.length - start < width ? start : bytes.length;
}

const _u32Max = 0xffffffff;
const _string = {'type': 'string', 'minLength': 1};
const _pageSize = {
  'type': 'integer',
  'minimum': 1,
  'maximum': _u32Max,
  'default': 100,
};
const _versionSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['resourceId', 'version', 'sha256', 'byteLength'],
  'properties': {
    'resourceId': _string,
    'version': _string,
    'sha256': _string,
    'byteLength': {'type': 'integer', 'minimum': 0},
    'modifiedAtMs': {'type': 'integer'},
  },
};

void _keys(Map<String, Object?> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    _invalid('Unknown file argument.');
  }
}

String _query(Object? value) {
  if (value is! String || value.isEmpty) {
    _invalid('query must be a nonempty string.');
  }
  return value;
}

String _text(Map<String, Object?> value, String key) {
  final text = value[key];
  if (text is! String || text.trim().isEmpty) {
    _invalid('$key must be a nonempty string.');
  }
  return text;
}

String? _optionalText(Map<String, Object?> value, String key) =>
    value.containsKey(key) ? _text(value, key) : null;
bool _boolean(Map<String, Object?> value, String key, bool fallback) {
  if (!value.containsKey(key)) return fallback;
  final flag = value[key];
  if (flag is! bool) _invalid('$key must be a boolean.');
  return flag;
}

int _number(
  Map<String, Object?> value,
  String key, {
  required int fallback,
  required int minimum,
  int? maximum,
}) {
  if (!value.containsKey(key)) return fallback;
  final number = value[key];
  if (number is! int ||
      number < minimum ||
      maximum != null && number > maximum) {
    _invalid('$key is outside the native numeric range.');
  }
  return number;
}

int? _optionalNumber(Map<String, Object?> value, String key, {int? minimum}) {
  if (!value.containsKey(key)) return null;
  final number = value[key];
  if (number is! int || minimum != null && number < minimum) {
    _invalid('$key is outside the native numeric range.');
  }
  return number;
}

Never _invalid(String message) =>
    throw OperationProblem(OperationErrorCode.invalidArgument, message);
