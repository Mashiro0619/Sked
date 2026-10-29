import 'dart:collection';
import 'dart:convert';

import '../utils/time_utils.dart';

/// These are admission limits, never truncation limits. An oversized result or
/// undo is rejected before the command's durable snapshot is written.
const operationReceiptMaxJsonBytes = 1024 * 1024;
const operationReceiptMaxJsonDepth = 32;
const operationReceiptMaxJsonNodes = 100000;
const applicationLedgerMaxReceipts = 128;
const applicationLedgerMaxBytes = 4 * 1024 * 1024;
const _maxSafeSequence = 9007199254740991;

class OperationReceipt {
  factory OperationReceipt({
    required String operationId,
    required int sequence,
    required String commandDigest,
    required String completedAtIso,
    required Map<String, Object?> result,
    Map<String, Object?>? undo,
  }) {
    if (operationId.trim().isEmpty || operationId.length > 256) {
      throw const FormatException('Operation receipt id is invalid.');
    }
    if (sequence < 1 || sequence >= _maxSafeSequence) {
      throw const FormatException('Operation receipt sequence is invalid.');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(commandDigest)) {
      throw const FormatException('Operation receipt digest is invalid.');
    }
    final timestamp = RegExp(
      r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(Z|[+-](\d{2}):(\d{2}))$',
    ).firstMatch(completedAtIso);
    if (timestamp == null ||
        tryParseStrictIsoDateTime(completedAtIso) == null ||
        (timestamp.group(2) != null &&
            (int.parse(timestamp.group(2)!) > 23 ||
                int.parse(timestamp.group(3)!) > 59))) {
      throw const FormatException(
        'Operation receipt completion time is invalid.',
      );
    }
    final budget = _JsonBudget();
    final frozenResult = budget.freezeObject(result);
    final frozenUndo = undo == null ? null : budget.freezeObject(undo);
    if (utf8
            .encode(jsonEncode({'result': frozenResult, 'undo': frozenUndo}))
            .length >
        operationReceiptMaxJsonBytes) {
      throw const FormatException('Operation receipt JSON is too large.');
    }
    return OperationReceipt._(
      operationId: operationId,
      sequence: sequence,
      commandDigest: commandDigest,
      completedAtIso: completedAtIso,
      result: frozenResult,
      undo: frozenUndo,
    );
  }

  const OperationReceipt._({
    required this.operationId,
    required this.sequence,
    required this.commandDigest,
    required this.completedAtIso,
    required this.result,
    required this.undo,
  });

  final String operationId;
  final int sequence;
  final String commandDigest;
  final String completedAtIso;
  final Map<String, Object?> result;
  final Map<String, Object?>? undo;

  factory OperationReceipt.fromJson(Object? value) {
    final json = _exactObject(value, const {
      'operationId',
      'sequence',
      'commandDigest',
      'completedAtIso',
      'result',
      'undo',
    });
    if (json['operationId'] is! String ||
        json['sequence'] is! int ||
        json['commandDigest'] is! String ||
        json['completedAtIso'] is! String) {
      throw const FormatException('Operation receipt metadata is invalid.');
    }
    return OperationReceipt(
      operationId: json['operationId'] as String,
      sequence: json['sequence'] as int,
      commandDigest: json['commandDigest'] as String,
      completedAtIso: json['completedAtIso'] as String,
      result: _stringObject(json['result']),
      undo: json['undo'] == null ? null : _stringObject(json['undo']),
    );
  }

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'sequence': sequence,
    'commandDigest': commandDigest,
    'completedAtIso': completedAtIso,
    'result': result,
    'undo': undo,
  };

  @override
  bool operator ==(Object other) =>
      other is OperationReceipt &&
      operationId == other.operationId &&
      sequence == other.sequence &&
      commandDigest == other.commandDigest &&
      completedAtIso == other.completedAtIso &&
      _jsonEquals(result, other.result) &&
      _jsonEquals(undo, other.undo);

  @override
  int get hashCode => Object.hash(
    operationId,
    sequence,
    commandDigest,
    completedAtIso,
    _jsonHash(result),
    _jsonHash(undo),
  );
}

/// A generation is supplied by the host exactly when a new data session is
/// initialized. Decoding and schema migration never generate random identity.
class ApplicationLedger {
  factory ApplicationLedger({
    required String generation,
    int nextSequence = 1,
    List<OperationReceipt> receipts = const [],
  }) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(generation)) {
      throw const FormatException('Application ledger generation is invalid.');
    }
    if (nextSequence < 1 ||
        nextSequence > _maxSafeSequence ||
        receipts.length > applicationLedgerMaxReceipts) {
      throw const FormatException('Application ledger bounds are invalid.');
    }
    final ids = <String>{};
    var expected = nextSequence - receipts.length;
    if (expected < 1 || (receipts.isEmpty && nextSequence != 1)) {
      throw const FormatException('Application ledger sequence is incomplete.');
    }
    for (final receipt in receipts) {
      if (receipt.sequence != expected || !ids.add(receipt.operationId)) {
        throw const FormatException(
          'Application ledger receipts are not ordered and unique.',
        );
      }
      expected++;
    }
    if (_receiptsByteLength(receipts) > applicationLedgerMaxBytes) {
      throw const FormatException(
        'Application ledger exceeds its byte budget.',
      );
    }
    return ApplicationLedger._(
      generation: generation,
      nextSequence: nextSequence,
      receipts: List.unmodifiable(receipts),
    );
  }

  const ApplicationLedger._({
    required this.generation,
    required this.nextSequence,
    required this.receipts,
  });

  final String generation;
  final int nextSequence;
  final List<OperationReceipt> receipts;

  OperationReceipt? receiptFor(String operationId) {
    for (final receipt in receipts) {
      if (receipt.operationId == operationId) return receipt;
    }
    return null;
  }

  ApplicationLedger append(OperationReceipt receipt) {
    if (receipt.sequence != nextSequence ||
        receiptFor(receipt.operationId) != null) {
      throw const FormatException('Operation receipt cannot be appended.');
    }
    final next = [...receipts, receipt];
    while (next.length > applicationLedgerMaxReceipts ||
        _receiptsByteLength(next) > applicationLedgerMaxBytes) {
      next.removeAt(0);
    }
    return ApplicationLedger(
      generation: generation,
      nextSequence: nextSequence + 1,
      receipts: next,
    );
  }

  factory ApplicationLedger.fromJson(Object? value) {
    final json = _exactObject(value, const {
      'generation',
      'nextSequence',
      'receipts',
    });
    if (json['generation'] is! String ||
        json['nextSequence'] is! int ||
        json['receipts'] is! List ||
        (json['receipts'] as List).length > applicationLedgerMaxReceipts) {
      throw const FormatException('Application ledger is invalid.');
    }
    return ApplicationLedger(
      generation: json['generation'] as String,
      nextSequence: json['nextSequence'] as int,
      receipts: (json['receipts'] as List)
          .map(OperationReceipt.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'generation': generation,
    'nextSequence': nextSequence,
    'receipts': [for (final receipt in receipts) receipt.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is ApplicationLedger &&
      generation == other.generation &&
      nextSequence == other.nextSequence &&
      _jsonEquals(receipts, other.receipts);

  @override
  int get hashCode =>
      Object.hash(generation, nextSequence, Object.hashAll(receipts));
}

int _receiptsByteLength(List<OperationReceipt> receipts) => utf8
    .encode(jsonEncode([for (final item in receipts) item.toJson()]))
    .length;

Map<String, Object?> _stringObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected a JSON object with string keys.');
  }
  return Map<String, Object?>.from(value);
}

Map<String, Object?> _exactObject(Object? value, Set<String> keys) {
  final json = _stringObject(value);
  if (json.length != keys.length ||
      json.keys.any((key) => !keys.contains(key))) {
    throw const FormatException('JSON object fields are invalid.');
  }
  return json;
}

class _JsonBudget {
  final active = HashSet<Object>.identity();
  int nodes = 0;

  Map<String, Object?> freezeObject(Map<String, Object?> value) =>
      freeze(value, 0) as Map<String, Object?>;

  Object? freeze(Object? value, int depth) {
    if (++nodes > operationReceiptMaxJsonNodes ||
        depth > operationReceiptMaxJsonDepth) {
      throw const FormatException(
        'Operation receipt JSON exceeds structural limits.',
      );
    }
    if (value == null || value is bool || value is String || value is int) {
      return value;
    }
    if (value is double && value.isFinite) return value;
    if (value is! List && value is! Map) {
      throw const FormatException(
        'Operation receipt contains a non-JSON value.',
      );
    }
    if (!active.add(value)) {
      throw const FormatException('Operation receipt JSON is cyclic.');
    }
    try {
      if (value is List) {
        return List<Object?>.unmodifiable(
          value.map((entry) => freeze(entry, depth + 1)),
        );
      }
      final map = _stringObject(value);
      return Map<String, Object?>.unmodifiable({
        for (final entry in map.entries)
          entry.key: freeze(entry.value, depth + 1),
      });
    } finally {
      active.remove(value);
    }
  }
}

bool _jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    return a.length == b.length &&
        Iterable<int>.generate(a.length).every((i) => _jsonEquals(a[i], b[i]));
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && _jsonEquals(a[key], b[key]),
        );
  }
  return a == b;
}

int _jsonHash(Object? value) {
  if (value is List) return Object.hashAll(value.map(_jsonHash));
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map(
        (entry) => Object.hash(entry.key, _jsonHash(entry.value)),
      ),
    );
  }
  return value.hashCode;
}
