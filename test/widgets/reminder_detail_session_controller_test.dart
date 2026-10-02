import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/reminder_detail_session_controller.dart';

void main() {
  testWidgets(
    '300ms enter, 200ms leave, bridge cancels leave and pending replacement',
    (t) async {
      final c = ReminderDetailSessionController();
      addTearDown(c.dispose);
      c.enterRow('a');
      await t.pump(const Duration(milliseconds: 299));
      expect(c.mode, ReminderDetailMode.hidden);
      await t.pump(const Duration(milliseconds: 1));
      expect(c.selectedKey, 'a');
      expect(c.mode, ReminderDetailMode.preview);
      c.leaveRow('a');
      await t.pump(const Duration(milliseconds: 150));
      c.enterPanel();
      await t.pump(const Duration(milliseconds: 300));
      expect(c.selectedKey, 'a');
      c.leavePanel();
      c.enterRow('b');
      await t.pump(const Duration(milliseconds: 200));
      c.enterPanel();
      await t.pump(const Duration(milliseconds: 200));
      expect(c.selectedKey, 'a');
      c.leaveRow('b');
      c.leavePanel();
      await t.pump(const Duration(milliseconds: 199));
      expect(c.visible, isTrue);
      await t.pump(const Duration(milliseconds: 1));
      expect(c.visible, isFalse);
    },
  );
  testWidgets('quick sweep and explicit close require reentry', (t) async {
    final c = ReminderDetailSessionController();
    addTearDown(c.dispose);
    c.enterRow('a');
    await t.pump(const Duration(milliseconds: 100));
    c.leaveRow('a');
    c.enterRow('b');
    await t.pump(const Duration(milliseconds: 299));
    expect(c.visible, isFalse);
    await t.pump(const Duration(milliseconds: 1));
    expect(c.selectedKey, 'b');
    c.close();
    c.enterRow('b');
    await t.pump(const Duration(seconds: 1));
    expect(c.visible, isFalse);
    c.leaveRow('b');
    c.enterRow('b');
    await t.pump(const Duration(milliseconds: 300));
    expect(c.visible, isTrue);
  });
  testWidgets(
    'upgrade preserves revision, explicit switching invalidates results and retains drag',
    (t) async {
      final c = ReminderDetailSessionController();
      addTearDown(c.dispose);
      c.enterRow('a');
      await t.pump(const Duration(milliseconds: 300));
      final version = c.revision;
      c.detach();
      expect(c.revision, version);
      c.moveTo(const Offset(80, 90));
      c.leaveRow('a');
      c.enterRow('b');
      await t.pump(const Duration(seconds: 1));
      expect(c.selectedKey, 'a');
      c.detach('b');
      expect(c.isCurrent(version, 'a'), isFalse);
      expect(c.manualPosition, const Offset(80, 90));
      c.setBusy(true);
      expect(c.detach('a'), isFalse);
      expect(c.close(), isFalse);
      c.setBusy(false);
      c.setChildTask(true);
      expect(c.close(), isFalse);
      c.setChildTask(false);
      c.close();
      expect(c.manualPosition, isNull);
    },
  );
  testWidgets('disposal cancels candidate and close timers', (t) async {
    final c = ReminderDetailSessionController();
    c.enterRow('a');
    c.dispose();
    await t.pump(const Duration(seconds: 1));
    final d = ReminderDetailSessionController();
    d.enterRow('a');
    await t.pump(const Duration(milliseconds: 300));
    d.leaveRow('a');
    d.dispose();
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
  });
  testWidgets('forced invalidation cancels a still-hidden pending hover', (
    t,
  ) async {
    final c = ReminderDetailSessionController();
    addTearDown(c.dispose);
    c.enterRow('old');
    await t.pump(const Duration(milliseconds: 200));
    c.close(force: true, explicit: false);
    await t.pump(const Duration(milliseconds: 300));
    expect(c.mode, ReminderDetailMode.hidden);
    c.enterRow('new');
    await t.pump(const Duration(milliseconds: 300));
    expect(c.selectedKey, 'new');
  });
}
