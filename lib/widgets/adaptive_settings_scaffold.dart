import '../theme/sked_surface.dart';

import 'desktop_window_host.dart';
import 'workbench_chrome_metrics.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/settings_catalog.dart';
import '../models/settings_destination.dart';
import 'workbench_layout_policy.dart';
import 'adaptive_navigation_scope.dart';
import '../theme/sked_expressive_theme.dart';
import 'settings_list.dart';

typedef SettingsOverviewBuilder = Widget Function(
  BuildContext context,
  ScrollController controller,
  Map<String, GlobalKey> sectionKeys,
  ValueChanged<SettingsDestination> openDestination,
  Widget headerSliver,
);

class AdaptiveSettingsScaffold extends StatefulWidget {
  const AdaptiveSettingsScaffold({
    super.key,
    required this.catalog,
    required this.builder,
    required this.overviewBuilder,
  });
  final List<SettingsCatalogEntry> catalog;
  final Widget Function(SettingsCatalogEntry) builder;
  final SettingsOverviewBuilder overviewBuilder;
  @override
  State<AdaptiveSettingsScaffold> createState() =>
      _AdaptiveSettingsScaffoldState();
}

class _AdaptiveSettingsScaffoldState extends State<AdaptiveSettingsScaffold> {
  final _navigator = GlobalKey<NavigatorState>();
  final _observer = _SettingsNavigatorObserver();
  final _pageExitGuards = <ModalRoute<dynamic>, Future<bool> Function()>{};
  final _overviewController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};
  String? _highlightedGroup;

  VoidCallback _registerPageExitGuard(
    ModalRoute<dynamic> route,
    Future<bool> Function() exit,
  ) {
    _pageExitGuards[route] = exit;
    return () {
      if (identical(_pageExitGuards[route], exit)) {
        _pageExitGuards.remove(route);
      }
    };
  }

  Future<void> _popCurrentPage(NavigatorState navigator) async {
    final exit = _pageExitGuards[_observer.topRoute];
    if (exit != null) {
      await exit();
    } else {
      await navigator.maybePop();
    }
  }

  @override
  void dispose() {
    _pageExitGuards.clear();
    _overviewController.dispose();
    super.dispose();
  }

  SettingsDestination? _selected;
  bool _opening = false;
  bool _closing = false;
  bool _wide = false;
  int _routeGeneration = 0;

  void _openDestination(SettingsDestination destination) {
    final entry =
        widget.catalog
            .where((entry) => entry.destination == destination)
            .firstOrNull ??
        SettingsCatalogEntry(destination.name, '', destination);
    unawaited(_open(entry));
  }

  Future<void> _scrollToSection(SettingsCatalogEntry entry) async {
    if (_opening || _closing) return;
    _opening = true;
    try {
      final navigator = _navigator.currentState!;
      while (navigator.canPop()) {
        final revision = _observer.revision;
        await _popCurrentPage(navigator);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !navigator.mounted || revision == _observer.revision) {
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _selected = null;
        _highlightedGroup = entry.id;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final section = _sectionKeys[entry.id]?.currentContext;
      if (section != null && section.mounted) {
        await Scrollable.ensureVisible(
          section,
          alignment: 0,
          duration: SkedMotionPolicy.of(context).effects(SkedMotionSpeed.fast),
        );
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _open(SettingsCatalogEntry entry) async {
    final destination = entry.destination;
    if (!mounted ||
        _opening ||
        _closing ||
        (entry.category && destination == _selected)) {
      return;
    }
    _opening = true;
    try {
      final navigator = _navigator.currentState!;
      // Give the current page's save/exit guard the first opportunity to flush.
      while (navigator.canPop()) {
        final revision = _observer.revision;
        await _popCurrentPage(navigator);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !navigator.mounted || _observer.revision == revision) {
          return;
        }
      }
      if (!mounted) return;
      final generation = ++_routeGeneration;
      setState(() => _selected = destination);
      unawaited(
        navigator
            .push<void>(
              MaterialPageRoute(builder: (_) => widget.builder(entry)),
            )
            .then((_) {
              if (mounted && generation == _routeGeneration) {
                setState(() => _selected = null);
              }
            }),
      );
    } finally {
      _opening = false;
    }
  }

  Future<void> _back() async {
    if (_closing || _opening || !mounted) return;
    _closing = true;
    try {
      final navigator = _navigator.currentState!;
      if (navigator.canPop()) {
        await _popCurrentPage(navigator);
        // A detail always returns to the retained overview first, even wide.
        return;
      }
      // Inline controls register PopScopes on the nested overview route too.
      // Do not bypass them just because the inner navigator is at its root.
      if (_observer.topRoute?.popDisposition == RoutePopDisposition.doNotPop) {
        return;
      }
      if (mounted) await Navigator.of(context).maybePop();
    } finally {
      _closing = false;
    }
  }

  Widget _navigation({required bool sidebar}) {
    final entries = widget.catalog.where((entry) => entry.category).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final entry in entries)
                ListTile(
                  key: ValueKey('settings-category-${entry.id}'),
                  selected: sidebar && entry.id == _highlightedGroup,
                  leading: Icon(_icon(entry.destination), size: 22),
                  title: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: entry.summary.isEmpty ? null : Text(entry.summary),
                  trailing: sidebar ? null : const Icon(Icons.chevron_right),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => unawaited(_scrollToSection(entry)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      _wide = WorkbenchLayoutPolicy.formCanSplit(
        constraints.maxWidth,
        textScale,
      );
      if (!widget.catalog.any(
        (entry) => entry.category && entry.id == _highlightedGroup,
      )) {
        _highlightedGroup = widget.catalog
            .where((entry) => entry.category)
            .firstOrNull
            ?.id;
      }
      for (final entry in widget.catalog) {
        _sectionKeys.putIfAbsent(
          entry.id,
          () => GlobalKey(debugLabel: 'settings-section-${entry.id}'),
        );
      }
      return PopScope(
        canPop: _selected == null,
        child: Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: _wide
                      ? 224 * WorkbenchLayoutPolicy.textFactor(textScale)
                      : 0,
                  child: Offstage(
                    offstage: !_wide,
                    child: ExcludeFocus(
                      excluding: !_wide,
                      child: Column(
                        children: [
                          SizedBox(
                            height: WorkbenchChromeMetrics.of(context)
                                .toolbarHeight,
                            child: WorkbenchAppBar(
                              primary: false,
                              reserveCaption: false,
                              leading: BackButton(
                                onPressed: () => unawaited(_back()),
                              ),
                              title: Text(
                                AppLocalizations.of(context).settingsTitle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SkedSurface(
                              role: SkedSurfaceRole.frame,
                              child: _navigation(sidebar: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_wide) const VerticalDivider(width: 1),
                Expanded(
                  child: AdaptiveNavigationScope(
                    wide: _wide,
                    registerPageExitGuard: _registerPageExitGuard,
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      child: NavigatorPopHandler<void>(
                        onPopWithResult: (_) => unawaited(_back()),
                        child: Navigator(
                          key: _navigator,
                          observers: [_observer],
                          requestFocus: false,
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (pageContext) => Scaffold(
                              body: widget.overviewBuilder(
                                pageContext,
                                _overviewController,
                                _sectionKeys,
                                _openDestination,
                                _SettingsOverviewAppBar(
                                  onBack: () => unawaited(_back()),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The overview has one scroll owner. Mobile gets Material's large title that
/// collapses naturally; pointer layouts keep a caption-safe compact toolbar.
class _SettingsOverviewAppBar extends StatelessWidget {
  const _SettingsOverviewAppBar({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final metrics = WorkbenchChromeMetrics.of(context);
    final wide = AdaptiveNavigationScope.isWide(context);
    final l = AppLocalizations.of(context);
    if (metrics.desktop || wide) {
      return SliverAppBar(
        key: const ValueKey('settings-overview-app-bar'),
        pinned: true,
        primary: false,
        toolbarHeight: metrics.toolbarHeight,
        automaticallyImplyLeading: false,
        leading: wide ? null : BackButton(onPressed: onBack),
        title: Text(wide ? l.settingsOverview : l.settingsTitle),
        actions: const [DesktopCaptionSpacer()],
        flexibleSpace: const DesktopDragRegion(child: SizedBox.expand()),
        backgroundColor: SkedSurfaceRole.frame.resolve(colors),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      );
    }
    final titleHeight =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(32) *
        1.25;
    return Theme(
      // AppBarTheme's compact title style otherwise overrides Material's large
      // expanded typography. Keep this override local to the overview header.
      data: theme.copyWith(
        appBarTheme: const AppBarThemeData(),
        textTheme: theme.textTheme.copyWith(
          headlineMedium: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      child: SliverAppBar.large(
        key: const ValueKey('settings-overview-app-bar'),
        primary: false,
        pinned: true,
        expandedHeight: 104 + titleHeight,
        automaticallyImplyLeading: false,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: BackButton(
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: SettingsVisuals.rowColor(colors),
              shape: const CircleBorder(),
            ),
          ),
        ),
        title: Text(l.settingsTitle),
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

IconData _icon(SettingsDestination destination) => switch (destination) {
  SettingsDestination.appearance => Icons.palette_outlined,
  SettingsDestination.notifications => Icons.notifications_outlined,
  SettingsDestination.language => Icons.language,
  SettingsDestination.data => Icons.shield_outlined,
  SettingsDestination.features => Icons.dashboard_customize_outlined,
  SettingsDestination.about => Icons.info_outline,
  SettingsDestination.student => Icons.school_outlined,
  SettingsDestination.general => Icons.event_outlined,
  SettingsDestination.schoolImport => Icons.download_outlined,
  SettingsDestination.studentPreferences => Icons.school_outlined,
  SettingsDestination.generalPreferences => Icons.event_note_outlined,
  SettingsDestination.parser => Icons.code,
  SettingsDestination.periods => Icons.schedule,
  SettingsDestination.notificationPermissions =>
    Icons.health_and_safety_outlined,
};

class _SettingsNavigatorObserver extends NavigatorObserver {
  int revision = 0;
  Route<dynamic>? topRoute;
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    this.topRoute = topRoute;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    revision++;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    revision++;
  }
}
