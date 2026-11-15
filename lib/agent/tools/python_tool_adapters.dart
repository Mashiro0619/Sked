import '../../application/operation_contracts.dart';
import '../bridge/generated/api/contracts.dart' show HostModelContent;
import '../bridge/generated/api/execution_contracts.dart';
import '../bridge/generated/api/file_contracts.dart';
import '../execution/agent_execution_coordinator.dart';
import '../operations/approval_requester.dart';
import '../provider/provider_models.dart';
import 'application_tool_host.dart';
import 'application_tool_result.dart';
import 'file_tool_adapters.dart';
import 'task_input_source.dart';

class PythonToolAdapters {
  PythonToolAdapters({
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
    _available = availability.available && availability.python;
    if (_registered || !_available) return;
    _registered = true;
    _host.registerWithCall(
      ToolDefinition(
        name: 'python.execute',
        description:
            'Run Python with the bundled interpreter. The host previews the exact code and inputs in plan mode, asks once in confirmation mode, and executes in full mode. '
            'cwd is an existing directory. inputs names map to complete saved files through from sked_runtime import inputs. Each source uses kind content with a contentId, or kind attachment with an ID from a sent message. '
            'Use from sked_runtime import output_dir, publish to create and register result files; publish(path, name=None, media_type=None) records their actual location. '
            'stdout and stderr are saved as durable content; use content.read for further text. A nonzero exit or cancellation does not undo file changes.',
        parameters: {
          'type': 'object',
          'additionalProperties': false,
          'required': ['code', 'cwd'],
          'properties': {
            'code': {'type': 'string'},
            'cwd': {
              'type': 'object',
              'additionalProperties': false,
              'required': ['kind', 'value'],
              'properties': {
                'kind': {
                  'type': 'string',
                  'enum': ['windowsPath', 'androidPath'],
                },
                'value': {
                  'type': 'string',
                  'description': 'Absolute directory path on this device.',
                },
              },
            },
            'argv': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'inputs': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'required': ['name', 'source'],
                'properties': {
                  'name': {
                    'type': 'string',
                    'description': 'Input key used as inputs[name] in Python.',
                  },
                  'source': taskInputSourceSchema,
                },
              },
            },
            'environment': {
              'type': 'object',
              'additionalProperties': {'type': 'string'},
              'description': 'Plain environment variables included in the execution preview.',
            },
          },
        },
      ),
      _execute,
    );
  }

  Future<Map<String, Object?>> _execute(
    ProviderToolCall call,
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester requestApproval,
  ) async {
    if (!_available) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'No Python execution provider is available.',
      );
    }
    final request = _request(args);
    final conversation = _host.conversationForScope(scope)!;
    final completed = await _execution.executePythonTask(
      call: call,
      scope: scope,
      conversationId: conversation.id,
      request: request,
      requestApproval: requestApproval,
      onPrepared: _host.onOperationPrepared,
      onUpdate: (update) => _host.onOperationUpdate?.call(scope, update),
    );
    final content = <HostModelContent>[];
    final failures = <Map<String, Object?>>[];
    for (final output
        in completed.receipt?.outputs ?? <ExecutionOutputReference>[]) {
      try {
        final read = await _files.readTextContent(
          scope: scope,
          source: output.file,
          expectedSha256: output.resource.digest,
          expectedByteLength: output.resource.byteLength,
        );
        if (read is ApplicationToolResult) {
          content.addAll(read.modelContent);
        } else {
          failures.add({'stream': output.stream.name, ...read});
        }
      } catch (error) {
        failures.add({
          'stream': output.stream.name,
          'message': error.toString(),
        });
      }
    }
    return ApplicationToolResult({
      ...completed.result,
      if (failures.isNotEmpty)
        'contentDelivery': {'status': 'failed', 'outputs': failures},
    }, modelContent: content);
  }
}

PythonTaskRequest _request(Map<String, Object?> args) {
  _keys(args, {'code', 'cwd', 'argv', 'inputs', 'environment'});
  final cwd = _object(args['cwd'], 'cwd');
  _keys(cwd, {'kind', 'value'}, field: 'cwd');
  final cwdKind = switch (cwd['kind']) {
    'windowsPath' => FileResourceKind.windowsPath,
    'androidPath' => FileResourceKind.androidPath,
    _ => _invalid(
      'cwd.kind',
      'Use windowsPath or androidPath for the working directory.',
    ),
  };
  final argv = args.containsKey('argv')
      ? _list(args['argv'], 'argv')
      : const <Object?>[];
  final inputs = args.containsKey('inputs')
      ? _list(args['inputs'], 'inputs')
      : const <Object?>[];
  final environment = args.containsKey('environment')
      ? _object(args['environment'], 'environment')
      : const <String, Object?>{};
  return PythonTaskRequest(
    code: _string(args['code'], 'code'),
    cwd: FileResourceRef(
      kind: cwdKind,
      value: _string(cwd['value'], 'cwd.value'),
    ),
    argv: [
      for (var index = 0; index < argv.length; index++)
        _string(argv[index], 'argv[$index]'),
    ],
    inputs: [
      for (var index = 0; index < inputs.length; index++)
        _input(inputs[index], 'inputs[$index]'),
    ],
    environment: [
      for (final entry in environment.entries)
        PythonTaskEnvironment(
          name: entry.key,
          value: _string(entry.value, 'environment.${entry.key}'),
        ),
    ],
  );
}

PythonTaskInput _input(Object? value, String field) {
  final input = _object(value, field);
  _keys(input, {'name', 'source'}, field: field);
  return PythonTaskInput(
    name: _string(input['name'], '$field.name'),
    source: parseTaskInputSource(input['source'], '$field.source'),
  );
}

Map<String, Object?> _object(Object? value, String field) =>
    value is Map<String, Object?>
    ? value
    : _invalid(field, 'Provide an object.');

List<Object?> _list(Object? value, String field) =>
    value is List<Object?> ? value : _invalid(field, 'Provide an array.');

String _string(Object? value, String field) =>
    value is String ? value : _invalid(field, 'Provide a string.');

void _keys(Map<String, Object?> value, Set<String> allowed, {String? field}) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      _invalid(field == null ? key : '$field.$key', 'Unknown parameter.');
    }
  }
}

Never _invalid(String field, String message) => throw OperationProblem(
  OperationErrorCode.invalidArgument,
  message,
  field: field,
);
