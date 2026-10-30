import '../../models/agent_settings.dart';

/// Resolves the shared base-URL or full-endpoint setting for both ordinary runs
/// and connection diagnostics. No credential or network access occurs here.
Uri resolveConfiguredAgentEndpoint(AgentSettings settings) {
  final uri = Uri.tryParse(settings.endpoint);
  if (uri == null ||
      !uri.isAbsolute ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !{'http', 'https'}.contains(uri.scheme)) {
    throw const FormatException('The model endpoint is not configured.');
  }
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  if (path.endsWith('/chat/completions') || path.endsWith('/responses')) {
    return uri.replace(path: path);
  }
  final suffix = settings.protocol == AgentModelProtocol.responses
      ? '/responses'
      : '/chat/completions';
  return uri.replace(path: '${path.isEmpty ? '/v1' : path}$suffix');
}
