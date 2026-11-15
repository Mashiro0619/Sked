import '../../application/operation_contracts.dart';
import '../bridge/generated/api/execution_contracts.dart';

const taskInputSourceSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['kind', 'id'],
  'properties': {
    'kind': {
      'type': 'string',
      'enum': ['content', 'attachment'],
    },
    'id': {
      'type': 'string',
      'description': 'A saved contentId from a tool result, or an attachment ID from a sent conversation message. The complete saved file is used.',
    },
  },
};

TaskInputSource parseTaskInputSource(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    _invalid(field, 'Provide an object with kind and id.');
  }
  for (final key in value.keys) {
    if (key != 'kind' && key != 'id') {
      _invalid('$field.$key', 'Unknown parameter.');
    }
  }
  final kind = switch (value['kind']) {
    'content' => TaskInputSourceKind.content,
    'attachment' => TaskInputSourceKind.attachment,
    _ => _invalid('$field.kind', 'Use content or attachment.'),
  };
  final id = value['id'];
  if (id is! String || id.isEmpty) {
    _invalid('$field.id', 'Provide the saved content or attachment ID.');
  }
  return TaskInputSource(kind: kind, id: id);
}

Never _invalid(String field, String message) => throw OperationProblem(
  OperationErrorCode.invalidArgument,
  message,
  field: field,
);
