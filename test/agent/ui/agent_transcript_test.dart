import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_transcript.dart';

void main() {
  const paneKey = ValueKey('retained-pane-transcript');
  const fullKey = ValueKey('full-transcript');
  const paneScrollKey = ValueKey('pane-scroll');
  const fullScrollKey = ValueKey('full-scroll');

  List<Widget> messages([Map<int, double> heights = const {}]) => [
    for (var index = 0; index < 512; index++)
      SizedBox(
        key: ValueKey('message-$index'),
        height: heights[index] ?? (index.isEven ? 120 : 274),
        child: Text('Saved message $index'),
      ),
  ];

  Widget host(
    AgentReadingPosition position, {
    required bool full,
    double paneWidth = 400,
    Map<int, double> heights = const {},
    Object? revision,
  }) => MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Offstage(
            offstage: full,
            child: SizedBox(
              width: paneWidth,
              height: 297.4,
              child: AgentTranscript(
                key: paneKey,
                position: position,
                active: !full,
                scrollViewKey: paneScrollKey,
                onReadingChanged: () {},
                contentRevision: revision,
                children: messages(heights),
              ),
            ),
          ),
          if (full)
            SizedBox(
              width: 760,
              height: 520,
              child: AgentTranscript(
                key: fullKey,
                position: position,
                active: true,
                scrollViewKey: fullScrollKey,
                onReadingChanged: () {},
                contentRevision: revision,
                children: messages(heights),
              ),
            ),
        ],
      ),
    ),
  );

  (String, double, double) visibleMessage(WidgetTester tester, Key scrollKey) {
    final scroll = find.byKey(scrollKey);
    final viewport = tester.getRect(scroll);
    final visible = <(String, Rect)>[];
    for (var index = 0; index < 512; index++) {
      final item = find.descendant(
        of: scroll,
        matching: find.byKey(ValueKey('message-$index')),
      );
      if (item.evaluate().isEmpty) continue;
      final rect = tester.getRect(item);
      if (rect.bottom > viewport.top && rect.top < viewport.bottom) {
        visible.add(('message-$index', rect));
      }
    }
    visible.sort((a, b) => a.$2.top.compareTo(b.$2.top));
    final first = visible.first;
    return (
      first.$1,
      (viewport.top - first.$2.top) / first.$2.height,
      first.$2.height,
    );
  }

  void expectSameReading(
    (String, double, double) actual,
    (String, double, double) expected,
  ) {
    expect(actual.$1, expected.$1);
    expect(actual.$2 * actual.$3, closeTo(expected.$2 * actual.$3, 4));
  }

  testWidgets('retained pane restores a distant lazy message after returning', (
    tester,
  ) async {
    final position = AgentReadingPosition();
    await tester.pumpWidget(host(position, full: false));
    await tester.pumpAndSettle();
    final paneState = tester.state(find.byKey(paneKey));
    await tester.drag(find.byKey(paneScrollKey), const Offset(0, 740));
    await tester.pumpAndSettle();
    final before = visibleMessage(tester, paneScrollKey);
    expect(position.followLatest, isFalse);
    expect(position.anchor, ValueKey(before.$1));

    await tester.pumpWidget(host(position, full: true));
    await tester.pumpAndSettle();
    expectSameReading(visibleMessage(tester, fullScrollKey), before);

    await tester.pumpWidget(host(position, full: false));
    await tester.pumpAndSettle();
    expect(tester.state(find.byKey(paneKey)), same(paneState));
    expectSameReading(visibleMessage(tester, paneScrollKey), before);
    expect(position.followLatest, isFalse);
    expect(
      find
          .descendant(
            of: find.byKey(paneScrollKey),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'message-',
                  ),
            ),
          )
          .evaluate()
          .length,
      lessThan(20),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'reactivation with new width uses the other reader latest anchor',
    (tester) async {
      final position = AgentReadingPosition();
      await tester.pumpWidget(host(position, full: false));
      await tester.pumpAndSettle();
      final paneState = tester.state(find.byKey(paneKey));
      await tester.drag(find.byKey(paneScrollKey), const Offset(0, 740));
      await tester.pumpAndSettle();
      final paneReading = visibleMessage(tester, paneScrollKey);

      await tester.pumpWidget(host(position, full: true));
      await tester.pumpAndSettle();
      expectSameReading(visibleMessage(tester, fullScrollKey), paneReading);
      await tester.drag(find.byKey(fullScrollKey), const Offset(0, 600));
      await tester.pumpAndSettle();
      final fullReading = visibleMessage(tester, fullScrollKey);
      expect(fullReading.$1, isNot(paneReading.$1));
      expect(position.anchor, ValueKey(fullReading.$1));

      await tester.pumpWidget(host(position, full: false, paneWidth: 440));
      await tester.pumpAndSettle();
      expect(tester.state(find.byKey(paneKey)), same(paneState));
      expectSameReading(visibleMessage(tester, paneScrollKey), fullReading);
      expect(position.anchor, ValueKey(fullReading.$1));
      expect(position.followLatest, isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'in-place reply reveal keeps its original position while text grows',
    (tester) async {
      final position = AgentReadingPosition();
      await tester.pumpWidget(host(position, full: true, revision: 0));
      await tester.pumpAndSettle();
      final state = tester.state<AgentTranscriptState>(find.byKey(fullKey));
      expect(state.reveal(const ValueKey('message-120')), isTrue);
      await tester.pumpAndSettle();
      final before = visibleMessage(tester, fullScrollKey);
      expect(before.$1, 'message-120');
      expect(position.followLatest, isFalse);
      await tester.pumpWidget(
        host(
          position,
          full: true,
          heights: const {40: 1800, 120: 640},
          revision: 1,
        ),
      );
      await tester.pumpAndSettle();
      final after = visibleMessage(tester, fullScrollKey);
      expect(after.$1, before.$1);
      expect(after.$2 * after.$3, closeTo(before.$2 * before.$3, 4));
      final scroll = tester
          .widget<CustomScrollView>(find.byKey(fullScrollKey))
          .controller!;
      expect(scroll.position.extentAfter, greaterThan(10000));
      expect(position.unread, isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'changed earlier content preserves a reader who already scrolled upward',
    (tester) async {
      final position = AgentReadingPosition();
      await tester.pumpWidget(host(position, full: true, revision: 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(fullScrollKey), const Offset(0, 740));
      await tester.pumpAndSettle();
      final before = visibleMessage(tester, fullScrollKey);
      expect(position.followLatest, isFalse);
      await tester.pumpWidget(
        host(position, full: true, heights: const {40: 1800}, revision: 1),
      );
      await tester.pumpAndSettle();
      expectSameReading(visibleMessage(tester, fullScrollKey), before);
      final inactive = tester.state<AgentTranscriptState>(
        find.byKey(paneKey, skipOffstage: false),
      );
      expect(inactive.reveal(const ValueKey('message-120')), isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
