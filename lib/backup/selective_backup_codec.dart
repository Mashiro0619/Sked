import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'selective_backup_models.dart';

/// A ZIP with an explicit manifest and checked object/file entries. No archive
/// path is ever extracted to the filesystem or interpreted as a user path.
class SelectiveBackupCodec {
  const SelectiveBackupCodec();
  static const schema = 'sked-selective-backup';
  static const version = 2;
  static const agentSchema = 'sked-agent-records';
  static const agentVersion = 1;
  static const manifestPath = 'manifest.json';

  Uint8List encode(
    SelectiveBackupBundle bundle, {
    BackupCancellation? cancellation,
  }) {
    cancellation?.check();
    final archive = Archive();
    final objects = <Map<String, Object?>>[];
    for (var index = 0; index < bundle.records.length; index++) {
      cancellation?.check();
      final record = bundle.records[index];
      final path = 'objects/${index.toString().padLeft(4, '0')}.json';
      final bytes = utf8.encode(jsonEncode(record.toJson()));
      objects.add({
        'key': record.key.toJson(),
        'path': path,
        'byteLength': bytes.length,
        'digest': backupDigest(bytes),
      });
      archive.add(ArchiveFile.noCompress(path, bytes.length, bytes));
    }
    final files = <Map<String, Object?>>[];
    for (final entry in bundle.binaries.entries) {
      cancellation?.check();
      final path = 'files/${entry.key}.bin';
      files.add({
        'path': path,
        'byteLength': entry.value.length,
        'digest': entry.key,
      });
      archive.add(
        ArchiveFile.noCompress(path, entry.value.length, entry.value),
      );
    }
    final manifest = utf8.encode(
      jsonEncode({
        'schema': schema,
        'version': version,
        'agentSchema': agentSchema,
        'agentVersion': agentVersion,
        'createdAt': bundle.createdAt.toIso8601String(),
        'roots': bundle.roots.map((key) => key.toJson()).toList(),
        'objects': objects,
        'files': files,
      }),
    );
    archive.add(
      ArchiveFile.noCompress(manifestPath, manifest.length, manifest),
    );
    final output = _CancellableBackupOutput(cancellation);
    ZipEncoder().encodeStream(archive, output, modified: DateTime.utc(2000));
    cancellation?.check();
    return output.getBytes();
  }

  SelectiveBackupBundle decode(
    Uint8List bytes, {
    BackupCancellation? cancellation,
  }) {
    cancellation?.check();
    try {
      final directory = ZipDirectory()..read(InputMemoryStream(bytes));
      final entries = <String, ZipFileHeader>{};
      for (final header in directory.fileHeaders) {
        cancellation?.check();
        final path = header.filename;
        final local = header.file;
        if (local == null ||
            local.filename != path ||
            local.uncompressedSize != header.uncompressedSize ||
            (local.flags & 1) != 0 ||
            (header.generalPurposeBitFlag & 1) != 0 ||
            header.diskNumberStart != 0 ||
            !const [0, 8].contains(header.compressionMethod) ||
            ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000 ||
            !_validEntryPath(path) ||
            entries.containsKey(path)) {
          backupInvalid('Invalid, duplicate, linked, or encrypted ZIP entry.');
        }
        entries[path] = header;
      }
      Uint8List readEntry(String path) {
        cancellation?.check();
        final header = entries[path];
        if (header == null) {
          backupInvalid('A manifest entry is absent from the archive.');
        }
        final output = _CancellableBackupOutput(cancellation);
        header.file!.decompress(output);
        final content = output.getBytes();
        if (content.length != header.uncompressedSize ||
            getCrc32(content) != header.crc32) {
          backupInvalid(
            'ZIP content does not match its declared length or checksum.',
          );
        }
        return content;
      }

      final rawManifest = jsonDecode(
        utf8.decode(readEntry(manifestPath), allowMalformed: false),
      );
      if (rawManifest is Map &&
          rawManifest['schema'] == schema &&
          rawManifest['version'] != version &&
          rawManifest['version'] != 1) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unsupportedVersion,
          'Unsupported selective backup version.',
        );
      }
      final legacy = rawManifest is Map && rawManifest['version'] == 1;
      final manifest = backupMap(rawManifest, {
        'schema',
        'version',
        if (!legacy) 'agentSchema',
        if (!legacy) 'agentVersion',
        'createdAt',
        'roots',
        'objects',
        'files',
      });
      if (manifest['schema'] != schema) {
        backupInvalid('This is not a selective Sked backup.');
      }
      if (!legacy &&
          (manifest['agentSchema'] != agentSchema ||
              manifest['agentVersion'] != agentVersion)) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unsupportedVersion,
          'Unsupported Agent backup format.',
        );
      }
      final date = DateTime.tryParse(
        backupText(manifest['createdAt'], max: 64),
      );
      if (date == null || !date.isUtc) {
        backupInvalid('Invalid backup timestamp.');
      }
      final roots = backupList(manifest['roots'])
          .map(BackupObjectKey.fromJson)
          .toList();
      if (roots.toSet().length != roots.length) {
        backupInvalid('Duplicate backup selection.');
      }
      final used = <String>{manifestPath};
      Uint8List readDeclared(Map<String, dynamic> entry, String prefix) {
        final path = backupText(entry['path'], max: 128);
        final digest = backupText(entry['digest'], max: 64);
        final length = backupInteger(entry['byteLength']);
        if (!path.startsWith(prefix) ||
            !used.add(path) ||
            !backupDigestIsValid(digest)) {
          backupInvalid('Invalid or duplicate manifest entry.');
        }
        final content = readEntry(path);
        if (content.length != length || backupDigest(content) != digest) {
          backupInvalid('Backup content checksum mismatch.');
        }
        return content;
      }

      final records = <BackupRecord>[];
      for (final raw in backupList(manifest['objects'])) {
        final entry = backupMap(raw, {'key', 'path', 'byteLength', 'digest'});
        final key = BackupObjectKey.fromJson(entry['key']);
        if (legacy &&
            const {
              BackupObjectKind.conversation,
              BackupObjectKind.attachment,
              BackupObjectKind.skill,
              BackupObjectKind.memory,
            }.contains(key.kind)) {
          throw const SelectiveBackupException(
            SelectiveBackupError.unsupportedVersion,
            'This backup contains the retired Agent format. Export its business groups separately.',
          );
        }
        final content = readDeclared(entry, 'objects/');
        final record = BackupRecord.fromJson(
          jsonDecode(utf8.decode(content, allowMalformed: false)),
        );
        if (record.key != key) {
          backupInvalid('Backup object identity mismatch.');
        }
        records.add(record);
      }
      final binaries = <String, Uint8List>{};
      for (final raw in backupList(manifest['files'])) {
        final entry = backupMap(raw, {'path', 'byteLength', 'digest'});
        final content = readDeclared(entry, 'files/');
        final digest = entry['digest'] as String;
        if (entry['path'] != 'files/$digest.bin' ||
            binaries.containsKey(digest)) {
          backupInvalid('Invalid backup binary identity.');
        }
        binaries[digest] = content;
      }
      if (used.length != entries.length) {
        backupInvalid('The archive contains undeclared entries.');
      }
      cancellation?.check();
      return SelectiveBackupBundle(
        records: records,
        roots: roots,
        binaries: binaries,
        createdAt: date,
      );
    } on SelectiveBackupException {
      rethrow;
    } catch (_) {
      backupInvalid('The backup archive is damaged or invalid.');
    }
  }

  bool _validEntryPath(String path) =>
      path == manifestPath ||
      RegExp(r'^objects/[0-9]{4,}\.json$').hasMatch(path) ||
      RegExp(r'^files/[a-f0-9]{64}\.bin$').hasMatch(path);
}

class _CancellableBackupOutput extends OutputMemoryStream {
  _CancellableBackupOutput(this.cancellation) : super(size: 32768);
  final BackupCancellation? cancellation;
  void _check(int count) {
    cancellation?.check();
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }
}
