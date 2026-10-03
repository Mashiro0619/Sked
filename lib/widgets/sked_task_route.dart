import 'package:material_ui/material_ui.dart';

/// Completes only the route owning this context, never a newer route above it.
/// Call only after a successful operation or an authorized user exit.
void completeSkedTaskRoute<T>(BuildContext context, [T? result]) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  final navigator = route?.navigator;
  if (route == null || navigator == null || !route.isActive) return;
  if (route.isCurrent) {
    navigator.pop<T>(result);
  } else {
    navigator.removeRoute(route, result);
  }
}
