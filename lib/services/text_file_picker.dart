import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

class TextFileTooLargeException implements Exception {
  const TextFileTooLargeException();

  @override
  String toString() => 'Text file exceeds ${TextFilePicker.maxBytes} bytes.';
}

class PickedTextFile {
  const PickedTextFile({required this.name, required this.text});
  final String name;
  final String text;
}

class TextFilePicker {
  const TextFilePicker._();

  static const maxMegabytes = 20;
  static const maxBytes = maxMegabytes * 1000 * 1000;

  static Future<String?> pickText({
    required List<String> allowedExtensions,
  }) async => (await pickDocument(allowedExtensions: allowedExtensions))?.text;

  /// Shares the existing bounded UTF-8 reader while retaining a display name.
  /// A consumer may lower its budget; no caller may bypass the global limit.
  static Future<PickedTextFile?> pickDocument({
    required List<String> allowedExtensions,
    int byteLimit = maxBytes,
  }) async {
    if (byteLimit < 1 || byteLimit > maxBytes) {
      throw ArgumentError.value(byteLimit, 'byteLimit');
    }
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
    if (declaredLength > byteLimit) {
      throw const TextFileTooLargeException();
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    // An exact bounded range also supports in-memory XFile data and limits
    // the Blob slice on web, where openRead may buffer its entire range.
    await for (final chunk in file.openRead(0, declaredLength)) {
      length += chunk.length;
      if (length > byteLimit) {
        throw const TextFileTooLargeException();
      }
      bytes.add(chunk);
    }
    final finalLength = await file.length();
    if (finalLength > byteLimit) {
      throw const TextFileTooLargeException();
    }
    if (finalLength != declaredLength || length != declaredLength) {
      throw const FormatException('The text file changed while reading.');
    }
    // Utf8Decoder removes the initial UTF-8 BOM, including across chunks,
    // while retaining embedded U+FEFF and rejecting malformed byte sequences.
    return PickedTextFile(
      name: file.name,
      text: utf8.decode(bytes.takeBytes()),
    );
  }
}
