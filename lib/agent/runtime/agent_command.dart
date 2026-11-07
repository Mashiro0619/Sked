import '../provider/provider_models.dart';

sealed class AgentExecutionCommand {
  const AgentExecutionCommand(this.conversationId);
  final String conversationId;
}

final class SendAgentMessage extends AgentExecutionCommand {
  const SendAgentMessage(super.conversationId, this.text);
  final String text;
}

final class AcceptAgentHandoff extends AgentExecutionCommand {
  const AcceptAgentHandoff(super.conversationId);
}

final class ContinueAgentRun extends AgentExecutionCommand {
  const ContinueAgentRun(super.conversationId, {this.reservedRunId});
  final String? reservedRunId;
}

final class ConsumeAgentQueue extends AgentExecutionCommand {
  const ConsumeAgentQueue(super.conversationId);
}

final class RegenerateAgentReply extends AgentExecutionCommand {
  const RegenerateAgentReply(super.conversationId, this.messageId);
  final String messageId;
}

final class ReplayAgentHistory extends AgentExecutionCommand {
  const ReplayAgentHistory(
    super.conversationId, {
    required this.batchId,
    this.reservedRunId,
    this.continuedRunId,
  });
  final String batchId;
  final String? reservedRunId, continuedRunId;
}

final class CompactAgentContext extends AgentExecutionCommand {
  const CompactAgentContext(super.conversationId);
}

final class ExecuteAgentHostAction extends AgentExecutionCommand {
  const ExecuteAgentHostAction(super.conversationId, this.call);
  final ProviderToolCall call;
}
