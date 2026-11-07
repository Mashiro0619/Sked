import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../services/app_storage_layout_io.dart';
import 'agent_store_cutover.dart';

Future<Directory> _root(String? directoryPath) async => directoryPath == null
    ? AppStorageLayout().directory()
    : Directory(directoryPath);

Future<LegacyAgentCutoverEvidence> readLegacyAgentCutoverEvidence({
  String? directoryPath,
}) async {
  final root = await _root(directoryPath);
  Future<String?> read(String name) async {
    final file = File(path.join(root.path, name));
    return await file.exists() ? file.readAsString() : null;
  }

  return decodeLegacyAgentCutoverEvidence(
    [
      await read('Sked_agent_conversations.0.json'),
      await read('Sked_agent_conversations.1.json'),
    ],
    await read('Sked_agent_conversations.pending'),
    knowledgeSlots: [
      await read('Sked_agent_knowledge.0.json'),
      await read('Sked_agent_knowledge.1.json'),
    ],
  );
}

Future<void> retireLegacyAgentData({String? directoryPath}) async {
  await _removeLegacyArtifacts(directoryPath, const [
    'Sked_agent_conversations.0.json',
    'Sked_agent_conversations.1.json',
    'Sked_agent_conversations.pending',
    'Sked_agent_knowledge.0.json',
    'Sked_agent_knowledge.1.json',
  ]);
}

Future<void> retireLegacyAgentAttachments({String? directoryPath}) =>
    _removeLegacyArtifacts(directoryPath, const ['Sked_agent_attachments']);

Future<void> _removeLegacyArtifacts(
  String? directoryPath,
  List<String> names,
) async {
  final root = await _root(directoryPath);
  for (final name in names) {
    final target = path.join(root.path, name);
    switch (await FileSystemEntity.type(target, followLinks: false)) {
      case FileSystemEntityType.notFound:
        break;
      case FileSystemEntityType.file:
        await File(target).delete();
      case FileSystemEntityType.directory:
        await Directory(target).delete(recursive: true);
      case FileSystemEntityType.link:
        await Link(target).delete();
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        throw FileSystemException(
          'Unsupported retired Agent artifact.',
          target,
        );
    }
  }
}
