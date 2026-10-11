import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/widgets/sked_floating_dialog.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_resizable.dart';
import 'package:sked/widgets/sked_task_dialog.dart';
import 'package:sked/widgets/workspace_editor.dart';

const _surfaceKey = ValueKey('scrollbar-frame-surface');
const _frameKey = ValueKey('scrollbar-resize-frame');
const _scrollViewKey = ValueKey('scrollbar-frame-scroll-view');

/// Locate the painted thumb through Flutter's public mouse hit test. This also
/// verifies visibility and follows scrollbar theme margins without assuming
/// that the thumb sits at a fixed offset from the floating surface.
Rect _visibleThumb(WidgetTester tester, Finder scrollView) {
  final paints = find.descendant(
    of: scrollView,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.foregroundPainter is ScrollbarPainter,
    ),
  );
  for (final element in paints.evaluate()) {
    final painter =
        (element.widget as CustomPaint).foregroundPainter! as ScrollbarPainter;
    final box = element.renderObject! as RenderBox;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (var y = 0.5; y < box.size.height; y++) {
      for (var x = 0.5; x < box.size.width; x++) {
        if (!painter.hitTestOnlyThumbInteractive(
          Offset(x, y),
          PointerDeviceKind.mouse,
        )) {
          continue;
        }
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (left.isFinite) {
      return Rect.fromLTRB(
        left,
        top,
        right,
        bottom,
      ).shift(box.localToGlobal(Offset.zero));
    }
  }
  throw StateError('No visible, interactive scrollbar thumb in $scrollView');
}

Future<void> _mouseDrag(WidgetTester tester, Offset start, Offset delta) async {
  final gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(delta / 2);
  await tester.pump();
  await gesture.moveBy(delta / 2);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Offset _thumbEndPoint(Rect thumb, Axis axis, {required bool atEnd}) =>
    axis == Axis.vertical
    ? Offset(thumb.center.dx, atEnd ? thumb.bottom - 1 : thumb.top + 1)
    : Offset(atEnd ? thumb.right - 1 : thumb.left + 1, thumb.center.dy);

ScrollPosition _position(WidgetTester tester, Finder scrollView) => tester
    .state<ScrollableState>(
      find.descendant(of: scrollView, matching: find.byType(Scrollable)).first,
    )
    .position;

class _FrameHarness extends StatefulWidget {
  const _FrameHarness({
    super.key,
    required this.axis,
    required this.direction,
    required this.editor,
    this.size = const Size(520, 400),
  });
  final Axis axis;
  final TextDirection direction;
  final bool editor;
  final Size size;

  @override
  State<_FrameHarness> createState() => _FrameHarnessState();
}

class _FrameHarnessState extends State<_FrameHarness> {
  final controller = ScrollController();
  late var rect = Rect.fromLTWH(
    180,
    120,
    widget.size.width,
    widget.size.height,
  );
  var resizeStarts = 0;
  var resizeUpdates = 0;
  var resizeEnds = 0;
  var enabled = true;

  void setEnabled(bool value) => setState(() => enabled = value);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _content() {
    if (widget.editor) {
      return WorkspaceEditorScope(
        enabled: true,
        floating: true,
        explicitHeight: true,
        onHeight: (_) {},
        child: WorkspaceEditorScaffold(
          title: const Text('Scrollable editor'),
          closeEnabled: true,
          onClose: () {},
          actions: [FilledButton(onPressed: () {}, child: const Text('Save'))],
          child: Column(
            children: [
              const TextField(
                decoration: InputDecoration(labelText: 'Draft title'),
              ),
              for (var index = 0; index < 40; index++)
                SizedBox(height: 40, child: Text('Editor row $index')),
            ],
          ),
        ),
      );
    }
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          key: _scrollViewKey,
          controller: controller,
          scrollDirection: widget.axis,
          child: SizedBox(
            width: widget.axis == Axis.horizontal ? 2400 : null,
            height: widget.axis == Axis.vertical ? 2400 : null,
            child: const Text('Scrollable floating content'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      platform: TargetPlatform.windows,
      scrollbarTheme: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(true),
      ),
    ),
    home: Directionality(
      textDirection: widget.direction,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: SkedResizableFrame(
                key: _frameKey,
                enabled: enabled,
                reserveResizeSpace: true,
                onStart: () => resizeStarts++,
                onEnd: () => resizeEnds++,
                onResize: (edge, delta) => setState(() {
                  resizeUpdates++;
                  rect = resizeSkedFloatingRect(
                    rect: rect,
                    delta: delta,
                    edge: edge,
                    bounds: const Rect.fromLTRB(0, 0, 1000, 800),
                    minimumSize: const Size(240, 160),
                  );
                }),
                child: SkedFloatingSurface(key: _surfaceKey, child: _content()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  for (final (axis, direction, editor) in [
    (Axis.vertical, TextDirection.ltr, false),
    (Axis.vertical, TextDirection.rtl, false),
    (Axis.horizontal, TextDirection.ltr, false),
    (Axis.vertical, TextDirection.ltr, true),
  ]) {
    testWidgets(
      'floating $axis scrollbar drag and edge resize remain separate ($direction, editor=$editor)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1000, 800);
        addTearDown(tester.view.reset);
        final hostKey = GlobalKey<_FrameHarnessState>();
        await tester.pumpWidget(
          _FrameHarness(
            key: hostKey,
            axis: axis,
            direction: direction,
            editor: editor,
          ),
        );
        await tester.pumpAndSettle();
        final host = hostKey.currentState!;
        final scrollView = find.byKey(
          editor
              ? const PageStorageKey('workspace-editor-body')
              : _scrollViewKey,
        );
        final content = tester.element(scrollView);
        final position = _position(tester, scrollView);
        expect(position.maxScrollExtent, greaterThan(0));
        // Explicit Scrollbar wraps the scroll view; the editor uses Flutter's
        // real automatic desktop scrollbar inside its body Scrollable.
        final scrollbarHost = editor
            ? scrollView
            : find.ancestor(of: scrollView, matching: find.byType(Scrollbar));
        final thumb = _visibleThumb(tester, scrollbarHost);
        final original = tester.getRect(find.byKey(_frameKey));
        final beforeScroll = position.pixels;
        await _mouseDrag(
          tester,
          thumb.center,
          axis == Axis.vertical ? const Offset(0, 60) : const Offset(60, 0),
        );
        expect(
          position.pixels,
          greaterThan(beforeScroll),
          reason: 'Dragging painted thumb $thumb inside $original must scroll',
        );
        expect(tester.getRect(find.byKey(_frameKey)), original);
        expect(
          (host.resizeStarts, host.resizeUpdates, host.resizeEnds),
          (0, 0, 0),
        );

        // At each scroll end, the thumb endpoint can lie within a corner
        // target's rectangular bounds. That inner area still belongs to the
        // viewport, including the rounded thumb's interactive endpoint.
        for (final atEnd in [false, true]) {
          position.jumpTo(
            atEnd ? position.maxScrollExtent : position.minScrollExtent,
          );
          await tester.pumpAndSettle();
          final endThumb = _visibleThumb(tester, scrollbarHost);
          final beforeEndDrag = position.pixels;
          final distance = atEnd ? -30.0 : 30.0;
          await _mouseDrag(
            tester,
            _thumbEndPoint(endThumb, axis, atEnd: atEnd),
            axis == Axis.vertical ? Offset(0, distance) : Offset(distance, 0),
          );
          expect(
            position.pixels,
            atEnd ? lessThan(beforeEndDrag) : greaterThan(beforeEndDrag),
            reason: 'The actual thumb endpoint $endThumb must remain draggable',
          );
          expect(tester.getRect(find.byKey(_frameKey)), original);
          expect(
            (host.resizeStarts, host.resizeUpdates, host.resizeEnds),
            (0, 0, 0),
          );
        }

        final afterScroll = position.pixels;
        final movedThumb = _visibleThumb(tester, scrollbarHost);
        final left = direction == TextDirection.rtl;
        final edgePoint = axis == Axis.horizontal
            ? Offset(movedThumb.center.dx, original.bottom - 1)
            : Offset(
                left ? original.left + 1 : original.right - 1,
                movedThumb.center.dy,
              );
        await _mouseDrag(
          tester,
          edgePoint,
          axis == Axis.horizontal
              ? const Offset(0, 60)
              : Offset(left ? -60 : 60, 0),
        );
        final resized = tester.getRect(find.byKey(_frameKey));
        expect(
          resized.width,
          original.width + (axis == Axis.vertical ? 60 : 0),
        );
        expect(
          resized.height,
          original.height + (axis == Axis.horizontal ? 60 : 0),
        );
        expect(position.pixels, closeTo(afterScroll, .01));
        expect(host.resizeUpdates, greaterThan(0));

        final viewportDimension = position.viewportDimension;
        final contentRect = tester.getRect(scrollView);
        host.setEnabled(false);
        await tester.pumpAndSettle();
        expect(tester.element(scrollView), same(content));
        expect(position.pixels, closeTo(afterScroll, .01));
        expect(position.viewportDimension, viewportDimension);
        expect(tester.getRect(scrollView), contentRect);
        host.setEnabled(true);
        await tester.pumpAndSettle();
        expect(tester.element(scrollView), same(content));
        expect(position.pixels, closeTo(afterScroll, .01));
        expect(position.viewportDimension, viewportDimension);
        expect(tester.getRect(scrollView), contentRect);
        expect(tester.getRect(find.byKey(_frameKey)), resized);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final axis in Axis.values) {
    testWidgets(
      'short floating $axis viewport keeps both thumb endpoints draggable',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1000, 800);
        addTearDown(tester.view.reset);
        final hostKey = GlobalKey<_FrameHarnessState>();
        await tester.pumpWidget(
          _FrameHarness(
            key: hostKey,
            axis: axis,
            direction: TextDirection.ltr,
            editor: false,
            size: axis == Axis.vertical
                ? const Size(260, 80)
                : const Size(80, 260),
          ),
        );
        await tester.pumpAndSettle();
        final host = hostKey.currentState!;
        final scrollView = find.byKey(_scrollViewKey);
        final scrollbarHost = find.ancestor(
          of: scrollView,
          matching: find.byType(Scrollbar),
        );
        final position = _position(tester, scrollView);
        final original = tester.getRect(find.byKey(_frameKey));
        expect(position.viewportDimension, inExclusiveRange(0, 80));
        expect(position.maxScrollExtent, greaterThan(0));
        for (final atEnd in [false, true]) {
          position.jumpTo(
            atEnd ? position.maxScrollExtent : position.minScrollExtent,
          );
          await tester.pumpAndSettle();
          final thumb = _visibleThumb(tester, scrollbarHost);
          final before = position.pixels;
          final distance = atEnd ? -12.0 : 12.0;
          await _mouseDrag(
            tester,
            _thumbEndPoint(thumb, axis, atEnd: atEnd),
            axis == Axis.vertical ? Offset(0, distance) : Offset(distance, 0),
          );
          expect(
            position.pixels,
            atEnd ? lessThan(before) : greaterThan(before),
          );
          expect(tester.getRect(find.byKey(_frameKey)), original);
          expect(
            (host.resizeStarts, host.resizeUpdates, host.resizeEnds),
            (0, 0, 0),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'floating dialog host keeps scrollbar gestures out of geometry and size preferences',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 800);
      addTearDown(tester.view.reset);
      const initialSize = PreferredRegionSize(width: 520, height: 400);
      final layouts = DesktopLayoutPreferences.memory(
        initialValues: const {DesktopLayoutRegion.categoryManager: initialSize},
      );
      final controller = ScrollController();
      addTearDown(layouts.dispose);
      addTearDown(controller.dispose);
      const listKey = ValueKey('floating-dialog-scroll-list');
      await tester.pumpWidget(
        ChangeNotifierProvider<DesktopLayoutPreferences>.value(
          value: layouts,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(platform: TargetPlatform.windows),
            home: Scaffold(
              body: SkedFloatingDialogHost(
                options: const SkedDesktopFloatingDialog(
                  layoutKey: DesktopLayoutRegion.categoryManager,
                ),
                child: SkedTaskDialog(
                  title: const Text('Scrollable categories'),
                  desktopContentOwnsScroll: true,
                  content: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
                    child: Scrollbar(
                      controller: controller,
                      thumbVisibility: true,
                      child: ListView.builder(
                        key: listKey,
                        controller: controller,
                        itemExtent: 40,
                        itemCount: 60,
                        itemBuilder: (_, index) => Text('Category $index'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = find.byKey(const ValueKey('floating-form-surface'));
      final frame = find.descendant(
        of: surface,
        matching: find.byType(SkedResizableFrame),
      );
      final list = find.byKey(listKey);
      final content = tester.element(list);
      final original = tester.getRect(surface);
      expect(tester.getRect(frame), original);
      final thumb = _visibleThumb(
        tester,
        find.ancestor(of: list, matching: find.byType(Scrollbar)),
      );
      await _mouseDrag(tester, thumb.center, const Offset(0, 60));
      expect(controller.offset, greaterThan(0));
      expect(tester.getRect(surface), original);
      expect(
        layouts.preferenceFor(DesktopLayoutRegion.categoryManager),
        initialSize,
      );

      final offset = controller.offset;
      await _mouseDrag(
        tester,
        Offset(original.right - 1, original.center.dy),
        const Offset(60, 0),
      );
      final resized = tester.getRect(surface);
      expect(resized.topLeft, original.topLeft);
      expect(resized.size, Size(original.width + 60, original.height));
      expect(tester.getRect(frame), resized);
      expect(controller.offset, closeTo(offset, .01));
      expect(tester.element(list), same(content));
      expect(
        layouts.preferenceFor(DesktopLayoutRegion.categoryManager),
        PreferredRegionSize(width: resized.width, height: resized.height),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
