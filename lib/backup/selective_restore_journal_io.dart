import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../services/app_storage_layout_io.dart';
import 'selective_backup_models.dart';
import 'selective_restore_journal.dart';

class PlatformSelectiveJournalStorage implements SelectiveJournalStorage {
  PlatformSelectiveJournalStorage({AppStorageLayout? layout})
    : _layout = layout ?? AppStorageLayout();
  final AppStorageLayout _layout;
  Future<File> _file(int slot) =>
      _layout.file('Sked_selective_restore.$slot.json');
  @override
  Future<List<String?>> readSlots() async {
    final result = <String?>[];
    for (var slot = 0; slot < 2; slot++) {
      final file = await _file(slot);
      if (!await file.exists()) {
        result.add(null);
        continue;
      }
      if (await file.length() > SelectiveBackupLimits.journalBytes) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unavailable,
          'The restore journal exceeds its byte budget.',
        );
      }
      try {
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in file.openRead()) {
          if (bytes.length + chunk.length >
              SelectiveBackupLimits.journalBytes) {
            throw const SelectiveBackupException(
              SelectiveBackupError.unavailable,
              'The restore journal exceeds its byte budget.',
            );
          }
          bytes.add(chunk);
        }
        result.add(utf8.decode(bytes.takeBytes(), allowMalformed: false));
      } on FormatException {
        result.add('{invalid-encoding');
      }
    }
    return result;
  }

  @override
  Future<void> writeSlot(int slot, String source) async {
    await (await _file(slot)).writeAsString(source, flush: true);
  }
}
