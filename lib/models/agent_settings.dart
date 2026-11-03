import 'package:flutter/foundation.dart' show listEquals;

import '../application/operation_contracts.dart';

enum AgentModelProtocol { chatCompletions, responses }

/// Every enabled model explicitly declares the reasoning parameters it accepts.
enum AgentReasoningEffort { none, minimal, low, medium, high, xhigh, max }

class AgentModelSelection {
  const AgentModelSelection({
    required this.modelId,
    required this.reasoningEffort,
  });

  final String modelId;
  final AgentReasoningEffort reasoningEffort;

  String get wireReasoningEffort => reasoningEffort.name;

  Map<String, Object?> toJson() => {
    'modelId': modelId,
    'reasoningEffort': reasoningEffort.name,
  };

  factory AgentModelSelection.fromJson(Object? value) {
    if (value is! Map ||
        value.length != 2 ||
        value['modelId'] is! String ||
        !_validModelId(value['modelId'] as String)) {
      throw const FormatException('Invalid model selection.');
    }
    final efforts = AgentReasoningEffort.values.where(
      (effort) => effort.name == value['reasoningEffort'],
    );
    if (efforts.isEmpty) {
      throw const FormatException('Invalid reasoning effort.');
    }
    return AgentModelSelection(
      modelId: value['modelId'] as String,
      reasoningEffort: efforts.single,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AgentModelSelection &&
      modelId == other.modelId &&
      reasoningEffort == other.reasoningEffort;

  @override
  int get hashCode => Object.hash(modelId, reasoningEffort);
}

/// User-enabled model choices. Catalog membership is not capability evidence.
class AgentModelConfig {
  const AgentModelConfig({
    required this.id,
    required this.reasoningEfforts,
    required this.defaultReasoningEffort,
  });

  final String id;
  final List<AgentReasoningEffort> reasoningEfforts;
  final AgentReasoningEffort defaultReasoningEffort;

  AgentModelSelection get defaultSelection =>
      AgentModelSelection(modelId: id, reasoningEffort: defaultReasoningEffort);

  void validate() {
    if (!_validModelId(id) ||
        reasoningEfforts.isEmpty ||
        reasoningEfforts.toSet().length != reasoningEfforts.length ||
        !reasoningEfforts.contains(defaultReasoningEffort)) {
      throw const FormatException('Invalid enabled model configuration.');
    }
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'id': id,
      'reasoningEfforts': reasoningEfforts.map((value) => value.name).toList(),
      'defaultReasoningEffort': defaultReasoningEffort.name,
    };
  }

  factory AgentModelConfig.fromJson(Object? value) {
    if (value is! Map ||
        value.length != 3 ||
        value['id'] is! String ||
        value['reasoningEfforts'] is! List) {
      throw const FormatException('Invalid enabled model configuration.');
    }
    AgentReasoningEffort decodeEffort(Object? raw) {
      final matches = AgentReasoningEffort.values.where((e) => e.name == raw);
      if (matches.isEmpty) {
        throw const FormatException('Invalid reasoning effort.');
      }
      return matches.single;
    }

    final result = AgentModelConfig(
      id: value['id'] as String,
      reasoningEfforts: List.unmodifiable(
        (value['reasoningEfforts'] as List).map(decodeEffort),
      ),
      defaultReasoningEffort: decodeEffort(value['defaultReasoningEffort']),
    );
    result.validate();
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is AgentModelConfig &&
      id == other.id &&
      listEquals(reasoningEfforts, other.reasoningEfforts) &&
      defaultReasoningEffort == other.defaultReasoningEffort;

  @override
  int get hashCode =>
      Object.hash(id, Object.hashAll(reasoningEfforts), defaultReasoningEffort);
}

bool _validModelId(String value) =>
    value.isNotEmpty && value == value.trim() && value.length <= 256;

const _keepCredential = Object();

/// Local configuration of the single built-in Agent. Secret values belong to
/// the credential store; only its opaque reference may be persisted here.
class AgentSettings {
  const AgentSettings({
    this.enabled = true,
    this.permissionMode = AgentPermissionMode.ask,
    this.protocol = AgentModelProtocol.chatCompletions,
    this.endpoint = '',
    this.model = '',
    this.models = const [],
    this.credentialRef,
    this.systemInstructions = '',
    this.maxModelRounds = 24,
    this.maxToolCalls = 128,
    this.maxTotalTokens = 100000,
    this.historyRetentionDays = 0,
  });

  final bool enabled;
  final AgentPermissionMode permissionMode;
  final AgentModelProtocol protocol;
  final String endpoint;
  final String model;
  final List<AgentModelConfig> models;

  /// The default ID must refer to an explicitly configured model and effort.
  List<AgentModelConfig> get availableModels => List.unmodifiable(models);

  AgentModelConfig? modelConfig(String id) =>
      availableModels.where((value) => value.id == id).firstOrNull;

  AgentModelSelection? get defaultModelSelection =>
      modelConfig(model)?.defaultSelection;

  bool allowsSelection(AgentModelSelection selection) =>
      modelConfig(selection.modelId)?.reasoningEfforts
          .contains(selection.reasoningEffort) ??
      false;
  final String? credentialRef;
  final String systemInstructions;
  final int maxModelRounds;
  final int maxToolCalls;
  final int maxTotalTokens;

  /// Zero retains conversations until the user deletes them explicitly.
  final int historyRetentionDays;

  AgentSettings copyWith({
    bool? enabled,
    AgentPermissionMode? permissionMode,
    AgentModelProtocol? protocol,
    String? endpoint,
    String? model,
    List<AgentModelConfig>? models,
    Object? credentialRef = _keepCredential,
    String? systemInstructions,
    int? maxModelRounds,
    int? maxToolCalls,
    int? maxTotalTokens,
    int? historyRetentionDays,
  }) {
    if (models != null && models.isEmpty && model != null && model.isNotEmpty) {
      throw const FormatException('A default model must be enabled.');
    }
    final nextModels =
        models ?? (model == '' ? const <AgentModelConfig>[] : this.models);
    final result = AgentSettings(
      enabled: enabled ?? this.enabled,
      permissionMode: permissionMode ?? this.permissionMode,
      protocol: protocol ?? this.protocol,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? (models != null && models.isEmpty ? '' : this.model),
      models: List.unmodifiable(nextModels),
      credentialRef: identical(credentialRef, _keepCredential)
          ? this.credentialRef
          : credentialRef as String?,
      systemInstructions: systemInstructions ?? this.systemInstructions,
      maxModelRounds: maxModelRounds ?? this.maxModelRounds,
      maxToolCalls: maxToolCalls ?? this.maxToolCalls,
      maxTotalTokens: maxTotalTokens ?? this.maxTotalTokens,
      historyRetentionDays: historyRetentionDays ?? this.historyRetentionDays,
    );
    result.validate();
    return result;
  }

  void validate() {
    if (models.length > 256 ||
        models.map((value) => value.id).toSet().length != models.length ||
        (models.isEmpty
            ? model.isNotEmpty
            : !models.any((value) => value.id == model)) ||
        (model.isNotEmpty && !_validModelId(model))) {
      throw const FormatException(
        'Enabled models or default model are invalid.',
      );
    }
    for (final value in models) {
      value.validate();
    }
    if (systemInstructions.length > 16000 ||
        maxModelRounds < 1 ||
        maxModelRounds > 100 ||
        maxToolCalls < 1 ||
        maxToolCalls > 500 ||
        maxTotalTokens < 1024 ||
        maxTotalTokens > 1000000 ||
        historyRetentionDays < 0 ||
        historyRetentionDays > 3650 ||
        (historyRetentionDays > 0 && historyRetentionDays < 7)) {
      throw const FormatException(
        'Agent preferences are outside their supported limits.',
      );
    }
    if (endpoint.length > 4096 ||
        model.length > 256 ||
        (credentialRef?.length ?? 0) > 256) {
      throw const FormatException(
        'Agent connection fields exceed their size limits.',
      );
    }
    if (endpoint.isNotEmpty) {
      final uri = Uri.tryParse(endpoint);
      if (endpoint != endpoint.trim() ||
          uri == null ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        throw const FormatException('Agent endpoint is invalid.');
      }
    }
    if (credentialRef != null && credentialRef!.trim().isEmpty) {
      throw const FormatException('Agent credential reference is invalid.');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'enabled': enabled,
      'permissionMode': permissionMode.name,
      'protocol': protocol.name,
      'endpoint': endpoint,
      'model': model,
      'models': availableModels.map((value) => value.toJson()).toList(),
      'credentialRef': credentialRef,
      'systemInstructions': systemInstructions,
      'maxModelRounds': maxModelRounds,
      'maxToolCalls': maxToolCalls,
      'maxTotalTokens': maxTotalTokens,
      'historyRetentionDays': historyRetentionDays,
    };
  }

  factory AgentSettings.fromJson(Object? value) {
    const preferenceKeys = {
      'systemInstructions',
      'maxModelRounds',
      'maxToolCalls',
      'maxTotalTokens',
      'historyRetentionDays',
      'models',
    };
    const keys = {
      'enabled',
      'permissionMode',
      'protocol',
      'endpoint',
      'model',
      'credentialRef',
    };
    if (value is! Map ||
        !keys.every(value.containsKey) ||
        value.keys.any(
          (key) =>
              key is! String ||
              (!keys.contains(key) && !preferenceKeys.contains(key)),
        ) ||
        value['enabled'] is! bool ||
        value['endpoint'] is! String ||
        value['model'] is! String ||
        (value['credentialRef'] != null && value['credentialRef'] is! String)) {
      throw const FormatException('Agent settings are invalid.');
    }
    if ((value.containsKey('systemInstructions') &&
            value['systemInstructions'] is! String) ||
        preferenceKeys
            .where((key) => key != 'systemInstructions' && key != 'models')
            .any((key) => value.containsKey(key) && value[key] is! int)) {
      throw const FormatException('Agent preference types are invalid.');
    }
    if (value.containsKey('models') && value['models'] is! List) {
      throw const FormatException('Enabled model list is invalid.');
    }
    if (value['models'] is List &&
        (value['models'] as List).isEmpty &&
        value['model'] != '') {
      throw const FormatException('A default model must be enabled.');
    }
    final permissions = AgentPermissionMode.values.where(
      (entry) => entry.name == value['permissionMode'],
    );
    final protocols = AgentModelProtocol.values.where(
      (entry) => entry.name == value['protocol'],
    );
    if (permissions.isEmpty || protocols.isEmpty) {
      throw const FormatException(
        'Agent settings protocol or mode is invalid.',
      );
    }
    final result = AgentSettings(
      enabled: value['enabled'] as bool,
      permissionMode: permissions.single,
      protocol: protocols.single,
      endpoint: value['endpoint'] as String,
      model: value['model'] as String,
      models: List.unmodifiable(
        ((value['models'] as List?) ?? const []).map(AgentModelConfig.fromJson),
      ),
      credentialRef: value['credentialRef'] as String?,
      systemInstructions: value['systemInstructions'] as String? ?? '',
      maxModelRounds: value['maxModelRounds'] as int? ?? 24,
      maxToolCalls: value['maxToolCalls'] as int? ?? 128,
      maxTotalTokens: value['maxTotalTokens'] as int? ?? 100000,
      historyRetentionDays: value['historyRetentionDays'] as int? ?? 0,
    );
    result.validate();
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is AgentSettings &&
      enabled == other.enabled &&
      permissionMode == other.permissionMode &&
      protocol == other.protocol &&
      endpoint == other.endpoint &&
      model == other.model &&
      listEquals(availableModels, other.availableModels) &&
      credentialRef == other.credentialRef &&
      systemInstructions == other.systemInstructions &&
      maxModelRounds == other.maxModelRounds &&
      maxToolCalls == other.maxToolCalls &&
      maxTotalTokens == other.maxTotalTokens &&
      historyRetentionDays == other.historyRetentionDays;

  @override
  int get hashCode => Object.hash(
    enabled,
    permissionMode,
    protocol,
    endpoint,
    model,
    Object.hashAll(availableModels),
    credentialRef,
    systemInstructions,
    maxModelRounds,
    maxToolCalls,
    maxTotalTokens,
    historyRetentionDays,
  );
}
