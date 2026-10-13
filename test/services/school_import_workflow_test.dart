import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/services/school_import_workflow.dart';

const _payload = SchoolImportPagePayload(
  url: 'https://school.example.edu/timetable',
  title: 'Timetable',
  html: '<table><tr><td>Math</td></tr></table>',
  locale: 'en',
  sourceHint: schoolImportParserSourceCustomOpenAi,
);

const _parserSettings = AiApiSettings(
  source: schoolImportParserSourceCustomOpenAi,
  customBaseUrl: 'https://api.example.com/v1',
  customApiKey: 'sk-test',
  customModel: 'test-model',
);

class _RecordingApi extends SchoolImportApi {
  final List<SchoolImportStreamEvent> events = const [
    ParseError('synthetic stop'),
  ];
  SchoolImportPagePayload? payload;
  AiApiSettings? parserSettings;
  http.Client? client;
  var calls = 0;

  @override
  Stream<SchoolImportStreamEvent> importCurrentPageStream(
    SchoolImportPagePayload payload, {
    AiApiSettings? parserSettings,
    http.Client? client,
  }) {
    calls += 1;
    this.payload = payload;
    this.parserSettings = parserSettings;
    this.client = client;
    return Stream<SchoolImportStreamEvent>.fromIterable(events);
  }
}

class _ThrowingApi extends SchoolImportApi {
  @override
  Stream<SchoolImportStreamEvent> importCurrentPageStream(
    SchoolImportPagePayload payload, {
    AiApiSettings? parserSettings,
    http.Client? client,
  }) {
    throw StateError('synthetic parser failure');
  }
}

class _TrackingClient extends http.BaseClient {
  var closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnsupportedError('The workflow test API never sends HTTP requests.');
  }

  @override
  void close() {
    closeCount += 1;
  }
}

void main() {
  test('prepares a bounded canonical source with the shared sanitizer', () {
    final workflow = SchoolImportWorkflow();

    final result = workflow.prepareContent(
      '<script>leak()</script><table><tr><td>Math</td></tr></table>',
    );

    expect(
      result.content,
      '<table><tbody><tr><td>Math</td></tr></tbody></table>',
    );
    expect(result.wasTruncated, isFalse);
  });

  test('parse forwards its snapshot and closes the client once', () async {
    final api = _RecordingApi();
    final client = _TrackingClient();
    final workflow = SchoolImportWorkflow(
      api: api,
      httpClientFactory: () => client,
    );

    final response = await workflow.parse(
      payload: _payload,
      parserSettings: _parserSettings,
      presentStream: (stream) async {
        expect(await stream.toList(), api.events);
        return null;
      },
    );

    expect(response, isNull);
    expect(api.calls, 1);
    expect(api.payload, same(_payload));
    expect(api.parserSettings, same(_parserSettings));
    expect(api.client, same(client));
    expect(client.closeCount, 1);
  });

  test('parse closes the client when transport setup fails', () async {
    final client = _TrackingClient();
    final workflow = SchoolImportWorkflow(
      api: _ThrowingApi(),
      httpClientFactory: () => client,
    );

    await expectLater(
      workflow.parse(
        payload: _payload,
        parserSettings: _parserSettings,
        presentStream: (_) async => null,
      ),
      throwsStateError,
    );
    expect(client.closeCount, 1);
  });

  test(
    'cancel closes one active client and rejects overlapping parses',
    () async {
      final firstClient = _TrackingClient();
      final secondClient = _TrackingClient();
      final clients = <_TrackingClient>[firstClient, secondClient];
      final presenterStarted = Completer<void>();
      final releasePresenter = Completer<void>();
      final workflow = SchoolImportWorkflow(
        api: _RecordingApi(),
        httpClientFactory: () => clients.removeAt(0),
      );

      final firstParse = workflow.parse(
        payload: _payload,
        parserSettings: _parserSettings,
        presentStream: (_) async {
          presenterStarted.complete();
          await releasePresenter.future;
          return null;
        },
      );
      await presenterStarted.future;

      await expectLater(
        workflow.parse(
          payload: _payload,
          parserSettings: _parserSettings,
          presentStream: (_) async => null,
        ),
        throwsStateError,
      );
      workflow.cancelActiveParse();
      workflow.cancelActiveParse();
      expect(firstClient.closeCount, 1);

      releasePresenter.complete();
      await firstParse;
      expect(firstClient.closeCount, 1);

      await workflow.parse(
        payload: _payload,
        parserSettings: _parserSettings,
        presentStream: (_) async => null,
      );
      expect(secondClient.closeCount, 1);
    },
  );
}
