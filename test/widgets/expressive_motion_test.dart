import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/expressive_motion.dart';

void main() {
  testWidgets('ExpressiveTap does not trigger when disabled', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ExpressiveTap(
              enabled: false,
              onTap: () => tapCount += 1,
              child: const SizedBox(width: 100, height: 48),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ExpressiveTap));
    await tester.pump();

    expect(tapCount, 0);
  });
}
