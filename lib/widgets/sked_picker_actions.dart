import 'package:material_ui/material_ui.dart';

/// Keeps secondary commands leading and commit commands trailing. Large text
/// wraps entire groups first, then individual commands, without shrinking them.
class SkedPickerActions extends StatelessWidget {
  const SkedPickerActions({
    super.key,
    required this.leading,
    required this.trailing,
  });
  final List<Widget> leading, trailing;

  @override
  Widget build(BuildContext context) => OverflowBar(
    alignment: MainAxisAlignment.spaceBetween,
    overflowAlignment: OverflowBarAlignment.end,
    spacing: 12,
    overflowSpacing: 4,
    children: [
      Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: leading,
      ),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: trailing,
      ),
    ],
  );
}
