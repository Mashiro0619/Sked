import '../utils/constants.dart';
import '../utils/time_utils.dart';
import 'app_data_json_values.dart';

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
        appDataNullableStringValue(json['source']),
      ),
      customBaseUrl: appDataStringValue(json['customBaseUrl']).trim(),
      customApiKey: appDataStringValue(json['customApiKey']).trim(),
      customModel: appDataStringValue(json['customModel']).trim(),
      customPrompt: appDataStringValue(json['customPrompt']).trim(),
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
