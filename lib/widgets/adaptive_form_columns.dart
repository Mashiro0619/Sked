import 'package:material_ui/material_ui.dart';

import 'workbench_layout_policy.dart';

/// Wrap repositions the same keyed form subtrees instead of replacing a Row
/// with a Column. Text controllers, focus and selection survive resizing.
class AdaptiveFormColumns extends StatelessWidget {
  const AdaptiveFormColumns({
    super.key,
    required this.primary,
    this.secondary,
    this.secondaryWidth = 320,
    this.minimumPrimaryWidth = 520,
  });
  final Widget primary;
  final Widget? secondary;
  final double secondaryWidth;
  final double minimumPrimaryWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final factor = WorkbenchLayoutPolicy.textFactor(scale);
      final sideWidth = secondaryWidth * factor;
      final wide =
          secondary != null &&
          constraints.maxWidth >= minimumPrimaryWidth * factor + sideWidth + 24;
      return Wrap(
        spacing: 24,
        runSpacing: 20,
        children: [
          SizedBox(
            key: const ValueKey('form-primary'),
            width: wide
                ? constraints.maxWidth - sideWidth - 24
                : constraints.maxWidth,
            child: primary,
          ),
          if (secondary != null)
            SizedBox(
              key: const ValueKey('form-secondary'),
              width: wide ? sideWidth : constraints.maxWidth,
              child: secondary,
            ),
        ],
      );
    },
  );
}
