import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/backup/selective_backup_codec.dart';
import 'package:sked/backup/selective_backup_models.dart';

const _fileKey = BackupObjectKey(BackupObjectKind.attachment, 'file-1');
const _chatKey = BackupObjectKey(BackupObjectKind.conversation, 'chat-1');

SelectiveBackupBundle _bundle() {
  final bytes = Uint8List.fromList([0, 1, 2, 0xff, 0, 0xc0]);
  final digest = backupDigest(bytes);
  final metadata = <String, Object?>{
    'id': 'file-1',
    'name': 'unknown.xyz',
    'mediaType': 'application/octet-stream',
    'byteLength': bytes.length,
    'digest': digest,
  };
  return SelectiveBackupBundle(
    createdAt: DateTime.utc(2026, 10, 31),
    records: [
      BackupRecord(
        key: _chatKey,
        label: 'Chat',
        data: {
          'id': 'chat-1',
          'attachments': [metadata],
        },
        dependencies: const [_fileKey],
      ),
      BackupRecord(
        key: _fileKey,
        label: 'Unknown file',
        data: metadata,
        binaryDigest: digest,
      ),
    ],
    roots: const [_chatKey],
    binaries: {digest: bytes},
  );
}

Uint8List _rewriteManifest(
  Uint8List source,
  void Function(Map<String, dynamic>) mutate, {
  ArchiveFile? extra,
}) {
  final original = ZipDecoder().decodeBytes(source);
  final archive = Archive();
  for (final file in original) {
    final content = file.readBytes()!;
    if (file.name == SelectiveBackupCodec.manifestPath) {
      final manifest = jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
      mutate(manifest);
      archive.add(ArchiveFile.string(file.name, jsonEncode(manifest)));
    } else {
      archive.add(ArchiveFile.bytes(file.name, content));
    }
  }
  if (extra != null) archive.add(extra);
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  const codec = SelectiveBackupCodec();
  Matcher error(SelectiveBackupError code) => isA<SelectiveBackupException>()
      .having((value) => value.code, 'code', code);

  test('versioned ZIP round-trips binary content and separate attachment selection', () {
    final original = _bundle();
    final restored = codec.decode(codec.encode(original));
    expect(restored.fingerprint, original.fingerprint);
    expect(
      restored.binaries.values.single,
      orderedEquals([0, 1, 2, 0xff, 0, 0xc0]),
    );
    final selected = original.select(
      BackupSelection(objects: const [_chatKey]),
    );
    final metadataOnly = codec.decode(codec.encode(selected));
    expect(metadataOnly.records, hasLength(2));
    expect(metadataOnly.byKey[_fileKey]!.data['byteLength'], 6);
    expect(metadataOnly.binaries, isEmpty);
    expect(metadataOnly.byKey[_fileKey]!.binaryDigest, isNull);
  });

  test(
    'manifest rejects mismatched digest, missing entries and future versions',
    () {
      final source = codec.encode(_bundle());
      expect(
        () => codec.decode(
          _rewriteManifest(source, (manifest) {
            (manifest['objects'] as List).first['digest'] = '0' * 64;
          }),
        ),
        throwsA(error(SelectiveBackupError.invalid)),
      );
      expect(
        () => codec.decode(
          _rewriteManifest(source, (manifest) {
            (manifest['objects'] as List).first['path'] = 'objects/9999.json';
          }),
        ),
        throwsA(error(SelectiveBackupError.invalid)),
      );
      expect(
        () => codec.decode(
          _rewriteManifest(source, (manifest) => manifest['version'] = 99),
        ),
        throwsA(error(SelectiveBackupError.unsupportedVersion)),
      );
    },
  );

  test('unlisted entries, traversal paths and symlinks are rejected without extraction', () {
    final source = codec.encode(_bundle());
    for (final extra in [
      ArchiveFile.string('objects/9999.json', '{}'),
      ArchiveFile.string('../outside.txt', 'untrusted'),
      ArchiveFile.string('objects/9999.json', '../outside.txt')
        ..symbolicLink = '../outside.txt',
    ]) {
      expect(
        () => codec.decode(_rewriteManifest(source, (_) {}, extra: extra)),
        throwsA(isA<SelectiveBackupException>()),
      );
    }
  });

  test('truncated ZIP and undeclared or cyclic dependencies are rejected', () {
    final source = codec.encode(_bundle());
    expect(
      () => codec.decode(Uint8List.sublistView(source, 0, source.length - 10)),
      throwsA(error(SelectiveBackupError.invalid)),
    );
    expect(
      () => SelectiveBackupBundle(
        records: [
          BackupRecord(
            key: _chatKey,
            label: 'Chat',
            data: const {},
            dependencies: const [_fileKey],
          ),
        ],
        roots: const [_chatKey],
      ),
      throwsA(error(SelectiveBackupError.invalid)),
    );
    expect(
      () => SelectiveBackupBundle(
        records: [
          BackupRecord(
            key: _chatKey,
            label: 'Chat',
            data: const {},
            dependencies: const [_fileKey],
          ),
          BackupRecord(
            key: _fileKey,
            label: 'File',
            data: const {},
            dependencies: const [_chatKey],
          ),
        ],
        roots: const [_chatKey],
      ),
      throwsA(error(SelectiveBackupError.invalid)),
    );
  });

  test('cancellation stops encoding and decoding and empty selection remains empty', () {
    final bundle = _bundle();
    final bytes = codec.encode(bundle);
    final token = BackupCancellation()..cancel();
    expect(
      () => codec.encode(bundle, cancellation: token),
      throwsA(error(SelectiveBackupError.cancelled)),
    );
    expect(
      () => codec.decode(bytes, cancellation: token),
      throwsA(error(SelectiveBackupError.cancelled)),
    );
    expect(
      codec.decode(codec.encode(bundle.select(BackupSelection()))).records,
      isEmpty,
    );
  });
}
