import 'dart:io';

import 'package:path/path.dart' as path;

import '../../services/app_storage_layout_io.dart';
import 'attachment_models.dart';
import 'attachment_storage.dart';

class PlatformAttachmentStorage extends AttachmentStorage {
  PlatformAttachmentStorage({AppStorageLayout? layout})
    : _layout = layout ?? AppStorageLayout(),
      super.base();
  final AppStorageLayout _layout;
  Future<Directory> _directory() async => Directory(
    path.join((await _layout.directory()).path, 'Sked_agent_attachments'),
  );
  Future<File> _file(String id) async {
    if (!validAttachmentId(id)) {
      throw const AttachmentException(AttachmentError.invalidMetadata);
    }
    return File(path.join((await _directory()).path, '$id.bin'));
  }

  @override
  Future<void> write(String id, Stream<List<int>> bytes) async {
    final file = await _file(id);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.pending');
    final handle = await temporary.open(mode: FileMode.write);
    try {
      var count = 0;
      await for (final chunk in bytes) {
        count += chunk.length;
        if (count > ConversationAttachment.maxFileBytes) {
          throw const AttachmentException(AttachmentError.tooLarge);
        }
        await handle.writeFrom(chunk);
      }
      await handle.flush();
    } catch (_) {
      await handle.close();
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    await handle.close();
    if (await file.exists()) {
      // IDs are unique; a retry is verified by the repository before writing.
      await temporary.delete();
      throw const AttachmentException(AttachmentError.conflict);
    }
    await temporary.rename(file.path);
  }

  @override
  Stream<List<int>> read(String id) async* {
    final file = await _file(id);
    if (!await file.exists()) {
      throw const AttachmentException(AttachmentError.missing);
    }
    if (await file.length() > ConversationAttachment.maxFileBytes) {
      throw const AttachmentException(AttachmentError.tooLarge);
    }
    yield* file.openRead();
  }

  @override
  Future<Set<String>> ids() async {
    final directory = await _directory();
    if (!await directory.exists()) return {};
    final result = <String>{};
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = path.basename(entity.path);
      final id = name.endsWith('.bin.pending')
          ? name.substring(0, name.length - '.bin.pending'.length)
          : name.endsWith('.bin')
          ? name.substring(0, name.length - 4)
          : '';
      if (validAttachmentId(id)) result.add(id);
    }
    return result;
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    final pending = File('${file.path}.pending');
    if (await pending.exists()) await pending.delete();
    if (await file.exists()) await file.delete();
    if (await file.exists() || await pending.exists()) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
  }
}
