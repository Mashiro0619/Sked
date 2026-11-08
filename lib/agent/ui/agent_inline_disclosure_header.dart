import 'package:material_ui/material_ui.dart';

import '../../theme/sked_menu_style.dart';
import 'agent_ui_style.dart';

/// A disclosure whose hover and tap surface follows its visible content.
class AgentInlineDisclosureHeader extends StatelessWidget {
  const AgentInlineDisclosureHeader({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.titleStyle,
    this.semanticsLabel,
    this.expanded,
    this.onTap,
    this.toggleKey,
    this.controlsKey,
    this.maxLines = 2,
  });

  final String title;
  final Widget? leading;
  final String? subtitle;
  final TextStyle? titleStyle;
  final String? semanticsLabel;
  final bool? expanded;
  final VoidCallback? onTap;
  final Key? toggleKey;
  final Key? controlsKey;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final style = AgentUiStyle.of(context);
    final disclosure = expanded != null;
    final desktop = SkedMenuStyle.of(context).desktop;
    final extent = disclosure ? (desktop ? 32.0 : 48.0) : 24.0;
    final textStyle = titleStyle ?? style.label.copyWith(color: style.muted);
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: extent),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading case final icon?) ...[icon, const SizedBox(width: 8)],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textStyle,
                    maxLines: maxLines,
                    overflow: maxLines == null
                        ? TextOverflow.clip
                        : TextOverflow.ellipsis,
                  ),
                  if (subtitle case final detail?)
                    Text(
                      detail,
                      style: style.caption.copyWith(color: style.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (disclosure) ...[
              const SizedBox(width: 4),
              Icon(
                expanded!
                    ? Icons.expand_more_rounded
                    : Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 16,
                color: style.muted,
              ),
            ],
          ],
        ),
      ),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: disclosure ? true : null,
        enabled: disclosure ? onTap != null : null,
        expanded: expanded,
        label: semanticsLabel ?? [title, ?subtitle].join(' · '),
        excludeSemantics: true,
        onTap: disclosure ? onTap : null,
        child: KeyedSubtree(
          key: controlsKey,
          child: disclosure
              ? _DisclosureSurface(
                  toggleKey: toggleKey,
                  onTap: onTap,
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}

class _DisclosureSurface extends StatefulWidget {
  const _DisclosureSurface({
    required this.toggleKey,
    required this.onTap,
    required this.child,
  });

  final Key? toggleKey;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_DisclosureSurface> createState() => _DisclosureSurfaceState();
}

class _DisclosureSurfaceState extends State<_DisclosureSurface> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final control = AgentUiStyle.of(context).controlStyle;
    const fallbackShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: widget.toggleKey,
        statesController: _states,
        onTap: widget.onTap,
        canRequestFocus: widget.onTap != null,
        customBorder:
            control.shape?.resolve(const <WidgetState>{}) ?? fallbackShape,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        child: ValueListenableBuilder<Set<WidgetState>>(
          valueListenable: _states,
          builder: (context, interaction, child) {
            final states = <WidgetState>{
              ...interaction,
              if (widget.onTap == null) WidgetState.disabled,
            };
            final shape = control.shape?.resolve(states) ?? fallbackShape;
            return DecoratedBox(
              decoration: ShapeDecoration(
                color:
                    control.backgroundColor?.resolve(states) ??
                    Colors.transparent,
                shape: shape.copyWith(
                  side: control.side?.resolve(states) ?? BorderSide.none,
                ),
              ),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
