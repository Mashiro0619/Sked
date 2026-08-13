import 'package:http/http.dart' as http;

import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import 'school_import_api.dart';
import 'school_import_apply_service.dart';
import 'school_import_content_sanitizer.dart';

typedef SchoolImportStreamPresenter = Future<SchoolImportResponse?> Function(
  Stream<SchoolImportStreamEvent> stream,
);

class SchoolImportWorkflow {
  SchoolImportWorkflow({
    this._api = const SchoolImportApi(),
    this._applyService = const SchoolImportApplyService(),
    http.Client Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? http.Client.new;

  final SchoolImportApi _api;
  final SchoolImportApplyService _applyService;
  final http.Client Function() _httpClientFactory;
  _SchoolImportParseSession? _activeParseSession;

  SchoolImportSanitizationResult prepareContent(String source) {
    return SchoolImportContentSanitizer.sanitizeWithResult(source);
  }

  Future<SchoolImportResponse?> parse({
    required SchoolImportPagePayload payload,
    required SchoolImportParserSettings parserSettings,
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
    return _applyService.apply(provider, request);
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
