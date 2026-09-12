import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_date_range.dart';
import 'package:sked/widgets/sked_date_range_controller.dart';

void main() {
  final range = GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13));
  test('pending start is civil, bounds are rejected and cancel leaves applied range intact', () async {
    final c = SkedDateRangeController(
      initialRange: range,
      onApply: (_) async {},
    );
    addTearDown(c.dispose);
    expect(await c.select(DateTime(1969, 12, 31)), isFalse);
    expect(c.start, isNull);
    expect(await c.select(DateTime(2100, 1, 2)), isFalse);
    expect(c.start, isNull);
    await c.select(DateTime(2026, 9, 17, 15, 30));
    expect(c.start, DateTime(2026, 9, 17));
    expect(c.highlighted, isNull);
    c.cancel();
    expect(c.start, isNull);
    expect(c.highlighted, range);
    expect(await c.retry(), isFalse);
    await c.select(DateTime(2026, 9, 17));
    c.sync(range);
    expect(c.start, DateTime(2026, 9, 17));
    final moved = range.shifted(5)!;
    c.sync(moved);
    expect(c.start, isNull);
    expect(c.applied, moved);
  });
  test(
    'sync, retry, cancel and duplicate apply cannot race an active save',
    () async {
      final gate = Completer<void>();
      var writes = 0;
      final c = SkedDateRangeController(
        initialRange: range,
        onApply: (_) async {
          writes++;
          await gate.future;
        },
      );
      addTearDown(c.dispose);
      final candidate = range.shifted(5)!;
      final save = c.apply(candidate);
      expect(c.saving, isTrue);
      c.sync(range.shifted(10)!);
      c.cancel();
      expect(c.applied, range);
      expect(c.candidate, candidate);
      expect(await c.retry(), isFalse);
      expect(await c.apply(range), isFalse);
      expect(await c.select(range.start), isFalse);
      gate.complete();
      expect(await save, isTrue);
      expect(writes, 1);
      expect(c.applied, candidate);
      expect(c.saving, isFalse);
    },
  );
  test(
    'disposed or invalidated sessions cannot notify or apply a delayed result',
    () async {
      final gate = Completer<void>();
      var current = true, writes = 0, notifications = 0;
      final c = SkedDateRangeController(
        initialRange: range,
        isSessionCurrent: () => current,
        onApply: (_) async {
          writes++;
          await gate.future;
        },
      );
      c.addListener(() => notifications++);
      final save = c.apply(range.shifted(5)!);
      expect(notifications, 1);
      current = false;
      gate.complete();
      expect(await save, isFalse);
      expect(c.applied, range);
      expect(c.saving, isFalse);
      expect(await c.select(range.start), isFalse);
      expect(await c.apply(range), isFalse);
      expect(writes, 1);
      c.dispose();
      c.cancel();
      c.sync(range);
      expect(await c.retry(), isFalse);
      final nextGate = Completer<void>();
      final next = SkedDateRangeController(
        initialRange: range,
        onApply: (_) => nextGate.future,
      );
      final pending = next.apply(range.shifted(5)!);
      next.dispose();
      nextGate.complete();
      expect(await pending, isFalse);
    },
  );
  test(
    'preview and endpoint edits never publish until a valid activation',
    () async {
      final writes = <GeneralDateRange>[];
      final c = SkedDateRangeController(
        initialRange: range,
        onApply: (r) async {
          writes.add(r);
        },
      );
      addTearDown(c.dispose);
      await c.select(DateTime(2026, 9, 10));
      c.preview(DateTime(2026, 9, 14));
      expect(
        c.previewRange,
        GeneralDateRange(DateTime(2026, 9, 10), DateTime(2026, 9, 14)),
      );
      expect(c.applied, range);
      expect(writes, isEmpty);
      c.preview(DateTime(2026, 9, 24));
      expect(c.previewInvalid, isTrue);
      expect(c.previewTooLong, isTrue);
      c.cancel();
      c.edit(DateRangeEndpoint.end);
      expect(await c.select(DateTime(2026, 9, 8)), isFalse);
      expect(c.invalidOrder, isTrue);
      expect(writes, isEmpty);
      expect(await c.select(DateTime(2026, 9, 15)), isTrue);
      expect(
        writes.single,
        GeneralDateRange(range.start, DateTime(2026, 9, 15)),
      );
      c.edit(DateRangeEndpoint.start);
      expect(await c.select(DateTime(2026, 9, 11)), isTrue);
      expect(
        c.applied,
        GeneralDateRange(DateTime(2026, 9, 11), DateTime(2026, 9, 15)),
      );
    },
  );
  test('drag cancellation restores pending selection and invalid drags never truncate', () async {
    var writes = 0;
    final c = SkedDateRangeController(
      initialRange: range,
      onApply: (_) async {
        writes++;
      },
    );
    addTearDown(c.dispose);
    await c.select(DateTime(2026, 9, 12));
    c.beginDrag(DateTime(2026, 9, 20));
    c.preview(DateTime(2026, 9, 22));
    c.cancelDrag();
    expect(c.start, DateTime(2026, 9, 12));
    expect(c.applied, range);
    c.beginDrag(DateTime(2026, 9, 20));
    c.preview(DateTime(2026, 9, 6));
    expect(await c.endDrag(), isFalse);
    expect(c.tooLong, isTrue);
    expect(c.start, DateTime(2026, 9, 12));
    expect(writes, 0);
    c.beginDrag(DateTime(2026, 9, 20));
    c.preview(null);
    expect(await c.endDrag(), isFalse);
    expect(writes, 0);
    c.beginDrag(DateTime(2026, 9, 20));
    c.preview(DateTime(2026, 9, 7));
    expect(await c.endDrag(), isTrue);
    expect(writes, 1);
    expect(c.applied.dayCount, 14);
  });
  test('hover cannot replace the failed snapshot behind Retry', () async {
    final c = SkedDateRangeController(
      initialRange: range,
      onApply: (_) async {
        throw StateError('disk busy');
      },
    );
    addTearDown(c.dispose);
    final failed = range.shifted(7)!;
    expect(await c.apply(failed), isFalse);
    c.preview(DateTime(2026, 9, 23));
    expect(c.previewRange, isNull);
    expect(c.highlighted, failed);
    expect(c.candidate, failed);
    c.edit(DateRangeEndpoint.start);
    expect(c.saveFailed, isFalse);
    expect(c.highlighted, failed);
  });
}
