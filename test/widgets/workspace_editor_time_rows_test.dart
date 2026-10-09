import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/workspace_editor_time_rows.dart';

Finder _key(String value, {bool skipOffstage = true}) =>
    find.byKey(ValueKey(value), skipOffstage: skipOffstage);

Future<void> _pumpRows(
  WidgetTester tester, {
  double width = 620,
  double scale = 1,
  double dateMinimum = 140,
  double timeMinimum = 76,
  TextDirection direction = TextDirection.ltr,
  bool showTime = true,
  bool error = false,
  bool retainedControls = false,
}) async {
  Widget control(String id, double minimum) => retainedControls
      ? _RetainedControl(key: ValueKey(id), minimumWidth: minimum)
      : SizedBox(key: ValueKey(id), width: minimum, height: 40);
  Widget label(String id, String value) =>
      Text(value, key: ValueKey(id), style: const TextStyle(fontSize: 12));

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: WorkspaceEditorTimeRows(
                showTime: showTime,
                textDirection: direction,
                minimumGroupWidth: 240 * scale,
                startLabel: label('start-label', 'Start time'),
                startDate: control('start-date', dateMinimum),
                startTime: control('start-time', timeMinimum),
                endLabel: label('end-label', 'End time'),
                endDate: control('end-date', dateMinimum),
                endTime: control('end-time', timeMinimum),
                allDay: const SizedBox(
                  key: ValueKey('all-day'),
                  width: 88,
                  height: 40,
                ),
                error: error
                    ? const Text(
                        'End time must be later than start time',
                        key: ValueKey('range-error'),
                        style: TextStyle(fontSize: 12),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'time groups have upper labels, a trailing toggle, and an end-group error: $direction',
      (tester) async {
        await _pumpRows(tester, direction: direction, error: true);
        final startLabel = tester.getRect(_key('start-label'));
        final endLabel = tester.getRect(_key('end-label'));
        final startDate = tester.getRect(_key('start-date'));
        final startTime = tester.getRect(_key('start-time'));
        final endDate = tester.getRect(_key('end-date'));
        final endTime = tester.getRect(_key('end-time'));
        final toggle = tester.getRect(_key('all-day'));
        final error = tester.getRect(_key('range-error'));
        final rows = tester.getRect(find.byType(WorkspaceEditorTimeRows));

        expect(toggle.bottom, lessThan(startLabel.top));
        expect(startLabel.top, endLabel.top);
        expect(startLabel.bottom, lessThan(startDate.top));
        expect(endLabel.bottom, lessThan(endDate.top));
        expect(startDate.top, endDate.top);
        expect(startDate.top, startTime.top);
        expect(endDate.top, endTime.top);
        expect(startLabel.overlaps(endLabel), isFalse);
        if (direction == TextDirection.ltr) {
          expect(toggle.right, rows.right);
          expect(startTime.right, lessThan(endDate.left));
        } else {
          expect(toggle.left, rows.left);
          expect(endDate.right, lessThan(startTime.left));
        }
        expect(error.top, greaterThan(endDate.bottom));
        expect(error.left, endLabel.left);
        expect(error.right, endLabel.right);
        expect(error.bottom, rows.bottom);

        final render = tester.renderObject<RenderBox>(
          find.byType(WorkspaceEditorTimeRows),
        );
        expect(
          render.getDryLayout(BoxConstraints.tightFor(width: rows.width)),
          render.size,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'natural date and time widths collapse groups before stacking their controls',
    (tester) async {
      Future<void> pump(double width) => _pumpRows(
        tester,
        width: width,
        dateMinimum: 170,
        timeMinimum: 100,
        error: true,
      );

      await pump(600);
      expect(
        tester.getTopLeft(_key('start-date')).dy,
        tester.getTopLeft(_key('end-date')).dy,
      );

      await pump(560);
      expect(
        tester.getTopLeft(_key('start-date')).dy,
        tester.getTopLeft(_key('start-time')).dy,
      );
      expect(
        tester.getTopLeft(_key('end-label')).dy,
        greaterThan(tester.getBottomLeft(_key('start-time')).dy),
      );
      expect(
        tester.getTopLeft(_key('range-error')).dx,
        tester.getTopLeft(_key('end-label')).dx,
      );

      await pump(280);
      expect(
        tester.getTopLeft(_key('start-time')).dy,
        greaterThan(tester.getBottomLeft(_key('start-date')).dy),
      );
      expect(
        tester.getTopLeft(_key('end-time')).dy,
        greaterThan(tester.getBottomLeft(_key('end-date')).dy),
      );
      expect(
        tester.getTopLeft(_key('range-error')).dy,
        greaterThan(tester.getBottomLeft(_key('end-time')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('group minimum follows text scale: $scale', (tester) async {
      await _pumpRows(tester, width: 568, scale: scale);
      final start = tester.getRect(_key('start-label'));
      final end = tester.getRect(_key('end-label'));
      if (scale == 1) {
        expect(start.top, end.top);
        expect(start.width, greaterThanOrEqualTo(240 * scale));
      } else {
        expect(end.top, greaterThan(start.bottom));
        expect(start.width, 568);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'wrapping and all-day round trips retain date and time elements and focus',
    (tester) async {
      await _pumpRows(tester, retainedControls: true);
      await tester.tap(_key('start-time'));
      await tester.pump();
      final date = tester.element(_key('start-date'));
      final time = tester.element(_key('start-time'));
      final state = tester.state<_RetainedControlState>(_key('start-time'));
      state.focusNode.requestFocus();
      await tester.pump();
      expect(state.presses, 1);
      expect(state.focusNode.hasFocus, isTrue);

      for (final width in [450.0, 200.0, 620.0]) {
        await _pumpRows(tester, width: width, retainedControls: true);
        expect(tester.element(_key('start-date')), same(date));
        expect(tester.element(_key('start-time')), same(time));
        expect(state.focusNode.hasFocus, isTrue);
        expect(state.presses, 1);
      }
      await _pumpRows(tester, showTime: false, retainedControls: true);
      expect(_key('start-time'), findsNothing);
      expect(
        tester.element(_key('start-time', skipOffstage: false)),
        same(time),
      );
      expect(tester.element(_key('start-date')), same(date));
      expect(
        tester.getSize(_key('start-date')).width,
        tester.getSize(_key('start-label')).width,
      );
      await _pumpRows(tester, retainedControls: true);
      expect(tester.element(_key('start-time')), same(time));
      expect(state.focusNode.hasFocus, isTrue);
      await tester.tap(_key('start-time'));
      await tester.pump();
      expect(state.presses, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _RetainedControl extends StatefulWidget {
  const _RetainedControl({required super.key, required this.minimumWidth});
  final double minimumWidth;

  @override
  State<_RetainedControl> createState() => _RetainedControlState();
}

class _RetainedControlState extends State<_RetainedControl> {
  final focusNode = FocusNode();
  int presses = 0;

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minWidth: widget.minimumWidth),
    child: TextButton(
      focusNode: focusNode,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => setState(() => presses++),
      child: const Text('Value', style: TextStyle(fontSize: 14)),
    ),
  );
}
