import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/school_import_api.dart';

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.onSend);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return onSend(request);
  }
}

class _DelayedResponseClient extends http.BaseClient {
  _DelayedResponseClient(this.delay);

  final Duration delay;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(delay);
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }
}

class _AbortObservingClient extends http.BaseClient {
  final aborted = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final abortTrigger = (request as http.Abortable).abortTrigger;
    if (abortTrigger == null) {
      throw StateError('Expected an abortable request.');
    }
    final response = Completer<http.StreamedResponse>();
    unawaited(
      abortTrigger.then((_) {
        if (!aborted.isCompleted) {
          aborted.complete();
        }
        if (!response.isCompleted) {
          response.completeError(http.RequestAbortedException(request.url));
        }
      }),
    );
    return response.future;
  }
}

Map<String, dynamic> _minimalCourseJson([String name = 'Imported Course']) {
  return {
    'name': name,
    'dayOfWeek': 1,
    'semesterWeeks': [1],
    'periods': [1],
    'startMinutes': 480,
    'endMinutes': 525,
  };
}

const _customParserSettings = SchoolImportParserSettings(
  source: schoolImportParserSourceCustomOpenAi,
  customBaseUrl: 'https://api.example.com/v1',
  customApiKey: 'sk-test',
  customModel: 'gpt-4.1-mini',
);

void main() {
  group('SchoolImportApi.buildResponseFromDoneEvent', () {
    Map<String, dynamic> timetableJson() {
      return {
        'name': 'Spring Timetable',
        'startDate': '2026-02-23',
        'totalWeeks': 20,
        'periodTimeSet': {
          'name': 'Imported periods',
          'periodTimes': [
            {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
            {'index': 2, 'startMinutes': 535, 'endMinutes': 580},
          ],
        },
        'courses': [
          {
            'name': 'Algebra',
            'teacher': 'Lin',
            'location': 'A101',
            'dayOfWeek': 1,
            'semesterWeeks': [1, 2, 3],
            'periods': [1, 2],
            'startMinutes': 480,
            'endMinutes': 580,
            'credit': 2,
            'remarks': 'Lab',
            'customFields': {'campus': 'North'},
          },
        ],
      };
    }

    test('preserves timetable fields from a streaming done event', () {
      final response = SchoolImportApi.buildResponseFromDoneEvent({
        'done': true,
        'ok': true,
        'meta': {
          'sourceUrl': 'https://example.test/timetable',
          'pageTitle': 'Timetable',
          'parser': 'custom-openai:gpt-4.1-mini',
          'warnings': ['trimmed navigation'],
        },
        'timetable': timetableJson(),
      });

      expect(response.meta.sourceUrl, 'https://example.test/timetable');
      expect(response.meta.parser, 'custom-openai:gpt-4.1-mini');
      expect(response.meta.warnings, ['trimmed navigation']);
      expect(response.timetable.name, 'Spring Timetable');
      expect(response.timetable.startDate, DateTime(2026, 2, 23));
      expect(response.timetable.totalWeeks, 20);
      expect(response.timetable.periodTimeSet.name, 'Imported periods');
      expect(response.timetable.periodTimeSet.periodTimes, hasLength(2));
      expect(response.timetable.periodTimeSet.periodTimes.first.index, 1);
      expect(response.timetable.courses.single.name, 'Algebra');
      expect(response.timetable.courses.single.teacher, 'Lin');
      expect(response.timetable.courses.single.periods, [1, 2]);
      expect(response.timetable.courses.single.customFields['campus'], 'North');
    });

    test('accepts a bare timetable object from manual stream editing', () {
      final response = SchoolImportApi.buildResponseFromDoneEvent(
        timetableJson(),
      );

      expect(response.timetable.name, 'Spring Timetable');
      expect(response.timetable.startDate, DateTime(2026, 2, 23));
      expect(response.timetable.periodTimeSet.periodTimes, hasLength(2));
      expect(response.timetable.courses.single.location, 'A101');
    });

    test('does not invent missing class or period times', () {
      final response = SchoolImportApi.buildResponseFromDoneEvent({
        'done': true,
        'ok': true,
        'timetable': {
          'name': 'Untimed Timetable',
          'startDate': '2026-02-23',
          'periodTimeSet': {
            'name': 'Untimed periods',
            'periodTimes': [
              {'index': 1},
            ],
          },
          'courses': [
            {
              'name': 'Seminar',
              'dayOfWeek': 2,
              'semesterWeeks': [1],
              'periods': [1],
            },
          ],
        },
      });

      expect(response.timetable.periodTimeSet.periodTimes, isEmpty);
      expect(response.timetable.courses.single.startMinutes, 0);
      expect(response.timetable.courses.single.endMinutes, 0);
    });

    test('preserves error messages from failed done events', () {
      expect(
        () => SchoolImportApi.buildResponseFromDoneEvent({
          'done': true,
          'ok': false,
          'message': 'No timetable found.',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'No timetable found.',
          ),
        ),
      );
    });

    test('rejects wrapped done events with malformed timetable objects', () {
      expect(
        () => SchoolImportApi.buildResponseFromDoneEvent({
          'done': true,
          'ok': true,
          'timetable': [
            {'name': 'Not a timetable object'},
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response format is invalid.',
          ),
        ),
      );
    });

    test('rejects done events without any timetable payload', () {
      expect(
        () => SchoolImportApi.buildResponseFromDoneEvent({
          'done': true,
          'ok': true,
          'meta': {'parser': 'custom-openai:gpt-4.1-mini'},
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response format is invalid.',
          ),
        ),
      );
    });

    test('rejects explicit empty-course timetable payloads', () {
      expect(
        () => SchoolImportApi.buildResponseFromDoneEvent({
          'done': true,
          'ok': true,
          'timetable': {
            'name': 'Empty Course Timetable',
            'startDate': '2026-02-23',
            'courses': [],
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response format is invalid.',
          ),
        ),
      );
    });
  });

  group('SchoolImportApi custom OpenAI streaming', () {
    test('model list supports HTTP base URLs', () async {
      final api = SchoolImportApi(
        client: _StreamingClient((request) async {
          expect(request.url.scheme, 'http');
          expect(request.url.path, '/v1/models');
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              utf8.encode(
                jsonEncode({
                  'data': [
                    {'id': 'local-model'},
                  ],
                }),
              ),
            ]),
            200,
          );
        }),
      );

      final models = await api.fetchCustomModels(
        baseUrl: 'http://api.example.com/v1',
        apiKey: 'sk-test',
      );

      expect(models, ['local-model']);
    });

    test('custom import supports HTTP base URLs', () async {
      final responseJson = {
        'ok': true,
        'meta': {
          'sourceUrl': '',
          'pageTitle': '',
          'parser': '',
          'warnings': [],
        },
        'timetable': {
          'name': 'HTTP Timetable',
          'startDate': '2026-02-23',
          'totalWeeks': 18,
          'periodTimeSet': {'name': '', 'periodTimes': []},
          'courses': [_minimalCourseJson('HTTP Course')],
        },
      };
      final api = SchoolImportApi(
        client: _StreamingClient((request) async {
          expect(request.url.scheme, 'http');
          expect(request.url.path, '/v1/chat/completions');
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              utf8.encode(
                jsonEncode({
                  'choices': [
                    {
                      'message': {'content': jsonEncode(responseJson)},
                      'finish_reason': 'stop',
                    },
                  ],
                }),
              ),
            ]),
            200,
          );
        }),
      );

      final result = await api.importCurrentPageWithRawResponse(
        const SchoolImportPagePayload(
          url: 'https://example.test/page',
          title: 'Example page',
          html: '<table>demo</table>',
          locale: 'zh',
          sourceHint: schoolImportParserSourceCustomOpenAi,
        ),
        parserSettings: const SchoolImportParserSettings(
          source: schoolImportParserSourceCustomOpenAi,
          customBaseUrl: 'http://api.example.com/v1',
          customApiKey: 'sk-test',
          customModel: 'gpt-4.1-mini',
        ),
      );

      expect(result.response.timetable.name, 'HTTP Timetable');
      expect(result.response.timetable.courses.single.name, 'HTTP Course');
    });

    test(
      'custom stream rejects non-web base URLs without sending requests',
      () async {
        var requestSent = false;
        final client = _StreamingClient((request) async {
          requestSent = true;
          return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
        });

        final events = await const SchoolImportApi()
            .importCurrentPageStream(
              const SchoolImportPagePayload(
                url: 'https://example.test/page',
                title: 'Example page',
                html: '<table>demo</table>',
                locale: 'zh',
                sourceHint: schoolImportParserSourceCustomOpenAi,
              ),
              parserSettings: const SchoolImportParserSettings(
                source: schoolImportParserSourceCustomOpenAi,
                customBaseUrl: 'ftp://api.example.com/v1',
                customApiKey: 'sk-test',
                customModel: 'gpt-4.1-mini',
              ),
              client: client,
            )
            .toList();

        expect(requestSent, isFalse);
        expect(events, hasLength(1));
        expect(events.single, isA<ParseError>());
        expect(
          (events.single as ParseError).message,
          customOpenAiBaseUrlInvalidMessage,
        );
      },
    );

    test('model list request reports a timeout clearly', () async {
      final api = SchoolImportApi(
        requestTimeout: const Duration(milliseconds: 1),
        client: _DelayedResponseClient(const Duration(milliseconds: 50)),
      );

      expect(
        () => api.fetchCustomModels(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'sk-test',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Model list request timed out.',
          ),
        ),
      );
    });

    test('model list ignores entries without string ids', () async {
      final api = SchoolImportApi(
        client: _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              utf8.encode(
                jsonEncode({
                  'data': [
                    {'id': 'z-model'},
                    {'id': 42},
                    {'id': ' a-model '},
                    {'id': null},
                    {
                      'id': {'name': 'nested'},
                    },
                    'malformed',
                    {'id': 'z-model'},
                  ],
                }),
              ),
            ]),
            200,
          );
        }),
      );

      final models = await api.fetchCustomModels(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-test',
      );

      expect(models, ['a-model', 'z-model']);
    });

    test('custom import ignores non-string message content parts', () async {
      final responseJson = {
        'ok': true,
        'meta': {
          'sourceUrl': '',
          'pageTitle': '',
          'parser': '',
          'warnings': [],
        },
        'timetable': {
          'name': 'Segmented Timetable',
          'startDate': '2026-02-23',
          'totalWeeks': 18,
          'periodTimeSet': {'name': '', 'periodTimes': []},
          'courses': [_minimalCourseJson('Segmented Course')],
        },
      };
      final encodedResponse = jsonEncode(responseJson);
      final splitAt = encodedResponse.indexOf('Segmented');
      final firstPart = encodedResponse.substring(0, splitAt);
      final secondPart = encodedResponse.substring(splitAt);
      final api = SchoolImportApi(
        client: _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              utf8.encode(
                jsonEncode({
                  'choices': [
                    {
                      'message': {
                        'content': [
                          {'type': 'output_text', 'text': firstPart},
                          {'type': 'output_text', 'text': 42},
                          {'type': 'output_text', 'text': secondPart},
                          {
                            'type': 'output_text',
                            'text': {'nested': 'bad'},
                          },
                        ],
                      },
                      'finish_reason': 'stop',
                    },
                  ],
                }),
              ),
            ]),
            200,
          );
        }),
      );

      final result = await api.importCurrentPageWithRawResponse(
        const SchoolImportPagePayload(
          url: 'https://example.test/page',
          title: 'Example page',
          html: '<table>demo</table>',
          locale: 'zh',
          sourceHint: schoolImportParserSourceCustomOpenAi,
        ),
        parserSettings: const SchoolImportParserSettings(
          source: schoolImportParserSourceCustomOpenAi,
          customBaseUrl: 'https://api.example.com/v1',
          customApiKey: 'sk-test',
          customModel: 'gpt-4.1-mini',
        ),
      );

      expect(result.response.meta.sourceUrl, 'https://example.test/page');
      expect(result.response.meta.parser, 'custom-openai:gpt-4.1-mini');
      expect(result.response.timetable.name, 'Segmented Timetable');
    });

    test('custom import rejects error-shaped model responses', () async {
      final api = SchoolImportApi(
        client: _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              utf8.encode(
                jsonEncode({
                  'choices': [
                    {
                      'message': {
                        'content': jsonEncode({'error': 'No timetable'}),
                      },
                      'finish_reason': 'stop',
                    },
                  ],
                }),
              ),
            ]),
            200,
          );
        }),
      );

      await expectLater(
        api.importCurrentPageWithRawResponse(
          const SchoolImportPagePayload(
            url: 'https://example.test/page',
            title: 'Example page',
            html: '<table>demo</table>',
            locale: 'zh',
            sourceHint: schoolImportParserSourceCustomOpenAi,
          ),
          parserSettings: const SchoolImportParserSettings(
            source: schoolImportParserSourceCustomOpenAi,
            customBaseUrl: 'https://api.example.com/v1',
            customApiKey: 'sk-test',
            customModel: 'gpt-4.1-mini',
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response parse failed.\n\nNo timetable',
          ),
        ),
      );
    });

    test('custom stream reports connection timeout clearly', () async {
      final api = const SchoolImportApi(
        requestTimeout: Duration(milliseconds: 1),
      );
      final client = _DelayedResponseClient(const Duration(milliseconds: 50));

      final events = await api
          .importCurrentPageStream(
            const SchoolImportPagePayload(
              url: 'https://example.test/page',
              title: 'Example page',
              html: '<table>demo</table>',
              locale: 'zh',
              sourceHint: schoolImportParserSourceCustomOpenAi,
            ),
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      expect(events, hasLength(1));
      expect(events.single, isA<ParseError>());
      expect(
        (events.single as ParseError).message,
        'Import request timed out.',
      );
    });

    test('custom stream reports idle stream timeout clearly', () async {
      final api = const SchoolImportApi(
        streamIdleTimeout: Duration(milliseconds: 1),
      );
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.periodic(
            const Duration(milliseconds: 50),
            (_) => utf8.encode(''),
          ),
          200,
        );
      });

      final events = await api
          .importCurrentPageStream(
            const SchoolImportPagePayload(
              url: 'https://example.test/page',
              title: 'Example page',
              html: '<table>demo</table>',
              locale: 'zh',
              sourceHint: schoolImportParserSourceCustomOpenAi,
            ),
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      expect(events, hasLength(1));
      expect(events.single, isA<ParseError>());
      expect((events.single as ParseError).message, 'Import stream timed out.');
    });

    test(
      'custom stream times out while reading non-2xx error bodies',
      () async {
        final api = const SchoolImportApi(
          streamIdleTimeout: Duration(milliseconds: 1),
        );
        final client = _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.periodic(
              const Duration(milliseconds: 50),
              (_) => utf8.encode('still failing'),
            ),
            500,
          );
        });

        final events = await api
            .importCurrentPageStream(
              const SchoolImportPagePayload(
                url: 'https://example.test/page',
                title: 'Example page',
                html: '<table>demo</table>',
                locale: 'zh',
                sourceHint: schoolImportParserSourceCustomOpenAi,
              ),
              parserSettings: _customParserSettings,
              client: client,
            )
            .toList();

        expect(events, hasLength(1));
        expect(events.single, isA<ParseError>());
        expect(
          (events.single as ParseError).message,
          'Import error response timed out.',
        );
      },
    );

    test('custom stream truncates oversized non-2xx error bodies', () async {
      final oversizedBody = 'x' * (40 * 1024);
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode(oversizedBody)]),
          500,
        );
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            const SchoolImportPagePayload(
              url: 'https://example.test/page',
              title: 'Example page',
              html: '<table>demo</table>',
              locale: 'zh',
              sourceHint: schoolImportParserSourceCustomOpenAi,
            ),
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      final message = (events.single as ParseError).message;
      expect(message, startsWith('Import request failed (500).'));
      expect(message, contains('[response body truncated]'));
      expect(message.length, lessThan(34 * 1024));
    });

    test('custom stream ignores non-string delta values', () async {
      final sseBody =
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 42},
              },
            ],
          })}\n\n'
          'data: [DONE]\n\n';
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode(sseBody)]),
          200,
        );
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            const SchoolImportPagePayload(
              url: 'https://example.test/page',
              title: 'Example page',
              html: '<table>demo</table>',
              locale: 'zh',
              sourceHint: schoolImportParserSourceCustomOpenAi,
            ),
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      expect(events.whereType<ParseDelta>(), isEmpty);
      expect(
        events.whereType<ParseError>().single.message,
        'AI returned empty content.',
      );
    });

    test('requests JSON mode and parses fenced streamed JSON', () async {
      late Map<String, dynamic> capturedBody;
      late Map<String, String> capturedHeaders;

      final responseJson = {
        'ok': true,
        'meta': {
          'sourceUrl': '',
          'pageTitle': '',
          'parser': '',
          'warnings': [],
        },
        'timetable': {
          'name': 'Streamed Timetable',
          'startDate': '2026-02-23',
          'totalWeeks': 18,
          'periodTimeSet': {'name': '', 'periodTimes': []},
          'courses': [
            {
              'name': 'Streamed Course',
              'teacher': '',
              'location': '',
              'dayOfWeek': 1,
              'semesterWeeks': [1],
              'periods': [1],
              'startMinutes': 0,
              'endMinutes': 0,
              'credit': 0,
              'remarks': '',
              'customFields': {},
            },
          ],
        },
      };
      final streamedContent = '```json\n${jsonEncode(responseJson)}\n```';
      final sseBody =
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': streamedContent},
              },
            ],
          })}\n\n'
          'data: [DONE]\n\n';

      final client = _StreamingClient((request) async {
        capturedHeaders = request.headers;
        capturedBody =
            jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode(sseBody)]),
          200,
        );
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            const SchoolImportPagePayload(
              url: 'https://example.test/page',
              title: 'Example page',
              html: '<table>demo</table>',
              locale: 'zh',
              sourceHint: schoolImportParserSourceCustomOpenAi,
            ),
            parserSettings: const SchoolImportParserSettings(
              source: schoolImportParserSourceCustomOpenAi,
              customBaseUrl: 'https://api.example.com/v1',
              customApiKey: 'sk-test',
              customModel: 'gpt-4.1-mini',
            ),
            client: client,
          )
          .toList();

      expect(capturedHeaders['authorization'], 'Bearer sk-test');
      expect(capturedBody['stream'], isTrue);
      expect(capturedBody['response_format']['type'], 'json_object');
      expect(events.whereType<ParseError>(), isEmpty);
      expect(
        events.whereType<ParseDelta>().map((event) => event.text).join(),
        streamedContent,
      );
      final done = events.whereType<ParseDone>().single;
      expect(done.response.meta.sourceUrl, 'https://example.test/page');
      expect(done.response.meta.parser, 'custom-openai:gpt-4.1-mini');
      expect(done.response.timetable.name, 'Streamed Timetable');
      expect(done.response.timetable.courses.single.name, 'Streamed Course');
    });

    test('custom stream rejects EOF before done marker', () async {
      final responseJson = {
        'ok': true,
        'timetable': {
          'name': 'Truncated Timetable',
          'startDate': '2026-02-23',
          'courses': [],
        },
      };
      final sseBody =
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': jsonEncode(responseJson)},
              },
            ],
          })}\n\n';
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode(sseBody)]),
          200,
        );
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            const SchoolImportPagePayload(
              url: 'https://example.test/page',
              title: 'Example page',
              html: '<table>demo</table>',
              locale: 'zh',
              sourceHint: schoolImportParserSourceCustomOpenAi,
            ),
            parserSettings: const SchoolImportParserSettings(
              source: schoolImportParserSourceCustomOpenAi,
              customBaseUrl: 'https://api.example.com/v1',
              customApiKey: 'sk-test',
              customModel: 'gpt-4.1-mini',
            ),
            client: client,
          )
          .toList();

      expect(events.whereType<ParseDone>(), isEmpty);
      final error = events.whereType<ParseError>().single;
      expect(error.message, 'Connection closed unexpectedly.');
    });

    test('custom stream parses array content delta parts', () async {
      final responseJson = {
        'ok': true,
        'meta': {
          'sourceUrl': '',
          'pageTitle': '',
          'parser': '',
          'warnings': [],
        },
        'timetable': {
          'name': 'Segmented Stream Timetable',
          'startDate': '2026-02-23',
          'totalWeeks': 18,
          'periodTimeSet': {'name': '', 'periodTimes': []},
          'courses': [_minimalCourseJson('Segmented Stream Course')],
        },
      };
      final encodedResponse = jsonEncode(responseJson);
      final splitAt = encodedResponse.indexOf('Segmented');
      final firstPart = encodedResponse.substring(0, splitAt);
      final secondPart = encodedResponse.substring(splitAt);
      final sseBody =
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {
                  'content': [
                    {'type': 'output_text', 'text': firstPart},
                    {'type': 'output_text', 'text': 42},
                    {'type': 'output_text', 'text': secondPart},
                    {
                      'type': 'output_text',
                      'text': {'nested': 'bad'},
                    },
                  ],
                },
              },
            ],
          })}\n\n'
          'data: [DONE]\n\n';

      final client = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode(sseBody)]),
          200,
        );
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            const SchoolImportPagePayload(
              url: 'https://example.test/page',
              title: 'Example page',
              html: '<table>demo</table>',
              locale: 'zh',
              sourceHint: schoolImportParserSourceCustomOpenAi,
            ),
            parserSettings: const SchoolImportParserSettings(
              source: schoolImportParserSourceCustomOpenAi,
              customBaseUrl: 'https://api.example.com/v1',
              customApiKey: 'sk-test',
              customModel: 'gpt-4.1-mini',
            ),
            client: client,
          )
          .toList();

      expect(events.whereType<ParseError>(), isEmpty);
      expect(
        events.whereType<ParseDelta>().map((event) => event.text).join(),
        encodedResponse,
      );
      final done = events.whereType<ParseDone>().single;
      expect(done.response.meta.sourceUrl, 'https://example.test/page');
      expect(done.response.meta.parser, 'custom-openai:gpt-4.1-mini');
      expect(done.response.timetable.name, 'Segmented Stream Timetable');
    });

    test(
      'custom stream accepts data lines without a space after colon',
      () async {
        final responseJson = {
          'ok': true,
          'meta': {
            'sourceUrl': '',
            'pageTitle': '',
            'parser': '',
            'warnings': [],
          },
          'timetable': {
            'name': 'No Space SSE Timetable',
            'startDate': '2026-02-23',
            'totalWeeks': 18,
            'periodTimeSet': {'name': '', 'periodTimes': []},
            'courses': [_minimalCourseJson('No Space SSE Course')],
          },
        };
        final encodedResponse = jsonEncode(responseJson);
        final sseBody =
            'data:${jsonEncode({
              'choices': [
                {
                  'delta': {'content': encodedResponse},
                },
              ],
            })}\n\n'
            'data:[DONE]\n\n';

        final client = _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable([utf8.encode(sseBody)]),
            200,
          );
        });

        final events = await const SchoolImportApi()
            .importCurrentPageStream(
              const SchoolImportPagePayload(
                url: 'https://example.test/page',
                title: 'Example page',
                html: '<table>demo</table>',
                locale: 'zh',
                sourceHint: schoolImportParserSourceCustomOpenAi,
              ),
              parserSettings: _customParserSettings,
              client: client,
            )
            .toList();

        expect(events.whereType<ParseError>(), isEmpty);
        expect(
          events.whereType<ParseDelta>().map((event) => event.text).join(),
          encodedResponse,
        );
        expect(
          events.whereType<ParseDone>().single.response.timetable.name,
          'No Space SSE Timetable',
        );
      },
    );

    test(
      'custom stream accepts message content chunks with finish reason',
      () async {
        final responseJson = {
          'ok': true,
          'meta': {
            'sourceUrl': '',
            'pageTitle': '',
            'parser': '',
            'warnings': [],
          },
          'timetable': {
            'name': 'Message Chunk Timetable',
            'startDate': '2026-02-23',
            'totalWeeks': 18,
            'periodTimeSet': {'name': '', 'periodTimes': []},
            'courses': [_minimalCourseJson('Message Chunk Course')],
          },
        };
        final encodedResponse = jsonEncode(responseJson);
        final sseBody =
            'data: ${jsonEncode({
              'choices': [
                {
                  'message': {'content': encodedResponse},
                  'finish_reason': 'stop',
                },
              ],
            })}\n\n';

        final client = _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable([utf8.encode(sseBody)]),
            200,
          );
        });

        final events = await const SchoolImportApi()
            .importCurrentPageStream(
              const SchoolImportPagePayload(
                url: 'https://example.test/page',
                title: 'Example page',
                html: '<table>demo</table>',
                locale: 'zh',
                sourceHint: schoolImportParserSourceCustomOpenAi,
              ),
              parserSettings: _customParserSettings,
              client: client,
            )
            .toList();

        expect(events.whereType<ParseError>(), isEmpty);
        expect(
          events.whereType<ParseDelta>().map((event) => event.text).join(),
          encodedResponse,
        );
        expect(
          events.whereType<ParseDone>().single.response.timetable.name,
          'Message Chunk Timetable',
        );
      },
    );

    test('falls back when custom stream meta fields are malformed', () async {
      final responseJson = {
        'ok': true,
        'meta': {
          'sourceUrl': 42,
          'pageTitle': ['bad'],
          'parser': 42,
          'warnings': 'bad',
        },
        'timetable': {
          'name': 'Malformed Meta Timetable',
          'startDate': '2026-02-23',
          'totalWeeks': 18,
          'periodTimeSet': {'name': '', 'periodTimes': []},
          'courses': [_minimalCourseJson('Malformed Meta Course')],
        },
      };
      final sseBody =
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': jsonEncode(responseJson)},
              },
            ],
          })}\n\n'
          'data: [DONE]\n\n';

      final client = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode(sseBody)]),
          200,
        );
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            const SchoolImportPagePayload(
              url: 'https://example.test/page',
              title: 'Example page',
              html: '<table>demo</table>',
              locale: 'zh',
              sourceHint: schoolImportParserSourceCustomOpenAi,
            ),
            parserSettings: const SchoolImportParserSettings(
              source: schoolImportParserSourceCustomOpenAi,
              customBaseUrl: 'https://api.example.com/v1',
              customApiKey: 'sk-test',
              customModel: 'gpt-4.1-mini',
            ),
            client: client,
          )
          .toList();

      expect(events.whereType<ParseError>(), isEmpty);
      final done = events.whereType<ParseDone>().single;
      expect(done.response.meta.sourceUrl, 'https://example.test/page');
      expect(done.response.meta.pageTitle, 'Example page');
      expect(done.response.meta.parser, 'custom-openai:gpt-4.1-mini');
      expect(done.response.meta.warnings, isEmpty);
    });

    test('custom stream reports response parse failures clearly', () async {
      final responseJson = {
        'ok': false,
        'message': 'No timetable found.',
        'meta': {
          'sourceUrl': '',
          'pageTitle': '',
          'parser': '',
          'warnings': [],
        },
        'timetable': {
          'name': '',
          'startDate': '',
          'totalWeeks': 18,
          'periodTimeSet': {'name': '', 'periodTimes': []},
          'courses': [],
        },
      };
      final sseBody =
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': jsonEncode(responseJson)},
              },
            ],
          })}\n\n'
          'data: [DONE]\n\n';

      final client = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode(sseBody)]),
          200,
        );
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            const SchoolImportPagePayload(
              url: 'https://example.test/page',
              title: 'Example page',
              html: '<table>demo</table>',
              locale: 'zh',
              sourceHint: schoolImportParserSourceCustomOpenAi,
            ),
            parserSettings: const SchoolImportParserSettings(
              source: schoolImportParserSourceCustomOpenAi,
              customBaseUrl: 'https://api.example.com/v1',
              customApiKey: 'sk-test',
              customModel: 'gpt-4.1-mini',
            ),
            client: client,
          )
          .toList();

      expect(events.whereType<ParseDone>(), isEmpty);
      final error = events.whereType<ParseError>().single;
      expect(error.message, startsWith('Import response parse failed.'));
      expect(error.message, contains('No timetable found.'));
      expect(error.message, isNot(contains('Unable to connect')));
    });
  });

  group('SchoolImportApi transport boundaries', () {
    const payload = SchoolImportPagePayload(
      url: 'https://example.test/page',
      title: 'Example page',
      html: '<table>demo</table>',
      locale: 'en',
      sourceHint: schoolImportParserSourceCustomOpenAi,
    );

    Map<String, dynamic> responseJson({
      List<Map<String, dynamic>>? courses,
      List<Map<String, dynamic>>? periodTimes,
    }) {
      return {
        'ok': true,
        'meta': {
          'sourceUrl': '',
          'pageTitle': '',
          'parser': '',
          'warnings': [],
        },
        'timetable': {
          'name': 'Bounded Timetable',
          'startDate': '2026-02-23',
          'totalWeeks': 18,
          'periodTimeSet': {'name': '', 'periodTimes': periodTimes ?? const []},
          'courses': courses ?? [_minimalCourseJson()],
        },
      };
    }

    String chatResponseBody(Map<String, dynamic> response) {
      return jsonEncode({
        'choices': [
          {
            'message': {'content': jsonEncode(response)},
            'finish_reason': 'stop',
          },
        ],
      });
    }

    void expectSmallError(String message) {
      expect(
        utf8.encode(message).length,
        lessThanOrEqualTo(SchoolImportApi.maxErrorMessageBytes),
      );
      expect(message, contains('[details truncated]'));
    }

    test(
      'model response enforces a raw byte limit without Content-Length',
      () async {
        final api = SchoolImportApi(
          maxModelResponseBytes: 24,
          client: _StreamingClient((request) async {
            return http.StreamedResponse(
              Stream<List<int>>.fromIterable([
                utf8.encode('{"data":['),
                utf8.encode('{"id":"model-that-is-too-large"}]}'),
              ]),
              200,
            );
          }),
        );

        expect(
          () => api.fetchCustomModels(
            baseUrl: 'https://api.example.test/v1',
            apiKey: 'sk-test',
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('Model list response exceeded 24 bytes'),
            ),
          ),
        );
      },
    );

    test('non-stream import enforces a raw byte response limit', () async {
      final body = chatResponseBody(responseJson());
      final api = SchoolImportApi(
        maxImportResponseBytes: 64,
        client: _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              utf8.encode(body.substring(0, 32)),
              utf8.encode(body.substring(32)),
            ]),
            200,
          );
        }),
      );

      expect(
        () => api.importCurrentPageWithRawResponse(
          payload,
          parserSettings: _customParserSettings,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Import response exceeded 64 bytes'),
          ),
        ),
      );
    });

    test('model-list errors expose only a small response excerpt', () async {
      final body = '私密详情' * 4000;
      final api = SchoolImportApi(
        client: _StreamingClient((request) async {
          return http.StreamedResponse(Stream.value(utf8.encode(body)), 500);
        }),
      );

      try {
        await api.fetchCustomModels(
          baseUrl: 'https://api.example.test/v1',
          apiKey: 'sk-test',
        );
        fail('Expected a bounded model-list error.');
      } on FormatException catch (error) {
        expect(error.message, startsWith('Model list request failed (500).'));
        expectSmallError(error.message);
      }
    });

    test(
      'non-stream parse errors expose only a small response excerpt',
      () async {
        final body = '课表原始响应' * 4000;
        final api = SchoolImportApi(
          client: _StreamingClient((request) async {
            return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
          }),
        );

        try {
          await api.importCurrentPageWithRawResponse(
            payload,
            parserSettings: _customParserSettings,
          );
          fail('Expected a bounded import parse error.');
        } on FormatException catch (error) {
          expect(
            error.message,
            startsWith('Import response format is invalid.'),
          );
          expectSmallError(error.message);
        }
      },
    );

    for (final finishReason in <Object?>[
      null,
      'length',
      'content_filter',
      42,
    ]) {
      test('non-stream import rejects finish reason $finishReason', () async {
        final choice = <String, dynamic>{
          'message': {'content': jsonEncode(responseJson())},
          'finish_reason': ?finishReason,
        };
        final api = SchoolImportApi(
          client: _StreamingClient((request) async {
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'choices': [choice],
                  }),
                ),
              ),
              200,
            );
          }),
        );

        await expectLater(
          api.importCurrentPageWithRawResponse(
            payload,
            parserSettings: _customParserSettings,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              finishReason is String
                  ? 'Import response ended with finish reason "$finishReason".'
                  : 'Import response finish reason is invalid.',
            ),
          ),
        );
      });
    }

    test('request timeout aborts the underlying sensitive request', () async {
      final client = _AbortObservingClient();
      final api = SchoolImportApi(
        client: client,
        requestTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        api.fetchCustomModels(
          baseUrl: 'https://api.example.test/v1',
          apiKey: 'sk-test',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Model list request timed out.',
          ),
        ),
      );
      await client.aborted.future.timeout(const Duration(seconds: 1));
    });

    test('successful model responses require valid UTF-8', () async {
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream.value(<int>[
            ...utf8.encode('{"data":[{"id":"model-'),
            0xff,
            ...utf8.encode('"}]}'),
          ]),
          200,
        );
      });
      final api = SchoolImportApi(client: client);

      await expectLater(
        api.fetchCustomModels(
          baseUrl: 'https://api.example.test/v1',
          apiKey: 'sk-test',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    for (final status in [301, 302, 303, 307, 308]) {
      test('blocks sensitive HTTP $status redirects', () async {
        var followRedirects = true;
        final api = SchoolImportApi(
          client: _StreamingClient((request) async {
            followRedirects = request.followRedirects;
            return http.StreamedResponse(
              const Stream<List<int>>.empty(),
              status,
              headers: {'location': 'https://other.example.test/models'},
            );
          }),
        );

        await expectLater(
          api.fetchCustomModels(
            baseUrl: 'https://api.example.test/v1',
            apiKey: 'sk-test',
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Model list request redirect was blocked.',
            ),
          ),
        );
        expect(followRedirects, isFalse);
      });
    }

    test('streaming timetable POST never follows a redirect', () async {
      var followRedirects = true;
      final client = _StreamingClient((request) async {
        followRedirects = request.followRedirects;
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          307,
          headers: {'location': 'http://other.example.test/import'},
        );
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      expect(followRedirects, isFalse);
      expect(
        events.whereType<ParseError>().single.message,
        'Import request redirect was blocked.',
      );
    });

    test(
      'SSE total deadline wins even when heartbeats keep arriving',
      () async {
        final client = _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream<List<int>>.periodic(
              const Duration(milliseconds: 2),
              (_) => utf8.encode(': heartbeat\n\n'),
            ),
            200,
          );
        });
        final events =
            await SchoolImportApi(
                  streamIdleTimeout: const Duration(seconds: 1),
                  streamTotalTimeout: const Duration(milliseconds: 30),
                )
                .importCurrentPageStream(
                  payload,
                  parserSettings: _customParserSettings,
                  client: client,
                )
                .toList();

        expect(events.whereType<ParseDone>(), isEmpty);
        expect(
          events.whereType<ParseError>().single.message,
          contains('Import stream exceeded its total deadline.'),
        );
      },
    );

    test('SSE rejects malformed UTF-8 instead of replacing bytes', () async {
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream.value(<int>[...utf8.encode('data: '), 0xff, 0x0a, 0x0a]),
          200,
        );
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      expect(events.whereType<ParseDone>(), isEmpty);
      expect(events.whereType<ParseError>(), hasLength(1));
    });

    test('SSE rejects non-JSON data frames instead of skipping them', () async {
      final encoded = jsonEncode(responseJson());
      final body =
          'data: not-json\n\n'
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': encoded},
              },
            ],
          })}\n\n'
          'data: [DONE]\n\n';
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      expect(events.whereType<ParseDone>(), isEmpty);
      expect(
        events.whereType<ParseError>().single.message,
        'Import stream event is invalid.',
      );
    });

    for (final finishReason in ['length', 'content_filter']) {
      test('SSE rejects incomplete $finishReason finish reasons', () async {
        final body =
            'data: ${jsonEncode({
              'choices': [
                {
                  'message': {'content': jsonEncode(responseJson())},
                  'finish_reason': finishReason,
                },
              ],
            })}\n\n';
        final client = _StreamingClient((request) async {
          return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
        });

        final events = await const SchoolImportApi()
            .importCurrentPageStream(
              payload,
              parserSettings: _customParserSettings,
              client: client,
            )
            .toList();

        expect(events.whereType<ParseDone>(), isEmpty);
        expect(
          events.whereType<ParseError>().single.message,
          'Import stream ended with finish reason "$finishReason".',
        );
      });
    }

    test('SSE rejects malformed finish reasons', () async {
      final body =
          'data: ${jsonEncode({
            'choices': [
              {
                'message': {'content': jsonEncode(responseJson())},
                'finish_reason': 42,
              },
            ],
          })}\n\n';
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      expect(events.whereType<ParseDone>(), isEmpty);
      expect(
        events.whereType<ParseError>().single.message,
        'Import stream finish reason is invalid.',
      );
    });

    test('SSE surfaces server error frames', () async {
      final body =
          'data: ${jsonEncode({
            'error': {'message': 'Request rejected by the parser.'},
          })}\n\ndata: [DONE]\n\n';
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      expect(events.whereType<ParseDone>(), isEmpty);
      expect(
        events.whereType<ParseError>().single.message,
        'Import stream failed: Request rejected by the parser.',
      );
    });

    test('SSE server and parse errors remain bounded', () async {
      final oversizedDetails = '私密流式详情' * 4000;
      final serverErrorBody =
          'data: ${jsonEncode({
            'error': {'message': oversizedDetails},
          })}\n\ndata: [DONE]\n\n';
      final serverErrorClient = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(serverErrorBody)),
          200,
        );
      });

      final serverEvents = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: serverErrorClient,
          )
          .toList();
      expectSmallError(serverEvents.whereType<ParseError>().single.message);

      final invalidContentBody =
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': oversizedDetails},
              },
            ],
          })}\n\ndata: [DONE]\n\n';
      final parseErrorClient = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(invalidContentBody)),
          200,
        );
      });
      final parseEvents = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: parseErrorClient,
          )
          .toList();
      final parseMessage = parseEvents.whereType<ParseError>().single.message;
      expect(parseMessage, startsWith('Import response parse failed.'));
      expectSmallError(parseMessage);
    });

    test('generic transport exception strings remain bounded', () async {
      final client = _StreamingClient((request) async {
        throw StateError('连接异常详情' * 4000);
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList();

      final message = events.whereType<ParseError>().single.message;
      expect(message, startsWith('Unable to connect to the import service.'));
      expectSmallError(message);
    });

    test('SSE enforces both single-line and total byte limits', () async {
      final oversizedLineClient = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: ${'x' * 40}\n\n')),
          200,
        );
      });
      final lineEvents = await SchoolImportApi(maxSseLineBytes: 16)
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: oversizedLineClient,
          )
          .toList();
      expect(
        lineEvents.whereType<ParseError>().single.message,
        contains('Import stream line exceeded 16 bytes'),
      );

      final oversizedTotalClient = _StreamingClient((request) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([
            utf8.encode(': ${'x' * 24}\n\n'),
            utf8.encode(': ${'y' * 24}\n\n'),
          ]),
          200,
        );
      });
      final totalEvents = await SchoolImportApi(maxStreamResponseBytes: 40)
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: oversizedTotalClient,
          )
          .toList();
      expect(
        totalEvents.whereType<ParseError>().single.message,
        contains('Import stream exceeded 40 bytes'),
      );
    });

    test('DONE cancels an open response immediately', () async {
      var responseCancelled = false;
      late final StreamController<List<int>> responseController;
      responseController = StreamController<List<int>>(
        onCancel: () => responseCancelled = true,
      );
      final encoded = jsonEncode(responseJson());
      responseController.add(
        utf8.encode(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': encoded},
              },
            ],
          })}\n\ndata: [DONE]\n\n',
        ),
      );
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(responseController.stream, 200);
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList()
          .timeout(const Duration(seconds: 1));

      expect(events.whereType<ParseDone>(), hasLength(1));
      expect(responseCancelled, isTrue);
      await responseController.close();
    });

    test('finish reason cancels an open response immediately', () async {
      var responseCancelled = false;
      late final StreamController<List<int>> responseController;
      responseController = StreamController<List<int>>(
        onCancel: () => responseCancelled = true,
      );
      final encoded = jsonEncode(responseJson());
      responseController.add(
        utf8.encode(
          'data: ${jsonEncode({
            'choices': [
              {
                'message': {'content': encoded},
                'finish_reason': 'stop',
              },
            ],
          })}\n\n',
        ),
      );
      final client = _StreamingClient((request) async {
        return http.StreamedResponse(responseController.stream, 200);
      });

      final events = await const SchoolImportApi()
          .importCurrentPageStream(
            payload,
            parserSettings: _customParserSettings,
            client: client,
          )
          .toList()
          .timeout(const Duration(seconds: 1));

      expect(events.whereType<ParseDone>(), hasLength(1));
      expect(responseCancelled, isTrue);
      await responseController.close();
    });

    test(
      'small SSE deltas are batched without changing their content',
      () async {
        final encoded = jsonEncode(responseJson());
        final body = StringBuffer();
        for (final rune in encoded.runes) {
          body.writeln(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': String.fromCharCode(rune)},
                },
              ],
            })}',
          );
          body.writeln();
        }
        body.writeln('data: [DONE]');
        final client = _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(body.toString())),
            200,
          );
        });

        final events = await const SchoolImportApi()
            .importCurrentPageStream(
              payload,
              parserSettings: _customParserSettings,
              client: client,
            )
            .toList();
        final deltas = events.whereType<ParseDelta>().toList();

        expect(deltas.map((event) => event.text).join(), encoded);
        expect(deltas.length, lessThan(encoded.length));
        expect(events.whereType<ParseDone>(), hasLength(1));
      },
    );

    test('model and parsed object counts are bounded', () async {
      final tooManyModels = List.generate(
        SchoolImportApi.maxModelCount + 1,
        (index) => {'id': 'model-$index'},
      );
      final modelApi = SchoolImportApi(
        client: _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'data': tooManyModels}))),
            200,
          );
        }),
      );
      await expectLater(
        modelApi.fetchCustomModels(
          baseUrl: 'https://api.example.test/v1',
          apiKey: 'sk-test',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Model list contains too many entries.',
          ),
        ),
      );

      final tooManyCourses = List.generate(
        SchoolImportApi.maxImportedCourseCount + 1,
        (index) => _minimalCourseJson('Course $index'),
      );
      final importApi = SchoolImportApi(
        client: _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                chatResponseBody(responseJson(courses: tooManyCourses)),
              ),
            ),
            200,
          );
        }),
      );
      await expectLater(
        importApi.importCurrentPageWithRawResponse(
          payload,
          parserSettings: _customParserSettings,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Import response contains too many courses.'),
          ),
        ),
      );
    });

    test('model IDs and imported period-time counts are bounded', () async {
      final modelApi = SchoolImportApi(
        client: _StreamingClient((request) async {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'data': [
                    {'id': 'x' * (SchoolImportApi.maxModelIdLength + 1)},
                  ],
                }),
              ),
            ),
            200,
          );
        }),
      );
      await expectLater(
        modelApi.fetchCustomModels(
          baseUrl: 'https://api.example.test/v1',
          apiKey: 'sk-test',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Model list contains an overlong model ID.',
          ),
        ),
      );

      final tooManyPeriodTimes = List.generate(
        SchoolImportApi.maxImportedPeriodTimeCount + 1,
        (index) => {
          'index': index + 1,
          'startMinutes': index * 5,
          'endMinutes': index * 5 + 4,
        },
      );
      expect(
        () => SchoolImportApi.buildResponseFromDoneEvent(
          responseJson(periodTimes: tooManyPeriodTimes),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response contains too many period times.',
          ),
        ),
      );
    });

    test(
      'structured string bounds apply to direct non-stream and SSE results',
      () async {
        final directJson = responseJson();
        (directJson['timetable'] as Map<String, dynamic>)['name'] =
            'x' * (SchoolImportApi.maxImportedShortTextBytes + 1);
        expect(
          () => SchoolImportApi.buildResponseFromDoneEvent(directJson),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Import response timetable name is too long.',
            ),
          ),
        );

        final nonStreamJson = responseJson();
        (nonStreamJson['meta'] as Map<String, dynamic>)['warnings'] = [
          'x' * (SchoolImportApi.maxImportedLongTextBytes + 1),
        ];
        final nonStreamApi = SchoolImportApi(
          client: _StreamingClient((request) async {
            return http.StreamedResponse(
              Stream.value(utf8.encode(chatResponseBody(nonStreamJson))),
              200,
            );
          }),
        );
        await expectLater(
          nonStreamApi.importCurrentPageWithRawResponse(
            payload,
            parserSettings: _customParserSettings,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('Import response warning is too long.'),
            ),
          ),
        );

        final streamJson = responseJson();
        final streamCourse =
            ((streamJson['timetable'] as Map<String, dynamic>)['courses']
                        as List)
                    .single
                as Map<String, dynamic>;
        streamCourse['teacher'] =
            'x' * (SchoolImportApi.maxImportedShortTextBytes + 1);
        final streamBody =
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': jsonEncode(streamJson)},
                },
              ],
            })}\n\ndata: [DONE]\n\n';
        final streamEvents = await const SchoolImportApi()
            .importCurrentPageStream(
              payload,
              parserSettings: _customParserSettings,
              client: _StreamingClient((request) async {
                return http.StreamedResponse(
                  Stream.value(utf8.encode(streamBody)),
                  200,
                );
              }),
            )
            .toList();
        expect(streamEvents.whereType<ParseDone>(), isEmpty);
        expect(
          streamEvents.whereType<ParseError>().single.message,
          contains('Import response course teacher is too long.'),
        );
      },
    );

    test('structured results enforce total text and custom-field bounds', () {
      final textHeavyCourses = List.generate(
        17,
        (index) => {
          ..._minimalCourseJson('Course $index'),
          'remarks': 'x' * SchoolImportApi.maxImportedLongTextBytes,
        },
      );
      expect(
        () => SchoolImportApi.buildResponseFromDoneEvent(
          responseJson(courses: textHeavyCourses),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response contains too much text.',
          ),
        ),
      );

      final customFieldJson = responseJson();
      final customFieldCourse =
          ((customFieldJson['timetable'] as Map<String, dynamic>)['courses']
                      as List)
                  .single
              as Map<String, dynamic>;
      customFieldCourse['customFields'] = {
        for (
          var index = 0;
          index <= SchoolImportApi.maxImportedCustomFieldCount;
          index++
        )
          'key-$index': 'value',
      };
      expect(
        () => SchoolImportApi.buildResponseFromDoneEvent(customFieldJson),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response contains too many custom fields.',
          ),
        ),
      );

      final customFieldsPerCourse = SchoolImportApi.maxImportedCustomFieldCount;
      final customFieldCourseCount =
          (SchoolImportApi.maxImportedTotalCustomFieldCount ~/
              customFieldsPerCourse) +
          1;
      final tooManyTotalCustomFields = List.generate(
        customFieldCourseCount,
        (courseIndex) => {
          ..._minimalCourseJson('Course $courseIndex'),
          'customFields': {
            for (var index = 0; index < customFieldsPerCourse; index++)
              'key-$index': index,
          },
        },
      );
      expect(
        () => SchoolImportApi.buildResponseFromDoneEvent(
          responseJson(courses: tooManyTotalCustomFields),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response contains too many custom fields.',
          ),
        ),
      );

      customFieldCourse['customFields'] = {
        'nested': {'unexpected': 'value'},
      };
      expect(
        () => SchoolImportApi.buildResponseFromDoneEvent(customFieldJson),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response custom field value is invalid.',
          ),
        ),
      );
    });

    test('raw course week and period arrays are bounded before filtering', () {
      for (final entry in [
        (
          field: 'semesterWeeks',
          values: List.filled(
            SchoolImportApi.maxImportedSemesterWeekCount + 1,
            1,
          ),
          message: 'Import response contains too many semester weeks.',
        ),
        (
          field: 'periods',
          values: List.filled(
            SchoolImportApi.maxImportedCoursePeriodCount + 1,
            1,
          ),
          message: 'Import response contains too many periods.',
        ),
      ]) {
        final json = responseJson();
        final course =
            ((json['timetable'] as Map<String, dynamic>)['courses'] as List)
                    .single
                as Map<String, dynamic>;
        course[entry.field] = entry.values;
        expect(
          () => SchoolImportApi.buildResponseFromDoneEvent(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              entry.message,
            ),
          ),
        );
      }
    });

    test(
      'oversized outbound content is rejected before a request is sent',
      () async {
        var requestSent = false;
        final client = _StreamingClient((request) async {
          requestSent = true;
          return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
        });
        final events = await const SchoolImportApi()
            .importCurrentPageStream(
              SchoolImportPagePayload(
                url: 'https://example.test/page',
                title: 'Example',
                html: 'x' * (SchoolImportApi.maxSourceContentLength + 1),
                locale: 'en',
              ),
              parserSettings: _customParserSettings,
              client: client,
            )
            .toList();

        expect(requestSent, isFalse);
        expect(
          events.whereType<ParseError>().single.message,
          'Import content is too large.',
        );
      },
    );
  });
}
