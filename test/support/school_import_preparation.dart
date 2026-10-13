import 'package:sked/services/school_import_content_sanitizer.dart';

// Widget tests control the async boundary; the workflow suite exercises the
// real isolate. Keep the same sanitizer and result semantics in both paths.
Future<SchoolImportSanitizationResult> prepareSchoolImportContentForTest(
  String source,
) async => SchoolImportContentSanitizer.sanitizeWithResult(source);
