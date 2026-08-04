class SchoolImportHttpConsentStore {
  SchoolImportHttpConsentStore();

  static final SchoolImportHttpConsentStore session =
      SchoolImportHttpConsentStore();

  final Set<String> _approvedEndpoints = <String>{};

  bool requiresConfirmation(String baseUrl) {
    final endpoint = normalizeSchoolImportHttpEndpoint(baseUrl);
    return endpoint != null && !_approvedEndpoints.contains(endpoint);
  }

  void approve(String baseUrl) {
    final endpoint = normalizeSchoolImportHttpEndpoint(baseUrl);
    if (endpoint != null) {
      _approvedEndpoints.add(endpoint);
    }
  }

  String displayEndpoint(String baseUrl) {
    return normalizeSchoolImportHttpEndpoint(baseUrl) ?? baseUrl.trim();
  }
}

String? normalizeSchoolImportHttpEndpoint(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'http' ||
      uri.host.trim().isEmpty) {
    return null;
  }

  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.isEmpty) {
    path = '/';
  }

  final includePort = uri.hasPort && uri.port != 80;
  return Uri(
    scheme: 'http',
    host: uri.host.toLowerCase(),
    port: includePort ? uri.port : null,
    path: path,
  ).toString();
}
