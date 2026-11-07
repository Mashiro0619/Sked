import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/app_storage_keys.dart';
import '../attachments/attachment_storage.dart';
import 'agent_store_cutover.dart';

Future<LegacyAgentCutoverEvidence> readLegacyAgentCutoverEvidence({
  String? directoryPath,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return decodeLegacyAgentCutoverEvidence(
    [
      prefs.getString('${agentConversationsWebStorageKeyPrefix}0'),
      prefs.getString('${agentConversationsWebStorageKeyPrefix}1'),
    ],
    prefs.getString('${agentConversationsWebStorageKeyPrefix}pending'),
    knowledgeSlots: [
      prefs.getString('sked.agent.knowledge.v1.0'),
      prefs.getString('sked.agent.knowledge.v1.1'),
    ],
  );
}

Future<void> retireLegacyAgentData({String? directoryPath}) async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in const [
    '${agentConversationsWebStorageKeyPrefix}0',
    '${agentConversationsWebStorageKeyPrefix}1',
    '${agentConversationsWebStorageKeyPrefix}pending',
    'sked.agent.knowledge.v1.0',
    'sked.agent.knowledge.v1.1',
  ]) {
    if (!await prefs.remove(key)) {
      throw StateError('Could not retire Agent preference $key.');
    }
  }
}

Future<void> retireLegacyAgentAttachments({String? directoryPath}) async {
  final files = AttachmentStorage();
  try {
    for (final id in await files.ids()) {
      await files.delete(id);
    }
  } finally {
    await files.close();
  }
}
