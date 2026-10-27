import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

class TextFileTooLargeException implements Exception {
  const TextFileTooLargeException();

  @override
  String toString() => 'Text file exceeds ${TextFilePicker.maxBytes} bytes.';
}

class TextFilePicker {
  const TextFilePicker._();

  static const maxMegabytes = 20;
  static const maxBytes = maxMegabytes * 1000 * 1000;

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
    final declaredLength = await file.length();
    if (declaredLength > maxBytes) {
      throw const TextFileTooLargeException();
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    // An exact bounded range also supports in-memory XFile data and limits
    // the Blob slice on web, where openRead may buffer its entire range.
    await for (final chunk in file.openRead(0, declaredLength)) {
      length += chunk.length;
      if (length > maxBytes) {
        throw const TextFileTooLargeException();
      }
      bytes.add(chunk);
    }
    final finalLength = await file.length();
    if (finalLength > maxBytes) {
      throw const TextFileTooLargeException();
    }
    if (finalLength != declaredLength || length != declaredLength) {
      throw const FormatException('The text file changed while reading.');
    }
    // Utf8Decoder removes the initial UTF-8 BOM, including across chunks,
    // while retaining embedded U+FEFF and rejecting malformed byte sequences.
    return utf8.decode(bytes.takeBytes());
  }
}
