import 'package:material_ui/material_ui.dart';

import '../screens/school_import_parse_page.dart';
import '../services/school_import_api.dart';

/// Backwards-compatible name for callers that used to place the streaming
/// parser inside an `AlertDialog`.
///
/// The parser is now a full-screen page. Keeping this thin widget avoids a
/// breaking import for integrations and older tests while ensuring no nested
/// parser `AlertDialog` is built by the application.
class SchoolImportStreamDialog extends StatelessWidget {
  const SchoolImportStreamDialog({super.key, required this.stream});

  static const int maxPreviewCodeUnits =
      SchoolImportParsePage.defaultMaxPreviewCodeUnits;
  static const int maxEditableCodeUnits =
      SchoolImportParsePage.defaultMaxEditableCodeUnits;

  final Stream<SchoolImportStreamEvent> stream;

  @override
  Widget build(BuildContext context) {
    return SchoolImportParsePage(
      stream: stream,
      maxPreviewCodeUnits: maxPreviewCodeUnits,
      maxEditableCodeUnits: maxEditableCodeUnits,
      returnResponseOnly: true,
      autoPopAfterEditor: true,
    );
  }
}
