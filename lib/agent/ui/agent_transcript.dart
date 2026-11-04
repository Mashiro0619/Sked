import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:material_ui/material_ui.dart';

/// A repository-scoped reading anchor, shared by the panel and full workspace.
/// The fraction belongs to a message, rather than the total transcript height.
class AgentReadingPosition {
  LocalKey? anchor;
  double fraction = 0;
  bool followLatest = true;
  bool unread = false;
}

/// Uses the remembered message as the scroll origin. Both sides remain lazy,
/// so restoring a long conversation never lays out all preceding messages.
class AgentTranscript extends StatefulWidget {
  const AgentTranscript({
    super.key,
    required this.children,
    required this.position,
    required this.active,
    required this.scrollViewKey,
    required this.onReadingChanged,
    this.contentRevision,
  });

  final List<Widget> children;
  final AgentReadingPosition position;
  final bool active;
  final Key scrollViewKey;
  final VoidCallback onReadingChanged;

  /// Changes when the host replaces or streams text in an existing message.
  /// Rebase a distant reader once before layout changes above its anchor.
  final Object? contentRevision;

  @override
  State<AgentTranscript> createState() => AgentTranscriptState();
}

class AgentTranscriptState extends State<AgentTranscript> {
  final _viewportKey = GlobalKey();
  final _centerSliverKey = GlobalKey();
  final _itemKeys = <LocalKey, GlobalKey>{};
  late ScrollController _controller = _newController();
  LocalKey? _center;
  double? _restoreFraction;
  (double, double)? _layout;
  bool _scheduled = false;
  bool _rememberScheduled = false;
  bool _moving = false;

  List<LocalKey> get _ids => [
    for (var index = 0; index < widget.children.length; index++)
      if (widget.children[index].key case final LocalKey key)
        key
      else
        ValueKey('agent-transcript-notice-$index'),
  ];

  ScrollController _newController() =>
      ScrollController(keepScrollOffset: false)..addListener(_scheduleRemember);

  @override
  void initState() {
    super.initState();
    _center = widget.position.anchor;
    _restoreFraction = widget.position.followLatest
        ? null
        : widget.position.fraction;
    _schedulePosition();
  }

  @override
  void didUpdateWidget(AgentTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _recenter();
    } else if (widget.active &&
        !widget.position.followLatest &&
        widget.contentRevision != oldWidget.contentRevision) {
      _remember();
      if (_center != widget.position.anchor) _recenter();
    }
    if (widget.position.followLatest) _schedulePosition();
  }

  void _scheduleRemember() {
    if (_rememberScheduled || _moving || !widget.active) return;
    _rememberScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rememberScheduled = false;
      if (mounted && _restoreFraction == null) _remember();
    });
  }

  void _remember() {
    if (!widget.active ||
        widget.position.followLatest ||
        _restoreFraction != null) {
      return;
    }
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    LocalKey? first;
    double? firstTop;
    var firstHeight = 0.0;
    for (final entry in _itemKeys.entries) {
      final item = entry.value.currentContext?.findRenderObject();
      if (item is! RenderBox || !item.attached || !item.hasSize) continue;
      final top = item.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top + item.size.height <= 0 || top >= viewport.size.height) continue;
      if (firstTop == null || top < firstTop) {
        first = entry.key;
        firstTop = top;
        firstHeight = item.size.height;
      }
    }
    if (first != null && firstHeight > 0) {
      widget.position.anchor = first;
      widget.position.fraction = (-firstTop! / firstHeight).clamp(-1.0, 1.0);
    }
  }

  void _recenter() {
    final previous = _controller;
    _controller = _newController();
    _center = widget.position.anchor;
    _restoreFraction = widget.position.followLatest
        ? null
        : widget.position.fraction;
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    _schedulePosition();
  }

  /// Called when a retained host becomes visible again, or when the reader
  /// explicitly returns to the latest reply.
  void restore() {
    if (!mounted) return;
    setState(_recenter);
  }

  void followLatest() => _schedulePosition();

  /// Opens the selected reply at its stable transcript identity. Streaming or
  /// browsing another saved version then changes this message in place instead
  /// of following the conversation's final message.
  bool reveal(LocalKey anchor, {double fraction = 0}) {
    if (!mounted || !widget.active || !_ids.contains(anchor)) return false;
    widget.position
      ..anchor = anchor
      ..fraction = fraction.clamp(-1.0, 1.0)
      ..followLatest = false
      ..unread = false;
    setState(_recenter);
    widget.onReadingChanged();
    return true;
  }

  void _schedulePosition() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !widget.active || !_controller.hasClients) return;
      final scroll = _controller.position;
      double? target;
      if (widget.position.followLatest) {
        target = scroll.maxScrollExtent;
      } else if (_restoreFraction case final fraction?) {
        final item = _itemKeys[_center]?.currentContext?.findRenderObject();
        if (item is RenderBox && item.hasSize) {
          target = fraction * item.size.height;
          _restoreFraction = null;
        }
      }
      if (target != null) {
        _moving = true;
        _controller.jumpTo(
          target.clamp(scroll.minScrollExtent, scroll.maxScrollExtent),
        );
        _moving = false;
      }
    });
  }

  bool _onUserScroll(UserScrollNotification event) {
    // Code blocks and other embedded scrollers do not own transcript follow.
    if (event.depth != 0 ||
        event.metrics.axis != Axis.vertical ||
        _moving ||
        !widget.active) {
      return false;
    }
    final follow =
        event.direction == ScrollDirection.idle &&
        event.metrics.extentAfter < 72;
    final position = widget.position;
    if (position.followLatest != follow || (follow && position.unread)) {
      position.followLatest = follow;
      if (follow) position.unread = false;
      widget.onReadingChanged();
    }
    _scheduleRemember();
    return false;
  }

  @override
  void deactivate() {
    _remember();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = (
        constraints.maxWidth.clamp(0.0, 812.0),
        MediaQuery.textScalerOf(context).scale(14),
      );
      if (_layout != null && _layout != layout) {
        _remember();
        _recenter();
      }
      _layout = layout;
      final ids = _ids;
      final idSet = ids.toSet();
      final rememberedIndex = ids.indexOf(_center ?? const ValueKey(''));
      final centerIndex = rememberedIndex < 0 ? 0 : rememberedIndex;
      if (ids.isNotEmpty) _center = ids[centerIndex];
      _itemKeys.removeWhere((id, _) => !idSet.contains(id));

      Widget item(int index) => IndexedSemantics(
        index: index,
        child: Align(
          key: _itemKeys.putIfAbsent(ids[index], GlobalKey.new),
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 812),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: widget.children[index],
            ),
          ),
        ),
      );

      return SizedBox.expand(
        key: _viewportKey,
        child: NotificationListener<UserScrollNotification>(
          onNotification: _onUserScroll,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (event) {
              if (event.depth == 0 && event.metrics.axis == Axis.vertical) {
                _schedulePosition();
              }
              return false;
            },
            child: KeyedSubtree(
              // A new message origin also needs a new ScrollPosition. Merely
              // replacing the controller retains the old absolute pixels.
              key: ObjectKey(_controller),
              child: CustomScrollView(
                key: widget.scrollViewKey,
                controller: _controller,
                center: _centerSliverKey,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                semanticChildCount: ids.length,
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  if (centerIndex > 0)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => item(centerIndex - index - 1),
                        childCount: centerIndex,
                        addSemanticIndexes: false,
                      ),
                    ),
                  SliverList(
                    key: _centerSliverKey,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => item(centerIndex + index),
                      childCount: ids.length - centerIndex,
                      addSemanticIndexes: false,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
