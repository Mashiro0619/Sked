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
  });

  final bool enabled;
  final AgentPermissionMode permissionMode;
  final AgentModelProtocol protocol;
  final String endpoint;
  final String model;
  final String? credentialRef;

  AgentSettings copyWith({
    bool? enabled,
    AgentPermissionMode? permissionMode,
    AgentModelProtocol? protocol,
    String? endpoint,
    String? model,
    Object? credentialRef = _keepCredential,
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
    );
    result.validate();
    return result;
  }

  void validate() {
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
    };
  }

  factory AgentSettings.fromJson(Object? value) {
    const keys = {
      'enabled',
      'permissionMode',
      'protocol',
      'endpoint',
      'model',
      'credentialRef',
    };
    if (value is! Map ||
        value.length != keys.length ||
        value.keys.any((key) => key is! String || !keys.contains(key)) ||
        value['enabled'] is! bool ||
        value['endpoint'] is! String ||
        value['model'] is! String ||
        (value['credentialRef'] != null && value['credentialRef'] is! String)) {
      throw const FormatException('Agent settings are invalid.');
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
      credentialRef == other.credentialRef;

  @override
  int get hashCode => Object.hash(
    enabled,
    permissionMode,
    protocol,
    endpoint,
    model,
    credentialRef,
  );
}
