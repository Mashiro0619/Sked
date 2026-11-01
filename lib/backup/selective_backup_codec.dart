import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'selective_backup_models.dart';

/// A ZIP with an explicit manifest and checked object/file entries. No archive
/// path is ever extracted to the filesystem or interpreted as a user path.
class SelectiveBackupCodec {
  const SelectiveBackupCodec();
  static const schema = 'sked-selective-backup';
  static const version = 1;
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
        'createdAt': bundle.createdAt.toIso8601String(),
        'roots': bundle.roots.map((key) => key.toJson()).toList(),
        'objects': objects,
        'files': files,
      }),
    );
    if (manifest.length > SelectiveBackupLimits.manifestBytes) {
      backupLimit('The backup manifest is too large.');
    }
    archive.add(
      ArchiveFile.noCompress(manifestPath, manifest.length, manifest),
    );
    final output = _BoundedBackupOutput(
      SelectiveBackupLimits.archiveBytes,
      cancellation,
    );
    ZipEncoder().encodeStream(archive, output, modified: DateTime.utc(2000));
    cancellation?.check();
    return output.getBytes();
  }

  SelectiveBackupBundle decode(
    Uint8List bytes, {
    BackupCancellation? cancellation,
  }) {
    cancellation?.check();
    if (bytes.length > SelectiveBackupLimits.archiveBytes) {
      backupLimit('The backup file is too large.');
    }
    try {
      final expectedEntries = _preflightDirectory(bytes);
      final directory = ZipDirectory()..read(InputMemoryStream(bytes));
      if (directory.fileHeaders.length != expectedEntries) {
        backupInvalid('Incomplete ZIP directory.');
      }
      final entries = <String, ZipFileHeader>{};
      var total = 0;
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
        final budget = path == manifestPath
            ? SelectiveBackupLimits.manifestBytes
            : path.startsWith('objects/')
            ? SelectiveBackupLimits.objectBytes
            : SelectiveBackupLimits.fileBytes;
        if (header.uncompressedSize < 0 || header.uncompressedSize > budget) {
          backupLimit('A ZIP entry exceeds its byte budget.');
        }
        total += header.uncompressedSize;
        if (total > SelectiveBackupLimits.expandedBytes) {
          backupLimit('The expanded backup is too large.');
        }
        entries[path] = header;
      }
      Uint8List readEntry(String path, int max) {
        cancellation?.check();
        final header = entries[path];
        if (header == null) {
          backupInvalid('A manifest entry is absent from the archive.');
        }
        final output = _BoundedBackupOutput(max, cancellation);
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
        utf8.decode(
          readEntry(manifestPath, SelectiveBackupLimits.manifestBytes),
          allowMalformed: false,
        ),
      );
      if (rawManifest is Map &&
          rawManifest['schema'] == schema &&
          rawManifest['version'] != version) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unsupportedVersion,
          'Unsupported selective backup version.',
        );
      }
      final manifest = backupMap(rawManifest, {
        'schema',
        'version',
        'createdAt',
        'roots',
        'objects',
        'files',
      });
      if (manifest['schema'] != schema || manifest['version'] != version) {
        backupInvalid('This is not a selective Sked backup.');
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
      Uint8List readDeclared(
        Map<String, dynamic> entry,
        String prefix,
        int max,
      ) {
        final path = backupText(entry['path'], max: 128);
        final digest = backupText(entry['digest'], max: 64);
        final length = backupInteger(entry['byteLength'], max: max);
        if (!path.startsWith(prefix) ||
            !used.add(path) ||
            !backupDigestIsValid(digest)) {
          backupInvalid('Invalid or duplicate manifest entry.');
        }
        final content = readEntry(path, max);
        if (content.length != length || backupDigest(content) != digest) {
          backupInvalid('Backup content checksum mismatch.');
        }
        return content;
      }

      final records = <BackupRecord>[];
      for (final raw in backupList(manifest['objects'])) {
        final entry = backupMap(raw, {'key', 'path', 'byteLength', 'digest'});
        final content = readDeclared(
          entry,
          'objects/',
          SelectiveBackupLimits.objectBytes,
        );
        final record = BackupRecord.fromJson(
          jsonDecode(utf8.decode(content, allowMalformed: false)),
        );
        if (record.key != BackupObjectKey.fromJson(entry['key'])) {
          backupInvalid('Backup object identity mismatch.');
        }
        records.add(record);
      }
      final binaries = <String, Uint8List>{};
      for (final raw in backupList(manifest['files'])) {
        final entry = backupMap(raw, {'path', 'byteLength', 'digest'});
        final content = readDeclared(
          entry,
          'files/',
          SelectiveBackupLimits.fileBytes,
        );
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
      RegExp(r'^objects/[0-9]{4}\.json$').hasMatch(path) ||
      RegExp(r'^files/[a-f0-9]{64}\.bin$').hasMatch(path);

  /// Bound directory allocation before allowing the ZIP library to parse it.
  /// Backups fit well below ZIP64 and never span disks.
  int _preflightDirectory(Uint8List bytes) {
    final view = ByteData.sublistView(bytes);
    for (
      var offset = bytes.length - 22;
      offset >= math.max(0, bytes.length - 65557);
      offset--
    ) {
      if (view.getUint32(offset, Endian.little) != 0x06054b50) continue;
      final comment = view.getUint16(offset + 20, Endian.little);
      if (offset + 22 + comment != bytes.length) continue;
      final disk = view.getUint16(offset + 4, Endian.little);
      final directoryDisk = view.getUint16(offset + 6, Endian.little);
      final diskCount = view.getUint16(offset + 8, Endian.little);
      final count = view.getUint16(offset + 10, Endian.little);
      final size = view.getUint32(offset + 12, Endian.little);
      final start = view.getUint32(offset + 16, Endian.little);
      if (disk != 0 ||
          directoryDisk != 0 ||
          count != diskCount ||
          count < 1 ||
          count > SelectiveBackupLimits.entries ||
          size > 8 * 1024 * 1024 ||
          start + size != offset ||
          start < 0) {
        backupInvalid('Unsupported or oversized ZIP directory.');
      }
      return count;
    }
    backupInvalid('The ZIP directory is missing or truncated.');
  }
}

class _BoundedBackupOutput extends OutputMemoryStream {
  _BoundedBackupOutput(this.maxBytes, this.cancellation)
    : super(size: math.min(maxBytes, 32768));
  final int maxBytes;
  final BackupCancellation? cancellation;
  void _check(int count) {
    cancellation?.check();
    if (count < 0 || length + count > maxBytes) {
      backupLimit('Backup encoding or decoding exceeded its byte budget.');
    }
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
