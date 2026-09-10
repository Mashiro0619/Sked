import 'package:material_ui/material_ui.dart';

typedef RegisterAdaptivePageExitGuard = VoidCallback Function(
  ModalRoute<dynamic> route,
  Future<bool> Function() exit,
);

class AdaptiveNavigationScope extends InheritedWidget {
  const AdaptiveNavigationScope({
    super.key,
    required this.wide,
    required super.child,
    this.registerPageExitGuard,
  });
  final bool wide;

  /// Lets category navigation await an explicit-save page's asynchronous exit
  /// instead of interpreting PopScope's immediate rejection as a final result.
  final RegisterAdaptivePageExitGuard? registerPageExitGuard;
  static AdaptiveNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveNavigationScope>();
  static bool isWide(BuildContext context) => maybeOf(context)?.wide ?? false;
  @override
  bool updateShouldNotify(AdaptiveNavigationScope oldWidget) =>
      wide != oldWidget.wide ||
      registerPageExitGuard != oldWidget.registerPageExitGuard;
}
