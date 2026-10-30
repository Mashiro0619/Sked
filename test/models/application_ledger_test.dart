import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/application_ledger.dart';

const _generation = '8215b660-b784-4c0a-9c9d-9acee313f7f5';
final _digest = 'a' * 64;

OperationReceipt _receipt(
  int sequence, {
  String? id,
  Map<String, Object?>? result,
}) => OperationReceipt(
  operationId: id ?? 'op-$sequence',
  sequence: sequence,
  commandDigest: _digest,
  completedAtIso: '2026-10-30T12:00:00.000+08:00',
  result: result ?? {'changed': true},
  undo: {'type': 'restore', 'id': 'calendar'},
);

void main() {
  test('receipt updates preserve identity, order and next sequence', () {
    final ledger = ApplicationLedger(generation: _generation)
        .append(_receipt(1))
        .append(_receipt(2));
    final updated = _receipt(1, result: {'effectStatus': 'applied'});
    final finalized = ledger.updateReceipt(updated);
    expect(finalized.generation, ledger.generation);
    expect(finalized.nextSequence, ledger.nextSequence);
    expect(finalized.receipts, [updated, ledger.receipts.last]);
    expect(ledger.receipts.first.result, {'changed': true});
    expect(() => ledger.updateReceipt(_receipt(3)), throwsFormatException);
    expect(
      () => ledger.updateReceipt(_receipt(2, id: 'op-1')),
      throwsFormatException,
    );
    final changedDigest = OperationReceipt.fromJson({
      ...updated.toJson(),
      'commandDigest': 'b' * 64,
    });
    expect(() => ledger.updateReceipt(changedDigest), throwsFormatException);
  });

  for (final state in ['pending', 'unknown']) {
    test(
      'unresolved external $state receipt blocks capacity eviction until recovered',
      () {
        var ledger = ApplicationLedger(generation: _generation).append(
          _receipt(1, result: {'kind': 'external', 'effectStatus': state}),
        );
        for (var i = 2; i <= 128; i++) {
          ledger = ledger.append(_receipt(i));
        }
        expect(
          () => ledger.append(_receipt(129)),
          throwsA(isA<ApplicationLedgerRecoveryRequiredException>()),
        );
        final recovered = ledger.updateReceipt(
          _receipt(1, result: {'kind': 'external', 'effectStatus': 'applied'}),
        );
        final appended = recovered.append(_receipt(129));
        expect(appended.receipts.first.sequence, 2);
        expect(appended.nextSequence, 130);
        expect(ledger.receipts.first.result['effectStatus'], state);
      },
    );
  }

  test('byte budget cannot evict an unresolved external receipt', () {
    var ledger = ApplicationLedger(generation: _generation).append(
      _receipt(1, result: {'kind': 'external', 'effectStatus': 'pending'}),
    );
    final payload = 'x' * (900 * 1024);
    for (var i = 2; i <= 5; i++) {
      ledger = ledger.append(_receipt(i, result: {'payload': payload}));
    }
    expect(
      () => ledger.append(_receipt(6, result: {'payload': payload})),
      throwsA(isA<ApplicationLedgerRecoveryRequiredException>()),
    );
    expect(
      () => ledger.updateReceipt(_receipt(1, result: {'payload': payload})),
      throwsFormatException,
    );
    final recovered = ledger.updateReceipt(
      _receipt(1, result: {'kind': 'external', 'effectStatus': 'failed'}),
    );
    final appended = recovered.append(
      _receipt(6, result: {'payload': payload}),
    );
    expect(appended.receipts.first.sequence, 3);
    expect(appended.nextSequence, 7);
  });

  test('receipt history also obeys a byte budget without truncating retained records', () {
    final payload = 'x' * (900 * 1024);
    var ledger = ApplicationLedger(generation: _generation);
    for (var i = 1; i <= 6; i++) {
      ledger = ledger.append(_receipt(i, result: {'payload': payload}));
    }
    expect(ledger.nextSequence, 7);
    expect(ledger.receipts, hasLength(4));
    expect(ledger.receipts.first.sequence, 3);
    expect(ledger.receipts.last.result['payload'], payload);
    expect(
      () => ApplicationLedger(
        generation: _generation,
        nextSequence: 7,
        receipts: [
          for (var i = 1; i <= 6; i++)
            _receipt(i, result: {'payload': payload}),
        ],
      ),
      throwsFormatException,
    );
  });

  test(
    'append preserves generation and retains exactly the latest 128 receipts',
    () {
      var ledger = ApplicationLedger(generation: _generation);
      expect(ledger.nextSequence, 1);
      for (var i = 1; i <= 130; i++) {
        ledger = ledger.append(_receipt(i));
      }
      expect(ledger.generation, _generation);
      expect(ledger.nextSequence, 131);
      expect(ledger.receipts.length, 128);
      expect(ledger.receipts.first.sequence, 3);
      expect(ledger.receiptFor('op-1'), isNull);
      expect(ledger.receiptFor('op-130')?.sequence, 130);
      final decoded = ApplicationLedger.fromJson(
        jsonDecode(jsonEncode(ledger.toJson())),
      );
      expect(decoded, ledger);
      expect(decoded.hashCode, ledger.hashCode);
    },
  );

  test('append rejects duplicate ids and out of order sequences', () {
    final ledger = ApplicationLedger(generation: _generation)
        .append(_receipt(1));
    expect(() => ledger.append(_receipt(2, id: 'op-1')), throwsFormatException);
    expect(() => ledger.append(_receipt(3)), throwsFormatException);
    expect(() => ledger.receipts.clear(), throwsUnsupportedError);
  });

  test('decode rejects duplicate ids, gaps, unordered or excess receipts', () {
    for (final receipts in [
      [_receipt(1).toJson(), _receipt(2, id: 'op-1').toJson()],
      [_receipt(2).toJson(), _receipt(1).toJson()],
      [_receipt(1).toJson(), _receipt(3).toJson()],
      [for (var i = 1; i <= 129; i++) _receipt(i).toJson()],
    ]) {
      expect(
        () => ApplicationLedger.fromJson({
          'generation': _generation,
          'nextSequence': receipts.length + 1,
          'receipts': receipts,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => ApplicationLedger(generation: 'not-a-uuid'),
      throwsFormatException,
    );
    expect(
      () => ApplicationLedger(generation: _generation, nextSequence: 2),
      throwsFormatException,
    );
  });

  test('receipt freezes caller-owned nested results and undo', () {
    final nested = <Object?>[
      {'value': 1},
    ];
    final original = <String, Object?>{'nested': nested};
    final receipt = _receipt(1, result: original);
    original['added'] = true;
    (nested.single as Map)['value'] = 2;
    expect(receipt.result, {
      'nested': [
        {'value': 1},
      ],
    });
    expect(() => receipt.result['added'] = true, throwsUnsupportedError);
    expect(
      () => (receipt.result['nested'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(() => (receipt.undo!['id'] = 'changed'), throwsUnsupportedError);
  });

  test('receipt validates digest, positive integer sequence and strict zoned dates', () {
    final json = _receipt(1).toJson();
    for (final change in <String, Object?>{
      'operationId': ' ',
      'sequence': 1.0,
      'commandDigest': 'digest',
      'result': [],
      'undo': false,
      'extra': true,
    }.entries) {
      expect(
        () => OperationReceipt.fromJson({...json, change.key: change.value}),
        throwsFormatException,
        reason: change.key,
      );
    }
    for (final date in [
      '2026-10-30',
      '2026-10-30T12:00:00',
      '2026-02-30T12:00:00Z',
      '2026-10-30T25:00:00Z',
      '2026-10-30T12:00:00+08:60',
      '2026-10-30T12:00:00+24:00',
      '2026-10-30T12:00:00Z ',
    ]) {
      expect(
        () => OperationReceipt.fromJson({...json, 'completedAtIso': date}),
        throwsFormatException,
        reason: date,
      );
    }
  });

  test('non-JSON values, non-string keys and cycles are rejected', () {
    final cyclic = <Object?>[];
    cyclic.add(cyclic);
    for (final value in <Object?>[
      double.nan,
      double.infinity,
      DateTime(2026),
      Object(),
      {1: 'not-string-key'},
      cyclic,
    ]) {
      expect(
        () => _receipt(1, result: {'value': value}),
        throwsFormatException,
      );
    }
    expect(
      () => OperationReceipt.fromJson({1: 'value'}),
      throwsFormatException,
    );
  });

  test(
    'oversized and deeply nested JSON is rejected without truncating undo',
    () {
      expect(
        () => _receipt(1, result: {'text': 'x' * operationReceiptMaxJsonBytes}),
        throwsFormatException,
      );
      Object? value;
      for (var i = 0; i <= operationReceiptMaxJsonDepth; i++) {
        value = [value];
      }
      expect(
        () => _receipt(1, result: {'nested': value}),
        throwsFormatException,
      );
      expect(
        () => _receipt(
          1,
          result: {'values': List.filled(operationReceiptMaxJsonNodes, null)},
        ),
        throwsFormatException,
      );
    },
  );
}
