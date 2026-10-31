import 'dart:convert';
import 'dart:io';

import '../../services/app_storage_layout_io.dart';
import 'knowledge_models.dart';
import 'knowledge_storage.dart';

class PlatformKnowledgeStorage extends KnowledgeStorage {
  PlatformKnowledgeStorage({AppStorageLayout? layout})
    : _layout = layout ?? AppStorageLayout(),
      super.base();
  final AppStorageLayout _layout;
  Future<File> _file(int slot) =>
      _layout.file('Sked_agent_knowledge.$slot.json');
  Future<String?> _read(File file) async {
    if (!await file.exists()) return null;
    if (await file.length() > KnowledgeLimits.archiveBytes * 2 + 1024) {
      throw const KnowledgeException(
        KnowledgeError.unavailable,
        'Knowledge storage exceeds its budget.',
      );
    }
    try {
      return utf8.decode(await file.readAsBytes(), allowMalformed: false);
    } on FormatException {
      return '{invalid-encoding';
    }
  }

  @override
  Future<KnowledgeStorageLoad> load() async => decodeKnowledgeSlots([
    await _read(await _file(0)),
    await _read(await _file(1)),
  ]);
  @override
  Future<void> save(KnowledgeArchive archive) async {
    final encoded = encodeKnowledgeSlot(archive);
    final files = [
      await _file(archive.revision % 2),
      await _file((archive.revision + 1) % 2),
    ];
    try {
      // Mirror successful deletes: recovery cannot revive an older live copy.
      for (final file in files) {
        await file.writeAsString(encoded, flush: true);
        if (await _read(file) != encoded) {
          throw StateError('Knowledge readback failed.');
        }
      }
    } catch (_) {
      try {
        if ((await Future.wait(files.map(_read)))
            .every((value) => value == encoded)) {
          return;
        }
      } catch (_) {
        // The caller must reload before accepting another write.
      }
      throw const KnowledgeException(
        KnowledgeError.unknown,
        'Knowledge write could not be confirmed. Reload before continuing.',
      );
    }
  }
}
