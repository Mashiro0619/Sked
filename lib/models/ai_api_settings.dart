import '../utils/constants.dart';
import '../utils/time_utils.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

String? _nullableStringValue(Object? value) {
  return value is String ? value : null;
}

class AiApiSettings {
  const AiApiSettings({
    this.source = defaultSchoolImportParserSource,
    this.customBaseUrl = '',
    this.customApiKey = '',
    this.customModel = '',
    this.customPrompt = '',
  });

  final String source;
  final String customBaseUrl;
  final String customApiKey;
  final String customModel;
  final String customPrompt;

  Map<String, dynamic> toJson() => {
    'source': normalizeSchoolImportParserSource(source),
    'customBaseUrl': customBaseUrl.trim(),
    'customModel': customModel.trim(),
    'customPrompt': customPrompt.trim(),
  };

  factory AiApiSettings.fromJson(Map<String, dynamic> json) {
    return AiApiSettings(
      source: normalizeSchoolImportParserSource(
        _nullableStringValue(json['source']),
      ),
      customBaseUrl: _stringValue(json['customBaseUrl']).trim(),
      customApiKey: _stringValue(json['customApiKey']).trim(),
      customModel: _stringValue(json['customModel']).trim(),
      customPrompt: _stringValue(json['customPrompt']).trim(),
    );
  }

  AiApiSettings copyWith({
    String? source,
    String? customBaseUrl,
    String? customApiKey,
    String? customModel,
    String? customPrompt,
  }) {
    return AiApiSettings(
      source: normalizeSchoolImportParserSource(source ?? this.source),
      customBaseUrl: (customBaseUrl ?? this.customBaseUrl).trim(),
      customApiKey: (customApiKey ?? this.customApiKey).trim(),
      customModel: (customModel ?? this.customModel).trim(),
      customPrompt: (customPrompt ?? this.customPrompt).trim(),
    );
  }
}

@Deprecated('Use AiApiSettings. The API configuration is app-wide.')
typedef SchoolImportParserSettings = AiApiSettings;
