import 'dart:convert';

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

  /// Reads UTF-8 incrementally while retaining the display name.
  /// Agent attachments pass no application-imposed byte limit.
  static Future<PickedTextFile?> pickDocument({
    required List<String> allowedExtensions,
    int? byteLimit = maxBytes,
  }) async {
    if (byteLimit != null && byteLimit < 1) {
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
    if (byteLimit != null && declaredLength > byteLimit) {
      throw const TextFileTooLargeException();
    }
    var length = 0;
    Stream<List<int>> read() async* {
      for (var start = 0; start < declaredLength; start += 65536) {
        final end = (start + 65536).clamp(0, declaredLength);
        await for (final chunk in file.openRead(start, end)) {
          length += chunk.length;
          if (byteLimit != null && length > byteLimit) {
            throw const TextFileTooLargeException();
          }
          yield chunk;
        }
      }
    }

    final text = await utf8.decoder.bind(read()).join();
    final finalLength = await file.length();
    if (byteLimit != null && finalLength > byteLimit) {
      throw const TextFileTooLargeException();
    }
    if (finalLength != declaredLength || length != declaredLength) {
      throw const FormatException('The text file changed while reading.');
    }
    // Utf8Decoder removes the initial UTF-8 BOM, including across chunks,
    // while retaining embedded U+FEFF and rejecting malformed byte sequences.
    return PickedTextFile(name: file.name, text: text);
  }
}
