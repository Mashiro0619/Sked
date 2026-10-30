import '../models/app_data.dart';
import '../models/app_data_commit.dart';
import '../models/application_ledger.dart';
import '../utils/unique_id.dart';

enum AgendaEffectState {
  pending,
  applied,
  superseded,
  failed,
  unknown,
  blocked,
  unsupported,
  notRequired,
}

/// An observation about one durable commit's notification projection. An
/// applied projection is not evidence that the OS delivered a notification.
class AgendaEffectTicket {
  const AgendaEffectTicket({
    required this.id,
    required this.generation,
    required this.desiredRevision,
    required this.agendaVersion,
    required this.projectionEpoch,
    required this.state,
    this.details = const {},
  });

  final String id;
  final String generation;
  final int desiredRevision;
  final int agendaVersion;
  final int projectionEpoch;
  final AgendaEffectState state;
  final Map<String, Object?> details;

  AgendaEffectTicket withState(
    AgendaEffectState value, {
    Map<String, Object?> details = const {},
  }) => AgendaEffectTicket(
    id: id,
    generation: generation,
    desiredRevision: desiredRevision,
    agendaVersion: agendaVersion,
    projectionEpoch: projectionEpoch,
    state: value,
    details: Map.unmodifiable(details),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': 'notifications',
    'generation': generation,
    'desiredRevision': desiredRevision,
    'agendaVersion': agendaVersion,
    'projectionEpoch': projectionEpoch,
    'state': state.name,
    'deliveryObserved': false,
    ...details,
  };
}

/// Bounded observations owned by one foreground coordinator. Durable business
/// receipts survive this tracker; missing or evicted observations are unknown,
/// never inferred from the service's most recent global status.
class AgendaEffectTracker {
  static const maxTickets = 256;

  final String _sessionId = generateUuidV4();
  final _tickets = <int, AgendaEffectTicket>{};
  final _operations = <String, int>{};
  Set<String> _knownOperations = {};
  bool _closed = false;

  void seed(AppData data) {
    _knownOperations = {
      for (final receipt
          in data.applicationLedger?.receipts ?? const <OperationReceipt>[])
        receipt.operationId,
    };
  }

  AgendaEffectTicket observe(
    AppDataCommit commit, {
    required int projectionEpoch,
    required bool requiresProjection,
  }) {
    final ledger = commit.snapshot.applicationLedger;
    final ticket = AgendaEffectTicket(
      id: '$_sessionId/${commit.revision}/notifications',
      generation: ledger?.generation ?? _sessionId,
      desiredRevision: commit.revision,
      agendaVersion: commit.versions.agenda,
      projectionEpoch: projectionEpoch,
      state: requiresProjection
          ? AgendaEffectState.pending
          : AgendaEffectState.notRequired,
    );
    _tickets[commit.revision] = ticket;
    for (final receipt in ledger?.receipts ?? const <OperationReceipt>[]) {
      if (!_knownOperations.contains(receipt.operationId) &&
          receipt.result['kind'] != 'external') {
        _operations[receipt.operationId] = commit.revision;
      }
    }
    seed(commit.snapshot);
    while (_tickets.length > maxTickets) {
      final removed = _tickets.keys.first;
      _tickets.remove(removed);
      _operations.removeWhere((_, revision) => revision == removed);
    }
    return ticket;
  }

  AgendaEffectTicket? forRevision(int revision) => _tickets[revision];

  Map<String, Object?>? forOperation(String operationId) {
    final ticket = _tickets[_operations[operationId]];
    if (ticket == null) return null;
    return {
      ...ticket.toJson(),
      'id': '$operationId/notifications',
      'operationId': operationId,
    };
  }

  void complete(
    int? revision,
    AgendaEffectState state, {
    Map<String, Object?> details = const {},
  }) {
    final previous = _tickets[revision];
    if (_closed ||
        previous == null ||
        previous.state == AgendaEffectState.superseded ||
        previous.state == AgendaEffectState.notRequired) {
      return;
    }
    _tickets[revision!] = previous.withState(state, details: details);
  }

  void supersedePending() {
    for (final entry in _tickets.entries.toList()) {
      if (entry.value.state == AgendaEffectState.pending ||
          entry.value.state == AgendaEffectState.failed) {
        _tickets[entry.key] = entry.value.withState(
          AgendaEffectState.superseded,
        );
      }
    }
  }

  void close() {
    _closed = true;
    for (final entry in _tickets.entries.toList()) {
      if (entry.value.state == AgendaEffectState.pending) {
        _tickets[entry.key] = entry.value.withState(AgendaEffectState.unknown);
      }
    }
  }
}
