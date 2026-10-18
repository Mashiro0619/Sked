import 'package:material_ui/material_ui.dart';

import '../theme/sked_menu_style.dart';

/// One row layout for menu labels, optional action icons and checked choices.
/// A null selection is an action; either boolean reserves the same check slot.
class SkedMenuItemContent extends StatelessWidget {
  const SkedMenuItemContent({
    super.key,
    required this.child,
    this.leading,
    this.trailing,
    this.selected,
  });

  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final bool? selected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (leading != null) ...[
        SizedBox.square(dimension: SkedMenuStyle.iconSize, child: leading),
        const SizedBox(width: SkedMenuStyle.iconGap),
      ],
      Expanded(child: child),
      if (trailing != null) ...[
        const SizedBox(width: SkedMenuStyle.iconGap),
        trailing!,
      ],
      if (selected != null) ...[
        const SizedBox(width: SkedMenuStyle.iconGap),
        SizedBox.square(
          dimension: SkedMenuStyle.iconSize,
          child: selected!
              ? const ExcludeSemantics(
                  child: Icon(Icons.check, size: SkedMenuStyle.iconSize),
                )
              : null,
        ),
      ],
    ],
  );
}
