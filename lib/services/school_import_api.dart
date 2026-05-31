import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/school_import_models.dart';
import '../models/timetable_models.dart';

sealed class SchoolImportStreamEvent {
  const SchoolImportStreamEvent();
}

class ParseDelta extends SchoolImportStreamEvent {
  const ParseDelta(this.text);
  final String text;
}

class ParseDone extends SchoolImportStreamEvent {
  const ParseDone({required this.response});
  final SchoolImportResponse response;
}

class ParseError extends SchoolImportStreamEvent {
  const ParseError(this.message);
  final String message;
}

class SchoolImportApiResult {
  const SchoolImportApiResult({
    required this.response,
    required this.rawBody,
    required this.statusCode,
  });

  final SchoolImportResponse response;
  final String rawBody;
  final int statusCode;
}

Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is String) {
      result[key] = entry.value;
    }
  }
  return result;
}

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

List<dynamic> _listValue(Object? value) {
  return value is List ? value : const <dynamic>[];
}

bool _hasTimetablePayload(Map<String, dynamic> json) {
  return json.containsKey('name') ||
      json.containsKey('startDate') ||
      json.containsKey('totalWeeks') ||
      json.containsKey('periodTimeSet') ||
      json.containsKey('courses');
}

class SchoolImportApi {
  const SchoolImportApi({
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 30),
    Duration streamIdleTimeout = const Duration(minutes: 2),
  }) : _client = client,
       _requestTimeout = requestTimeout,
       _streamIdleTimeout = streamIdleTimeout;

  static const _defaultCustomOpenAiSystemPrompt =
      '''You are an expert timetable extraction engine.

Your job is to read the provided page content and convert it into exactly one JSON object.
The content may be HTML, plain text, copied table text, JSON fragments, or mixed page source.
Return JSON only. Do not wrap it in markdown. Do not add explanations.

The timetable JSON schema must be exactly:
{
  "name": "string",
  "startDate": "YYYY-MM-DD",
  "totalWeeks": 18,
  "periodTimeSet": {
    "name": "string",
    "periodTimes": [
      {"index": 1, "startMinutes": 480, "endMinutes": 525}
    ]
  },
  "courses": [
    {
      "name": "string",
      "teacher": "string",
      "location": "string",
      "dayOfWeek": 1,
      "semesterWeeks": [1, 2, 3],
      "periods": [1, 2],
      "startMinutes": 480,
      "endMinutes": 570,
      "credit": 0,
      "remarks": "string",
      "customFields": {}
    }
  ]
}

Rules:
1. Extract the actual timetable from the provided content. Ignore navigation, scripts, styles, ads, and unrelated text.
2. The source content is not guaranteed to be valid HTML. You must still try to recognize timetable information from any text or mixed markup.
3. Output one valid JSON object only.
4. Use empty strings instead of null.
5. Use [] instead of null for arrays.
6. Use {} instead of null for customFields.
7. dayOfWeek uses Monday=1 through Sunday=7.
8. semesterWeeks and periods must contain positive integers only, sorted ascending, without duplicates.
9. startMinutes and endMinutes must be integers representing minutes after 00:00 when the source explicitly provides real class times; otherwise use 0.
10. Never invent period times, startMinutes, endMinutes, or a periodTimeSet when the source does not explicitly provide them.
11. If the content contains period numbers but not explicit times, keep periods only and leave time-related fields as 0; keep periodTimeSet.periodTimes as an empty array.
12. If the content contains explicit class times, preserve them exactly.
13. Only fill periodTimeSet.periodTimes when the source explicitly provides actual period time ranges.
14. If a field is unknown, keep it empty or 0, but still keep the field.
15. If the timetable title is visible, put it in name.
16. If the total week count is not visible, use 18.
17. If the start date is not visible, use the best reasonable YYYY-MM-DD value from the context; if unavailable, use today's date.
18. Only include real courses that appear in the provided content.

Return the final JSON using exactly this outer schema:
{"ok":true,"meta":{"sourceUrl":"string","pageTitle":"string","parser":"string","warnings":["string"]},"timetable":{"name":"string","startDate":"YYYY-MM-DD","totalWeeks":18,"periodTimeSet":{"name":"string","periodTimes":[{"index":1,"startMinutes":480,"endMinutes":525}]},"courses":[{"name":"string","teacher":"string","location":"string","dayOfWeek":1,"semesterWeeks":[1,2],"periods":[1,2],"startMinutes":480,"endMinutes":570,"credit":0,"remarks":"string","customFields":{}}]}}.
Populate timetable with the extracted timetable object. Keep ok=true. Fill meta.sourceUrl from the provided url when possible, meta.pageTitle from the provided title when possible, meta.parser with a non-empty parser label, and meta.warnings as an array. If some meta fields are unknown, still return valid JSON with safe defaults instead of prose.''';

  static String get defaultCustomOpenAiSystemPrompt =>
      _defaultCustomOpenAiSystemPrompt;

  static const int _maxStreamErrorBodyBytes = 32 * 1024;

  final http.Client? _client;
  final Duration _requestTimeout;
  final Duration _streamIdleTimeout;

  Future<SchoolImportResponse> importCurrentPage(
    SchoolImportPagePayload payload, {
    SchoolImportParserSettings? parserSettings,
  }) async {
    final result = await importCurrentPageWithRawResponse(
      payload,
      parserSettings: parserSettings,
    );
    return result.response;
  }

  Future<SchoolImportApiResult> importCurrentPageWithRawResponse(
    SchoolImportPagePayload payload, {
    SchoolImportParserSettings? parserSettings,
  }) async {
    final settings = parserSettings ?? const SchoolImportParserSettings();
    return _importWithCustomOpenAi(payload, settings);
  }

  Future<List<String>> fetchCustomModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedApiKey = apiKey.trim();
    if (normalizedBaseUrl.isEmpty || normalizedApiKey.isEmpty) {
      throw const FormatException(
        'Custom parser base URL or API key is missing.',
      );
    }

    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final uri = _buildOpenAiModelsUri(normalizedBaseUrl);
      final response = await client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $normalizedApiKey',
            },
          )
          .timeout(_requestTimeout);
      final rawBody = _decodeBody(response);
      final decoded = _tryDecodeJson(rawBody);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _extractErrorMessage(decoded);
        throw FormatException(
          message ??
              'Model list request failed (${response.statusCode}).\n\n$rawBody',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'Model list response format is invalid.\n\n$rawBody',
        );
      }
      final data = decoded['data'];
      if (data is! List) {
        throw FormatException(
          'Model list response format is invalid.\n\n$rawBody',
        );
      }
      final models =
          data
              .map((item) {
                if (item is Map) {
                  final id = item['id'];
                  return id is String ? id.trim() : '';
                }
                return '';
              })
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      return models;
    } on TimeoutException {
      throw const FormatException('Model list request timed out.');
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Unable to fetch the model list.\n\n$error');
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  Future<SchoolImportApiResult> _importWithCustomOpenAi(
    SchoolImportPagePayload payload,
    SchoolImportParserSettings settings,
  ) async {
    final normalizedBaseUrl = settings.customBaseUrl.trim();
    final normalizedApiKey = settings.customApiKey.trim();
    final normalizedModel = settings.customModel.trim();
    if (normalizedBaseUrl.isEmpty ||
        normalizedApiKey.isEmpty ||
        normalizedModel.isEmpty) {
      throw const FormatException('Custom parser configuration is incomplete.');
    }

    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final uri = _buildOpenAiChatUri(normalizedBaseUrl);
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $normalizedApiKey',
            },
            body: jsonEncode({
              'model': normalizedModel,
              'temperature': 0,
              'messages': [
                {
                  'role': 'system',
                  'content': _buildCustomOpenAiSystemPrompt(settings),
                },
                {'role': 'user', 'content': _buildOpenAiUserPrompt(payload)},
              ],
              'response_format': const {'type': 'json_object'},
            }),
          )
          .timeout(_requestTimeout);
      final rawBody = _decodeBody(response);
      final decoded = _tryDecodeJson(rawBody);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _extractErrorMessage(decoded);
        throw FormatException(
          message ??
              'Import request failed (${response.statusCode}).\n\n$rawBody',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Import response format is invalid.\n\n$rawBody');
      }
      final content = _extractOpenAiMessageContent(decoded);
      final parsedJson = _tryDecodeJsonFromModelContent(content);
      if (parsedJson is! Map<String, dynamic>) {
        throw FormatException('Import response parse failed.\n\n$rawBody');
      }
      try {
        final normalizedResponseJson = _normalizeCustomImportResponse(
          parsedJson,
          payload: payload,
          model: normalizedModel,
        );
        return SchoolImportApiResult(
          response: SchoolImportResponse.fromJson(normalizedResponseJson),
          rawBody: rawBody,
          statusCode: response.statusCode,
        );
      } on FormatException catch (error) {
        throw FormatException(
          'Import response parse failed.\n\n${error.message}',
        );
      }
    } on TimeoutException {
      throw const FormatException('Import request timed out.');
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException(
        'Unable to connect to the import service.\n\n$error',
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  String _buildCustomOpenAiSystemPrompt(SchoolImportParserSettings settings) {
    final customPrompt = settings.customPrompt.trim();
    if (customPrompt.isEmpty) {
      return defaultCustomOpenAiSystemPrompt;
    }
    return customPrompt;
  }

  String _buildOpenAiUserPrompt(SchoolImportPagePayload payload) {
    return jsonEncode({
      'task':
          'Extract timetable data from the provided source content. The content may be HTML or any other raw page content as long as it contains timetable information.',
      'locale': payload.locale,
      'sourceHint': payload.sourceHint,
      'url': payload.url,
      'title': payload.title,
      'html': payload.html,
    });
  }

  Map<String, dynamic> _normalizeCustomImportResponse(
    Map<String, dynamic> json, {
    required SchoolImportPagePayload payload,
    required String model,
  }) {
    final responseJson = json.containsKey('timetable')
        ? _normalizeCustomWrappedImportResponse(json)
        : _hasTimetablePayload(json)
        ? <String, dynamic>{
            'ok': true,
            'message': json['message'],
            'meta': _asStringKeyedMap(json['meta']) ?? const {},
            'timetable': Map<String, dynamic>.from(json),
          }
        : throw FormatException(
            _extractErrorMessage(json) ?? 'Import response format is invalid.',
          );
    if (responseJson['ok'] is! bool) {
      throw const FormatException('Import response format is invalid.');
    }
    final meta = _asStringKeyedMap(responseJson['meta']) ?? {};
    final sourceUrl = _stringValue(meta['sourceUrl']).trim();
    final pageTitle = _stringValue(meta['pageTitle']).trim();
    final parser = _stringValue(meta['parser'], 'custom-openai:$model').trim();
    meta['sourceUrl'] = sourceUrl.isEmpty ? payload.url.trim() : sourceUrl;
    meta['pageTitle'] = pageTitle.isEmpty ? payload.title.trim() : pageTitle;
    meta['parser'] = parser.isEmpty ? 'custom-openai:$model' : parser;
    meta['warnings'] = _listValue(meta['warnings']);
    responseJson['meta'] = meta;
    return responseJson;
  }

  Map<String, dynamic> _normalizeCustomWrappedImportResponse(
    Map<String, dynamic> json,
  ) {
    final responseJson = Map<String, dynamic>.from(json);
    if (!responseJson.containsKey('ok')) {
      final rawTimetable = _asStringKeyedMap(responseJson['timetable']);
      if (rawTimetable != null && _hasTimetablePayload(rawTimetable)) {
        responseJson['ok'] = true;
      }
    }
    return responseJson;
  }

  String _extractOpenAiMessageContent(Map<String, dynamic> json) {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('Import response format is invalid.');
    }
    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      throw const FormatException('Import response format is invalid.');
    }
    final message = firstChoice['message'];
    if (message is! Map) {
      throw const FormatException('Import response format is invalid.');
    }
    final content = message['content'];
    final result = _extractOpenAiTextContent(content).trim();
    if (result.isNotEmpty) {
      return result;
    }
    throw const FormatException('Import response format is invalid.');
  }

  String _extractOpenAiTextContent(Object? content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map) {
          final text = item['text'];
          if (text is String && text.trim().isNotEmpty) {
            buffer.write(text);
          }
        }
      }
      return buffer.toString();
    }
    return '';
  }

  String _extractOpenAiStreamTextContent(Map<String, dynamic> json) {
    final choices = json['choices'];
    final firstChoice = choices is List && choices.isNotEmpty
        ? choices.first
        : null;
    if (firstChoice is! Map) {
      return '';
    }
    final deltaJson = firstChoice['delta'];
    final delta = deltaJson is Map
        ? _extractOpenAiTextContent(deltaJson['content'])
        : '';
    if (delta.isNotEmpty) {
      return delta;
    }
    final messageJson = firstChoice['message'];
    final message = messageJson is Map
        ? _extractOpenAiTextContent(messageJson['content'])
        : '';
    if (message.isNotEmpty) {
      return message;
    }
    return _extractOpenAiTextContent(firstChoice['text']);
  }

  bool _hasOpenAiFinishReason(Map<String, dynamic> json) {
    final choices = json['choices'];
    final firstChoice = choices is List && choices.isNotEmpty
        ? choices.first
        : null;
    return firstChoice is Map && firstChoice['finish_reason'] != null;
  }

  String? _extractSseData(String line) {
    final trimmed = line.trimLeft();
    if (!trimmed.startsWith('data:')) {
      return null;
    }
    return trimmed.substring(5).trim();
  }

  Uri _buildOpenAiChatUri(String baseUrl) {
    final baseUri = Uri.parse(baseUrl.trim());
    final path = baseUri.path.trim().toLowerCase().endsWith('/chat/completions')
        ? baseUri.path
        : _joinPath(baseUri.path, 'chat/completions');
    return baseUri.replace(path: path, query: '');
  }

  Uri _buildOpenAiModelsUri(String baseUrl) {
    final baseUri = Uri.parse(baseUrl.trim());
    final path = baseUri.path.trim().toLowerCase().endsWith('/models')
        ? baseUri.path
        : _joinPath(baseUri.path, 'models');
    return baseUri.replace(path: path, query: '');
  }

  Map<String, dynamic>? _tryDecodeJson(String source) {
    try {
      return _asStringKeyedMap(jsonDecode(source));
    } catch (_) {
      return null;
    }
  }

  String _decodeBody(http.Response response) {
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  Map<String, dynamic>? _tryDecodeJsonFromModelContent(String source) {
    final exact = _tryDecodeJson(source);
    if (exact != null) {
      return exact;
    }

    final trimmed = source.trim();
    final fenceMatch = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (fenceMatch != null) {
      final fenced = _tryDecodeJson(fenceMatch.group(1) ?? '');
      if (fenced != null) {
        return fenced;
      }
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return _tryDecodeJson(trimmed.substring(start, end + 1));
    }
    return null;
  }

  String? _extractErrorMessage(Map<String, dynamic>? json) {
    final topLevelMessage = json?['message']?.toString().trim();
    if (topLevelMessage != null && topLevelMessage.isNotEmpty) {
      return topLevelMessage;
    }
    final error = json?['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }
    if (error is Map) {
      final nestedMessage = error['message']?.toString().trim();
      if (nestedMessage != null && nestedMessage.isNotEmpty) {
        return nestedMessage;
      }
    }
    return null;
  }

  String _timeoutMessage(TimeoutException error, {required String fallback}) {
    final message = error.message;
    if (message == null || message == 'Future not completed') {
      return fallback;
    }
    return message;
  }

  Future<String> _readStreamErrorBody(Stream<List<int>> stream) async {
    final bytes = <int>[];
    var truncated = false;
    final limitedStream = stream.timeout(
      _streamIdleTimeout,
      onTimeout: (sink) {
        sink.addError(
          TimeoutException(
            'Import error response timed out.',
            _streamIdleTimeout,
          ),
        );
      },
    );
    await for (final chunk in limitedStream) {
      final remaining = _maxStreamErrorBodyBytes - bytes.length;
      if (remaining <= 0) {
        truncated = true;
        break;
      }
      if (chunk.length > remaining) {
        bytes.addAll(chunk.take(remaining));
        truncated = true;
        break;
      }
      bytes.addAll(chunk);
      if (bytes.length >= _maxStreamErrorBodyBytes) {
        truncated = true;
        break;
      }
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    return truncated ? '$body\n\n[response body truncated]' : body;
  }

  Stream<SchoolImportStreamEvent> importCurrentPageStream(
    SchoolImportPagePayload payload, {
    SchoolImportParserSettings? parserSettings,
    http.Client? client,
  }) async* {
    final settings = parserSettings ?? const SchoolImportParserSettings();
    yield* _importStreamWithCustomOpenAi(payload, settings, client: client);
  }

  Stream<SchoolImportStreamEvent> _importStreamWithCustomOpenAi(
    SchoolImportPagePayload payload,
    SchoolImportParserSettings settings, {
    http.Client? client,
  }) async* {
    final normalizedBaseUrl = settings.customBaseUrl.trim();
    final normalizedApiKey = settings.customApiKey.trim();
    final normalizedModel = settings.customModel.trim();
    if (normalizedBaseUrl.isEmpty ||
        normalizedApiKey.isEmpty ||
        normalizedModel.isEmpty) {
      yield const ParseError('Custom parser configuration is incomplete.');
      return;
    }

    final effectiveClient = client ?? _client ?? http.Client();
    final ownsClient = client == null && _client == null;
    try {
      final uri = _buildOpenAiChatUri(normalizedBaseUrl);
      final body = jsonEncode({
        'model': normalizedModel,
        'temperature': 0,
        'stream': true,
        'messages': [
          {
            'role': 'system',
            'content': _buildCustomOpenAiSystemPrompt(settings),
          },
          {'role': 'user', 'content': _buildOpenAiUserPrompt(payload)},
        ],
        'response_format': const {'type': 'json_object'},
      });

      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer $normalizedApiKey',
        })
        ..body = body;

      final response = await effectiveClient
          .send(request)
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final rawBody = await _readStreamErrorBody(response.stream);
        yield ParseError(
          'Import request failed (${response.statusCode}).\n\n$rawBody',
        );
        return;
      }

      final stream = response.stream
          .timeout(
            _streamIdleTimeout,
            onTimeout: (sink) {
              sink.addError(
                TimeoutException(
                  'Import stream timed out.',
                  _streamIdleTimeout,
                ),
              );
            },
          )
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String accumulatedContent = '';
      bool doneReceived = false;
      await for (final line in stream) {
        final jsonStr = _extractSseData(line);
        if (jsonStr == null || jsonStr.isEmpty) continue;
        if (jsonStr == '[DONE]') {
          doneReceived = true;
          continue;
        }
        try {
          final json = _tryDecodeJson(jsonStr);
          if (json == null) continue;
          final delta = _extractOpenAiStreamTextContent(json);
          if (delta.isNotEmpty) {
            accumulatedContent += delta;
            yield ParseDelta(delta);
          }
          if (_hasOpenAiFinishReason(json)) {
            doneReceived = true;
          }
        } catch (_) {}
      }

      if (!doneReceived) {
        yield const ParseError('Connection closed unexpectedly.');
        return;
      }

      if (accumulatedContent.isEmpty) {
        yield const ParseError('AI returned empty content.');
        return;
      }

      final parsedJson = _tryDecodeJsonFromModelContent(accumulatedContent);
      if (parsedJson is! Map<String, dynamic>) {
        yield ParseError(
          'Import response parse failed.\n\n$accumulatedContent',
        );
        return;
      }

      try {
        final normalizedResponseJson = _normalizeCustomImportResponse(
          parsedJson,
          payload: payload,
          model: normalizedModel,
        );
        yield ParseDone(
          response: SchoolImportResponse.fromJson(normalizedResponseJson),
        );
      } catch (e) {
        yield ParseError(
          'Import response parse failed.\n\n$accumulatedContent\n\n$e',
        );
      }
    } on TimeoutException catch (e) {
      yield ParseError(
        _timeoutMessage(e, fallback: 'Import request timed out.'),
      );
    } catch (e) {
      yield ParseError('Unable to connect to the import service.\n\n$e');
    } finally {
      if (ownsClient) {
        effectiveClient.close();
      }
    }
  }

  static SchoolImportResponse buildResponseFromDoneEvent(
    Map<String, dynamic> json,
  ) {
    if (json['ok'] == false) {
      return SchoolImportResponse.fromJson({
        'ok': false,
        'message': json['message'],
        'meta': _asStringKeyedMap(json['meta']) ?? const {},
        'timetable': const {},
      });
    }

    final rawTimetable = json.containsKey('timetable')
        ? _asStringKeyedMap(json['timetable'])
        : json;
    if (rawTimetable == null) {
      throw const FormatException('Import response format is invalid.');
    }
    if (!_hasTimetablePayload(rawTimetable)) {
      throw const FormatException('Import response format is invalid.');
    }
    final wrapped = <String, dynamic>{
      'ok': json['ok'] ?? true,
      'message': json['message'],
      'meta': _asStringKeyedMap(json['meta']) ?? const {},
      'timetable': {
        'name': rawTimetable['name'] ?? '',
        'startDate': rawTimetable['startDate'] ?? '',
        'totalWeeks': rawTimetable['totalWeeks'] ?? 18,
        'periodTimeSet': rawTimetable['periodTimeSet'] ?? const {},
        'courses': rawTimetable['courses'] ?? const [],
      },
    };
    return SchoolImportResponse.fromJson(wrapped);
  }

  String _joinPath(String basePath, String child) {
    final trimmedBase = basePath.trim();
    if (trimmedBase.isEmpty || trimmedBase == '/') {
      return '/$child';
    }
    final normalizedBase = trimmedBase.endsWith('/')
        ? trimmedBase.substring(0, trimmedBase.length - 1)
        : trimmedBase;
    return '$normalizedBase/$child';
  }
}
