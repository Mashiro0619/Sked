import '../../models/agent_settings.dart';

/// One metadata source for model-edit arguments and their writable fields.
/// Service-reported context belongs to the existing host configuration.
abstract final class AgentModelToolConfiguration {
  static Map<String, Object?> get properties => {
    'id': {'type': 'string', 'minLength': 1},
    'reasoningEfforts': {
      'type': 'array',
      'minItems': 1,
      'uniqueItems': true,
      'items': {
        'type': 'string',
        'enum': AgentReasoningEffort.values.map((value) => value.name).toList(),
      },
    },
    'defaultReasoningEffort': {
      'type': 'string',
      'enum': AgentReasoningEffort.values.map((value) => value.name).toList(),
    },
    'maxContextTokens': {
      'type': ['integer', 'null'],
      'minimum': 1,
    },
    'autoCompactAtTokens': {
      'type': ['integer', 'null'],
      'minimum': 1,
    },
    'autoCompact': {'type': 'boolean'},
  };

  static Map<String, Object?> get schema => {
    'type': 'object',
    'properties': properties,
    'required': ['id', 'reasoningEfforts', 'defaultReasoningEffort'],
    'additionalProperties': false,
  };

  static AgentModelConfig decode(Object? value, {AgentModelConfig? previous}) {
    if (value is! Map ||
        value.keys.any((key) => !properties.containsKey(key)) ||
        (schema['required'] as List).any((key) => !value.containsKey(key))) {
      throw const FormatException(
        'A model edit contains an unknown or host-owned field.',
      );
    }
    return AgentModelConfig.fromJson({...?previous?.toJson(), ...value});
  }

  static Map<String, Object?> arguments(AgentModelConfig model) => {
    for (final entry in model.toJson().entries)
      if (properties.containsKey(entry.key)) entry.key: entry.value,
  };
}
