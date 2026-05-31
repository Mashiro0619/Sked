import 'dart:convert';

import 'package:file_selector/file_selector.dart';

class TextFilePicker {
  const TextFilePicker._();

  static Future<String?> pickText({
    required List<String> allowedExtensions,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: allowedExtensions.map((ext) => ext.toUpperCase()).join('/'),
          extensions: allowedExtensions,
        ),
      ],
    );
    if (file == null) {
      return null;
    }
    return utf8.decode(await file.readAsBytes());
  }
}
