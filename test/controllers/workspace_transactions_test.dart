import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/controllers/workspace_transactions.dart';

void main() {
  test('later commands wait for rollback and own their result', () async {
    final transactions = WorkspaceTransactions();
    final release = Completer<void>();
    final events = <String>[];
    var value = 'original';
    final first = transactions.run((transaction) async {
      value = 'draft';
      events.add('first started');
      await release.future;
      value = 'original';
      events.add('first rolled back');
      throw StateError('write failed');
    });
    final rejected = expectLater(first, throwsStateError);
    final second = transactions.run((transaction) async {
      events.add('second saw $value');
      value = 'second';
    });
    expect(events, ['first started']);
    expect(transactions.isIdle, isFalse);

    release.complete();
    await rejected;
    await second;

    expect(events, [
      'first started',
      'first rolled back',
      'second saw original',
    ]);
    expect(value, 'second');
    expect(transactions.isIdle, isTrue);
  });

  test(
    'preparation can save but commit holds other saves until rollback',
    () async {
      final transactions = WorkspaceTransactions();
      final release = Completer<void>();
      final entered = Completer<void>();
      final events = <String>[];
      late WorkspaceCommit commitLease;
      final command = transactions.run((transaction) async {
        expect(transactions.waitBeforeSave(), isNull);
        await transaction.commit((commit) async {
          commitLease = commit;
          expect(transactions.waitBeforeSave(commit: commit), isNull);
          entered.complete();
          await release.future;
          events.add('rollback finished');
          throw StateError('write failed');
        });
      });
      final rejected = expectLater(command, throwsStateError);
      await entered.future;
      final pendingSave = transactions.waitBeforeSave()!.then((_) {
        events.add('ordinary save started');
      });
      expect(events, isEmpty);

      release.complete();
      await rejected;
      await pendingSave;

      expect(events, ['rollback finished', 'ordinary save started']);
      expect(transactions.waitBeforeSave(), isNull);
      expect(
        () => transactions.waitBeforeSave(commit: commitLease),
        throwsStateError,
      );
    },
  );

  test('a completed command cannot commit while a new command runs', () async {
    final transactions = WorkspaceTransactions();
    late WorkspaceTransaction stale;
    await transactions.run((transaction) async => stale = transaction);
    await transactions.run((transaction) async {
      await expectLater(stale.commit((_) async {}), throwsStateError);
      await transaction.commit((commit) async {
        expect(transactions.waitBeforeSave(commit: commit), isNull);
      });
    });
    expect(transactions.isIdle, isTrue);
  });
}
