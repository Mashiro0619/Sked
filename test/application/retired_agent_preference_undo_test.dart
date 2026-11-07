import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/mutation_undo.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';

import 'mutation_undo_test.dart' as fixtures;

const _retired = [
  (key: 'agent.maxTotalTokens', minimum: 1024, maximum: 1000000),
  (key: 'agent.maxModelRounds', minimum: 1, maximum: 100),
  (key: 'agent.maxToolCalls', minimum: 1, maximum: 500),
];

void main() {
  for (final preference in _retired) {
    final key = preference.key;
    final before = preference.minimum;
    final after = preference.maximum;

    test('$key preserves its inverse projection alongside live settings', () {
      final base = fixtures.fixture();
      final applied = fixtures.apply(
        base,
        [],
        settings: const [
          SettingEdit.set('agent.systemInstructions', 'Changed guidance'),
          SettingEdit.set('general.showWeekends', false),
        ],
      );
      final original = _receipt([
        ...applied.receipt.undo!['changes'] as List,
        _change(key, before, after),
      ]);

      final reversed = MutationUndoCompiler().prepare(applied.data, original);
      expect(reversed.candidate.toJson(), base.toJson());
      expect(
        reversed.changes.singleWhere((change) => change.key == key).toJson(),
        _change(key, after, before),
      );
      _expectRetiredFieldsAbsent(reversed.candidate);

      // The stored inverse retains the historic projection for a later undo
      // or recovery check, while the application snapshot keeps no old limits.
      final inverse = OperationReceipt.fromJson(
        _receipt([for (final change in reversed.changes) change.toJson()])
            .toJson(),
      );
      expect(
        inverse.undo!['changes'],
        contains(equals(_change(key, after, before))),
      );
      final restored = MutationUndoCompiler().prepare(
        reversed.candidate,
        inverse,
      );
      expect(restored.candidate.toJson(), applied.data.toJson());
      _expectRetiredFieldsAbsent(restored.candidate);
    });

    test('$key alone records an inverse without reviving the setting', () {
      final base = fixtures.fixture();
      final reversed = MutationUndoCompiler().prepare(
        base,
        _receipt([_change(key, before, after)]),
      );
      expect(reversed.candidate.toJson(), base.toJson());
      expect(reversed.changes.single.toJson(), _change(key, after, before));
      _expectRetiredFieldsAbsent(reversed.candidate);
    });

    test('$key folds chronological receipts using their recorded values', () {
      final base = fixtures.fixture();
      final first = fixtures.apply(
        base,
        [],
        settings: const [
          SettingEdit.set('agent.systemInstructions', 'First guidance'),
        ],
      );
      final second = fixtures.apply(
        first.data,
        [],
        settings: const [
          SettingEdit.set('agent.systemInstructions', 'Second guidance'),
        ],
      );
      final middle = before + 1;
      final older = _receipt([
        ...first.receipt.undo!['changes'] as List,
        _change(key, before, middle),
      ], sequence: 1);
      final newer = _receipt([
        ...second.receipt.undo!['changes'] as List,
        _change(key, middle, after),
      ], sequence: 2);

      final reversed = MutationUndoCompiler().prepareSequence(second.data, [
        newer,
        older,
      ]);
      expect(reversed.candidate.toJson(), base.toJson());
      expect(
        reversed.changes.singleWhere((change) => change.key == key).toJson(),
        _change(key, after, before),
      );
      _expectRetiredFieldsAbsent(reversed.candidate);
    });

    test('$key round-trip receipts have no net inverse change', () {
      final base = fixtures.fixture();
      final reversed = MutationUndoCompiler().prepareSequence(base, [
        _receipt([_change(key, before, after)], sequence: 1),
        _receipt([_change(key, after, before)], sequence: 2),
      ]);
      expect(reversed.candidate.toJson(), base.toJson());
      expect(reversed.changes, isEmpty);
      _expectRetiredFieldsAbsent(reversed.candidate);
    });

    test('$key still rejects discontinuous historical receipt values', () {
      final base = fixtures.fixture();
      expect(
        () => MutationUndoCompiler().prepareSequence(base, [
          _receipt([_change(key, before, before + 1)], sequence: 1),
          _receipt([_change(key, before + 2, after)], sequence: 2),
        ]),
        throwsA(fixtures.problem(OperationErrorCode.conflict)),
      );
      _expectRetiredFieldsAbsent(base);
    });

    test(
      '$key cannot hide a conflict in a live setting from the same receipt',
      () {
        final base = fixtures.fixture();
        final applied = fixtures.apply(
          base,
          [],
          settings: const [
            SettingEdit.set('agent.systemInstructions', 'Agent edit'),
          ],
        );
        final later = fixtures.apply(
          applied.data,
          [],
          settings: const [
            SettingEdit.set('agent.systemInstructions', 'Later user edit'),
          ],
        );
        expect(
          () => MutationUndoCompiler().prepare(
            later.data,
            _receipt([
              ...applied.receipt.undo!['changes'] as List,
              _change(key, before, after),
            ]),
          ),
          throwsA(fixtures.problem(OperationErrorCode.conflict)),
        );
        expect(later.data.agentSettings.systemInstructions, 'Later user edit');
      },
    );

    test('$key compatibility validates both historic integer values', () {
      final base = fixtures.fixture();
      for (final invalid in <Object?>[
        null,
        false,
        '$before',
        before.toDouble(),
        before - 1,
        after + 1,
        <String, Object?>{},
      ]) {
        for (final change in [
          _change(key, invalid, after),
          _change(key, before, invalid),
          _change(key, invalid, invalid),
        ]) {
          expect(
            () => MutationUndoCompiler().prepare(base, _receipt([change])),
            throwsA(fixtures.problem(OperationErrorCode.invalidArgument)),
            reason: '$key must reject $change before ignoring a no-op',
          );
        }
      }
    });

    test(
      '$key compatibility keeps strict change shape and duplicate checks',
      () {
        final base = fixtures.fixture();
        for (final change in [
          {..._change(key, before, after), 'extra': true},
          {..._change(key, before, after), 'beforeIndex': null},
          {
            ..._change(key, before, after),
            'ref': {'kind': 'calendar', 'id': 'a'},
            'beforeIndex': 0,
          },
        ]) {
          expect(
            () => MutationUndoCompiler().prepare(base, _receipt([change])),
            throwsA(fixtures.problem(OperationErrorCode.invalidArgument)),
          );
        }
        expect(
          () => MutationUndoCompiler().prepare(
            base,
            _receipt([
              _change(key, before, after),
              _change(key, before + 1, after),
            ]),
          ),
          throwsA(fixtures.problem(OperationErrorCode.invalidArgument)),
        );
      },
    );

    test('$key stays unavailable to ordinary settings reads and writes', () {
      final registry = SettingRegistry();
      final base = fixtures.fixture();
      expect(
        registry.descriptors.map((entry) => entry.key),
        isNot(contains(key)),
      );
      final unknown = isA<SettingValidationException>().having(
        (error) => error.code,
        'code',
        SettingValidationCode.unknownKey,
      );
      expect(() => registry.read(base, key), throwsA(unknown));
      for (final edit in [
        SettingEdit.set(key, before),
        SettingEdit.reset(key),
      ]) {
        expect(() => registry.prepare(base, [edit]), throwsA(unknown));
      }
    });
  }

  test('retired compatibility does not accept arbitrary unknown settings', () {
    for (final key in [
      'agent.maxUnknownBudget',
      'agent.maxTotalTokens.extra',
      'app.maxModelRounds',
    ]) {
      expect(
        () => MutationUndoCompiler().prepare(
          fixtures.fixture(),
          _receipt([_change(key, 1, 2)]),
        ),
        throwsA(fixtures.problem(OperationErrorCode.invalidArgument)),
      );
    }
  });
}

Map<String, Object?> _change(String key, Object? before, Object? after) => {
  'key': key,
  'before': before,
  'after': after,
};

OperationReceipt _receipt(List<Object?> changes, {int sequence = 1}) =>
    OperationReceipt(
      operationId: 'historic-receipt-$sequence',
      sequence: sequence,
      commandDigest: '0' * 64,
      completedAtIso: '2026-11-07T00:00:00.000Z',
      result: const {'status': 'committed'},
      undo: {'changes': changes},
    );

void _expectRetiredFieldsAbsent(AppData data) {
  final stored = data.agentSettings.toJson();
  for (final preference in _retired) {
    expect(stored, isNot(contains(preference.key.substring('agent.'.length))));
  }
  expect(
    AppData.decodeStorageSnapshot(data.encode()).agentSettings.toJson(),
    stored,
  );
}
