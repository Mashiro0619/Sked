import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/sked_floating_position_controller.dart';

void main() {
  test(
    'position follows anchor until dragged and remembers invalid anchors',
    () {
      final p = SkedFloatingPositionController();
      expect(p.positionOverride(hasAnchor: false), isNull);
      p.recordLayout(const Offset(100, 100), const Size(200, 200));
      expect(p.positionOverride(hasAnchor: true), isNull);
      expect(p.positionOverride(hasAnchor: false), const Offset(100, 100));
      p.drag(const Offset(50, 40), const Rect.fromLTWH(8, 8, 600, 600));
      expect(p.positionOverride(hasAnchor: true), const Offset(150, 140));
      expect(p.detached, isTrue);
      p.reset();
      expect(p.positionOverride(hasAnchor: false), isNull);
      expect(p.detached, isFalse);
    },
  );
  test(
    'resize clamps drag origin before applying delta; state is instance local',
    () {
      final p = SkedFloatingPositionController();
      p.recordLayout(const Offset(500, 500), const Size(200, 200));
      expect(
        p.drag(const Offset(-10, -10), const Rect.fromLTWH(8, 8, 400, 400)),
        const Offset(198, 198),
      );
      expect(SkedFloatingPositionController().lastPosition, isNull);
    },
  );
}
