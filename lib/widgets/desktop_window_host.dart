import '../theme/sked_surface.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/desktop_window_bridge.dart';
import 'desktop_window_modal_observer.dart';
import 'workbench_chrome_metrics.dart';
import 'workspace_frame.dart';

export 'desktop_window_modal_observer.dart';

/// Interactive controls win gestures; only unused toolbar space starts a native
/// move. The OS retains edge resize, snapping and the maximize hit-test region.
class DesktopDragRegion extends StatelessWidget {
  const DesktopDragRegion({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final bridge = DesktopWindowBridge.instance;
    if (!bridge.available) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => unawaited(bridge.command('startDrag')),
            onDoubleTap: () => unawaited(bridge.command('toggleMaximize')),
            onSecondaryTap: () => unawaited(bridge.command('systemMenu')),
          ),
        ),
        child,
      ],
    );
  }
}

class DesktopCaptionSpacer extends StatelessWidget {
  const DesktopCaptionSpacer({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: DesktopWindowBridge.instance.available
        ? WorkbenchChromeMetrics.of(context).captionWidth
        : 0,
  );
}

/// Drop-in app bar with native caption clearance. The application and OS controls
/// share one row, including settings, import, onboarding and recovery pages.
class WorkbenchAppBar extends AppBar {
  WorkbenchAppBar({
    super.key,
    super.title,
    super.leading,
    super.automaticallyImplyLeading,
    List<Widget>? actions,
    super.bottom,
    super.backgroundColor,
    super.foregroundColor,
    super.elevation,
    super.scrolledUnderElevation,
    super.centerTitle,
    super.titleSpacing,
    super.leadingWidth,
    super.toolbarHeight,
    super.notificationPredicate,
    super.shape,
    super.iconTheme,
    super.actionsIconTheme,
    super.primary,
    super.titleTextStyle,
    super.toolbarTextStyle,
    super.systemOverlayStyle,
    Widget? flexibleSpace,
    bool reserveCaption = true,
  }) : super(
         actions: [
           ...?actions,
           if (reserveCaption && DesktopWindowBridge.instance.available)
             const DesktopCaptionSpacer(),
         ],
         flexibleSpace: DesktopDragRegion(
           child: flexibleSpace ?? const SizedBox.expand(),
         ),
       );
}

/// Pages supply commands; this host owns native controls and the shared divider,
/// never a second empty title bar. Geometry is sent to Win32 in logical pixels.
class DesktopWindowHost extends StatelessWidget {
  const DesktopWindowHost({
    super.key,
    required this.child,
    required this.modalObserver,
  });
  final Widget child;
  final DesktopWindowModalObserver modalObserver;
  @override
  Widget build(BuildContext context) {
    final bridge = DesktopWindowBridge.instance;
    final metrics = WorkbenchChromeMetrics.of(context);
    if (!metrics.desktop) return child;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          toolbarHeight: metrics.toolbarHeight,
          backgroundColor: SkedSurfaceRole.frame.resolve(colors),
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
      ),
      child: !bridge.available
          ? child
          : AnimatedBuilder(
              animation: Listenable.merge([bridge, modalObserver]),
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    unawaited(
                      bridge.configureChrome(
                        width: constraints.maxWidth,
                        height: metrics.toolbarHeight,
                        buttonWidth: metrics.captionButtonWidth,
                      ),
                    );
                  });
                  final l = AppLocalizations.of(context);
                  return Stack(
                    children: [
                      Positioned.fill(child: child),
                      Positioned(
                        top: 0,
                        right: 0,
                        width: metrics.captionWidth,
                        height: metrics.toolbarHeight,
                        child: Material(
                          color: SkedSurfaceRole.frame.resolve(colors),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              children: [
                                _CaptionButton(
                                  label: l.minimizeWindow,
                                  icon: Icons.remove,
                                  height: metrics.toolbarHeight,
                                  width: metrics.captionButtonWidth,
                                  onPressed: () => bridge.command('minimize'),
                                ),
                                _CaptionButton(
                                  label: bridge.maximized
                                      ? l.restoreWindow
                                      : l.maximizeWindow,
                                  nativeHover: bridge.maximizeHovered,
                                  icon: bridge.maximized
                                      ? Icons.filter_none
                                      : Icons.crop_square,
                                  height: metrics.toolbarHeight,
                                  width: metrics.captionButtonWidth,
                                  onPressed: () =>
                                      bridge.command('toggleMaximize'),
                                ),
                                _CaptionButton(
                                  label: l.closeWindow,
                                  icon: Icons.close,
                                  close: true,
                                  height: metrics.toolbarHeight,
                                  width: metrics.captionButtonWidth,
                                  onPressed: bridge.closing
                                      ? null
                                      : bridge.requestClose,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        key: const ValueKey('desktop-window-divider'),
                        top: metrics.toolbarHeight - 1,
                        left: 0,
                        right: 0,
                        height: 1,
                        child: IgnorePointer(
                          child: ColoredBox(color: colors.outlineVariant),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: metrics.toolbarHeight,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: ClipPath(
                              clipper: _ChromeScrimClipper(
                                metrics.captionWidth,
                              ),
                              child: ColoredBox(
                                key: const ValueKey(
                                  'desktop-window-modal-scrim',
                                ),
                                color: modalObserver.scrimColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

// The application toolbar already sits under Navigator's real barrier. Only
// shade the chrome drawn above it; shading the whole row would dim it twice.
class _ChromeScrimClipper extends CustomClipper<Path> {
  const _ChromeScrimClipper(this.captionWidth);
  final double captionWidth;

  @override
  Path getClip(Size size) {
    final left = (size.width - captionWidth).clamp(0.0, size.width);
    return Path()
      ..addRect(Rect.fromLTRB(left, 0, size.width, size.height))
      ..addRect(Rect.fromLTRB(0, size.height - 1, left, size.height));
  }

  @override
  bool shouldReclip(_ChromeScrimClipper oldClipper) =>
      oldClipper.captionWidth != captionWidth;
}

/// Desktop commands do not inherit mobile ordering/hiding preferences. Calendar
/// callers supply a compact row when native-caption clearance leaves little room.
class WorkbenchCommandBar extends StatelessWidget {
  const WorkbenchCommandBar({
    super.key,
    required this.navigation,
    this.actions = const [],
    this.compactBuilder,
  });
  final List<Widget> navigation;
  final List<Widget> actions;
  final WidgetBuilder? compactBuilder;
  @override
  Widget build(BuildContext context) {
    final m = WorkbenchChromeMetrics.of(context);
    final colors = Theme.of(context).colorScheme;
    final layout = WorkspaceCanvasScope.maybeOf(context);
    final reserve =
        DesktopWindowBridge.instance.available &&
        !(layout?.dockedDetail == true ||
            layout?.dockedAssistant == true ||
            layout?.supporting == true);
    Widget row(List<Widget> items) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          items[i],
        ],
      ],
    );
    return SkedSurface(
      role: SkedSurfaceRole.frame,
      shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
      child: SizedBox(
        height: m.toolbarHeight,
        child: IconButtonTheme(
          data: IconButtonThemeData(style: m.iconStyle),
          child: TextButtonTheme(
            data: TextButtonThemeData(
              style: TextButton.styleFrom(
                minimumSize: Size(32, m.commandHeight),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            child: DesktopDragRegion(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: 12,
                  end: 12 + (reserve ? m.captionWidth : 0),
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    if (compactBuilder != null &&
                        c.maxWidth < 700 * m.textScale) {
                      return compactBuilder!(context);
                    }
                    if (c.maxWidth < 700) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: row([...navigation, ...actions]),
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: row(navigation),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        row(actions),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.close = false,
    this.nativeHover = false,
    required this.height,
    required this.width,
  });
  final String label;
  final IconData icon;
  final Future<void> Function()? onPressed;
  final bool close;
  final bool nativeHover;
  final double height;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Semantics(
      label: label,
      button: true,
      child: IconButton(
        onPressed: onPressed,
        iconSize: 16,
        style: IconButton.styleFrom(
          minimumSize: Size(width, height),
          maximumSize: Size(width, height),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(),
          backgroundColor: nativeHover
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
          hoverColor: close
              ? Theme.of(context).colorScheme.errorContainer
              : null,
        ),
        icon: Icon(icon),
      ),
    ),
  );
}
