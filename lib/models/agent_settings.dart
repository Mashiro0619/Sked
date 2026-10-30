import '../application/operation_contracts.dart';

enum AgentModelProtocol { chatCompletions, responses }

const _keepCredential = Object();

/// Local configuration of the single built-in Agent. Secret values belong to
/// the credential store; only its opaque reference may be persisted here.
class AgentSettings {
  const AgentSettings({
    this.enabled = false,
    this.permissionMode = AgentPermissionMode.ask,
    this.protocol = AgentModelProtocol.chatCompletions,
    this.endpoint = '',
    this.model = '',
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
    Object? credentialRef = _keepCredential,
    String? systemInstructions,
    int? maxModelRounds,
    int? maxToolCalls,
    int? maxTotalTokens,
    int? historyRetentionDays,
  }) {
    final result = AgentSettings(
      enabled: enabled ?? this.enabled,
      permissionMode: permissionMode ?? this.permissionMode,
      protocol: protocol ?? this.protocol,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
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
            .where((key) => key != 'systemInstructions')
            .any((key) => value.containsKey(key) && value[key] is! int)) {
      throw const FormatException('Agent preference types are invalid.');
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
    credentialRef,
    systemInstructions,
    maxModelRounds,
    maxToolCalls,
    maxTotalTokens,
    historyRetentionDays,
  );
}
