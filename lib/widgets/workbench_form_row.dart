import 'package:material_ui/material_ui.dart';

import 'workbench_chrome_metrics.dart';

class WorkbenchFormRow extends StatelessWidget {
  const WorkbenchFormRow({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final m = WorkbenchChromeMetrics.of(context);
      final inline = constraints.maxWidth >= 440 * m.textScale;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Flex(
          direction: inline ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: inline ? 144 * m.textScale : null,
              child: Padding(
                padding: EdgeInsets.only(
                  top: inline ? 10 : 0,
                  bottom: inline ? 0 : 8,
                  right: 16,
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            Flexible(flex: inline ? 1 : 0, fit: FlexFit.loose, child: child),
          ],
        ),
      );
    },
  );
}
