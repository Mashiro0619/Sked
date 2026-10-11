import 'desktop_window_host.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

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

/// A stable detail navigator shared by settings-owned collections. Content
/// keeps its own validation/flush guards while the surrounding panes reflow.
class AdaptiveCollectionScaffold extends StatefulWidget {
  const AdaptiveCollectionScaffold({
    super.key,
    required this.title,
    required this.items,
    required this.detailBuilder,
    this.actions = const [],
    this.busy = false,
    this.initialSelection,
  });
  final String title;
  final List<CollectionItem> items;
  final Widget Function(String id) detailBuilder;
  final List<Widget> actions;
  final bool busy;
  final String? initialSelection;
  @override
  State<AdaptiveCollectionScaffold> createState() =>
      _AdaptiveCollectionScaffoldState();
}

class _AdaptiveCollectionScaffoldState
    extends State<AdaptiveCollectionScaffold> {
  final _navigator = GlobalKey<NavigatorState>();
  final _homeKey = GlobalKey();
  String? _selected;
  bool _changing = false;
  String? _requestedSelection;
  @override
  void didUpdateWidget(covariant AdaptiveCollectionScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _requestInitialSelection();
  }

  @override
  void initState() {
    super.initState();
    _requestInitialSelection();
  }

  void _requestInitialSelection() {
    final id = widget.initialSelection;
    if (id == null || id == _requestedSelection) return;
    _requestedSelection = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_select(id));
    });
  }

  Future<void> _select(String id) async {
    if (_changing || _selected == id) return;
    _changing = true;
    try {
      if (_navigator.currentState!.canPop()) {
        await _navigator.currentState!.maybePop();
        await WidgetsBinding.instance.endOfFrame;
        if (_navigator.currentState!.canPop()) return;
      }
      if (!mounted) return;
      setState(() => _selected = id);
      unawaited(
        _navigator.currentState!
            .push<void>(
              MaterialPageRoute(builder: (_) => widget.detailBuilder(id)),
            )
            .then((_) {
              if (mounted && _selected == id) setState(() => _selected = null);
            }),
      );
    } finally {
      _changing = false;
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
        final wide = WorkbenchLayoutPolicy.formCanSplit(
          constraints.maxWidth,
          MediaQuery.textScalerOf(context).scale(14) / 14,
        );
        return PopScope(
          canPop: _selected == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_navigator.currentState!.maybePop());
          },
          child: Scaffold(
            appBar: WorkbenchAppBar(
              title: Text(widget.title),
              actions: widget.actions,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: UiCommandBusyIndicator(busy: widget.busy),
              ),
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
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          child: Navigator(
                            key: _navigator,
                            requestFocus: false,
                            onGenerateRoute: (_) => MaterialPageRoute<void>(
                              builder: (_) => LayoutBuilder(
                                key: _homeKey,
                                builder: (context, _) =>
                                    AdaptiveNavigationScope.isWide(context)
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
              ],
            ),
          ),
        );
      },
    ),
  );
}
