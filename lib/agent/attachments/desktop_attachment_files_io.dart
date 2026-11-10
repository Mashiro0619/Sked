import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';

import '../../services/desktop_file_actions.dart';
import '../../services/export_service.dart';
import 'agent_attachment_controller.dart';

/// Verified private content is materialized under its display filename before
/// handing it to an external program. Successful copies belong to the system
/// temporary cache, so leaving a chat does not remove a file opened elsewhere.
class DesktopAttachmentFiles {
  const DesktopAttachmentFiles();

  static final _copies =
      Expando<Map<(String, String, int, String), SavedDesktopFile>>();

  Future<SavedDesktopFile> prepare(
    AgentAttachmentFileReader reader,
    ConversationAttachment attachment, {
    required AttachmentCancellation cancellation,
  }) async {
    attachment.validate();
    if (!DesktopFileActions.supported) {
      throw const AttachmentException(AttachmentError.unsupported);
    }
    final source = reader.fileSession;
    void check() {
      cancellation.check();
      if (!identical(source, reader.fileSession)) {
        throw const AttachmentException(AttachmentError.conflict);
      }
    }

    check();
    final copies = _copies[source] ??= {};
    final key = (
      attachment.id,
      attachment.name,
      attachment.byteLength,
      attachment.digest,
    );
    final existing = copies[key];
    if (existing != null &&
        await _matchesAttachment(existing, attachment, cancellation)) {
      check();
      return existing;
    }
    final root = await getTemporaryDirectory();
    check();
    final directory = await root.createTemp('sked-agent-open-');
    try {
      check();
      final destination = paths.join(
        directory.path,
        _filename(attachment.name),
      );
      await reader.copyToFile(
        attachment,
        destination,
        cancellation: cancellation,
      );
      check();
      final file = SavedDesktopFile.fromResult(
        ExportSaveResult(status: ExportSaveStatus.saved, path: destination),
      );
      if (file == null) {
        throw const AttachmentException(AttachmentError.unavailable);
      }
      copies[key] = file;
      return file;
    } catch (_) {
      // copyToFile closes its writer before returning even when cancelled.
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        // The system owns eventual cleanup if a scanner still holds the file.
      }
      rethrow;
    }
  }
}

Future<bool> _matchesAttachment(
  SavedDesktopFile file,
  ConversationAttachment attachment,
  AttachmentCancellation cancellation,
) async {
  final digest = _DesktopCopyDigest();
  final hashing = sha256.startChunkedConversion(digest);
  RandomAccessFile? input;
  var count = 0;
  try {
    cancellation.check();
    input = await File(file.path).open();
    if (await input.length() != attachment.byteLength) return false;
    while (true) {
      cancellation.check();
      final bytes = await input.read(65536);
      cancellation.check();
      if (bytes.isEmpty) break;
      count += bytes.length;
      if (count > attachment.byteLength) return false;
      hashing.add(bytes);
    }
  } on FileSystemException {
    return false;
  } finally {
    hashing.close();
    await input?.close();
  }
  cancellation.check();
  return count == attachment.byteLength &&
      digest.value.toString() == attachment.digest;
}

class _DesktopCopyDigest implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

String _filename(String original) {
  var name = original;
  if (Platform.isWindows) {
    name = name.replaceAll(RegExp(r'[<>:"|?*]'), '_');
    name = name.replaceFirst(RegExp(r'[. ]+$'), '');
    if (RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\.|$)',
      caseSensitive: false,
    ).hasMatch(name)) {
      name = '_$name';
    }
  }
  return name.isEmpty || name == '.' || name == '..' ? 'attachment' : name;
}
