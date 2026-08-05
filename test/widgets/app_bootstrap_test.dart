import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/main.dart' hide main;
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/app_instance_lease.dart';

class _MemoryStorage implements TimetableStorage {
  AppData? data = buildInitialAppData(buildDefaultPeriodTimes());

  @override
  Future<String?> filePath() async => 'memory://bootstrap-test';

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }
}

class _FakeLease implements AppInstanceLease {
  _FakeLease(this.attempts);

  final List<Object> attempts;
  var acquireCount = 0;
  var releaseCount = 0;

  @override
  Future<bool> tryAcquire() async {
    acquireCount += 1;
    final attempt = attempts.removeAt(0);
    if (attempt is Future<bool>) return attempt;
    if (attempt is bool) return attempt;
    throw attempt;
  }

  @override
  Future<void> release() async {
    releaseCount += 1;
  }
}

TimetableProvider _provider() => TimetableProvider(
  storage: _MemoryStorage(),
  systemLocaleCodeResolver: () => 'en',
);

class _ControlledShutdownProvider extends TimetableProvider {
  _ControlledShutdownProvider({
    required this.loadCompleter,
    required this.quiesceCompleter,
  }) : super(storage: _MemoryStorage(), systemLocaleCodeResolver: () => 'en');

  final Completer<void> loadCompleter;
  final Completer<void> quiesceCompleter;
  final Completer<void> quiesceStarted = Completer<void>();
  var disposed = false;

  @override
  Future<void> load() => loadCompleter.future;

  @override
  Future<void> quiesceForShutdown() async {
    if (!quiesceStarted.isCompleted) quiesceStarted.complete();
    await quiesceCompleter.future;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  testWidgets('does not create a provider before the lease is acquired', (
    tester,
  ) async {
    final lease = _FakeLease([false, true]);
    var providerFactoryCalls = 0;

    await tester.pumpWidget(
      AppBootstrap(
        lease: lease,
        providerFactory: () {
          providerFactoryCalls += 1;
          return _provider();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sked is already open'), findsOneWidget);
    expect(providerFactoryCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
    expect(providerFactoryCalls, 1);
    expect(lease.acquireCount, 2);
    expect(lease.releaseCount, 0);
  });

  testWidgets('shows lease failures separately and allows retry', (
    tester,
  ) async {
    final lease = _FakeLease([const FileSystemException('denied'), true]);

    await tester.pumpWidget(
      AppBootstrap(lease: lease, providerFactory: _provider),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local data is unavailable'), findsOneWidget);
    expect(find.textContaining('was not opened or changed'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
  });

  testWidgets('releases a lease acquired after the bootstrap is disposed', (
    tester,
  ) async {
    final result = Completer<bool>();
    final lease = _FakeLease([result.future]);
    var providerFactoryCalls = 0;

    await tester.pumpWidget(
      AppBootstrap(
        lease: lease,
        providerFactory: () {
          providerFactoryCalls += 1;
          return _provider();
        },
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    result.complete(true);
    await tester.pump();

    expect(lease.releaseCount, 1);
    expect(providerFactoryCalls, 0);
  });

  testWidgets('keeps tracking an in-flight retry after duplicate callbacks', (
    tester,
  ) async {
    final retryResult = Completer<bool>();
    final lease = _FakeLease([false, retryResult.future]);

    await tester.pumpWidget(
      AppBootstrap(lease: lease, providerFactory: _provider),
    );
    await tester.pumpAndSettle();

    final retry = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Retry'))
        .onPressed!;
    retry();
    retry();
    await tester.pumpWidget(const SizedBox.shrink());

    retryResult.complete(true);
    await tester.pump();

    expect(lease.acquireCount, 2);
    expect(lease.releaseCount, 1);
  });

  testWidgets('releases the lease when provider creation fails', (
    tester,
  ) async {
    final lease = _FakeLease([true, true]);
    var providerFactoryCalls = 0;

    await tester.pumpWidget(
      AppBootstrap(
        lease: lease,
        providerFactory: () {
          providerFactoryCalls += 1;
          if (providerFactoryCalls == 1) {
            throw StateError('provider creation failed');
          }
          return _provider();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local data is unavailable'), findsOneWidget);
    expect(lease.releaseCount, 1);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
    expect(providerFactoryCalls, 2);
    expect(lease.acquireCount, 2);
  });

  testWidgets(
    'waits for provider load and shutdown before releasing a ready lease',
    (tester) async {
      final loadCompleter = Completer<void>();
      final quiesceCompleter = Completer<void>();
      final provider = _ControlledShutdownProvider(
        loadCompleter: loadCompleter,
        quiesceCompleter: quiesceCompleter,
      );
      final lease = _FakeLease([true]);

      await tester.pumpWidget(
        AppBootstrap(lease: lease, providerFactory: () => provider),
      );
      await tester.pump();
      expect(find.byType(MyApp), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(lease.releaseCount, 0);
      expect(provider.disposed, isFalse);
      expect(provider.quiesceStarted.isCompleted, isFalse);

      loadCompleter.complete();
      await provider.quiesceStarted.future;
      expect(lease.releaseCount, 0);
      expect(provider.disposed, isFalse);

      quiesceCompleter.complete();
      await tester.pump();
      expect(provider.disposed, isTrue);
      expect(lease.releaseCount, 1);
    },
  );
}
