import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/sked_surface.dart';
import 'adaptive_navigation_scope.dart';
import 'desktop_window_host.dart';
import 'settings_list.dart';
import 'workbench_chrome_metrics.dart';
import 'workbench_layout_policy.dart';

typedef SettingsPageBodyBuilder = Widget Function(
  BuildContext context,
  Widget? headerSliver,
);

/// Settings destinations share their header with the retained overview. The
/// body owns the scroll view so the large title and preferences scroll together.
class SettingsPageScaffold extends StatelessWidget {
  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.bodyBuilder,
    this.headerBottom,
    this.statusIndicator,
  });

  final String title;
  final SettingsPageBodyBuilder bodyBuilder;
  final PreferredSizeWidget? headerBottom;
  final Widget? statusIndicator;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _buildLayout);

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final navigation = AdaptiveNavigationScope.maybeOf(context);
    final compact =
        metrics.desktop ||
        (navigation?.wide ??
            WorkbenchLayoutPolicy.formCanSplit(
              math.max(
                0,
                constraints.maxWidth - MediaQuery.paddingOf(context).horizontal,
              ),
              metrics.textScale,
            ));
    final topInset = MediaQuery.paddingOf(context).top;
    final overlayDefaults =
        ThemeData.estimateBrightnessForColor(theme.scaffoldBackgroundColor) ==
            Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    final overlayTheme = AppBarTheme.of(context).systemOverlayStyle;
    final statusBarStyle = SystemUiOverlayStyle(
      statusBarColor: overlayTheme?.statusBarColor ?? Colors.transparent,
      statusBarBrightness:
          overlayTheme?.statusBarBrightness ??
          overlayDefaults.statusBarBrightness,
      statusBarIconBrightness:
          overlayTheme?.statusBarIconBrightness ??
          overlayDefaults.statusBarIconBrightness,
      systemStatusBarContrastEnforced:
          overlayTheme?.systemStatusBarContrastEnforced ??
          overlayDefaults.systemStatusBarContrastEnforced,
    );
    final mobileBottom = statusIndicator == null
        ? headerBottom
        : PreferredSize(
            preferredSize: Size.fromHeight(
              (headerBottom?.preferredSize.height ?? 0) + 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [?headerBottom, statusIndicator!],
            ),
          );
    final header = SettingsPageHeader(
      title: title,
      bottom: compact ? headerBottom : mobileBottom,
      toolbar: compact,
    );
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: compact
                      ? metrics.toolbarHeight +
                            (headerBottom?.preferredSize.height ?? 0)
                      : 0,
                  child: compact ? header : null,
                ),
                if (compact && statusIndicator != null)
                  statusIndicator!
                else
                  const SizedBox.shrink(),
                Expanded(
                  // Keep both the body location and its scroll host stable
                  // across touch layout breakpoints. Pointer pages retain
                  // their eager form host for persistent overlay semantics.
                  child: bodyBuilder(
                    context,
                    metrics.desktop
                        ? null
                        : compact
                        ? const SliverToBoxAdapter()
                        : header,
                  ),
                ),
              ],
            ),
          ),
          if (!metrics.desktop && topInset > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset,
              child: IgnorePointer(
                // AppBar is below SafeArea. Annotate only its top inset so
                // navigation-bar annotations remain owned by their surface.
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: statusBarStyle,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    super.key,
    required this.title,
    this.compactTitle,
    this.onBack,
    this.headerKey = const ValueKey('settings-page-app-bar'),
    this.bottom,
    this.toolbar = false,
  });

  final String title;
  final String? compactTitle;
  final VoidCallback? onBack;
  final Key headerKey;
  final PreferredSizeWidget? bottom;
  final bool toolbar;

  @override
  Widget build(BuildContext context) {
    if (toolbar) {
      final metrics = WorkbenchChromeMetrics.of(context);
      final wide = AdaptiveNavigationScope.isWide(context);
      return WorkbenchAppBar(
        key: headerKey,
        primary: false,
        toolbarHeight: metrics.toolbarHeight,
        automaticallyImplyLeading: false,
        leading: wide ? null : BackButton(onPressed: onBack),
        title: _SettingsCompactTitle(compactTitle ?? title),
        bottom: bottom,
        reserveCaption: false,
        actions: const [DesktopCaptionSpacer()],
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final metrics = WorkbenchChromeMetrics.of(context);
        final wide = AdaptiveNavigationScope.isWide(context);
        void back() {
          if (onBack case final callback?) {
            callback();
          } else {
            Navigator.of(context).maybePop();
          }
        }

        if (metrics.desktop || wide) {
          return SliverAppBar(
            key: headerKey,
            pinned: true,
            primary: false,
            toolbarHeight: metrics.toolbarHeight,
            automaticallyImplyLeading: false,
            leading: wide ? null : BackButton(onPressed: back),
            title: _SettingsCompactTitle(compactTitle ?? title),
            bottom: bottom,
            actions: const [DesktopCaptionSpacer()],
            flexibleSpace: const DesktopDragRegion(child: SizedBox.expand()),
            backgroundColor: SkedSurfaceRole.frame.resolve(colors),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          );
        }

        final titleStyle = theme.textTheme.headlineMedium!.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: colors.onSurface,
        );
        final titleScaler = MediaQuery.textScalerOf(context)
            .clamp(maxScaleFactor: 1.3);
        final painter = TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textScaler: titleScaler,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: math.max(1, constraints.crossAxisExtent - 32));
        final titleHeight = math.max(
          titleScaler.scale(32) * 1.25,
          painter.height,
        );
        painter.dispose();
        final bottomHeight = bottom?.preferredSize.height ?? 0;
        return Theme(
          data: theme.copyWith(appBarTheme: const AppBarThemeData()),
          child: SliverAppBar.large(
            key: headerKey,
            primary: false,
            pinned: true,
            expandedHeight: 104 + titleHeight + bottomHeight,
            automaticallyImplyLeading: false,
            leadingWidth: 72,
            leading: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
              child: BackButton(
                onPressed: back,
                style: IconButton.styleFrom(
                  backgroundColor: SettingsVisuals.rowColor(colors),
                  shape: const CircleBorder(),
                ),
              ),
            ),
            title: _SettingsCompactTitle(title, expandingHeader: true),
            flexibleSpace: _SettingsExpandedTitle(
              title: title,
              style: titleStyle,
              textScaler: titleScaler,
              bottomHeight: bottomHeight,
            ),
            bottom: bottom,
            backgroundColor: colors.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
        );
      },
    );
  }
}

class _SettingsCompactTitle extends StatelessWidget {
  const _SettingsCompactTitle(this.title, {this.expandingHeader = false});
  final String title;
  final bool expandingHeader;

  @override
  Widget build(BuildContext context) {
    final settings = expandingHeader
        ? context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>()
        : null;
    return ExcludeSemantics(
      excluding:
          settings != null && settings.currentExtent > settings.minExtent,
      child: Semantics(
        header: true,
        label: title,
        child: ExcludeSemantics(
          child: SingleChildScrollView(
            key: const ValueKey('settings-compact-title-scroll'),
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Text(title, maxLines: 1, softWrap: false),
          ),
        ),
      ),
    );
  }
}

class _SettingsExpandedTitle extends StatelessWidget {
  const _SettingsExpandedTitle({
    required this.title,
    required this.style,
    required this.textScaler,
    required this.bottomHeight,
  });
  final String title;
  final TextStyle style;
  final TextScaler textScaler;
  final double bottomHeight;

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>()!;
    final progress =
        ((settings.currentExtent - settings.minExtent) /
                (settings.maxExtent - settings.minExtent))
            .clamp(0.0, 1.0);
    return ExcludeSemantics(
      excluding: progress == 0,
      child: ClipRect(
        child: Padding(
          padding: EdgeInsets.only(top: kToolbarHeight, bottom: bottomHeight),
          child: Opacity(
            opacity: progress,
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 28),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    key: const ValueKey('settings-expanded-title'),
                    style: style,
                    textScaler: textScaler,
                    softWrap: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
