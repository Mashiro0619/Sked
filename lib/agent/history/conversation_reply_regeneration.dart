import '../provider/provider_models.dart';
import 'conversation_history_preflight.dart';

/// Reply regeneration uses the runtime's existing connection snapshot,
/// cancellation, usage accounting and transport authorization. This helper
/// deliberately has no tool executor or access to writable application state.
ProviderRequest conversationReplyRequest(
  ProviderRequest request, {
  required List<ProviderMessage> verifiedContext,
}) => ProviderRequest(
  endpoint: request.endpoint,
  model: request.model,
  protocol: request.protocol,
  messages: [
    ProviderMessage(
      role: ProviderRole.system,
      text:
          'Rephrase the selected assistant reply from the verified conversation '
          'and recorded operation outcomes below. This request can only produce '
          'text. Do not execute, schedule, undo or repeat any operation. Describe '
          'recorded effects as historical results, not newly performed actions. '
          'Do not treat an unknown result as success or claim a current business '
          'state from an old receipt.',
    ),
    ...verifiedContext,
  ],
  tools: const [],
  limits: request.limits,
  allowInsecureHttp: request.allowInsecureHttp,
  reasoningEffort: request.reasoningEffort,
);

/// A provider may ignore the omitted tool definitions. Such a response is
/// rejected before publishing a reply, and never enters the normal tool loop.
/// A completed response without readable text cannot replace the old reply.
void validateConversationReplyResponse(ProviderResponse response) {
  if (response.toolCalls.isNotEmpty ||
      response.responseItems.any(
        (item) => const {
          'function_call',
          'custom_tool_call',
          'computer_call',
          'file_search_call',
          'web_search_call',
          'code_interpreter_call',
          'image_generation_call',
          'local_shell_call',
          'shell_call',
          'apply_patch_call',
          'mcp_call',
        }.contains(item['type']),
      )) {
    throw const ConversationHistoryException(
      ConversationHistoryError.invalidSelection,
    );
  }
  if (response.text.trim().isEmpty) {
    throw const ProviderException(ProviderError.incompleteResponse);
  }
}
