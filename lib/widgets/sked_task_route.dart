import 'package:material_ui/material_ui.dart';

import 'sked_guarded_bottom_sheet_route.dart';
export 'sked_guarded_bottom_sheet_route.dart' show retireSkedTaskRoutesUntil;

/// Completes only the route owning this context, never a newer route above it.
/// Call only after a successful operation or an authorized user exit.
void completeSkedTaskRoute<T>(BuildContext context, [T? result]) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  final navigator = route?.navigator;
  if (route == null || navigator == null || !route.isActive) return;
  if (route is SkedGuardedBottomSheetRoute<dynamic>) {
    route.complete(result);
    return;
  }
  if (route.isCurrent) {
    navigator.pop<T>(result);
  } else {
    navigator.removeRoute(route, result);
  }
}
