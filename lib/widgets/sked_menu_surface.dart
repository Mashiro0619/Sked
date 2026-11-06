import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/sked_expressive_theme.dart';
import '../theme/sked_menu_style.dart';

abstract final class SkedMenuMotion {
  static Duration duration(SkedMotionPolicy motion, {bool reverse = false}) {
    if (!motion.animationsEnabled) return Duration.zero;
    if (motion.reduceMotion) return const Duration(milliseconds: 120);
    return Duration(milliseconds: reverse ? 160 : 280);
  }
}

/// One transition for the entire menu, independent of its number of items.
class SkedMenuSurface extends StatelessWidget {
  const SkedMenuSurface({
    super.key,
    required this.animation,
    required this.motion,
    required this.alignment,
    required this.child,
    this.style,
    this.closing = false,
  });

  final Animation<double> animation;
  final SkedMotionPolicy motion;
  final Alignment alignment;
  final MenuStyle? style;
  final Widget child;
  final bool closing;

  @override
  Widget build(BuildContext context) {
    final menu = SkedMenuStyle.of(context);
    final effective = menu.menuStyle.merge(style);
    const states = <WidgetState>{};
    final surface = Material(
      type: MaterialType.card,
      color: effective.backgroundColor?.resolve(states) ?? menu.surface,
      elevation: effective.elevation?.resolve(states) ?? menu.elevation,
      shadowColor: effective.shadowColor?.resolve(states) ?? menu.shadow,
      surfaceTintColor: Colors.transparent,
      shape: effective.shape?.resolve(states) ?? menu.shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: effective.padding?.resolve(states) ?? menu.padding,
        child: child,
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      child: surface,
      builder: (context, child) {
        final exiting = closing || animation.status == AnimationStatus.reverse;
        // Use the same mapping in both directions so interruptions retain
        // their current opacity and scale rather than switching easing curves.
        final progress = motion.animationsEnabled
            ? Curves.easeOutCubic.transform(animation.value.clamp(0.0, 1.0))
            : exiting
            ? 0.0
            : 1.0;
        return ExcludeSemantics(
          excluding: exiting,
          child: ExcludeFocus(
            excluding: exiting,
            child: IgnorePointer(
              ignoring: exiting,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: motion.spatialAnimationsEnabled
                      ? .90 + .10 * progress
                      : 1,
                  alignment: alignment,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Places both route menus and anchored panels inside current overlay bounds.
class SkedMenuLayoutDelegate extends SingleChildLayoutDelegate {
  SkedMenuLayoutDelegate({
    required this.anchor,
    required this.available,
    required this.textDirection,
    required this.constraints,
    this.alignToAnchorTop = false,
    this.anchorAlignment,
    this.preferredAlignment,
    this.onAlignment,
  });

  final Rect anchor;
  final Rect available;
  final TextDirection textDirection;
  final BoxConstraints constraints;
  final bool alignToAnchorTop;
  final AlignmentGeometry? anchorAlignment;
  final Alignment? preferredAlignment;
  final ValueChanged<Alignment>? onAlignment;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final below = alignToAnchorTop ? anchor.top : anchor.bottom;
    final aboveSpace = (anchor.top - available.top).clamp(
      0.0,
      available.height,
    );
    final belowSpace = (available.bottom - below).clamp(0.0, available.height);
    final sideHeight = math.max(aboveSpace, belowSpace);
    // Route callers provide a desired menu position. Anchored controls provide
    // their actual bounds and keep the menu on one side of that control.
    final heightLimit = alignToAnchorTop || sideHeight == 0
        ? available.height
        : sideHeight;
    final width = math.min(
      constraints.maxWidth,
      math.min(available.width, this.constraints.maxWidth),
    );
    final height = math.min(
      constraints.maxHeight,
      math.min(heightLimit, this.constraints.maxHeight),
    );
    return BoxConstraints(
      minWidth: math.min(this.constraints.minWidth, width),
      maxWidth: width,
      minHeight: math.min(this.constraints.minHeight, height),
      maxHeight: height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = alignToAnchorTop ? anchor.top : anchor.bottom;
    final fitsBelow = below + childSize.height <= available.bottom;
    final fitsAbove = anchor.top - childSize.height >= available.top;
    final preferAbove = preferredAlignment?.y == 1;
    final above = preferAbove
        ? fitsAbove || !fitsBelow
        : !fitsBelow && fitsAbove;
    final top = (above ? anchor.top - childSize.height : below).clamp(
      available.top,
      math.max(available.top, available.bottom - childSize.height),
    );
    final spaceBefore = anchor.left - available.left;
    final spaceAfter = available.right - anchor.right;
    final horizontal = anchorAlignment?.resolve(textDirection).x;
    final alignEnd = horizontal == null
        ? spaceBefore > spaceAfter ||
              (spaceBefore == spaceAfter && textDirection == TextDirection.rtl)
        : horizontal > 0;
    final left = (alignEnd ? anchor.right - childSize.width : anchor.left)
        .clamp(
          available.left,
          math.max(available.left, available.right - childSize.width),
        );
    final originX = childSize.width == 0
        ? 0.0
        : ((anchor.center.dx - left) / childSize.width * 2 - 1).clamp(
            -1.0,
            1.0,
          );
    final alignment = Alignment(originX, above ? 1 : -1);
    if (alignment != preferredAlignment && onAlignment != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onAlignment!(alignment),
      );
    }
    return Offset(left.toDouble(), top.toDouble());
  }

  @override
  bool shouldRelayout(SkedMenuLayoutDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      available != oldDelegate.available ||
      textDirection != oldDelegate.textDirection ||
      constraints != oldDelegate.constraints ||
      alignToAnchorTop != oldDelegate.alignToAnchorTop ||
      anchorAlignment != oldDelegate.anchorAlignment ||
      preferredAlignment != oldDelegate.preferredAlignment;
}
