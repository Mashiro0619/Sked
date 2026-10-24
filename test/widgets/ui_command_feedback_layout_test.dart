import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/ui_command.dart';
import 'package:sked/widgets/workspace_frame.dart';

class _Draft extends StatefulWidget {
  const _Draft({this.long = false});
  final bool long;
  @override
  State<_Draft> createState() => _DraftState();
}

class _DraftState extends State<_Draft> {
  final controller = TextEditingController(text: 'Unsaved course text');
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('draft-scroll'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Course text', key: ValueKey('draft-title')),
        TextField(controller: controller),
        FilledButton(
          onPressed: () => showUiFailureFeedback(
            context: context,
            message: widget.long
                ? 'Unable to save this course text color. Your draft is kept. Please check storage and try applying the color again.'
                : 'Unable to save. Your draft is kept.',
          ),
          child: const Text('Apply settings'),
        ),
      ],
    ),
  );
}

Widget _app({required Widget child, double scale = 1}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'floating view reserves only its failure content and shrinks after dismissal',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1400, 800);
      addTearDown(t.view.reset);
      final pane = WorkspacePaneController();
      addTearDown(pane.dispose);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: WorkspaceFrame(
              controller: pane,
              panelDisplayMode: WorkspacePanelDisplayMode.overlay,
              resources: const SizedBox.expand(),
              canvas: const WorkspaceCanvasBody(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      unawaited(
        pane.show<void>(
          (_) => WorkspaceViewPanel(
            title: const Text('Reminders'),
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showUiFailureFeedback(
                  context: context,
                  message: 'Save failed. Please try again later.',
                ),
                child: const Text('Handle reminder'),
              ),
            ),
          ),
          presentation: WorkspacePanePresentation.view,
          dismissOnCanvasTap: false,
        ),
      );
      await t.pumpAndSettle();
      try {
        final surface = find.byKey(const ValueKey('workspace-detail-surface'));
        final initial = t.getRect(surface);
        final initialContentHeight = pane.viewContentHeight!;
        for (var attempt = 0; attempt < 2; attempt++) {
          await t.tap(find.text('Handle reminder'));
          await t.pumpAndSettle();
          final expanded = t.getRect(surface);
          final noticeSlot = t.getSize(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('ui-command-failure-notice')),
                  matching: find.byType(Padding),
                )
                .first,
          );
          expect(expanded.topLeft, initial.topLeft);
          expect(
            expanded.height,
            closeTo(initial.height + noticeSlot.height, .01),
          );
          expect(
            pane.viewContentHeight,
            closeTo(initialContentHeight + noticeSlot.height, .01),
          );
          expect(
            find
                .byKey(const ValueKey('ui-command-failure-dismiss'))
                .hitTestable(),
            findsOneWidget,
          );
          await t.tap(find.byKey(const ValueKey('ui-command-failure-dismiss')));
          await t.pumpAndSettle();
          expect(t.getRect(surface), initial);
          expect(pane.viewContentHeight, initialContentHeight);
          expect(find.text('Handle reminder').hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull);
        }
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'draft survives feedback and bounded to unbounded layout changes',
    (t) async {
      final host = GlobalKey();
      late StateSetter updateLayout;
      var bounded = true;
      await t.pumpWidget(
        _app(
          child: StatefulBuilder(
            builder: (context, setState) {
              updateLayout = setState;
              final feedback = UiCommandFeedbackHost(
                key: host,
                builder: (_) => const _Draft(),
              );
              return bounded
                  ? SizedBox(height: 500, child: feedback)
                  : SingleChildScrollView(child: feedback);
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      final original = t.state<_DraftState>(find.byType(_Draft));
      await t.enterText(find.byType(TextField), 'Keep through layout changes');
      await t.tap(find.text('Apply settings'));
      await t.pumpAndSettle();
      for (final next in [false, true]) {
        updateLayout(() => bounded = next);
        await t.pumpAndSettle();
        expect(t.state<_DraftState>(find.byType(_Draft)), same(original));
        expect(original.controller.text, 'Keep through layout changes');
        expect(
          find.byKey(const ValueKey('ui-command-failure-notice')),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      }
      await t.tap(find.byKey(const ValueKey('ui-command-failure-dismiss')));
      await t.pumpAndSettle();
      expect(t.state<_DraftState>(find.byType(_Draft)), same(original));
    },
  );

  testWidgets(
    'unbounded scroll host keeps editor state through failure and dismiss',
    (t) async {
      await t.pumpWidget(
        _app(
          child: ListView(
            children: [UiCommandFeedbackHost(builder: (_) => const _Draft())],
          ),
        ),
      );
      await t.pumpAndSettle();
      final original = t.state<_DraftState>(find.byType(_Draft));
      await t.enterText(find.byType(TextField), 'Keep this changed draft');
      await t.tap(find.text('Apply settings'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ui-command-failure-notice')),
        findsOneWidget,
      );
      expect(t.state<_DraftState>(find.byType(_Draft)), same(original));
      expect(original.controller.text, 'Keep this changed draft');
      final notice = t.getRect(
        find.byKey(const ValueKey('ui-command-failure-notice')),
      );
      expect(
        t.getBottomLeft(find.byKey(const ValueKey('draft-scroll'))).dy,
        lessThanOrEqualTo(notice.top),
      );
      await t.tap(find.byKey(const ValueKey('ui-command-failure-dismiss')));
      await t.pumpAndSettle();
      expect(t.state<_DraftState>(find.byType(_Draft)), same(original));
      expect(original.controller.text, 'Keep this changed draft');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'bounded 320dp double text failure reserves space and keeps apply reachable',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 760);
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          scale: 2,
          child: UiCommandFeedbackHost(
            builder: (_) => const _Draft(long: true),
          ),
        ),
      );
      await t.pumpAndSettle();
      final original = t.state<_DraftState>(find.byType(_Draft));
      await t.tap(find.text('Apply settings'));
      await t.pumpAndSettle();
      final notice = find.byKey(const ValueKey('ui-command-failure-notice'));
      final body = find.byKey(const ValueKey('draft-scroll'));
      expect(t.getRect(body).bottom, lessThanOrEqualTo(t.getRect(notice).top));
      final messageScroll = find.descendant(
        of: find.byKey(const ValueKey('ui-command-failure-message-scroll')),
        matching: find.byType(Scrollable),
      );
      expect(
        t.state<ScrollableState>(messageScroll).position.maxScrollExtent,
        greaterThan(0),
      );
      await t.ensureVisible(find.text('Apply settings'));
      await t.pumpAndSettle();
      expect(find.text('Apply settings').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ui-command-failure-dismiss')).hitTestable(),
        findsOneWidget,
      );
      expect(t.state<_DraftState>(find.byType(_Draft)), same(original));
      expect(t.takeException(), isNull);
    },
  );
}
