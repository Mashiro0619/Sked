import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../theme/sked_expressive_theme.dart';
import '../widgets/ui_command.dart';
import 'general_schedule_home_screen.dart';
import 'home_screen.dart';

const double _compactNavigationBreakpoint = 600;
// Medium windows keep a compact rail. A full drawer only becomes useful once
// the workspace still has substantial room beside its 240 dp navigation.
const double _permanentDrawerBreakpoint = 1200;
const double _compactRailWidth = 80;
// Keep the permanent drawer close to Material's compact width.  Destination
// labels below are flexible so longer localizations never create a layout
// overflow in the constrained leading/selection row.
const double _permanentDrawerWidth = 240;

/// The persistent, adaptive root shell shown after recovery and onboarding.
///
/// Both workspaces remain mounted so local page controllers, scroll positions,
/// and view selections survive mode switches. Only the active workspace can
/// paint semantics, receive focus or handle input.
class AdaptiveSkedShell extends StatefulWidget {
  const AdaptiveSkedShell({
    super.key,
    required this.provider,
    required this.activeMode,
    this.enabled = true,
    required this.onOpenSettings,
  });

  final TimetableProvider provider;
  final AppMode activeMode;
  final bool enabled;
  final Future<void> Function() onOpenSettings;

  @override
  State<AdaptiveSkedShell> createState() => _AdaptiveSkedShellState();
}

class _AdaptiveSkedShellState extends State<AdaptiveSkedShell>
    with UiCommandRunner<AdaptiveSkedShell> {
  bool _settingsOpen = false;
  bool _modeSwitchInFlight = false;
  bool _navigationToggleInFlight = false;
  Object? _navigationLayoutIdentity;
  late AppMode _committedMode;
  final _workspaceStackKey = GlobalKey<_AdaptiveWorkspaceStackState>();
  final _navigationFocusBridgeKey =
      GlobalKey<_AdaptiveNavigationFocusBridgeState>();
  final _studentWeekShortcutFocusNode = FocusNode(
    debugLabel: 'Student timetable week shortcuts',
  );
  final _settingsFocusNode = FocusNode(debugLabel: 'Global settings');

  @override
  void dispose() {
    _studentWeekShortcutFocusNode.dispose();
    _settingsFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _committedMode = widget.activeMode;
  }

  @override
  void didUpdateWidget(covariant AdaptiveSkedShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ignore unrelated provider notifications while a mode write is still in
    // flight. The provider mutates its in-memory snapshot optimistically, so
    // only the completed command is allowed to move the shell selection.
    if (!uiCommandBusy &&
        !_modeSwitchInFlight &&
        oldWidget.activeMode != widget.activeMode) {
      _committedMode = widget.activeMode;
    }
  }

  AppMode get _effectiveMode => _committedMode;

  int get _selectedIndex => _effectiveMode == AppMode.student ? 0 : 1;

  Future<void> _selectWorkspace(int index) async {
    if (!widget.enabled ||
        uiCommandBusy ||
        _navigationToggleInFlight ||
        _settingsOpen ||
        index == _selectedIndex) {
      return;
    }
    final target = index == 0 ? AppMode.student : AppMode.general;
    FocusManager.instance.primaryFocus?.unfocus();
    _modeSwitchInFlight = true;
    try {
      final saved = await runUiCommand(
        debugLabel: 'Switch application workspace',
        command: () => widget.provider.switchMode(target),
      );
      if (saved && mounted) {
        setState(() => _committedMode = target);
      }
    } finally {
      _modeSwitchInFlight = false;
    }
  }

  Future<void> _openSettings() async {
    if (!widget.enabled ||
        uiCommandBusy ||
        _navigationToggleInFlight ||
        _settingsOpen ||
        !mounted) {
      return;
    }
    setState(() => _settingsOpen = true);
    try {
      await widget.onOpenSettings();
    } finally {
      if (mounted) setState(() => _settingsOpen = false);
    }
  }

  Future<void> _toggleWorkspaceNavigation() async {
    if (!widget.enabled ||
        uiCommandBusy ||
        _navigationToggleInFlight ||
        _settingsOpen ||
        !mounted) {
      return;
    }
    final target = !widget.provider.homeWorkspaceNavigationCollapsed;
    setState(() => _navigationToggleInFlight = true);
    try {
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Toggle large-screen workspace navigation',
        command: () =>
            widget.provider.updateHomeWorkspaceNavigationCollapsed(target),
      );
    } finally {
      if (mounted) setState(() => _navigationToggleInFlight = false);
    }
  }

  void _openSettingsFromWorkspace() {
    unawaited(_openSettings());
  }

  void _prepareNavigationLayout(Object layoutIdentity) {
    final previousLayoutIdentity = _navigationLayoutIdentity;
    if (previousLayoutIdentity != null &&
        previousLayoutIdentity != layoutIdentity) {
      _navigationFocusBridgeKey.currentState?.prepareForLayoutChange();
    }
    _navigationLayoutIdentity = layoutIdentity;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < _compactNavigationBreakpoint;
        final supportsCollapsibleNavigation =
            width >= _permanentDrawerBreakpoint;
        final hideWorkspaceNavigation =
            widget.provider.hideHomeWorkspaceNavigation;
        final navigationCollapsed =
            supportsCollapsibleNavigation &&
            widget.provider.homeWorkspaceNavigationCollapsed;
        final navigationLayoutIdentity = hideWorkspaceNavigation
            ? 'hidden'
            : compact
            ? 'bar'
            : !supportsCollapsibleNavigation
            ? 'rail-medium'
            : 'rail-large';
        _prepareNavigationLayout(navigationLayoutIdentity);
        final selectedIndex = _selectedIndex;
        final showCompactNavigationBar = compact && !hideWorkspaceNavigation;
        final showWorkspaceSettingsAction = compact || hideWorkspaceNavigation;
        final compactSettingsEnabled =
            widget.enabled &&
            !uiCommandBusy &&
            !_navigationToggleInFlight &&
            !_settingsOpen;
        final workspaceStack = _AdaptiveWorkspaceStack(
          key: _workspaceStackKey,
          selectedIndex: selectedIndex,
          enabled: widget.enabled,
          busy: uiCommandBusy,
          studentPreferredFocusNode: _studentWeekShortcutFocusNode,
          studentBuilder: (active, interactive) => HomeScreen(
            key: const ValueKey('student-home'),
            embedded: true,
            active: active,
            interactive: interactive,
            weekShortcutFocusNode: _studentWeekShortcutFocusNode,
            showSettingsAction: showWorkspaceSettingsAction,
            settingsEnabled: compactSettingsEnabled,
            settingsAction: showWorkspaceSettingsAction
                ? _openSettingsFromWorkspace
                : null,
            settingsFocusNode: showWorkspaceSettingsAction && active
                ? _settingsFocusNode
                : null,
          ),
          generalBuilder: (active, interactive) => GeneralScheduleHomeScreen(
            key: const ValueKey('general-home'),
            embedded: true,
            active: active,
            interactive: interactive,
            showSettingsAction: showWorkspaceSettingsAction,
            settingsEnabled: compactSettingsEnabled,
            settingsAction: showWorkspaceSettingsAction
                ? _openSettingsFromWorkspace
                : null,
            settingsFocusNode: showWorkspaceSettingsAction && active
                ? _settingsFocusNode
                : null,
          ),
        );

        final navigation = hideWorkspaceNavigation
            ? const SizedBox.shrink()
            : compact
            ? _CompactWorkspaceNavigation(
                selectedIndex: selectedIndex,
                busy: uiCommandBusy,
                enabled: widget.enabled,
                onDestinationSelected: _selectWorkspace,
              )
            : !supportsCollapsibleNavigation
            ? _WorkspaceRail(
                selectedIndex: selectedIndex,
                busy: uiCommandBusy,
                enabled: widget.enabled,
                settingsBusy: _settingsOpen,
                onDestinationSelected: _selectWorkspace,
                onOpenSettings: _openSettings,
                settingsFocusNode: _settingsFocusNode,
              )
            : _ExpandableWorkspaceRail(
                expanded: !navigationCollapsed,
                interactionBlocked: _navigationToggleInFlight,
                selectedIndex: selectedIndex,
                busy: uiCommandBusy,
                enabled: widget.enabled,
                settingsBusy: _settingsOpen,
                onDestinationSelected: _selectWorkspace,
                onOpenSettings: _openSettings,
                settingsFocusNode: _settingsFocusNode,
                collapseToggleTooltip: navigationCollapsed
                    ? AppLocalizations.of(context).expandWorkspaceNavigation
                    : AppLocalizations.of(context).collapseWorkspaceNavigation,
                onToggleCollapsed: _toggleWorkspaceNavigation,
              );
        final navigationWithFocus = _AdaptiveNavigationFocusBridge(
          key: _navigationFocusBridgeKey,
          layoutIdentity: navigationLayoutIdentity,
          persistentFocusNode: _settingsFocusNode,
          child: navigation,
        );
        final textDirection = Directionality.of(context);

        // Put the compact bar in Scaffold's dedicated slot.  NavigationBar
        // owns the bottom safe area; keeping it in the body would expose it to
        // the top status-bar inset as well and make the bar unnecessarily tall
        // on Android.
        if (compact || hideWorkspaceNavigation) {
          final body = Directionality(
            textDirection: textDirection,
            child: compact && showCompactNavigationBar
                ? MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: workspaceStack,
                  )
                : workspaceStack,
          );
          return Scaffold(
            body: body,
            bottomNavigationBar: showCompactNavigationBar
                ? Directionality(
                    textDirection: textDirection,
                    child: navigationWithFocus,
                  )
                : null,
          );
        }

        return Scaffold(
          body: Directionality(
            textDirection: textDirection,
            child: Row(
              children: [
                navigationWithFocus,
                Expanded(child: workspaceStack),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdaptiveWorkspaceStack extends StatefulWidget {
  const _AdaptiveWorkspaceStack({
    super.key,
    required this.selectedIndex,
    required this.enabled,
    required this.busy,
    required this.studentPreferredFocusNode,
    required this.studentBuilder,
    required this.generalBuilder,
  });

  final int selectedIndex;
  final bool enabled;
  final bool busy;
  final FocusNode studentPreferredFocusNode;
  final Widget Function(bool active, bool interactive) studentBuilder;
  final Widget Function(bool active, bool interactive) generalBuilder;

  @override
  State<_AdaptiveWorkspaceStack> createState() =>
      _AdaptiveWorkspaceStackState();
}

class _AdaptiveWorkspaceStackState extends State<_AdaptiveWorkspaceStack>
    with SingleTickerProviderStateMixin {
  static const _paintSwitchPoint = 0.35;
  static const _incomingScale = 0.985;

  late final AnimationController _controller;
  late int _settledIndex;
  late int _paintIndex;
  int? _fromIndex;
  int? _toIndex;
  bool _transitioning = false;
  bool _reversing = false;
  SkedMotionPolicy? _motion;

  @override
  void initState() {
    super.initState();
    _settledIndex = widget.selectedIndex;
    _paintIndex = widget.selectedIndex;
    _controller = AnimationController(vsync: this, value: 0)
      ..addListener(_handleAnimationTick)
      ..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = SkedMotionPolicy.of(context);
    _motion = motion;
    _controller.duration = motion.effects(SkedMotionSpeed.standard);
    if (!motion.spatialAnimationsEnabled && _transitioning) {
      _snapTo(widget.selectedIndex);
    }
  }

  @override
  void didUpdateWidget(covariant _AdaptiveWorkspaceStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _setTarget(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (!_transitioning || !mounted) return;
    final from = _fromIndex;
    final to = _toIndex;
    if (from == null || to == null) return;
    if (status == AnimationStatus.completed) {
      _settle(to);
    } else if (status == AnimationStatus.dismissed && _reversing) {
      _settle(from);
    }
  }

  void _handleAnimationTick() {
    if (!_transitioning || !mounted) return;
    final from = _fromIndex;
    final to = _toIndex;
    if (from == null || to == null) return;
    final next = _reversing
        ? (_controller.value < _paintSwitchPoint ? from : to)
        : (_controller.value > _paintSwitchPoint ? to : from);
    if (next != _paintIndex) setState(() => _paintIndex = next);
  }

  void _setTarget(int target) {
    if (!_transitioning && target == _settledIndex) return;
    final motion = _motion ?? SkedMotionPolicy.of(context);
    final duration = motion.effects(SkedMotionSpeed.standard);
    _controller.duration = duration;
    if (!motion.spatialAnimationsEnabled || duration == Duration.zero) {
      _snapTo(target);
      return;
    }

    if (!_transitioning) {
      _fromIndex = _settledIndex;
      _toIndex = target;
      _paintIndex = _settledIndex;
      _reversing = false;
      _transitioning = true;
      setState(() {});
      unawaited(_controller.forward(from: 0));
      return;
    }

    if (target == _toIndex) {
      _reversing = false;
      unawaited(_controller.forward());
    } else if (target == _fromIndex) {
      _reversing = true;
      unawaited(_controller.reverse());
    } else {
      _snapTo(target);
    }
  }

  void _snapTo(int target) {
    _controller.stop();
    _transitioning = false;
    _fromIndex = null;
    _toIndex = null;
    _settledIndex = target;
    _paintIndex = target;
    _reversing = false;
    if (mounted) setState(() {});
  }

  void _settle(int index) {
    _transitioning = false;
    _fromIndex = null;
    _toIndex = null;
    _settledIndex = index;
    _paintIndex = index;
    _reversing = false;
    setState(() {});
  }

  double _fadeOutValue() {
    return 1 -
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(
            0,
            _paintSwitchPoint,
            curve: Easing.emphasizedAccelerate,
          ),
        ).value;
  }

  double _fadeInValue() {
    return CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        _paintSwitchPoint,
        1,
        curve: Easing.emphasizedDecelerate,
      ),
    ).value;
  }

  double _scaleFor(double opacity) {
    return _incomingScale + (1 - _incomingScale) * opacity;
  }

  Widget _slot({
    required int index,
    required Widget Function(bool active, bool interactive) childBuilder,
  }) {
    final selected = widget.selectedIndex == index;
    // During fade-through there is a short intentional gap: the outgoing
    // workspace loses semantics, focus, input and business tickers
    // immediately, while the incoming workspace becomes live only when its
    // paint index is reached. A pending mode save keeps the still-visible
    // workspace readable, but freezes its business timers and state writes
    // together with user interaction until persistence completes.
    final paintActive = !_transitioning || _paintIndex == index;
    final semanticActive = widget.enabled && selected && paintActive;
    final runtimeActive = semanticActive && !widget.busy;
    final interactive = runtimeActive;
    return _WorkspaceSlot(
      key: ValueKey('adaptive-workspace-slot-$index'),
      slotIndex: index,
      semanticActive: semanticActive,
      runtimeActive: runtimeActive,
      interactive: interactive,
      preferredFocusNode: index == 0 ? widget.studentPreferredFocusNode : null,
      child: childBuilder(runtimeActive, interactive),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        var opacity = 1.0;
        var scale = 1.0;
        if (_transitioning) {
          final progress = _controller.value;
          final fadeOut = _fadeOutValue();
          final fadeIn = _fadeInValue();
          opacity = progress < _paintSwitchPoint ? fadeOut : fadeIn;
          scale = _scaleFor(progress < _paintSwitchPoint ? fadeOut : fadeIn);
        }
        return Opacity(
          key: const ValueKey('adaptive-workspace-transition-opacity'),
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            key: const ValueKey('adaptive-workspace-transition-scale'),
            scale: scale,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: IndexedStack(
        key: const ValueKey('adaptive-workspace-stack'),
        index: _paintIndex,
        sizing: StackFit.expand,
        children: [
          _slot(index: 0, childBuilder: widget.studentBuilder),
          _slot(index: 1, childBuilder: widget.generalBuilder),
        ],
      ),
    );
  }
}

class _WorkspaceSlot extends StatefulWidget {
  const _WorkspaceSlot({
    super.key,
    required this.slotIndex,
    required this.semanticActive,
    required this.runtimeActive,
    required this.interactive,
    this.preferredFocusNode,
    required this.child,
  });

  final int slotIndex;
  final bool semanticActive;
  final bool runtimeActive;
  final bool interactive;
  final FocusNode? preferredFocusNode;
  final Widget child;

  @override
  State<_WorkspaceSlot> createState() => _WorkspaceSlotState();
}

class _WorkspaceSlotState extends State<_WorkspaceSlot> {
  late final FocusScopeNode _focusScopeNode;

  @override
  void initState() {
    super.initState();
    _focusScopeNode = FocusScopeNode(
      debugLabel: 'Adaptive workspace focus scope',
    );
    if (widget.interactive) _scheduleFocusRestore();
  }

  @override
  void didUpdateWidget(covariant _WorkspaceSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.interactive && widget.interactive) {
      _scheduleFocusRestore();
    }
  }

  void _scheduleFocusRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.interactive) return;
      // Restore the scope's previously focused child only after this frame
      // has applied the new focus policy. An unattached preferred node must
      // never receive a queued request that could steal focus later.
      final preferredFocusNode = widget.preferredFocusNode;
      if (preferredFocusNode != null &&
          preferredFocusNode.context != null &&
          preferredFocusNode.canRequestFocus) {
        preferredFocusNode.requestFocus();
      } else {
        _focusScopeNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      key: ValueKey('adaptive-workspace-ticker-${widget.slotIndex}'),
      enabled: widget.runtimeActive,
      child: ExcludeSemantics(
        key: ValueKey('adaptive-workspace-semantics-${widget.slotIndex}'),
        excluding: !widget.semanticActive,
        child: IgnorePointer(
          key: ValueKey('adaptive-workspace-input-${widget.slotIndex}'),
          ignoring: !widget.interactive,
          child: FocusScope(
            node: _focusScopeNode,
            canRequestFocus: widget.interactive,
            descendantsAreFocusable: widget.interactive,
            descendantsAreTraversable: widget.interactive,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Keeps keyboard focus inside the adaptive navigation when its Material
/// component changes between bar, rail and drawer layouts.
class _AdaptiveNavigationFocusBridge extends StatefulWidget {
  const _AdaptiveNavigationFocusBridge({
    super.key,
    required this.layoutIdentity,
    this.persistentFocusNode,
    required this.child,
  });

  final Object layoutIdentity;
  final FocusNode? persistentFocusNode;
  final Widget child;

  @override
  State<_AdaptiveNavigationFocusBridge> createState() =>
      _AdaptiveNavigationFocusBridgeState();
}

class _AdaptiveNavigationFocusBridgeState
    extends State<_AdaptiveNavigationFocusBridge> {
  late final FocusScopeNode _focusScopeNode;
  int? _pendingTraversalIndex;
  bool _restorePersistentFocus = false;
  int _restoreGeneration = 0;

  @override
  void initState() {
    super.initState();
    _focusScopeNode = FocusScopeNode(
      debugLabel: 'Adaptive navigation focus scope',
      skipTraversal: true,
    );
  }

  @override
  void didUpdateWidget(covariant _AdaptiveNavigationFocusBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutIdentity != widget.layoutIdentity) {
      _capturePersistentFocus();
      _captureFocusedTraversalIndex();
      _scheduleFocusRestore();
    }
  }

  void prepareForLayoutChange() {
    _capturePersistentFocus();
    _captureFocusedTraversalIndex();
  }

  @override
  void deactivate() {
    _capturePersistentFocus();
    _captureFocusedTraversalIndex();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (_restorePersistentFocus || _pendingTraversalIndex != null) {
      _scheduleFocusRestore();
    }
  }

  List<FocusNode> _orderedFocusableDescendants() {
    final persistentFocusNode = widget.persistentFocusNode;
    return _focusScopeNode.traversalDescendants
        .where((node) => !identical(node, persistentFocusNode))
        .toList(growable: false);
  }

  void _captureFocusedTraversalIndex() {
    if (!_focusScopeNode.hasFocus) return;
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return;
    final descendants = _orderedFocusableDescendants();
    final focusedIndex = descendants.indexWhere(
      (node) =>
          identical(node, primaryFocus) ||
          primaryFocus.ancestors.contains(node),
    );
    if (focusedIndex >= 0) _pendingTraversalIndex = focusedIndex;
  }

  void _capturePersistentFocus() {
    if (widget.persistentFocusNode?.hasFocus ?? false) {
      _restorePersistentFocus = true;
    }
  }

  void _scheduleFocusRestore({int attemptsRemaining = 3}) {
    final restoreGeneration = ++_restoreGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || restoreGeneration != _restoreGeneration) return;
      final persistentFocusNode = widget.persistentFocusNode;
      if (_restorePersistentFocus && persistentFocusNode != null) {
        if (persistentFocusNode.context == null ||
            !persistentFocusNode.canRequestFocus) {
          if (attemptsRemaining > 0) {
            _scheduleFocusRestore(attemptsRemaining: attemptsRemaining - 1);
          }
          return;
        }
        persistentFocusNode.requestFocus();
        FocusManager.instance.applyFocusChangesIfNeeded();
        if (persistentFocusNode.hasFocus) {
          _restorePersistentFocus = false;
          _pendingTraversalIndex = null;
        } else if (attemptsRemaining > 0) {
          _scheduleFocusRestore(attemptsRemaining: attemptsRemaining - 1);
        }
        return;
      }
      final pendingIndex = _pendingTraversalIndex;
      if (pendingIndex == null) return;
      final descendants = _orderedFocusableDescendants();
      if (descendants.isEmpty) {
        if (attemptsRemaining > 0) {
          _scheduleFocusRestore(attemptsRemaining: attemptsRemaining - 1);
        }
        return;
      }
      descendants[pendingIndex.clamp(0, descendants.length - 1)].requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      if (_focusScopeNode.hasFocus) {
        _pendingTraversalIndex = null;
      } else if (attemptsRemaining > 0) {
        _scheduleFocusRestore(attemptsRemaining: attemptsRemaining - 1);
      }
    });
  }

  @override
  void dispose() {
    _focusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      key: const ValueKey('adaptive-navigation-focus-bridge'),
      node: _focusScopeNode,
      skipTraversal: true,
      child: widget.child,
    );
  }
}

class _CompactWorkspaceNavigation extends StatelessWidget {
  const _CompactWorkspaceNavigation({
    required this.selectedIndex,
    required this.busy,
    required this.enabled,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final bool busy;
  final bool enabled;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final motion = SkedMotionPolicy.of(context);
    final navigationAnimationDuration = motion.spatialAnimationsEnabled
        ? motion.effects(SkedMotionSpeed.standard)
        : Duration.zero;
    final navigationBar = NavigationBar(
      key: const ValueKey('adaptive-shell-navigation-bar'),
      // Keep the Material 3 navigation component at a stable content height.
      // NavigationBar already clamps destination label scaling internally; the
      // shell must not grow the bar linearly with the system text scale.
      height: 80,
      animationDuration: navigationAnimationDuration,
      selectedIndex: selectedIndex,
      onDestinationSelected: busy || !enabled ? null : onDestinationSelected,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          key: const ValueKey('adaptive-shell-student-destination'),
          icon: const Icon(Icons.school_outlined),
          selectedIcon: const Icon(Icons.school),
          label: l10n.studentTimetable,
          enabled: enabled && !busy,
        ),
        NavigationDestination(
          key: const ValueKey('adaptive-shell-general-destination'),
          icon: const Icon(Icons.event_note_outlined),
          selectedIcon: const Icon(Icons.event_note),
          label: l10n.generalSchedule,
          enabled: enabled && !busy,
        ),
      ],
    );
    return Material(
      color: colors.surfaceContainer,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          navigationBar,
          if (busy)
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: UiCommandBusyIndicator(
                busy: true,
                semanticsKey: const ValueKey('workspace-switch-busy'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Uses one official navigation rail for both large-screen states. Material's
/// extended transition keeps every icon in the same 80 dp slot while the
/// labels and occupied width reveal progressively, avoiding a blank swap
/// frame between unrelated drawer and rail trees.
class _ExpandableWorkspaceRail extends StatelessWidget {
  const _ExpandableWorkspaceRail({
    required this.expanded,
    required this.interactionBlocked,
    required this.selectedIndex,
    required this.busy,
    required this.enabled,
    required this.settingsBusy,
    required this.onDestinationSelected,
    required this.onOpenSettings,
    required this.settingsFocusNode,
    required this.collapseToggleTooltip,
    required this.onToggleCollapsed,
  });

  final bool expanded;
  final bool interactionBlocked;
  final int selectedIndex;
  final bool busy;
  final bool enabled;
  final bool settingsBusy;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenSettings;
  final FocusNode settingsFocusNode;
  final String collapseToggleTooltip;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final motion = SkedMotionPolicy.of(context);
    final rail = NavigationRail(
      key: const ValueKey('adaptive-shell-navigation-rail'),
      extended: expanded,
      minWidth: _compactRailWidth,
      minExtendedWidth: _permanentDrawerWidth,
      selectedIndex: selectedIndex,
      labelType: NavigationRailLabelType.none,
      scrollable: true,
      onDestinationSelected: busy || !enabled ? null : onDestinationSelected,
      leading: _ExpandableRailBrand(
        tooltip: collapseToggleTooltip,
        onPressed: busy || settingsBusy || !enabled ? null : onToggleCollapsed,
      ),
      trailingAtBottom: true,
      trailing: _ExpandableRailSettingsAction(
        busy: busy,
        enabled: enabled,
        settingsBusy: settingsBusy,
        onOpenSettings: onOpenSettings,
        settingsFocusNode: settingsFocusNode,
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.school_outlined),
          selectedIcon: const Icon(Icons.school),
          label: Text(
            l10n.studentTimetable,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          disabled: !enabled || busy,
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.event_note_outlined),
          selectedIcon: const Icon(Icons.event_note),
          label: Text(
            l10n.generalSchedule,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          disabled: !enabled || busy,
        ),
      ],
    );
    final motionAwareRail = motion.spatialAnimationsEnabled
        ? KeyedSubtree(
            key: const ValueKey('adaptive-shell-wide-navigation-animated'),
            child: rail,
          )
        : KeyedSubtree(
            key: ValueKey('adaptive-shell-wide-navigation-static-$expanded'),
            child: rail,
          );
    final targetWidth = expanded ? _permanentDrawerWidth : _compactRailWidth;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: targetWidth),
      duration: motion.spatialAnimationsEnabled
          ? kThemeAnimationDuration
          : Duration.zero,
      curve: Curves.easeInOut,
      builder: (context, width, child) => SizedBox(
        key: const ValueKey('adaptive-shell-wide-navigation-width'),
        width: width,
        child: ClipRect(child: child),
      ),
      child: Stack(
        children: [
          AbsorbPointer(absorbing: interactionBlocked, child: motionAwareRail),
          if (interactionBlocked)
            Semantics(
              liveRegion: true,
              label: l10n.savingChanges,
              child: const SizedBox.shrink(),
            ),
          if (busy)
            const PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: UiCommandBusyIndicator(
                busy: true,
                semanticsKey: ValueKey('workspace-switch-busy'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandableRailBrand extends StatelessWidget {
  const _ExpandableRailBrand({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final animation = NavigationRail.extendedAnimation(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final width =
            _compactRailWidth +
            (_permanentDrawerWidth - _compactRailWidth) * animation.value;
        final labelOpacity = const Interval(0, 0.25).transform(animation.value);
        return SizedBox(
          key: const ValueKey('adaptive-shell-wide-brand'),
          width: width,
          height: 56,
          child: Row(
            children: [
              SizedBox(
                key: const ValueKey('adaptive-shell-wide-brand-icon-slot'),
                width: _compactRailWidth,
                child: Center(
                  child: _WorkspaceNavigationBrandIcon(
                    tooltip: tooltip,
                    onPressed: onPressed,
                  ),
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: Opacity(
                    opacity: labelOpacity,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 16),
                        child: Text(
                          l10n.appTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpandableRailSettingsAction extends StatelessWidget {
  const _ExpandableRailSettingsAction({
    required this.busy,
    required this.enabled,
    required this.settingsBusy,
    required this.onOpenSettings,
    required this.settingsFocusNode,
  });

  final bool busy;
  final bool enabled;
  final bool settingsBusy;
  final VoidCallback onOpenSettings;
  final FocusNode settingsFocusNode;

  @override
  Widget build(BuildContext context) {
    final animation = NavigationRail.extendedAnimation(context);
    final l10n = AppLocalizations.of(context);
    final actionEnabled = !busy && !settingsBusy && enabled;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final width =
                _compactRailWidth +
                (_permanentDrawerWidth - _compactRailWidth) * animation.value;
            final labelOpacity = const Interval(
              0,
              0.25,
            ).transform(animation.value);
            return SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Divider(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Semantics(
                      button: true,
                      enabled: actionEnabled,
                      child: Tooltip(
                        message: l10n.settings,
                        child: InkWell(
                          key: const ValueKey('adaptive-shell-settings-action'),
                          focusNode: settingsFocusNode,
                          onTap: actionEnabled ? onOpenSettings : null,
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 48,
                            child: Opacity(
                              opacity: busy || !enabled ? 0.38 : 1,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: _compactRailWidth - 24,
                                    child: Center(
                                      child: settingsBusy
                                          ? const SizedBox.square(
                                              dimension: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.settings_outlined),
                                    ),
                                  ),
                                  Expanded(
                                    child: ClipRect(
                                      child: Opacity(
                                        opacity: labelOpacity,
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: Padding(
                                            padding:
                                                const EdgeInsetsDirectional.only(
                                                  start: 12,
                                                  end: 4,
                                                ),
                                            child: Text(
                                              l10n.settings,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceRail extends StatelessWidget {
  const _WorkspaceRail({
    required this.selectedIndex,
    required this.busy,
    required this.enabled,
    required this.settingsBusy,
    required this.onDestinationSelected,
    required this.onOpenSettings,
    required this.settingsFocusNode,
  });

  final int selectedIndex;
  final bool busy;
  final bool enabled;
  final bool settingsBusy;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenSettings;
  final FocusNode settingsFocusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    key: const ValueKey('adaptive-shell-navigation-rail'),
                    selectedIndex: selectedIndex,
                    extended: false,
                    scrollable: true,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: busy || !enabled
                        ? null
                        : onDestinationSelected,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const _WorkspaceNavigationBrandIcon(),
                    ),
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.school_outlined),
                        selectedIcon: const Icon(Icons.school),
                        label: _WorkspaceRailLabel(
                          label: l10n.studentTimetable,
                        ),
                        disabled: !enabled || busy,
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.event_note_outlined),
                        selectedIcon: const Icon(Icons.event_note),
                        label: _WorkspaceRailLabel(label: l10n.generalSchedule),
                        disabled: !enabled || busy,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: IconButton(
                    key: const ValueKey('adaptive-shell-settings-action'),
                    focusNode: settingsFocusNode,
                    onPressed: busy || settingsBusy || !enabled
                        ? null
                        : onOpenSettings,
                    tooltip: l10n.settings,
                    icon: settingsBusy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.settings_outlined),
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: UiCommandBusyIndicator(
                busy: true,
                semanticsKey: ValueKey('workspace-switch-busy'),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceRailLabel extends StatelessWidget {
  const _WorkspaceRailLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 72),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _WorkspaceNavigationBrandIcon extends StatelessWidget {
  const _WorkspaceNavigationBrandIcon({this.tooltip, this.onPressed});

  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.calendar_month_outlined,
      color: Theme.of(context).colorScheme.primary,
    );
    if (tooltip == null) {
      return ExcludeSemantics(
        child: SizedBox.square(
          key: const ValueKey('adaptive-shell-navigation-brand-icon'),
          dimension: 48,
          child: Center(child: icon),
        ),
      );
    }
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        label: tooltip,
        button: true,
        enabled: onPressed != null,
        child: IconButton(
          key: const ValueKey('adaptive-shell-navigation-collapse-toggle'),
          onPressed: onPressed,
          icon: icon,
        ),
      ),
    );
  }
}
