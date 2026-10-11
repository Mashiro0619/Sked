import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

import '../test/support/reminder_summary_harness.dart';
import '../test/support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'desktop resizing keeps real content and produces Windows font captures',
    (tester) async {
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/desktop-resize-visual',
        ),
      );
      await output.create(recursive: true);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.reset);

      // Only memory-backed sample data and layout preferences reach this app.
      final sample = reminderSummaryStorage(locale: 'zh').data;
      final storage = WorkspaceMemoryStorage(
        sample.copyWith(
          generalMode: sample.generalMode.copyWith(
            schedules: [
              ...sample.generalMode.schedules,
              for (var i = 0; i < 24; i++)
                GeneralSchedule(
                  id: 'resize-category-$i',
                  name: '演示分类 ${i + 1}',
                  events: const [],
                ),
            ],
          ),
        ),
      );
      final provider = await workspaceProvider(
        mode: AppMode.general,
        locale: 'zh',
        storage: storage,
      );
      final layouts = DesktopLayoutPreferences.memory();
      final clock = ReminderSummaryClock();
      final boundary = GlobalKey();
      final captures = <Map<String, Object>>[];
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        provider.dispose();
        layouts.dispose();
      });
      Widget preview({double scale = 1}) => RepaintBoundary(
        key: boundary,
        child: ChangeNotifierProvider<DesktopLayoutPreferences>.value(
          value: layouts,
          child: reminderSummaryHarness(
            provider,
            clock,
            locale: 'zh',
            scale: scale,
          ),
        ),
      );
      await tester.pumpWidget(preview());
      await tester.pumpAndSettle();

      Future<void> capture(String name, Finder surface) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('${output.path}/$name.png').writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
        } finally {
          image.dispose();
        }
        final rect = tester.getRect(surface);
        captures.add({
          'file': '$name.png',
          'left': rect.left,
          'top': rect.top,
          'width': rect.width,
          'height': rect.height,
        });
      }

      final sidebar = _key('workspace-resource-width');
      final sidebarWidth = tester.getSize(sidebar).width;
      await tester.drag(
        _key('workspace-resource-resize'),
        const Offset(100, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, greaterThan(sidebarWidth));
      await capture('sidebar-wide', sidebar);

      await tester.tap(_key('general-add-event'));
      await tester.pumpAndSettle();
      final field = _key('event-desktop-title');
      final editorElement = tester.element(field);
      final l10n = AppLocalizations.of(tester.element(field));
      await tester.enterText(field, '可调整大小的演示日程');
      final editor = _key('workspace-detail-surface');
      final initialEditor = tester.getRect(editor);
      await tester.drag(
        _key('workspace-editor-drag'),
        const Offset(380, 100) - initialEditor.topLeft,
      );
      await tester.pumpAndSettle();
      final beforeResize = tester.getSize(editor);
      await tester.drag(
        _key('workspace-floating-resize-bottomRight'),
        Offset(900 - beforeResize.width, 800 - beforeResize.height),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(editor), const Size(900, 800));
      expect(tester.element(field), same(editorElement));
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        '可调整大小的演示日程',
      );
      await capture('event-editor-full-work-area', editor);
      tester.view.physicalSize = const Size(900, 520);
      await capture('event-editor-small-window', editor);
      expect(_key('workspace-editor-close').hitTestable(), findsOneWidget);

      await tester.pumpWidget(preview(scale: 2));
      await tester.pumpAndSettle();
      expect(tester.element(field), same(editorElement));
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        '可调整大小的演示日程',
      );
      final editorBody = find.byKey(
        const PageStorageKey('workspace-editor-body'),
      );
      final bodyScroll = tester.state<ScrollableState>(
        find
            .descendant(of: editorBody, matching: find.byType(Scrollable))
            .first,
      );
      expect(bodyScroll.position.maxScrollExtent, greaterThan(0));
      await tester.drag(editorBody, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(bodyScroll.position.pixels, greaterThan(0));
      expect(_key('workspace-editor-close').hitTestable(), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.save).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        '可调整大小的演示日程',
      );
      await capture('event-editor-small-window-large-text', editor);

      tester.view.physicalSize = const Size(1600, 1000);
      await tester.pumpWidget(preview());
      await tester.pumpAndSettle();
      expect(tester.getSize(editor), const Size(900, 800));
      await tester.tap(_key('workspace-editor-close'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.discardChangesAndExit),
      );
      await tester.pumpAndSettle();

      await tester.tap(_key('general-reminders-action'));
      await tester.pumpAndSettle();
      final reminders = _key('general-reminders-list');
      final reminderRect = tester.getRect(reminders);
      await tester.tap(
        find.descendant(of: reminders, matching: find.text('学习小组')),
      );
      await tester.pumpAndSettle();
      final detail = _key('workspace-companion-view-surface');
      final detailContent = find.byType(GeneralEventDetailsSheet);
      final detailElement = tester.element(detailContent);
      await tester.drag(
        find.descendant(
          of: detailContent,
          matching: _key('workspace-view-drag-handle'),
        ),
        const Offset(300, 160) - tester.getRect(detail).topLeft,
      );
      await tester.pumpAndSettle();
      final detailSize = tester.getSize(detail);
      await tester.drag(
        _key('workspace-companion-resize-bottomRight'),
        Offset(680 - detailSize.width, 620 - detailSize.height),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(detail), const Size(680, 620));
      expect(tester.element(detailContent), same(detailElement));
      expect(tester.getRect(reminders), reminderRect);
      await capture('independent-event-details', detail);
      await tester.tap(
        find.descendant(
          of: detailContent,
          matching: _key('workspace-inspector-close'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: reminders,
          matching: _key('workspace-inspector-close'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_key('workspace-resource-open'));
      await tester.pumpAndSettle();
      final manager = _key('floating-form-surface');
      await tester.drag(
        _key('floating-form-drag-handle'),
        const Offset(300, 100) - tester.getRect(manager).topLeft,
      );
      await tester.pumpAndSettle();
      final list = find.byKey(const PageStorageKey('calendar-manager-list'));
      final listElement = tester.element(list);
      final managerSize = tester.getSize(manager);
      await tester.drag(
        _key('floating-form-resize-bottomRight'),
        Offset(780 - managerSize.width, 780 - managerSize.height),
      );
      await tester.pumpAndSettle();
      expect(tester.element(list), same(listElement));
      expect(tester.getSize(list).height, greaterThan(400));
      await capture('category-manager-tall-list', manager);
      await tester.tap(_key('calendar-name-summary'));
      await tester.pumpAndSettle();
      final nameForm = _key('floating-form-surface').last;
      await tester.drag(
        _key('floating-form-drag-handle').last,
        const Offset(460, 200) - tester.getRect(nameForm).topLeft,
      );
      await tester.pumpAndSettle();
      final nameSize = tester.getSize(nameForm);
      await tester.drag(
        _key('floating-form-resize-bottomRight').last,
        Offset(600 - nameSize.width, 400 - nameSize.height),
      );
      await capture('category-name-form', nameForm);
      expect(
        layouts.preferenceFor(DesktopLayoutRegion.categoryNameEditor),
        const PreferredRegionSize(width: 600, height: 400),
      );
      await File('${output.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'status': 'passed',
          'evidence': 'Windows engine fonts and Flutter test pointer events',
          'data': 'memory-only generated sample data',
          'captures': captures,
        }),
      );
    },
    skip: !Platform.isWindows,
  );
}
