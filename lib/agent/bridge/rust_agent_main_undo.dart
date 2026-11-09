import '../../application/mutation_coordinator.dart';
import '../../application/operation_contracts.dart';
import '../../controllers/app_session.dart';
import '../../utils/unique_id.dart';
import '../history/conversation_history.dart';
import '../history/conversation_main_undo.dart';
import '../history/conversation_redo_coordinator.dart';
import 'generated/api/contracts.dart' as native;
import 'generated/api/models.dart' as view;

/// The explicit history action reuses the business owner's receipt-based undo.
/// Rust owns which messages and knowledge versions are retired after this save.
class RustAgentMainUndo {
  RustAgentMainUndo({required this.session, required this.mutations});

  final AppSession session;
  final MutationCoordinator mutations;
  final _participants = <String, ConversationMainUndoParticipant>{};

  ConversationMainUndoParticipant _participant(String token) =>
      _participants.putIfAbsent(token, () {
        final policy = OperationPolicy()
          ..update(enabled: true, mode: AgentPermissionMode.full);
        final scope = OperationScope(id: token, policy: policy);
        return ConversationMainUndoParticipant(
          mutations: mutations,
          readCommittedData: () => session.committedData,
          scope: () => scope,
        );
      });

  Future<view.ViewUndoTicket> prepare(native.HostRequest request) async {
    if (request.owner != view.ViewOperationStore.main) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'This external effect cannot be undone by editing chat history.',
      );
    }
    final token = generateUuidV4();
    final ticket = await _participant(token)
        .prepare(batchId: token, operationIds: request.operationIds);
    return view.ViewUndoTicket(
      owner: view.ViewOperationStore.main,
      token: ticket.token,
      digest: ticket.digest,
      operationIds: ticket.operationIds,
    );
  }

  Future<Map<String, Object?>> commit(native.HostRequest request) async {
    final nativeTicket = request.ticket!;
    if (nativeTicket.owner != view.ViewOperationStore.main) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'This undo ticket belongs to a different storage owner.',
      );
    }
    final ticket = ConversationUndoTicket(
      owner: ConversationUndoOwner.main,
      token: nativeTicket.token,
      digest: nativeTicket.digest,
      operationIds: nativeTicket.operationIds,
    );
    final participant = _participant(ticket.token);
    final state = await participant.readState(ticket);
    if (state == ConversationUndoState.unknown) {
      throw const OperationProblem(
        OperationErrorCode.outcomeUnknown,
        'The original business receipt must be reconciled before undo.',
      );
    }
    if (state == ConversationUndoState.prepared) {
      await participant.validate(ticket);
      await participant.commit(ticket);
    }
    _participants.remove(ticket.token);
    return {
      'status': 'committed',
      'undoBatchId': ticket.token,
      'operationIds': ticket.operationIds,
    };
  }
}
