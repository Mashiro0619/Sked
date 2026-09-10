import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/developer_ui_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'first launch is off; stored device choice survives a new instance',
    () async {
      final p = DeveloperUiPreferences();
      addTearDown(p.dispose);
      expect(p.assistantVisible, isFalse);
      await p.load();
      expect(p.ready, isTrue);
      expect(await p.setAssistantVisible(true), isTrue);
      final restored = DeveloperUiPreferences();
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.assistantVisible, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          DeveloperUiPreferences.storageKey,
        ),
        isTrue,
      );
    },
  );
  test(
    'saved false overrides preview default without briefly showing the panel',
    () async {
      SharedPreferences.setMockInitialValues({
        DeveloperUiPreferences.storageKey: false,
      });
      final p = DeveloperUiPreferences(previewDefault: true);
      addTearDown(p.dispose);
      expect(p.assistantVisible, isFalse);
      await p.load();
      expect(p.assistantVisible, isFalse);
      final preview = DeveloperUiPreferences(
        read: () async => null,
        previewDefault: true,
      );
      addTearDown(preview.dispose);
      await preview.load();
      expect(preview.assistantVisible, isTrue);
    },
  );
  test('load failure fails closed and retry reads instead of writing a guessed value', () async {
    var fail = true;
    var writes = 0;
    final p = DeveloperUiPreferences(
      previewDefault: true,
      read: () async {
        if (fail) throw StateError('read');
        return false;
      },
      write: (_) async {
        writes++;
        return true;
      },
    );
    addTearDown(p.dispose);
    await p.load();
    expect(p.hasError, isTrue);
    expect(p.ready, isFalse);
    expect(await p.waitForPendingSave(), isTrue);
    expect(await p.setAssistantVisible(true), isFalse);
    expect(p.assistantVisible, isFalse);
    fail = false;
    expect(await p.retry(), isTrue);
    expect(p.ready, isTrue);
    expect(writes, 0);
  });
  test(
    'failed save retains old state; retry repeats the failed intent',
    () async {
      var succeed = false;
      final values = <bool>[];
      final p = DeveloperUiPreferences(
        read: () async => true,
        write: (value) async {
          values.add(value);
          return succeed;
        },
      );
      addTearDown(p.dispose);
      await p.load();
      expect(await p.setAssistantVisible(false), isFalse);
      expect(p.assistantVisible, isTrue);
      expect(p.hasError, isTrue);
      expect(await p.waitForPendingSave(), isFalse);
      succeed = true;
      expect(await p.retry(), isTrue);
      expect(p.assistantVisible, isFalse);
      expect(values, [false, false]);
      expect(await p.waitForPendingSave(), isTrue);
      expect(await p.setAssistantVisible(false), isTrue);
      expect(values, hasLength(2));
    },
  );
  test('pending writes publish once and close waits for persistence', () async {
    final write = Completer<bool>();
    final p = DeveloperUiPreferences(
      read: () async => false,
      write: (_) => write.future,
    );
    addTearDown(p.dispose);
    await p.load();
    final saving = p.setAssistantVisible(true);
    var closed = false;
    final closing = p.waitForPendingSave().then((ok) {
      closed = ok;
    });
    expect(p.busy, isTrue);
    expect(p.assistantVisible, isFalse);
    expect(await p.setAssistantVisible(false), isFalse);
    expect(await p.retry(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    write.complete(true);
    expect(await saving, isTrue);
    await closing;
    expect(closed, isTrue);
    expect(p.assistantVisible, isTrue);
  });
  test(
    'concurrent load shares read and errors are contained after disposal',
    () async {
      final read = Completer<bool?>();
      var reads = 0;
      final p = DeveloperUiPreferences(
        read: () {
          reads++;
          return read.future;
        },
      );
      final loading = p.load();
      final second = p.load();
      p.dispose();
      read.completeError(StateError('gone'));
      await loading;
      await second;
      expect(reads, 1);
      expect(await p.retry(), isFalse);
      await p.load();
      expect(await p.setAssistantVisible(true), isFalse);
    },
  );
  test(
    'write exceptions keep state and preferences stay out of AppData',
    () async {
      final p = DeveloperUiPreferences(
        read: () async => false,
        write: (_) async => throw StateError('disk'),
      );
      addTearDown(p.dispose);
      await p.load();
      expect(await p.setAssistantVisible(true), isFalse);
      expect(p.assistantVisible, isFalse);
      final data = buildInitialAppData(buildDefaultPeriodTimes());
      final serialized = jsonEncode(data.toJson());
      expect(serialized, isNot(contains(DeveloperUiPreferences.storageKey)));
      expect(serialized, isNot(contains('assistantVisible')));
    },
  );
  test('memory preferences are immediately usable and isolated', () async {
    final a = DeveloperUiPreferences.memory(visible: true),
        b = DeveloperUiPreferences.memory();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.load();
    expect(a.ready, isTrue);
    expect(a.assistantVisible, isTrue);
    expect(b.assistantVisible, isFalse);
    await a.setAssistantVisible(false);
    expect(a.assistantVisible, isFalse);
  });
}
