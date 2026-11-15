import 'dart:convert';

import '../../application/operation_contracts.dart';
import '../bridge/generated/api/contracts.dart' show HostModelContent;
import '../bridge/generated/api/execution_contracts.dart';
import '../bridge/generated/api/file_contracts.dart';
import '../execution/agent_execution_coordinator.dart';
import '../execution/execution_evidence.dart';
import '../provider/provider_models.dart';
import 'application_tool_host.dart';
import 'application_tool_result.dart';
import 'file_tool_adapters.dart';
import 'task_input_source.dart';

class OfficeToolAdapters {
  OfficeToolAdapters({
    required this._host,
    required this._execution,
    required this._files,
  });

  final ApplicationToolHost _host;
  final AgentExecutionCoordinator _execution;
  final FileToolAdapters _files;
  bool _registered = false;
  bool _available = false;

  void registerAvailable(ExecutionAvailability availability) {
    _available =
        availability.available &&
        availability.controlledReaders.any(
          (reader) => reader.readerId == 'office.inspect',
        );
    if (_registered || !_available) return;
    _registered = true;
    _host.register(
      ToolDefinition(
        name: 'office.read',
        description:
            'Read a DOCX, XLSX, or PPTX with the fixed bundled reader, including in plan mode. '
            'Use a sent attachment ID or saved contentId; capture device files with files.read format native first. '
            'Returns structured document content, formulas and existing cached values, and extracted images. '
            'Full output is durable content: continue with content.read using contentId and nextOffset. '
            'Use python.execute and the Office Skills for creating or editing documents.',
        parameters: {
          'type': 'object',
          'additionalProperties': false,
          'required': ['source', 'format'],
          'properties': {
            'source': taskInputSourceSchema,
            'format': {
              'type': 'string',
              'enum': ['docx', 'xlsx', 'pptx'],
            },
          },
        },
      ),
      (args, scope, _) => _read(args, scope),
      readOnly: true,
    );
  }

  Future<Map<String, Object?>> _read(
    Map<String, Object?> args,
    OperationScope scope,
  ) async {
    if (!_available) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'No Office reader is available.',
      );
    }
    for (final key in args.keys) {
      if (key != 'source' && key != 'format') {
        _invalid(key, 'Unknown parameter.');
      }
    }
    final format = switch (args['format']) {
      'docx' => OfficeDocumentFormat.docx,
      'xlsx' => OfficeDocumentFormat.xlsx,
      'pptx' => OfficeDocumentFormat.pptx,
      _ => _invalid('format', 'Use docx, xlsx, or pptx.'),
    };
    final source = parseTaskInputSource(args['source'], 'source');
    final receipt = await _execution.readOfficeTask(
      scope: scope,
      conversationId: _host.conversationForScope(scope)!.id,
      request: OfficeReadTaskRequest(source: source, format: format),
    );
    final content = <HostModelContent>[];
    final pages = <Map<String, Object?>>[];
    final images = <Map<String, Object?>>[];
    final failures = <Map<String, Object?>>[];
    for (final output in receipt.outputs) {
      try {
        final read = await _files.readTextContent(
          scope: scope,
          source: output.file,
          expectedSha256: output.resource.digest,
          expectedByteLength: output.resource.byteLength,
        );
        if (read is ApplicationToolResult) {
          content.addAll(read.modelContent);
          pages.add({'stream': output.stream.name, ...read});
        } else {
          failures.add({'stream': output.stream.name, ...read});
        }
      } catch (error) {
        failures.add({'stream': output.stream.name, 'message': '$error'});
      }
    }
    final detail =
        jsonDecode(receipt.effects.detail.json) as Map<String, Object?>? ??
        const <String, Object?>{};
    for (final item in detail['files'] as List? ?? const []) {
      final file = item as Map<String, Object?>;
      final mediaType = file['mediaType'] as String?;
      if (!const {
        'image/png',
        'image/jpeg',
        'image/gif',
        'image/webp',
      }.contains(mediaType)) {
        continue;
      }
      final resource = file['file'] as Map<String, Object?>;
      final version = file['version'] as Map<String, Object?>;
      try {
        final read = await _files.readNativeContent(
          scope: scope,
          source: FileResourceRef(
            kind: FileResourceKind.values.byName(resource['kind'] as String),
            value: resource['value'] as String,
          ),
          name: file['name'] as String,
          mediaType: mediaType!,
          expectedSha256: version['digest'] as String,
          expectedByteLength: version['byteLength'] as int,
        );
        if (read is ApplicationToolResult) {
          content.addAll(read.modelContent);
          images.add({'name': file['name'], ...read});
        } else {
          failures.add({'name': file['name'], ...read});
        }
      } catch (error) {
        failures.add({'name': file['name'], 'message': '$error'});
      }
    }
    final status = switch (receipt.terminal) {
      ExecutionTerminal.cancelled => 'cancelled',
      ExecutionTerminal.lost || null => 'outcome_unknown',
      ExecutionTerminal.notStarted
          when receipt.error?.code == ExecutionErrorCode.cancelledBeforeStart =>
        'cancelled',
      ExecutionTerminal.exited
          when receipt.exitCode == 0 &&
              receipt.error == null &&
              !receipt.outputs.any((output) => output.truncated) &&
              (detail['errors'] as List? ?? const []).isEmpty &&
              failures.isEmpty =>
        'read',
      _ => 'failed',
    };
    return ApplicationToolResult({
      'status': status,
      'format': format.name,
      'source': {'kind': source.kind.name, 'id': source.id},
      'execution': executionReceiptJson(receipt),
      'pages': pages,
      'images': images,
      if (failures.isNotEmpty)
        'contentDelivery': {'status': 'failed', 'outputs': failures},
    }, modelContent: content);
  }
}

Never _invalid(String field, String message) => throw OperationProblem(
  OperationErrorCode.invalidArgument,
  message,
  field: field,
);
