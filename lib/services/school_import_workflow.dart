import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show compute;

import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import 'school_import_api.dart';
import 'school_import_content_sanitizer.dart';

typedef SchoolImportStreamPresenter = Future<SchoolImportResponse?> Function(
  Stream<SchoolImportStreamEvent> stream,
);

typedef SchoolImportContentPreparer =
    Future<SchoolImportSanitizationResult> Function(String source);

Future<SchoolImportSanitizationResult> _prepareInBackground(String source) =>
    compute(
      SchoolImportContentSanitizer.sanitizeWithResult,
      source,
      debugLabel: 'sked.import.prepare',
    );

class SchoolImportWorkflow {
  SchoolImportWorkflow({
    this._api = const SchoolImportApi(),
    SchoolImportContentPreparer? contentPreparer,
    http.Client Function()? httpClientFactory,
  }) : contentPreparer = contentPreparer ?? _prepareInBackground,
       _httpClientFactory = httpClientFactory ?? http.Client.new;

  final SchoolImportApi _api;
  final SchoolImportContentPreparer contentPreparer;
  final http.Client Function() _httpClientFactory;
  _SchoolImportParseSession? _activeParseSession;

  Future<SchoolImportSanitizationResult> prepareContent(String source) =>
      contentPreparer(source);

  Future<SchoolImportResponse?> parse({
    required SchoolImportPagePayload payload,
    required AiApiSettings parserSettings,
    required SchoolImportStreamPresenter presentStream,
  }) async {
    if (_activeParseSession != null) {
      throw StateError('A school import parse is already active.');
    }
    final session = _SchoolImportParseSession(_httpClientFactory());
    _activeParseSession = session;
    try {
      final stream = _api.importCurrentPageStream(
        payload,
        parserSettings: parserSettings,
        client: session.client,
      );
      return await presentStream(stream);
    } finally {
      session.close();
      if (identical(_activeParseSession, session)) {
        _activeParseSession = null;
      }
    }
  }

  Future<void> apply(
    TimetableProvider provider,
    SchoolImportApplyRequest request,
  ) {
    return provider.applySchoolImportRequest(request);
  }

  void cancelActiveParse() {
    _activeParseSession?.close();
  }
}

class _SchoolImportParseSession {
  _SchoolImportParseSession(this.client);

  final http.Client client;
  var _isClosed = false;

  void close() {
    if (_isClosed) return;
    _isClosed = true;
    client.close();
  }
}
