import 'package:material_ui/material_ui.dart';

import 'settings_list.dart';
import 'workbench_layout_policy.dart';

class SettingsPreviewLayout extends StatelessWidget {
  const SettingsPreviewLayout({
    super.key,
    required this.preview,
    required this.children,
    this.scrollViewKey,
  });
  final Widget preview;
  final List<Widget> children;
  final Key? scrollViewKey;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = WorkbenchLayoutPolicy.formCanSplit(
        constraints.maxWidth,
        MediaQuery.textScalerOf(context).scale(14) / 14,
        navigation: 320,
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ResponsiveSettingsSingleColumnBody(
              scrollViewKey: scrollViewKey,
              children: [
                ...children,
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    child: IgnorePointer(child: preview),
                  ),
              ],
            ),
          ),
          if (wide)
            SizedBox(
              width: 320,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: IgnorePointer(child: preview),
              ),
            ),
        ],
      );
    },
  );
}
