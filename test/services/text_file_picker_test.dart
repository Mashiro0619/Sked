import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/text_file_picker.dart';

class _FilePicker extends FileSelectorPlatform {
  _FilePicker(this.file);

  final XFile? file;
  var calls = 0;
  List<XTypeGroup>? acceptedTypeGroups;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    calls += 1;
    this.acceptedTypeGroups = acceptedTypeGroups;
    return file;
  }
}

class _TrackedFile extends XFile {
  _TrackedFile({
    required this.reportedLength,
    required this.chunks,
    this.subsequentLength,
  }) : super('memory://text-import');

  final int reportedLength;
  final int? subsequentLength;
  final Iterable<Uint8List> chunks;
  final readRequests = <(int?, int?)>[];
  var lengthCalls = 0;
  var wholeFileReads = 0;
  var yieldedChunks = 0;
  var streamClosed = false;

  @override
  Future<int> length() async {
    lengthCalls += 1;
    return lengthCalls == 1
        ? reportedLength
        : subsequentLength ?? reportedLength;
  }

  @override
  Future<Uint8List> readAsBytes() {
    wholeFileReads += 1;
    throw StateError('Text imports must request a bounded stream.');
  }

  @override
  Stream<Uint8List> openRead([int? start, int? end]) {
    readRequests.add((start, end));
    return _readChunks();
  }

  Stream<Uint8List> _readChunks() async* {
    try {
      for (final chunk in chunks) {
        yieldedChunks += 1;
        yield chunk;
      }
    } finally {
      streamClosed = true;
    }
  }
}

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

Iterable<Uint8List> _asciiChunks(int length) sync* {
  const chunkSize = 64 * 1024;
  final chunk = Uint8List(chunkSize)..fillRange(0, chunkSize, 0x61);
  var remaining = length;
  while (remaining >= chunkSize) {
    yield chunk;
    remaining -= chunkSize;
  }
  if (remaining > 0) {
    yield Uint8List.sublistView(chunk, 0, remaining);
  }
}

_FilePicker _select(XFile? file) {
  final picker = _FilePicker(file);
  FileSelectorPlatform.instance = picker;
  return picker;
}

Future<String?> _pick() =>
    TextFilePicker.pickText(allowedExtensions: const ['json', 'ics']);

void _expectBoundedRead(_TrackedFile file, {int lengthChecks = 2}) {
  expect(file.lengthCalls, lengthChecks);
  expect(file.wholeFileReads, 0);
  expect(file.readRequests, [(0, file.reportedLength)]);
  expect(
    file.readRequests.single.$2,
    lessThanOrEqualTo(TextFilePicker.maxBytes),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FileSelectorPlatform previousPicker;

  setUp(() {
    previousPicker = FileSelectorPlatform.instance;
  });

  tearDown(() {
    FileSelectorPlatform.instance = previousPicker;
  });

  test('canceling the picker returns null', () async {
    final picker = _select(null);

    expect(await _pick(), isNull);
    expect(picker.calls, 1);
  });

  test('passes the requested extensions and reads a bounded stream', () async {
    final file = _TrackedFile(
      reportedLength: 2,
      chunks: [
        _bytes([0x7b, 0x7d]),
      ],
    );
    final picker = _select(file);

    expect(await _pick(), '{}');
    expect(picker.calls, 1);
    final group = picker.acceptedTypeGroups!.single;
    expect(group.label, 'JSON/ICS');
    expect(group.extensions, ['json', 'ics']);
    _expectBoundedRead(file);
    expect(file.streamClosed, isTrue);
  });

  test('an empty file is returned as empty text', () async {
    final file = _TrackedFile(reportedLength: 0, chunks: const []);
    _select(file);

    expect(await _pick(), isEmpty);
    _expectBoundedRead(file);
  });

  test(
    'a real in-memory XFile remains readable when shorter than the cap',
    () async {
      _select(XFile.fromData(_bytes(utf8.encode('{"ok":true}'))));

      expect(await _pick(), '{"ok":true}');
    },
  );

  test('accepts exactly 20 decimal megabytes', () async {
    expect(TextFilePicker.maxMegabytes, 20);
    expect(TextFilePicker.maxBytes, 20 * 1000 * 1000);
    final file = _TrackedFile(
      reportedLength: TextFilePicker.maxBytes,
      chunks: _asciiChunks(TextFilePicker.maxBytes),
    );
    _select(file);

    final text = await _pick();

    expect(text, isNotNull);
    expect(text!.length, TextFilePicker.maxBytes);
    expect(text.startsWith('aaaa'), isTrue);
    expect(text.endsWith('aaaa'), isTrue);
    _expectBoundedRead(file);
    expect(file.streamClosed, isTrue);
  });

  test('rejects one byte over the declared limit before reading', () async {
    final file = _TrackedFile(
      reportedLength: TextFilePicker.maxBytes + 1,
      chunks: const [],
    );
    _select(file);

    await expectLater(_pick(), throwsA(isA<TextFileTooLargeException>()));

    expect(file.lengthCalls, 1);
    expect(file.readRequests, isEmpty);
    expect(file.wholeFileReads, 0);
    expect(file.yieldedChunks, 0);
  });

  test(
    'rejects a falsely reported length when actual bytes exceed the cap',
    () async {
      var reachedTrailingChunk = false;
      Iterable<Uint8List> chunks() sync* {
        yield* _asciiChunks(TextFilePicker.maxBytes);
        yield _bytes([0x61]);
        reachedTrailingChunk = true;
        yield _bytes([0x61]);
      }

      final file = _TrackedFile(reportedLength: 1, chunks: chunks());
      _select(file);

      await expectLater(_pick(), throwsA(isA<TextFileTooLargeException>()));

      _expectBoundedRead(file, lengthChecks: 1);
      expect(file.streamClosed, isTrue);
      expect(reachedTrailingChunk, isFalse);
    },
  );

  test('counts the UTF-8 BOM bytes toward the file limit', () async {
    Iterable<Uint8List> chunks() sync* {
      yield _bytes([0xef, 0xbb, 0xbf]);
      yield* _asciiChunks(TextFilePicker.maxBytes - 2);
    }

    final file = _TrackedFile(
      reportedLength: TextFilePicker.maxBytes,
      chunks: chunks(),
    );
    _select(file);

    await expectLater(_pick(), throwsA(isA<TextFileTooLargeException>()));
    _expectBoundedRead(file, lengthChecks: 1);
  });

  test('rejects a file that grows beyond the cap while reading', () async {
    final file = _TrackedFile(
      reportedLength: 2,
      subsequentLength: TextFilePicker.maxBytes + 1,
      chunks: [
        _bytes([0x7b, 0x7d]),
      ],
    );
    _select(file);

    await expectLater(_pick(), throwsA(isA<TextFileTooLargeException>()));

    _expectBoundedRead(file);
  });

  for (final (name, reportedLength, subsequentLength, content) in [
    ('grows within the cap', 2, 3, '{}'),
    ('shrinks while reading', 3, 2, '{}'),
    ('returns fewer bytes than declared', 3, 3, '{}'),
    ('returns extra bytes within the cap', 1, 1, '{}'),
  ]) {
    test(
      'rejects a file that $name instead of importing partial text',
      () async {
        final file = _TrackedFile(
          reportedLength: reportedLength,
          subsequentLength: subsequentLength,
          chunks: [_bytes(utf8.encode(content))],
        );
        _select(file);

        await expectLater(_pick(), throwsA(isA<FormatException>()));

        _expectBoundedRead(file);
      },
    );
  }

  test(
    'removes only the leading UTF-8 BOM across chunks and preserves text',
    () async {
      const content = '\uFEFF \r\n计划\uFEFF保留\t ';
      final encoded = utf8.encode(content);
      final file = _TrackedFile(
        reportedLength: encoded.length + 3,
        chunks: [
          _bytes([0xef]),
          _bytes([0xbb]),
          _bytes([0xbf]),
          for (final byte in encoded) _bytes([byte]),
        ],
      );
      _select(file);

      expect(await _pick(), content);
      _expectBoundedRead(file);
    },
  );

  for (final (name, chunks) in [
    (
      'invalid byte',
      [
        [0xff],
      ],
    ),
    (
      'unfinished multibyte character',
      [
        [0xe4],
        [0xb8],
      ],
    ),
    (
      'unfinished BOM',
      [
        [0xef],
        [0xbb],
      ],
    ),
    (
      'UTF-16 input',
      [
        [0xff, 0xfe],
        [0x7b, 0, 0x7d, 0],
      ],
    ),
  ]) {
    test('strict UTF-8 decoding rejects $name', () async {
      final file = _TrackedFile(
        reportedLength: chunks.fold(0, (total, chunk) => total + chunk.length),
        chunks: chunks.map(_bytes),
      );
      _select(file);

      await expectLater(_pick(), throwsA(isA<FormatException>()));
      _expectBoundedRead(file);
    });
  }
}
