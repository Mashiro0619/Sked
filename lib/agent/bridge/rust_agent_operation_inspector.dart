import 'dart:convert';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart';
import '../../application/operation_contracts.dart';
import '../../controllers/app_session.dart';
import 'generated/api/contracts.dart' as native;
import 'generated/api/models.dart' as view;

/// Resolves a native operation only from its business owner's durable receipt.
class RustAgentOperationInspector {
  const RustAgentOperationInspector({
    required this.session,
    required this.mutations,
    required this.external,
    this.reconcileExternal,
  });

  final AppSession session;
  final MutationCoordinator mutations;
  final ExternalOperationCoordinator external;
  final Future<Map<String, Object?>?> Function(String operationId)?
  reconcileExternal;

  Future<Map<String, Object?>> read(native.HostRequest request) async {
    final id = request.operationIds.singleOrNull;
    if (id == null || id.isEmpty) {
      return _unknown(id, 'The original operation identity is missing.');
    }
    if (session.repository.current == null ||
        !session.repository.canWrite ||
        session.repository.isWriteStateUnknown) {
      return _unknown(
        id,
        'Recover the business storage before checking this operation.',
      );
    }
    try {
      final raw = request.arguments == null
          ? null
          : jsonDecode(request.arguments!.json);
      final details = raw is Map ? raw : const <String, Object?>{};
      if (details['operationId'] != null && details['operationId'] != id) {
        return _unknown(id, 'The recorded operation identities do not match.');
      }
      final generation = details['generation'];
      if (generation != null && generation != id.split('/').first) {
        return _unknown(
          id,
          'The recorded operation generation does not match.',
        );
      }
      final receipt = switch (request.owner) {
        view.ViewOperationStore.main => mutations.status(id),
        view.ViewOperationStore.external_ => external.status(id),
        _ => null,
      };
      if (request.owner != view.ViewOperationStore.main &&
          request.owner != view.ViewOperationStore.external_) {
        return _unknown(id, 'This receipt belongs to another storage owner.');
      }
      if (receipt == null) {
        // The status methods reject stale generations. In a known current
        // generation, absence proves that this exact operation never committed.
        return {'operationId': id, 'status': 'not_executed', 'recovered': true};
      }
      if (request.owner == view.ViewOperationStore.main &&
          receipt.result['kind'] == 'external') {
        return _unknown(
          id,
          'The durable receipt belongs to an external operation.',
        );
      }
      if (request.owner == view.ViewOperationStore.external_) {
        final recovered = await reconcileExternal?.call(id);
        if (recovered != null) {
          return {
            ...projectExternalOperationResult(recovered),
            'operationId': id,
            'recovered': true,
          };
        }
      }
      return {
        ...projectExternalOperationResult(receipt.result),
        'operationId': receipt.operationId,
        'completedAt': receipt.completedAtIso,
        'replayed': true,
        'recovered': true,
      };
    } on OperationProblem catch (error) {
      return _unknown(id, error.message);
    } on FormatException {
      return _unknown(id, 'The recorded operation metadata cannot be read.');
    }
  }
}

Map<String, Object?> _unknown(String? operationId, String message) => {
  'operationId': ?operationId,
  'status': 'outcome_unknown',
  'recoveryRequired': true,
  'error': {'code': 'outcomeUnknown', 'message': message},
};
