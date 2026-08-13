// The bridge is intentionally isolated here until every dependency imports
// Material from the standalone package.
// ignore_for_file: deprecated_member_use

import 'package:material_ui/material_ui.dart';

Widget bridgeLegacyMaterialUi(BuildContext context, Widget? child) {
  return MaterialUiCompatibilityBridge(child: child ?? const SizedBox.shrink());
}
