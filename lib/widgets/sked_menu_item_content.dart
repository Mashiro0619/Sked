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
  Widget build(BuildContext context) {
    final menu = SkedMenuStyle.of(context);
    return Row(
      children: [
        if (leading != null) ...[
          SizedBox.square(dimension: menu.iconSize, child: leading),
          SizedBox(width: menu.iconGap),
        ],
        Expanded(child: child),
        if (trailing != null) ...[SizedBox(width: menu.iconGap), trailing!],
        if (selected != null) ...[
          SizedBox(width: menu.iconGap),
          SizedBox.square(
            dimension: menu.iconSize,
            child: selected!
                ? ExcludeSemantics(
                    child: Icon(Icons.check, size: menu.iconSize),
                  )
                : null,
          ),
        ],
      ],
    );
  }
}
