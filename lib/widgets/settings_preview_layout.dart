import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../services/desktop_layout_preferences.dart';
import 'settings_list.dart';
import 'sked_resizable.dart';
import 'workbench_layout_policy.dart';

class SettingsPreviewLayout extends StatelessWidget {
  const SettingsPreviewLayout({
    super.key,
    required this.preview,
    required this.children,
    this.scrollViewKey,
    this.headerSliver,
  });
  final Widget preview;
  final List<Widget> children;
  final Key? scrollViewKey;
  final Widget? headerSliver;
  @override
  Widget build(BuildContext context) => DesktopResizableRegion(
    layoutKey: DesktopLayoutRegion.themePreview,
    builder: (context, preferred, update, commit, reset) => LayoutBuilder(
      builder: (context, constraints) {
        final factor = WorkbenchLayoutPolicy.textFactor(
          MediaQuery.textScalerOf(context).scale(14) / 14,
        );
        final maximumWidth = math.max(
          320 * factor,
          constraints.maxWidth - 520 * factor,
        );
        final previewWidth = ((preferred ?? 320) * factor).clamp(
          320 * factor,
          maximumWidth,
        );
        final wide = WorkbenchLayoutPolicy.formCanSplit(
          constraints.maxWidth,
          MediaQuery.textScalerOf(context).scale(14) / 14,
          navigation: 320,
        );
        return Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ResponsiveSettingsSingleColumnBody(
                    scrollViewKey: scrollViewKey,
                    headerSliver: headerSliver,
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
                    width: previewWidth,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: IgnorePointer(child: preview),
                    ),
                  ),
              ],
            ),
            if (wide && WorkbenchLayoutPolicy.pointerLayout(context))
              PositionedDirectional(
                end: previewWidth - 4,
                top: 0,
                bottom: 0,
                width: 9,
                child: SkedExtentResizeHandle(
                  key: const ValueKey('theme-preview-resize'),
                  reverse: true,
                  extent: previewWidth,
                  minExtent: 320 * factor,
                  maxExtent: maximumWidth,
                  onChanged: (extent) => update(extent / factor),
                  onEnd: commit,
                  onReset: reset,
                ),
              ),
          ],
        );
      },
    ),
  );
}
