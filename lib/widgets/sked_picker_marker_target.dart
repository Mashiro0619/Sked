import 'package:material_ui/material_ui.dart';

/// Keeps the full picker cell interactive while its builder paints state only
/// inside the date/week marker. The containing grid owns focus and semantics.
class SkedPickerMarkerTarget extends StatefulWidget {
  const SkedPickerMarkerTarget({
    super.key,
    required this.onTap,
    required this.builder,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, double stateOpacity) builder;

  @override
  State<SkedPickerMarkerTarget> createState() => _SkedPickerMarkerTargetState();
}

class _SkedPickerMarkerTargetState extends State<SkedPickerMarkerTarget> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      statesController: _states,
      onTap: widget.onTap,
      canRequestFocus: false,
      excludeFromSemantics: true,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      child: ValueListenableBuilder<Set<WidgetState>>(
        valueListenable: _states,
        builder: (context, states, _) => widget.builder(
          context,
          widget.onTap == null || states.contains(WidgetState.disabled)
              ? .0
              : states.contains(WidgetState.pressed)
              ? .08
              : states.contains(WidgetState.hovered)
              ? .05
              : .0,
        ),
      ),
    ),
  );
}
