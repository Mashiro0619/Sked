import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/sked_adaptive_picker_dialog.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_picker_task.dart';
import 'package:sked/widgets/sked_task_dialog.dart';

void main() {
  for (final adaptive in [false, true]) {
    testWidgets('explicit picker rectangle survives trigger movement and '
        'retains focus return (adaptive: $adaptive)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);
      final position = ValueNotifier<Offset>(const Offset(610, 440));
      final focus = FocusNode();
      addTearDown(position.dispose);
      addTearDown(focus.dispose);
      const snapshot = Rect.fromLTWH(260, 180, 90, 32);
      const body = SkedTaskDialog(
        title: Text('Choose'),
        content: SizedBox(height: 90),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          builder: (_, child) => Padding(
            padding: const EdgeInsets.fromLTRB(180, 80, 60, 40),
            child: child!,
          ),
          home: Scaffold(
            body: ValueListenableBuilder<Offset>(
              valueListenable: position,
              builder: (_, offset, _) => Stack(
                children: [
                  Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    width: 100,
                    height: 32,
                    child: Builder(
                      builder: (anchor) => TextButton(
                        focusNode: focus,
                        onPressed: () {
                          if (adaptive) {
                            unawaited(
                              showSkedAdaptivePickerDialog<void>(
                                context: anchor,
                                anchorContext: anchor,
                                anchorRect: snapshot,
                                routeName: 'snapshot-picker',
                                preferredWidth: 240,
                                placement: SkedFloatingPlacement.below,
                                builder: (_) => body,
                              ),
                            );
                          } else {
                            unawaited(
                              showSkedPickerTask<void>(
                                context: anchor,
                                anchorContext: anchor,
                                anchorRect: snapshot,
                                routeName: 'snapshot-picker',
                                preferredSize: (_) => const Size(240, 180),
                                placement: SkedFloatingPlacement.below,
                                builder: (_, finish, _) => SkedTaskDialogScope(
                                  onClose: () => finish(null),
                                  child: body,
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      focus.requestFocus();
      await tester.pump();
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Open'))
          .onPressed!();
      await tester.pumpAndSettle();
      final surface = find.byType(SkedFloatingSurface);
      final rect = tester.getRect(surface);
      expect(rect.left, closeTo(snapshot.left, 0.01));
      expect(rect.top, closeTo(snapshot.bottom + 6, 0.01));
      position.value = const Offset(400, 500);
      await tester.pumpAndSettle();
      expect(tester.getRect(surface), rect);
      Navigator.of(tester.element(surface)).pop();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
