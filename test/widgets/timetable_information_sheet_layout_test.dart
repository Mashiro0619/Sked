import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _form => find.byType(TimetableInformationDialogSurface);
Finder get _scroll => find
    .ancestor(of: _form, matching: find.byType(SingleChildScrollView))
    .first;
Finder get _surface =>
    find.ancestor(of: _form, matching: _key('app-bottom-task-surface')).first;

void _viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.reset);
}

Future<TimetableProvider> _open(
  WidgetTester t, {
  bool editing = false,
  String locale = 'en',
  double scale = 1,
}) async {
  final provider = await workspaceProvider(
    locale: locale,
    storage: editing
        ? null
        : WorkspaceMemoryStorage(
            buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale),
          ),
  );
  addTearDown(provider.dispose);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      locale: Locale(locale),
      textScale: scale,
      home: const HomeScreen(),
    ),
  );
  await t.pumpAndSettle();
  final l = AppLocalizations.of(t.element(find.byType(HomeScreen)));
  if (editing) {
    await t.tap(_key('student-timetable-picker-button'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip(l.editTimetable));
  } else {
    final create = find.widgetWithText(FilledButton, l.createTimetable);
    await t.ensureVisible(create);
    await t.pumpAndSettle();
    expect(create.hitTestable(), findsOneWidget);
    await t.tap(create);
  }
  await t.pumpAndSettle();
  expect(_form, findsOneWidget);
  return provider;
}

void main() {
  for (final editing in [false, true]) {
    for (final locale in ['en', 'zh']) {
      testWidgets(
        'phone timetable editing=$editing $locale sheet wraps its form',
        (t) async {
          _viewport(t, const Size(393, 852));
          final provider = await _open(t, editing: editing, locale: locale);
          final before = provider.timetables.length;
          expect(
            ModalRoute.of(t.element(_form)),
            isA<ModalBottomSheetRoute<dynamic>>(),
          );
          final surface = t.getRect(_surface);
          final form = t.getRect(_form);
          expect(
            surface.height,
            closeTo(form.height + 24, .01),
            reason: 'Only the bottom safe area may extend past a short form.',
          );
          expect(surface.bottom, 852);
          expect(surface.top, greaterThan(24 + 100));
          final l = AppLocalizations.of(t.element(_form));
          final cancel = find.descendant(
            of: _form,
            matching: find.widgetWithText(TextButton, l.cancel),
          );
          expect(cancel.hitTestable(), findsOneWidget);
          await t.tap(cancel);
          await t.pumpAndSettle();
          expect(_form, findsNothing);
          expect(provider.timetables.length, before);
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }
  }

  for (final size in [
    const Size(393, 852),
    const Size(320, 568),
    const Size(800, 393),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'phone timetable $size scale=$scale uses the keyboard inset once',
        (t) async {
          _viewport(t, size);
          final provider = await _open(t, locale: 'zh', scale: scale);
          final field = find
              .descendant(of: _form, matching: find.byType(TextField))
              .first;
          final controller = t.widget<TextField>(field).controller!;
          await t.enterText(field, '键盘与旋转后保留的课表');
          const keyboard = 180.0;
          t.view.viewInsets = const FakeViewPadding(bottom: keyboard);
          t.view.padding = const FakeViewPadding(top: 24);
          await t.pumpAndSettle();
          expect(t.widget<TextField>(field).controller, same(controller));
          final surface = t.getRect(_surface);
          final viewport = t.getRect(_scroll);
          expect(surface.bottom, closeTo(size.height - keyboard, .01));
          expect(
            viewport.bottom,
            closeTo(surface.bottom, .01),
            reason: 'The modal host already removes the IME; no second inset.',
          );
          expect(surface.top, greaterThanOrEqualTo(24));
          final l = AppLocalizations.of(t.element(_form));
          final save = find.descendant(
            of: _form,
            matching: find.widgetWithText(FilledButton, l.save),
          );
          await t.ensureVisible(save);
          await t.pumpAndSettle();
          expect(save.hitTestable(), findsOneWidget);
          expect(
            t.getRect(save).bottom,
            lessThanOrEqualTo(size.height - keyboard),
          );
          expect(t.takeException(), isNull);
          t.view.viewInsets = const FakeViewPadding();
          t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          t.view.physicalSize = const Size(393, 852);
          await t.pumpAndSettle();
          expect(controller.text, '键盘与旋转后保留的课表');
          await t.ensureVisible(save);
          await t.pumpAndSettle();
          await t.tap(save);
          await t.pumpAndSettle();
          expect(_form, findsNothing);
          expect(provider.activeTimetable.config.name, '键盘与旋转后保留的课表');
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }
  }

  testWidgets('desktop timetable editor remains in its full-height pane', (
    t,
  ) async {
    _viewport(t, const Size(1440, 900));
    await _open(t);
    expect(find.byType(BottomSheet), findsNothing);
    expect(WorkspaceTaskScope.contains(t.element(_form)), isTrue);
    final pane = t.getRect(_key('workspace-detail-surface'));
    expect(pane.height, greaterThan(t.getRect(_form).height));
    expect(t.getRect(_form).top, greaterThanOrEqualTo(pane.top));
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
