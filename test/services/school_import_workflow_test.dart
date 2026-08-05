import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/services/school_import_apply_service.dart';
import 'package:sked/services/school_import_workflow.dart';

const _payload = SchoolImportPagePayload(
  url: 'https://school.example.edu/timetable',
  title: 'Timetable',
  html: '<table><tr><td>Math</td></tr></table>',
  locale: 'en',
  sourceHint: schoolImportParserSourceCustomOpenAi,
);

const _parserSettings = SchoolImportParserSettings(
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
  SchoolImportParserSettings? parserSettings;
  http.Client? client;
  var calls = 0;

  @override
  Stream<SchoolImportStreamEvent> importCurrentPageStream(
    SchoolImportPagePayload payload, {
    SchoolImportParserSettings? parserSettings,
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
    SchoolImportParserSettings? parserSettings,
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

class _MemoryStorage implements TimetableStorage {
  AppData data = buildInitialAppData(buildDefaultPeriodTimes());

  @override
  Future<String?> filePath() async => 'memory://school-import-workflow';

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }
}

class _RecordingApplyService extends SchoolImportApplyService {
  TimetableProvider? provider;
  SchoolImportApplyRequest? request;
  Object? error;
  var calls = 0;

  @override
  Future<void> apply(
    TimetableProvider provider,
    SchoolImportApplyRequest request,
  ) async {
    calls += 1;
    this.provider = provider;
    this.request = request;
    final failure = error;
    if (failure != null) throw failure;
  }
}

SchoolImportApplyRequest _applyRequest() {
  return SchoolImportApplyRequest(
    response: SchoolImportResponse(
      meta: const SchoolImportMeta(
        sourceUrl: 'https://school.example.edu/timetable',
        pageTitle: 'Timetable',
        parser: 'custom-openai:test-model',
        warnings: [],
      ),
      timetable: SchoolImportTimetableDraft(
        name: 'Spring',
        startDate: DateTime(2026, 2, 23),
        totalWeeks: 18,
        periodTimeSet: const ImportedPeriodTimeSetDraft(
          name: '',
          periodTimes: [],
        ),
        courses: const [],
      ),
    ),
    mode: TimetableImportMode.addAsNew,
    importBundledPeriodTimeSet: false,
  );
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

  test(
    'apply invokes its commit seam exactly once and propagates failure',
    () async {
      final applyService = _RecordingApplyService();
      final workflow = SchoolImportWorkflow(applyService: applyService);
      final provider = TimetableProvider(storage: _MemoryStorage());
      final request = _applyRequest();

      await workflow.apply(provider, request);

      expect(applyService.calls, 1);
      expect(applyService.provider, same(provider));
      expect(applyService.request, same(request));

      applyService.error = StateError('synthetic apply failure');
      await expectLater(workflow.apply(provider, request), throwsStateError);
      expect(applyService.calls, 2);
    },
  );
}
