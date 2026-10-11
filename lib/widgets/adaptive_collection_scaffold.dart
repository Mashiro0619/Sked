import 'desktop_window_host.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../services/desktop_layout_preferences.dart';
import 'adaptive_navigation_scope.dart';
import 'sked_resizable.dart';
import 'workbench_layout_policy.dart';
import 'ui_command.dart';

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.trailing,
    this.tileBuilder,
  });
  final String id;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget Function(bool selected, VoidCallback openDetail)? tileBuilder;
}

/// One collection toolbar and a stable detail navigator. Embedded detail pages
/// keep their validation/flush guards while the surrounding panes reflow.
class AdaptiveCollectionScaffold extends StatefulWidget {
  const AdaptiveCollectionScaffold({
    super.key,
    required this.title,
    required this.items,
    required this.detailBuilder,
    this.actions = const [],
    this.busy = false,
    this.initialSelection,
    this.empty,
  });
  final String title;
  final List<CollectionItem> items;
  final Widget Function(String id) detailBuilder;
  final List<Widget> actions;
  final bool busy;
  final String? initialSelection;
  final Widget? empty;
  @override
  State<AdaptiveCollectionScaffold> createState() =>
      _AdaptiveCollectionScaffoldState();
}

class _AdaptiveCollectionScaffoldState
    extends State<AdaptiveCollectionScaffold> {
  final _navigator = GlobalKey<NavigatorState>();
  final _observer = _CollectionNavigatorObserver();
  final _pageExitGuards = <ModalRoute<dynamic>, Future<bool> Function()>{};
  final _contentRevision = ValueNotifier(0);
  final _homeKey = GlobalKey();
  String? _selected;
  Route<void>? _selectedRoute;
  bool _changing = false;
  bool _closing = false;
  bool _allowPop = false;
  bool _wide = false;
  String? _requestedSelection;
  @override
  void didUpdateWidget(covariant AdaptiveCollectionScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _contentRevision.value++;
    _requestInitialSelection();
    final selected = _selected;
    if (selected != null && !_contains(selected)) {
      final route = _selectedRoute;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selected != selected || _contains(selected)) return;
        if (route?.isActive == true) route!.navigator?.removeRoute(route);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _requestInitialSelection();
  }

  void _requestInitialSelection() {
    final id = widget.initialSelection;
    if (id == null || id == _requestedSelection || !_contains(id)) return;
    _requestedSelection = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_select(id));
    });
  }

  @override
  void dispose() {
    _pageExitGuards.clear();
    _contentRevision.dispose();
    super.dispose();
  }

  bool _contains(String id) => widget.items.any((item) => item.id == id);

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

  Future<bool> _popCurrentPage(NavigatorState navigator) async {
    final revision = _observer.revision;
    final exit = _pageExitGuards[_observer.topRoute];
    if (exit != null) {
      await exit();
    } else {
      await navigator.maybePop();
    }
    await WidgetsBinding.instance.endOfFrame;
    return mounted && navigator.mounted && revision != _observer.revision;
  }

  Future<void> _back() async {
    if (!mounted || _closing || _changing || widget.busy) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _closing = true);
    try {
      final navigator = _navigator.currentState!;
      if (navigator.canPop()) {
        final popped = await _popCurrentPage(navigator);
        if (!popped || navigator.canPop() || !_wide) return;
      }
      if (!mounted) return;
      // On a wide layout the list is already visible. Back leaves management;
      // a compact detail first returns to the retained list.
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        await Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _closing = false;
          _allowPop = false;
        });
      }
    }
  }

  Future<void> _select(String id) async {
    if (_changing ||
        _closing ||
        widget.busy ||
        _selected == id ||
        !_contains(id)) {
      return;
    }
    setState(() => _changing = true);
    try {
      final navigator = _navigator.currentState!;
      while (navigator.canPop()) {
        if (!await _popCurrentPage(navigator)) return;
      }
      if (!mounted || !_contains(id)) return;
      final route = MaterialPageRoute<void>(
        builder: (_) => widget.detailBuilder(id),
      );
      setState(() {
        _selected = id;
        _selectedRoute = route;
      });
      unawaited(
        navigator.push<void>(route).then((_) {
          if (mounted && identical(_selectedRoute, route)) {
            setState(() {
              _selected = null;
              _selectedRoute = null;
            });
          }
        }),
      );
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Widget _list() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      for (final item in widget.items)
        if (item.tileBuilder != null)
          item.tileBuilder!(
            item.id == _selected,
            () => unawaited(_select(item.id)),
          )
        else
          ListTile(
            selected: item.id == _selected,
            title: Text(item.title),
            subtitle: item.subtitle == null ? null : Text(item.subtitle!),
            trailing: item.trailing ?? const Icon(Icons.chevron_right),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () => unawaited(_select(item.id)),
          ),
    ],
  );
  @override
  Widget build(BuildContext context) => DesktopResizableRegion(
    layoutKey: DesktopLayoutRegion.periodTimeSets,
    builder: (context, preferred, update, commit, reset) => LayoutBuilder(
      builder: (context, constraints) {
        final factor = WorkbenchLayoutPolicy.textFactor(
          MediaQuery.textScalerOf(context).scale(14) / 14,
        );
        final maximumWidth = math.max(
          224 * factor,
          constraints.maxWidth - 520 * factor - 1,
        );
        final listWidth = ((preferred ?? 224) * factor).clamp(
          224 * factor,
          maximumWidth,
        );
        final wide = _wide =
            widget.items.isNotEmpty &&
            WorkbenchLayoutPolicy.formCanSplit(
              constraints.maxWidth,
              MediaQuery.textScalerOf(context).scale(14) / 14,
            );
        return PopScope(
          canPop:
              _allowPop ||
              (_selected == null && !widget.busy && !_changing && !_closing),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_back());
          },
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  unawaited(_back()),
            },
            child: Scaffold(
              appBar: WorkbenchAppBar(
                key: const ValueKey('period-time-set-manager-app-bar'),
                automaticallyImplyLeading: false,
                leading: _selected != null || Navigator.of(context).canPop()
                    ? BackButton(
                        key: const ValueKey('period-time-set-manager-back'),
                        onPressed: () => unawaited(_back()),
                      )
                    : null,
                title: Text(widget.title),
                actions: [
                  for (final action in widget.actions)
                    AbsorbPointer(
                      absorbing: _changing || _closing,
                      child: ExcludeFocus(
                        excluding: _changing || _closing,
                        child: action,
                      ),
                    ),
                ],
              ),
              body: Stack(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: wide ? listWidth : 0,
                        child: Offstage(
                          offstage: !wide,
                          child: ExcludeFocus(excluding: !wide, child: _list()),
                        ),
                      ),
                      SizedBox(
                        width: wide ? 1 : 0,
                        child: const VerticalDivider(width: 1),
                      ),
                      Expanded(
                        child: AdaptiveNavigationScope(
                          wide: wide,
                          registerPageExitGuard: _registerPageExitGuard,
                          child: Semantics(
                            container: true,
                            explicitChildNodes: true,
                            child: Navigator(
                              key: _navigator,
                              observers: [_observer],
                              requestFocus: false,
                              onGenerateRoute: (_) => MaterialPageRoute<void>(
                                builder: (_) => ValueListenableBuilder(
                                  valueListenable: _contentRevision,
                                  builder: (context, _, _) => LayoutBuilder(
                                    key: _homeKey,
                                    builder: (context, _) =>
                                        widget.items.isEmpty &&
                                            widget.empty != null
                                        ? widget.empty!
                                        : AdaptiveNavigationScope.isWide(
                                            context,
                                          )
                                        ? Center(
                                            child: Text(
                                              widget.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge,
                                            ),
                                          )
                                        : _list(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (wide && WorkbenchLayoutPolicy.pointerLayout(context))
                    PositionedDirectional(
                      start: listWidth - 4,
                      top: 0,
                      bottom: 0,
                      width: 9,
                      child: SkedExtentResizeHandle(
                        key: const ValueKey('period-time-sets-resize'),
                        extent: listWidth,
                        minExtent: 224 * factor,
                        maxExtent: maximumWidth,
                        onChanged: (extent) => update(extent / factor),
                        onEnd: commit,
                        onReset: reset,
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: UiCommandBusyIndicator(busy: widget.busy),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _CollectionNavigatorObserver extends NavigatorObserver {
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
