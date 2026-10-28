part of 'home_screen.dart';

typedef TimetableLiveRefreshTimerFactory = Timer Function(
  Duration delay,
  VoidCallback callback,
);

@visibleForTesting
class TimetableLiveRefreshScope extends InheritedWidget {
  const TimetableLiveRefreshScope({
    super.key,
    required this.now,
    required this.createTimer,
    required super.child,
  });

  final DateTime Function() now;
  final TimetableLiveRefreshTimerFactory createTimer;

  static TimetableLiveRefreshScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TimetableLiveRefreshScope>();
  }

  @override
  bool updateShouldNotify(TimetableLiveRefreshScope oldWidget) {
    return now != oldWidget.now || createTimer != oldWidget.createTimer;
  }
}

Timer _createTimetableLiveRefreshTimer(Duration delay, VoidCallback callback) {
  return Timer(delay, callback);
}

class _StudentWorkspaceToolbar extends StatelessWidget {
  const _StudentWorkspaceToolbar({
    required this.timetable,
    required this.week,
    required this.weekNavigationDirection,
    required this.viewMode,
    required this.navigationOrder,
    required this.hiddenNavigationIds,
    required this.hiddenItemsBehavior,
    required this.compactWidth,
    required this.compactHeight,
    required this.interactive,
    required this.showSettings,
    this.settingsFocusNode,
    required this.onOpenTimetablePicker,
    required this.onOpenWeekPicker,
    required this.onJumpToToday,
    required this.onViewChanged,
    required this.onOpenSettings,
    this.onManagePeriodTimeSets,
    this.onAddCourse,
    this.onStep,
    this.showAddLabel = false,
  });

  final TimetableData timetable;
  final int week;
  final int weekNavigationDirection;
  final _StudentTimetableView viewMode;
  final List<String> navigationOrder;
  final List<String> hiddenNavigationIds;
  final String hiddenItemsBehavior;
  final bool compactWidth;
  final bool compactHeight;
  final bool interactive;
  final bool showSettings;
  final FocusNode? settingsFocusNode;
  final ValueChanged<BuildContext>? onOpenTimetablePicker;
  final ValueChanged<BuildContext>? onOpenWeekPicker;
  final VoidCallback? onJumpToToday;
  final ValueChanged<_StudentTimetableView>? onViewChanged;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onManagePeriodTimeSets;
  final ValueChanged<BuildContext>? onAddCourse;
  final ValueChanged<int>? onStep;
  final bool showAddLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final first = startOfWeekFor(timetable.config, week);
    final last = addCalendarDays(first, 6);
    final dates = MaterialLocalizations.of(context);
    final fullWeekLabel =
        '${l10n.weekLabel(week)} · ${dates.formatFullDate(first)} – ${dates.formatFullDate(last)}';
    if (WorkbenchChromeMetrics.of(context).desktop) {
      return WorkbenchCommandBar(
        key: const ValueKey('student-workspace-toolbar'),
        compactBuilder: (context) => _desktopCompact(context, first, last),
        navigation: [
          if (needsWorkspaceMenu(context)) const WorkspaceModeMenu(),
          if (WorkspaceCanvasScope.maybeOf(context)?.resources != true)
            Builder(
              builder: (anchor) => IconButton(
                key: const ValueKey('student-timetable-picker-button'),
                tooltip: l10n.timetable,
                onPressed:
                    WorkspaceResourceScope.maybeOf(context)?.open ??
                    (onOpenTimetablePicker == null
                        ? null
                        : () => onOpenTimetablePicker!(anchor)),
                icon: const Icon(Icons.view_sidebar_outlined),
              ),
            ),
          IconButton(
            key: const ValueKey('student-previous-week'),
            tooltip:
                '${MaterialLocalizations.of(context).previousPageTooltip} (PageUp)',
            onPressed: week > 1 && onStep != null ? () => onStep!(-1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            key: const ValueKey('student-next-week'),
            tooltip:
                '${MaterialLocalizations.of(context).nextPageTooltip} (PageDown)',
            onPressed: week < timetable.config.totalWeeks && onStep != null
                ? () => onStep!(1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          TextButton(
            key: const ValueKey('student-today'),
            onPressed: onJumpToToday,
            child: Text(l10n.today),
          ),
          Builder(
            builder: (anchor) => SkedTooltip(
              message: fullWeekLabel,
              excludeFromSemantics: true,
              child: TextButton(
                key: const ValueKey('student-week-picker-button'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: onOpenWeekPicker == null
                    ? null
                    : () => onOpenWeekPicker!(anchor),
                onLongPress: onJumpToToday,
                child: Text(
                  '${l10n.weekLabel(week)} · ${first.month}/${first.day} – ${last.month}/${last.day}',
                  semanticsLabel: fullWeekLabel,
                ),
              ),
            ),
          ),
        ],
        actions: [
          SkedPopupMenuButton<_StudentTimetableView>(
            key: const ValueKey('student-view-toggle'),
            tooltip: l10n.defaultView,
            onSelected: onViewChanged,
            itemBuilder: (_) => [
              SkedCheckedPopupMenuItem(
                value: _StudentTimetableView.week,
                checked: viewMode == _StudentTimetableView.week,
                label: l10n.viewWeek,
              ),
              SkedCheckedPopupMenuItem(
                value: _StudentTimetableView.day,
                checked: viewMode == _StudentTimetableView.day,
                label: l10n.viewDay,
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text(
                    viewMode == _StudentTimetableView.week
                        ? l10n.viewWeek
                        : l10n.viewDay,
                  ),
                  const Icon(Icons.expand_more, size: 16),
                ],
              ),
            ),
          ),
          const AssistantPaneToggle(),
          if (showSettings)
            IconButton(
              key: const ValueKey('student-settings-button'),
              tooltip: l10n.settings,
              focusNode: settingsFocusNode,
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          Builder(
            builder: (anchor) => FilledButton.icon(
              key: const ValueKey('student-add-course'),
              onPressed: onAddCourse == null
                  ? null
                  : () => onAddCourse!(anchor),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addCourse),
            ),
          ),
        ],
      );
    }

    final phoneWidth = compactWidth;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScaler = MediaQuery.textScalerOf(context);
    final scaledLabelSize = textScaler.scale(
      theme.textTheme.labelLarge?.fontSize ?? 14,
    );
    final preferWeekPickerWithoutIcon =
        phoneWidth && (screenWidth < 360 || scaledLabelSize > 18.2);
    final controlShape = skedShapeSchemeOf(context).control;
    final motion = SkedMotionPolicy.of(context);
    final weekTextStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final weekTextPainter = TextPainter(
      text: TextSpan(text: l10n.weekLabel(week), style: weekTextStyle),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final measuredWeekWidth = weekTextPainter.width;
    weekTextPainter.dispose();
    final iconButtonStyle = IconButton.styleFrom(
      minimumSize: const Size.square(48),
      padding: const EdgeInsets.all(8),
      iconSize: 20,
    );
    Widget buildTimetableSelector() {
      return Builder(
        builder: (anchor) => SkedTooltip(
          message: timetable.config.name,
          excludeFromSemantics: true,
          child: TextButton(
            key: const ValueKey('student-timetable-picker-button'),
            onPressed: interactive && onOpenTimetablePicker != null
                ? () => onOpenTimetablePicker!(anchor)
                : null,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
              minimumSize: const Size(48, 48),
              shape: controlShape,
              alignment: AlignmentDirectional.centerStart,
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(
              timetable.config.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    final viewToggle = IconButton(
      key: const ValueKey('student-view-toggle-button'),
      onPressed: interactive && onViewChanged != null
          ? () => onViewChanged!(
              viewMode == _StudentTimetableView.day
                  ? _StudentTimetableView.week
                  : _StudentTimetableView.day,
            )
          : null,
      style: iconButtonStyle,
      tooltip: viewMode == _StudentTimetableView.day
          ? l10n.viewWeek
          : l10n.viewDay,
      icon: AnimatedSwitcher(
        duration: motion.effects(SkedMotionSpeed.fast),
        switchInCurve: motion.scheme.enterCurve,
        switchOutCurve: motion.scheme.exitCurve,
        child: Icon(
          viewMode == _StudentTimetableView.day
              ? Icons.view_week_outlined
              : Icons.view_day_outlined,
          key: ValueKey(viewMode),
          size: 20,
        ),
      ),
    );
    Widget buildWeekPicker({required double width}) {
      return Builder(
        builder: (anchor) => SkedTooltip(
          message: '$fullWeekLabel\n${l10n.jumpToWeek}; ${l10n.today}',
          child: Semantics(
            key: const ValueKey('student-week-picker-semantics'),
            button: true,
            enabled:
                interactive &&
                (onOpenWeekPicker != null || onJumpToToday != null),
            excludeSemantics: true,
            label: fullWeekLabel,
            hint: '${l10n.jumpToWeek}; ${l10n.today}',
            onTap: interactive && onOpenWeekPicker != null
                ? () => onOpenWeekPicker!(anchor)
                : null,
            onLongPress: onJumpToToday,
            onTapHint: l10n.jumpToWeek,
            onLongPressHint: l10n.today,
            child: SizedBox(
              width: width,
              child: TextButton(
                key: const ValueKey('student-week-picker-button'),
                onPressed: interactive && onOpenWeekPicker != null
                    ? () => onOpenWeekPicker!(anchor)
                    : null,
                onLongPress: interactive ? onJumpToToday : null,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  textStyle: weekTextStyle,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: controlShape,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showIcon =
                        !preferWeekPickerWithoutIcon &&
                        constraints.maxWidth >= measuredWeekWidth + 34;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showIcon) ...[
                          const Icon(Icons.calendar_month_outlined, size: 18),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: SkedDirectionalTransition(
                            trigger: week,
                            direction: weekNavigationDirection,
                            distance: 12,
                            child: Text(
                              l10n.weekLabel(week),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    final settingsAction = IconButton(
      key: const ValueKey('student-settings-button'),
      focusNode: settingsFocusNode,
      onPressed: onOpenSettings,
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.settings,
      style: iconButtonStyle,
    );
    final mobile = WorkbenchChromeMetrics.compactTouch(
      context,
      width: compactWidth ? 0 : null,
    );
    final showWorkspace = mobile
        ? needsMobileWorkspaceMenu(context)
        : needsWorkspaceMenu(context);
    final resourceLayout = WorkspaceCanvasScope.maybeOf(context);
    final timetableInResources =
        resourceLayout?.resources == true &&
        resourceLayout!.resourceWidth > AppBreakpoints.compactResourcePane;
    final placement = MobileToolbarLayout.resolve(
      order: navigationOrder,
      hiddenIds: mobile
          ? hiddenNavigationIds
          : hiddenNavigationIds.where((id) => id != 'settings').toList(),
      hiddenBehavior: hiddenItemsBehavior,
      defaultOrder: studentToolbarNavigationDefaultOrder,
      hasFixedMenuItems:
          !timetableInResources && onManagePeriodTimeSets != null,
      availableIds: {
        if (!timetableInResources) 'timetable',
        'week',
        'view',
        if (mobile && showWorkspace) 'workspace',
        if (showSettings) 'settings',
      },
    );
    final actionById = <String, Widget>{
      if (!timetableInResources) 'timetable': buildTimetableSelector(),
      'week': buildWeekPicker(width: double.infinity),
      'view': viewToggle,
      'workspace': const WorkspaceModeMenu(),
      if (showSettings) 'settings': settingsAction,
      'more': Builder(
        builder: (anchor) => SkedPopupMenuButton<String>(
          key: const ValueKey('student-toolbar-more-button'),
          focusNode: placement.menuIds.contains('settings')
              ? settingsFocusNode
              : null,
          icon: const Icon(Icons.more_horiz),
          tooltip: l10n.more,
          enabled: interactive,
          onSelected: (id) {
            if (!context.mounted || !interactive) return;
            switch (id) {
              case 'timetable':
                onOpenTimetablePicker?.call(anchor);
              case 'week':
                onOpenWeekPicker?.call(anchor);
              case 'today':
                onJumpToToday?.call();
              case 'view':
                onViewChanged?.call(
                  viewMode == _StudentTimetableView.day
                      ? _StudentTimetableView.week
                      : _StudentTimetableView.day,
                );
              case 'settings':
                onOpenSettings?.call();
              case 'periods':
                onManagePeriodTimeSets?.call();
              case 'student':
                selectWorkspace(context, AppMode.student);
              case 'general':
                selectWorkspace(context, AppMode.general);
            }
          },
          itemBuilder: (_) => [
            if (!timetableInResources && onManagePeriodTimeSets != null)
              SkedPopupMenuItem<String>(
                key: const ValueKey('student-more-periods'),
                value: 'periods',
                child: Text(l10n.managePeriodTimeSets),
              ),
            for (final id in placement.menuIds)
              if (id == 'workspace')
                ...workspaceMenuItems<String>(
                  context,
                  valueFor: (mode) => mode.value,
                  keyPrefix: 'student-more-workspace',
                )
              else
                SkedPopupMenuItem<String>(
                  key: ValueKey('student-more-$id'),
                  value: id,
                  enabled: id != 'settings' || onOpenSettings != null,
                  child: Text(switch (id) {
                    'timetable' => l10n.timetable,
                    'week' => l10n.weekLabel(week),
                    'view' => l10n.toolbarNavigationView,
                    'settings' => l10n.settings,
                    _ => id,
                  }),
                ),
            if (placement.menuIds.contains('week') && onJumpToToday != null)
              SkedPopupMenuItem<String>(
                value: 'today',
                child: Text(l10n.today),
              ),
          ],
        ),
      ),
    };
    final orderedIds = placement.toolbarIds;
    return SkedWorkspaceToolbar(
      key: const ValueKey('student-workspace-toolbar'),
      leading: !mobile && showWorkspace ? const WorkspaceModeMenu() : null,
      actions: [
        if (!WorkbenchChromeMetrics.compactTouch(context) ||
            AssistantPaneScope.of(context)?.enabled == true)
          const AssistantPaneToggle(),
        if (onAddCourse != null)
          Builder(
            builder: (anchor) => SkedTooltip(
              message: l10n.addCourse,
              child: showAddLabel
                  ? FilledButton.icon(
                      onPressed: onAddCourse == null
                          ? null
                          : () => onAddCourse!(anchor),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addCourse),
                    )
                  : IconButton.filled(
                      onPressed: onAddCourse == null
                          ? null
                          : () => onAddCourse!(anchor),
                      icon: const Icon(Icons.add),
                    ),
            ),
          ),
      ],
      padding: EdgeInsets.symmetric(
        horizontal: phoneWidth ? 8 : 16,
        vertical: WorkbenchChromeMetrics.compactTouch(context)
            ? 0
            : phoneWidth || compactHeight
            ? 4
            : 8,
      ),
      navigationSpacing: 0,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : screenWidth - (phoneWidth ? 16 : 32);
          const gap = 4.0;
          const selectorMinimum = 48.0;
          // Fixed-width navigation actions. Both the width budget below and the
          // final `contentWidth` check read from this one map, so adding an
          // action of a different width cannot make the two disagree.
          const fixedActionWidths = <String, double>{
            'view': 48,
            'workspace': 48,
            'settings': 48,
            'more': 48,
          };
          const defaultActionWidth = 48.0;
          final weekMinimum = phoneWidth ? 80.0 : 96.0;
          final hasTimetable = orderedIds.contains('timetable');
          final hasWeek = orderedIds.contains('week');
          final nonFlexibleWidth = orderedIds
              .where((id) => id != 'timetable' && id != 'week')
              .fold<double>(
                0,
                (sum, id) =>
                    sum + (fixedActionWidths[id] ?? defaultActionWidth),
              );
          final gapWidth = math.max(0, orderedIds.length - 1) * gap;
          final maximumWeekWidth = math.max(
            48.0,
            availableWidth -
                nonFlexibleWidth -
                gapWidth -
                (hasTimetable ? selectorMinimum : 0),
          );
          final desiredWeekWidth = math.max(
            weekMinimum,
            measuredWeekWidth + 12,
          );
          // Give the date its preferred width before allocating the filter.
          // A long localized week can wrap once the filter reaches its minimum;
          // keep the existing scroll fallback for rows whose targets cannot fit.
          final weekWidth = hasWeek
              ? math.min(desiredWeekWidth, maximumWeekWidth)
              : 0.0;
          final flexibleWidth = math.max(
            selectorMinimum,
            availableWidth - nonFlexibleWidth - gapWidth - weekWidth,
          );
          // The first timetable selector is the toolbar's content anchor.
          // Let it use the whole remaining row on phones instead of leaving a
          // blank spacer before the fixed navigation actions.
          final selectorMaximum = phoneWidth ? flexibleWidth : 240.0;
          final selectorWidth = hasTimetable
              ? math.min(selectorMaximum, flexibleWidth)
              : 0.0;
          final widths = <String, double>{
            ...fixedActionWidths,
            'timetable': selectorWidth,
            'week': weekWidth,
          };
          final contentWidth =
              orderedIds.fold<double>(
                0,
                (sum, id) => sum + (widths[id] ?? defaultActionWidth),
              ) +
              math.max(0, orderedIds.length - 1) * gap;
          final children = [
            for (var i = 0; i < orderedIds.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: widths[orderedIds[i]],
                child: actionById[orderedIds[i]],
              ),
            ],
          ];
          if (contentWidth > availableWidth + 0.5) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(children: children),
            );
          }
          if (children.isEmpty) {
            return const SizedBox.shrink();
          }
          // Keep the first navigation item anchored to the leading edge and
          // the remaining actions at the trailing edge.  This is the layout
          // used by the original timetable toolbar (the timetable selector
          // on the left, week/view/settings on the right) and prevents a
          // wide window from making the selector appear centered.  The
          // configured order still controls the order within each side; if a
          // user moves another item to the first position, that item becomes
          // the leading control.
          final first = children.first;
          final trailing = children.skip(1).toList(growable: false);
          return SizedBox(
            width: availableWidth,
            child: Row(
              children: [
                first,
                if (trailing.isNotEmpty) ...[const Spacer(), ...trailing],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _desktopCompact(BuildContext context, DateTime first, DateTime last) {
    final l = AppLocalizations.of(context);
    final workspace = context
        .select<
          WorkspaceViewState,
          ({AppMode activeMode, Set<AppMode> enabledWorkspaces})
        >(
          (view) => (
            activeMode: view.activeMode,
            enabledWorkspaces: view.enabledWorkspaces,
          ),
        );
    final assistant = AssistantPaneScope.of(context);
    final resources = WorkspaceCanvasScope.maybeOf(context)?.resources == true;
    return WorkbenchCompactCalendarBar(
      id: 'student',
      dateTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      primaryAction: WorkbenchOverflowAction(
        id: 'student-add-course',
        label: l.addCourse,
        icon: Icons.add,
        dividerBefore: true,
        onSelected: onAddCourse,
      ),
      enabled: interactive,
      moreFocusNode: showSettings ? settingsFocusNode : null,
      date: WorkbenchOverflowAction(
        id: 'student-week-picker-button',
        label:
            '${l.weekLabel(week)} · ${first.month}/${first.day} – ${last.month}/${last.day}',
        tooltip:
            '${l.weekLabel(week)} · ${MaterialLocalizations.of(context).formatFullDate(first)} – ${MaterialLocalizations.of(context).formatFullDate(last)}',
        icon: Icons.date_range_outlined,
        onSelected: onOpenWeekPicker,
      ),
      shortDateLabel: l.weekLabel(week),
      onDateLongPress: onJumpToToday,
      previous: WorkbenchOverflowAction(
        id: 'student-previous-week',
        label:
            '${MaterialLocalizations.of(context).previousPageTooltip} (PageUp)',
        icon: Icons.chevron_left,
        onSelected: week > 1 && onStep != null ? (_) => onStep!(-1) : null,
      ),
      next: WorkbenchOverflowAction(
        id: 'student-next-week',
        label:
            '${MaterialLocalizations.of(context).nextPageTooltip} (PageDown)',
        icon: Icons.chevron_right,
        onSelected: week < timetable.config.totalWeeks && onStep != null
            ? (_) => onStep!(1)
            : null,
      ),
      today: WorkbenchOverflowAction(
        id: 'student-today',
        label: l.today,
        icon: Icons.today,
        onSelected: onJumpToToday == null ? null : (_) => onJumpToToday!(),
      ),
      actions: [
        if (!resources)
          WorkbenchOverflowAction(
            id: 'student-timetable-picker-button',
            label: l.timetable,
            icon: Icons.view_sidebar_outlined,
            onSelected: onOpenTimetablePicker == null
                ? null
                : (anchor) {
                    final open = WorkspaceResourceScope.maybeOf(context)?.open;
                    if (open != null) {
                      open();
                    } else {
                      onOpenTimetablePicker!(anchor);
                    }
                  },
          ),
        for (final mode in _StudentTimetableView.values)
          WorkbenchOverflowAction(
            id: 'student-view-choice-${mode.name}',
            label:
                '${l.generalViewSwitchMenuTooltip} · ${mode == _StudentTimetableView.week ? l.viewWeek : l.viewDay}',
            icon: mode == _StudentTimetableView.week
                ? Icons.view_week_outlined
                : Icons.view_day_outlined,
            selected: mode == viewMode,
            onSelected: onViewChanged == null
                ? null
                : (_) => onViewChanged!(mode),
          ),
        if (assistant?.enabled == true)
          WorkbenchOverflowAction(
            id: 'assistant-toggle',
            label: l.assistantLayoutPreview,
            icon: Icons.chat_bubble_outline,
            onSelected: assistant!.interactive
                ? (_) => (assistant.onToggle ?? assistant.controller.toggle)()
                : null,
          ),
        if (showSettings)
          WorkbenchOverflowAction(
            id: 'student-settings-button',
            label: l.settings,
            icon: Icons.settings_outlined,
            onSelected: onOpenSettings == null
                ? null
                : (_) => onOpenSettings!(),
          ),
        if (needsWorkspaceMenu(context))
          for (final mode in workspace.enabledWorkspaces)
            WorkbenchOverflowAction(
              id: 'workspace-menu-${mode.value}',
              label: mode == AppMode.student
                  ? l.studentTimetable
                  : l.generalSchedule,
              icon: mode == AppMode.student
                  ? Icons.school_outlined
                  : Icons.event_note_outlined,
              selected: workspace.activeMode == mode,
              dividerBefore: mode == workspace.enabledWorkspaces.first,
              onSelected: (_) => selectWorkspace(context, mode),
            ),
      ],
    );
  }
}

class _StudentDayStrip extends StatefulWidget {
  const _StudentDayStrip({
    required this.weekStart,
    required this.selectedWeekday,
    required this.enabled,
    required this.fitToWidth,
    this.horizontalScrollLocked = false,
    this.onHorizontalPointerDown,
    this.onHorizontalEdgeDrag,
    required this.onSelected,
  });

  final DateTime weekStart;
  final int selectedWeekday;
  final bool enabled;
  final bool fitToWidth;
  final bool horizontalScrollLocked;
  final ValueChanged<int>? onHorizontalPointerDown;
  final ValueChanged<double>? onHorizontalEdgeDrag;
  final ValueChanged<int> onSelected;

  @override
  State<_StudentDayStrip> createState() => _StudentDayStripState();
}

class _StudentDayStripState extends State<_StudentDayStrip> {
  final ScrollController _scrollController = ScrollController();
  _DayStripMetrics? _lastMetrics;

  @override
  void initState() {
    super.initState();
    _scheduleRevealSelected(_lastMetrics);
  }

  @override
  void didUpdateWidget(covariant _StudentDayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedWeekday != widget.selectedWeekday ||
        oldWidget.weekStart != widget.weekStart ||
        oldWidget.fitToWidth != widget.fitToWidth) {
      _scheduleRevealSelected(_lastMetrics);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleRevealSelected(_DayStripMetrics? metrics) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || metrics == null || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0.5) {
        if (_scrollController.offset.abs() >= 0.5) {
          _scrollController.jumpTo(0);
        }
        return;
      }
      final selectedCenter =
          metrics.padding +
          ((widget.selectedWeekday - 1) * metrics.itemExtent) +
          (metrics.itemWidth / 2);
      final target = (selectedCenter - (position.viewportDimension / 2)).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() < 0.5) return;
      final motion = SkedMotionPolicy.of(context);
      final duration = motion.effects(SkedMotionSpeed.fast);
      if (!motion.spatialAnimationsEnabled || duration == Duration.zero) {
        _scrollController.jumpTo(target);
      } else {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: duration,
            curve: motion.scheme.standardCurve,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final motion = SkedMotionPolicy.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final today = DateTime.now();
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final boldText = MediaQuery.boldTextOf(context);
    Size singleLineSize(String text, TextStyle? style) {
      var effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
      if (boldText) {
        effectiveStyle = effectiveStyle.copyWith(fontWeight: FontWeight.bold);
      }
      final painter = TextPainter(
        text: TextSpan(text: text, style: effectiveStyle),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
        locale: Localizations.maybeLocaleOf(context),
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final localeCode = Localizations.localeOf(context).toLanguageTag();
    final weekdayLabels = List.generate(
      7,
      (index) => formatWeekdayShortLabel(index + 1, localeCode: localeCode),
    );
    final dateLabels = List.generate(
      7,
      (index) => '${addCalendarDays(widget.weekStart, index).day}',
    );
    final weekdaySizes = [
      for (final label in weekdayLabels)
        for (final weight in const [FontWeight.w500, FontWeight.w700])
          singleLineSize(
            label,
            theme.textTheme.labelMedium?.copyWith(fontWeight: weight),
          ),
    ];
    final dateSizes = [
      for (final label in dateLabels)
        for (final weight in const [FontWeight.w600, FontWeight.w800])
          singleLineSize(
            label,
            theme.textTheme.titleMedium?.copyWith(fontWeight: weight),
          ),
    ];
    final weekdayHeight = weekdaySizes
        .map((size) => size.height)
        .reduce(math.max);
    final dateHeight = dateSizes.map((size) => size.height).reduce(math.max);
    final weekdayWidth = weekdaySizes
        .map((size) => size.width)
        .reduce(math.max);
    final dateWidth = dateSizes.map((size) => size.width).reduce(math.max);
    // Include both selection weights and horizontal padding.
    // Fitting all seven days is a preference, subject to readable labels.
    final minimumItemWidth = math
        .max(36.0, math.max(weekdayWidth, dateWidth) + 12)
        .ceilToDouble();
    final stripHeight = math
        .max(60.0, weekdayHeight + dateHeight + 18)
        .ceilToDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _DayStripMetrics.fromWidth(
          constraints.maxWidth,
          fitToWidth: widget.fitToWidth,
          minimumItemWidth: minimumItemWidth,
        );
        _lastMetrics = metrics;
        _scheduleRevealSelected(metrics);
        final contentWidth =
            metrics.padding * 2 + metrics.itemWidth * 7 + metrics.gap * 6;
        final scrollable = contentWidth > constraints.maxWidth + 0.5;
        final physics = widget.horizontalScrollLocked || !scrollable
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              );
        bool reportHorizontalOverscroll(OverscrollNotification notification) {
          if (notification.metrics.axis != Axis.horizontal ||
              notification.dragDetails == null) {
            return false;
          }
          final delta = notification.dragDetails!.primaryDelta;
          if (delta != null && delta != 0) {
            widget.onHorizontalEdgeDrag?.call(delta);
          }
          return false;
        }

        return SizedBox(
          height: stripHeight,
          child: NotificationListener<OverscrollNotification>(
            onNotification: reportHorizontalOverscroll,
            child: Listener(
              onPointerDown: scrollable
                  ? (event) =>
                        widget.onHorizontalPointerDown?.call(event.pointer)
                  : null,
              onPointerPanZoomStart: scrollable
                  ? (event) =>
                        widget.onHorizontalPointerDown?.call(event.pointer)
                  : null,
              child: ListView.separated(
                key: const ValueKey('student-day-strip'),
                controller: _scrollController,
                physics: physics,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: metrics.padding),
                itemCount: 7,
                separatorBuilder: (_, _) => SizedBox(width: metrics.gap),
                itemBuilder: (context, index) {
                  final weekday = index + 1;
                  final date = addCalendarDays(widget.weekStart, index);
                  final selected = weekday == widget.selectedWeekday;
                  final isToday = DateUtils.isSameDay(date, today);
                  final foreground = selected
                      ? colors.onPrimaryContainer
                      : colors.onSurface;
                  return Semantics(
                    button: true,
                    enabled: widget.enabled,
                    selected: selected,
                    label: MaterialLocalizations.of(context)
                        .formatFullDate(date),
                    child: AnimatedContainer(
                      key: ValueKey('student-day-$weekday'),
                      duration: motion.effects(SkedMotionSpeed.fast),
                      curve: motion.scheme.standardCurve,
                      width: metrics.itemWidth,
                      child: Material(
                        color: Colors.transparent,
                        shape: shape,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: shape,
                          onTap: widget.enabled
                              ? () => widget.onSelected(weekday)
                              : null,
                          child: Center(
                            child: AnimatedContainer(
                              key: ValueKey('student-day-indicator-$weekday'),
                              duration: motion.effects(SkedMotionSpeed.fast),
                              curve: motion.scheme.standardCurve,
                              width: minimumItemWidth,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              decoration: ShapeDecoration(
                                shape: shape,
                                color: selected
                                    ? colors.primaryContainer
                                    : Colors.transparent,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    weekdayLabels[index],
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: foreground,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                  Text(
                                    dateLabels[index],
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: foreground,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    height: 4,
                                    width: 4,
                                    child: isToday
                                        ? DecoratedBox(
                                            key: const ValueKey(
                                              'student-day-today-dot',
                                            ),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: selected
                                                  ? colors.onPrimaryContainer
                                                  : colors.primary,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayStripMetrics {
  const _DayStripMetrics({
    required this.itemWidth,
    required this.gap,
    required this.padding,
  });

  final double itemWidth;
  final double gap;
  final double padding;

  double get itemExtent => itemWidth + gap;

  factory _DayStripMetrics.fromWidth(
    double width, {
    required bool fitToWidth,
    required double minimumItemWidth,
  }) {
    if (!fitToWidth) {
      return _DayStripMetrics(
        itemWidth: math.max(54, minimumItemWidth),
        gap: 4,
        padding: 4,
      );
    }
    final safeWidth = width.isFinite && width > 0 ? width : 320.0;
    const gap = 2.0;
    const padding = 0.0;
    return _DayStripMetrics(
      itemWidth: math.max(minimumItemWidth, (safeWidth - gap * 6) / 7),
      gap: gap,
      padding: padding,
    );
  }
}

class _TimetablePickerPanel extends StatefulWidget {
  const _TimetablePickerPanel({
    required this.student,
    required this.onSwitch,
    required this.onEdit,
    required this.onCreate,
  });

  final StudentViewState student;
  final Future<bool> Function(BuildContext context, TimetableData timetable)
  onSwitch;
  final Future<bool> Function(BuildContext context, TimetableData timetable)
  onEdit;
  final Future<bool> Function(BuildContext context) onCreate;

  @override
  State<_TimetablePickerPanel> createState() => _TimetablePickerPanelState();
}

class _TimetablePickerPanelState extends State<_TimetablePickerPanel> {
  bool _busy = false;
  bool _childDialogOpen = false;

  Future<void> _switch(Future<bool> Function() command) async {
    if (_busy || _childDialogOpen) return;
    setState(() => _busy = true);
    final completed = await command();
    if (!mounted) return;
    if (completed) {
      completeSkedTaskRoute(context);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _openChildDialog(
    Future<bool> Function() openDialog, {
    bool closeWhenNoTimetables = false,
  }) async {
    if (_busy || _childDialogOpen) return;
    setState(() => _childDialogOpen = true);
    var closePanel = false;
    try {
      final completed = await openDialog();
      closePanel =
          completed &&
          closeWhenNoTimetables &&
          widget.student.timetables.isEmpty;
    } finally {
      if (mounted && !closePanel) {
        setState(() => _childDialogOpen = false);
      } else {
        _childDialogOpen = false;
      }
    }
    if (mounted && closePanel) {
      completeSkedTaskRoute(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final floating = SkedTaskDialogScope.maybeOf(context) != null;
    final metrics = WorkbenchChromeMetrics.of(context);
    final height = math.min(MediaQuery.sizeOf(context).height * 0.72, 640.0);
    final compact = !floating && WorkbenchChromeMetrics.compactTouch(context);
    final heading = Padding(
      key: const ValueKey('timetable-picker-heading'),
      padding: floating
          ? skedPanelHeaderPadding
          : const EdgeInsets.fromLTRB(16, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: SkedPickerTitle(
              alignment: floating
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.topStart,
              child: SkedTaskHeader(title: Text(l10n.multiTimetableSwitch)),
            ),
          ),
          IconButton(
            key: const ValueKey('timetable-picker-close'),
            style: floating ? metrics.iconStyle : null,
            onPressed: _busy || _childDialogOpen
                ? null
                : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.cancel,
          ),
        ],
      ),
    );
    final status = UiCommandBusyIndicator(
      busy: _busy,
      semanticsKey: const ValueKey('timetable-picker-busy'),
    );
    final create = Builder(
      builder: (anchor) => FilledButton.icon(
        key: const ValueKey('timetable-picker-create'),
        onPressed: _busy || _childDialogOpen
            ? null
            : () => _openChildDialog(() => widget.onCreate(anchor)),
        icon: const Icon(Icons.add),
        label: Text(l10n.createTimetable),
      ),
    );
    Widget body({required bool sliver}) => ListenableBuilder(
      listenable: widget.student,
      builder: (context, _) {
        final selectedId = widget.student.activeTimetableOrNull?.id;
        final items = [
          for (final item in widget.student.timetables)
            _TimetableDrawerItem(
              timetable: item,
              selected: item.id == selectedId,
              enabled: !_busy && !_childDialogOpen,
              currentLabel: l10n.currentTimetableWeeks(item.config.totalWeeks),
              switchLabel: l10n.tapToSwitchWeeks(item.config.totalWeeks),
              editTooltip: l10n.editTimetable,
              onTap: _busy || _childDialogOpen
                  ? null
                  : () => _switch(() => widget.onSwitch(context, item)),
              onEdit: _busy || _childDialogOpen
                  ? null
                  : (anchor) => _openChildDialog(
                      () => widget.onEdit(anchor, item),
                      closeWhenNoTimetables: true,
                    ),
            ),
        ];
        return sliver
            ? SkedTaskBody(
                header: heading,
                headerPadding: EdgeInsets.zero,
                status: status,
                bodyIsSliver: true,
                semanticChildCount: items.length,
                bodyKey: const PageStorageKey('timetable-picker-list'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                footerPadding: const EdgeInsets.all(16),
                footer: create,
                child: SliverList.list(children: items),
              )
            : ListView(
                shrinkWrap: floating,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: items,
              );
      },
    );
    return PopScope(
      canPop: !_busy && !_childDialogOpen,
      child: SafeArea(
        top: false,
        child: compact
            ? LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.min(constraints.maxHeight, height),
                  ),
                  child: body(sliver: true),
                ),
              )
            : SizedBox(
                height: floating ? null : height,
                child: Column(
                  mainAxisSize: floating ? MainAxisSize.min : MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    status,
                    Flexible(
                      fit: floating ? FlexFit.loose : FlexFit.tight,
                      child: body(sliver: false),
                    ),
                    Padding(padding: const EdgeInsets.all(16), child: create),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TimetableDrawerItem extends StatelessWidget {
  const _TimetableDrawerItem({
    required this.timetable,
    required this.selected,
    required this.enabled,
    required this.currentLabel,
    required this.switchLabel,
    required this.editTooltip,
    required this.onTap,
    required this.onEdit,
  });

  final TimetableData timetable;
  final bool selected;
  final bool enabled;
  final String currentLabel;
  final String switchLabel;
  final String editTooltip;
  final VoidCallback? onTap;
  final ValueChanged<BuildContext>? onEdit;

  @override
  Widget build(BuildContext context) {
    final metrics = WorkbenchChromeMetrics.of(context);
    final edit = Builder(
      builder: (anchor) => IconButton(
        key: ValueKey('timetable-picker-edit-${timetable.id}'),
        tooltip: editTooltip,
        style: metrics.iconStyle,
        icon: const Icon(Icons.edit_outlined),
        onPressed: enabled && onEdit != null ? () => onEdit!(anchor) : null,
      ),
    );
    if (!WorkbenchChromeMetrics.compactTouch(context)) {
      return ExpressiveDialogOption(
        key: ValueKey('timetable-picker-item-${timetable.id}'),
        selected: selected,
        enabled: enabled,
        leading: Icon(selected ? Icons.check_circle : Icons.calendar_view_week),
        title: Text(timetable.config.name),
        subtitle: Text(selected ? currentLabel : switchLabel),
        trailing: edit,
        onTap: enabled ? onTap : null,
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = skedReadableAccent(
      colors,
      surface: colors.primary.withValues(alpha: 0.12),
    );
    final textColor = enabled
        ? (selected ? accent : colors.onSurface)
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? (selected ? accent : colors.onSurfaceVariant)
        : colors.onSurface.withValues(alpha: 0.38);
    final radius = skedShapeSchemeOf(context).fieldRadius;
    return Semantics(
      key: ValueKey('timetable-picker-item-${timetable.id}'),
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    selected ? Icons.check_circle : Icons.calendar_view_week,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timetable.config.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected ? currentLabel : switchLabel,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconTheme.merge(
                  data: IconThemeData(color: secondaryColor),
                  child: edit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimetableWeekPager extends StatefulWidget {
  const _TimetableWeekPager({
    required this.controller,
    required this.snapshot,
    required this.timetable,
    required this.config,
    required this.committedWeek,
    required this.active,
    required this.interactive,
    required this.swipeEnabled,
    required this.viewMode,
    required this.selectedWeekday,
    required this.fitDaySelectorToWidth,
    required this.fitWeekColumnsToWidth,
    this.shortcutFocusNode,
    required this.bottomContentInset,
    required this.dayHorizontalInset,
    required this.onPageScrollStateChanged,
    required this.onWeekSettled,
    required this.onWeekdaySelected,
    required this.onJumpWeekBy,
    required this.onCourseTap,
    required this.onAddCourse,
    required this.onEmptySlotTap,
  });

  final PageController controller;
  final _StudentHomeSnapshot snapshot;
  final TimetableData timetable;
  final TimetableConfig config;
  final int committedWeek;
  final bool active;
  final bool interactive;
  final bool swipeEnabled;
  final _StudentTimetableView viewMode;
  final int selectedWeekday;
  final bool fitDaySelectorToWidth;
  final bool fitWeekColumnsToWidth;
  final FocusNode? shortcutFocusNode;
  final double bottomContentInset;
  final double dayHorizontalInset;
  final ValueChanged<bool> onPageScrollStateChanged;
  final Future<void> Function(int week) onWeekSettled;
  final ValueChanged<int> onWeekdaySelected;
  final Future<void> Function(int offset) onJumpWeekBy;
  final ValueChanged<TimetableCourseTapInfo> onCourseTap;
  final ValueChanged<BuildContext>? onAddCourse;
  final ValueChanged<TimetableEmptySlotTapInfo>? onEmptySlotTap;

  @override
  State<_TimetableWeekPager> createState() => _TimetableWeekPagerState();
}

class _TimetableWeekPagerState extends State<_TimetableWeekPager>
    with WidgetsBindingObserver {
  Timer? _liveCourseTimer;
  late final FocusNode _shortcutFocusNode;
  DateTime Function() _now = DateTime.now;
  TimetableLiveRefreshTimerFactory _createTimer =
      _createTimetableLiveRefreshTimer;
  bool _isForeground = true;
  bool _tickerEnabled = false;
  bool _manualEdgeDrag = false;
  bool _manualSettleInProgress = false;
  bool _pageScrollReported = false;
  final Set<int> _innerHorizontalPointers = <int>{};
  int? _activePointer;
  int? _manualOriginPage;
  int _manualDirection = 0;
  Offset _pointerTravel = Offset.zero;
  double _manualProgressPixels = 0;
  VelocityTracker? _velocityTracker;

  @override
  void initState() {
    super.initState();
    _shortcutFocusNode =
        widget.shortcutFocusNode ??
        FocusNode(debugLabel: 'Student timetable week shortcuts');
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _restartLiveCourseTimer(refreshImmediately: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final timeScope = TimetableLiveRefreshScope.maybeOf(context);
    final nextNow = timeScope?.now ?? DateTime.now;
    final nextCreateTimer =
        timeScope?.createTimer ?? _createTimetableLiveRefreshTimer;
    final nextTickerEnabled = TickerMode.valuesOf(context).enabled;
    final timingChanged = _now != nextNow || _createTimer != nextCreateTimer;
    if (!timingChanged && _tickerEnabled == nextTickerEnabled) return;
    _now = nextNow;
    _createTimer = nextCreateTimer;
    _tickerEnabled = nextTickerEnabled;
    _restartLiveCourseTimer(refreshImmediately: _canRefresh);
  }

  @override
  void didUpdateWidget(covariant _TimetableWeekPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _restartLiveCourseTimer(refreshImmediately: _canRefresh);
    }
    if (oldWidget.swipeEnabled && !widget.swipeEnabled && _manualEdgeDrag) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_finishManualEdgeDrag(0));
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isForeground;
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground != wasForeground) {
      _restartLiveCourseTimer(refreshImmediately: _canRefresh);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveCourseTimer?.cancel();
    _reportPageScrolling(false);
    if (widget.shortcutFocusNode == null) _shortcutFocusNode.dispose();
    super.dispose();
  }

  bool get _canRefresh =>
      mounted && widget.active && _tickerEnabled && _isForeground;

  bool get _shortcutsEnabled => mounted && widget.active && _tickerEnabled;

  void _restartLiveCourseTimer({required bool refreshImmediately}) {
    _liveCourseTimer?.cancel();
    _liveCourseTimer = null;
    if (!_canRefresh) return;
    if (refreshImmediately) setState(() {});
    _scheduleLiveCourseTimer();
  }

  void _scheduleLiveCourseTimer() {
    if (!_canRefresh) return;
    final now = _now();
    _liveCourseTimer = _createTimer(
      timetableLiveRefreshDelayUntilNextMinute(now),
      () {
        _liveCourseTimer = null;
        if (!_canRefresh) return;
        setState(() {});
        _scheduleLiveCourseTimer();
      },
    );
  }

  void _reportPageScrolling(bool scrolling) {
    if (_pageScrollReported == scrolling) return;
    _pageScrollReported = scrolling;
    widget.onPageScrollStateChanged(scrolling);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.swipeEnabled || _activePointer != null) return;
    _activePointer = event.pointer;
    _pointerTravel = Offset.zero;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _handlePointerPanZoomStart(PointerPanZoomStartEvent event) {
    if (!widget.swipeEnabled || _activePointer != null) return;
    _activePointer = event.pointer;
    _pointerTravel = Offset.zero;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, Offset.zero);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    _handlePointerDelta(event.pointer, event.delta);
  }

  void _handlePointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (event.pointer != _activePointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.pan);
    _handlePointerDelta(event.pointer, event.panDelta);
  }

  void _handlePointerDelta(int pointer, Offset delta) {
    _pointerTravel += delta;
    if (_manualEdgeDrag) {
      _applyManualPageDelta(delta.dx);
      return;
    }
    if (!_innerHorizontalPointers.contains(pointer) &&
        _pointerTravel.dx.abs() >= kTouchSlop &&
        _pointerTravel.dx.abs() > _pointerTravel.dy.abs() * 1.1) {
      _beginManualPageDrag(_pointerTravel.dx);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    _innerHorizontalPointers.remove(event.pointer);
    _activePointer = null;
    _velocityTracker = null;
    _pointerTravel = Offset.zero;
    if (_manualEdgeDrag) {
      unawaited(_finishManualEdgeDrag(velocity));
    }
  }

  void _handlePointerPanZoomEnd(PointerPanZoomEndEvent event) {
    if (event.pointer != _activePointer) return;
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    _innerHorizontalPointers.remove(event.pointer);
    _activePointer = null;
    _velocityTracker = null;
    _pointerTravel = Offset.zero;
    if (_manualEdgeDrag) {
      unawaited(_finishManualEdgeDrag(velocity));
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _innerHorizontalPointers.remove(event.pointer);
    _activePointer = null;
    _velocityTracker = null;
    _pointerTravel = Offset.zero;
    if (_manualEdgeDrag) {
      unawaited(_finishManualEdgeDrag(0));
    }
  }

  void _markInnerHorizontalPointer(int pointer) {
    if (widget.swipeEnabled) _innerHorizontalPointers.add(pointer);
  }

  void _beginManualEdgeDrag(double physicalDelta) {
    _beginManualPageDrag(physicalDelta);
  }

  /// Nested horizontal scrollables consume the gesture first. Once one of
  /// them reports that it has reached an edge, keep the same pointer stream
  /// and move the outer page at the finger's physical delta.
  void _beginManualPageDrag(double physicalDelta) {
    if (_manualEdgeDrag ||
        _manualSettleInProgress ||
        _activePointer == null ||
        !widget.swipeEnabled ||
        widget.config.totalWeeks <= 1 ||
        !widget.controller.hasClients) {
      return;
    }
    final position = widget.controller.position;
    if (!position.hasViewportDimension || position.viewportDimension <= 0) {
      return;
    }
    final originPage = (widget.controller.page ?? widget.committedWeek - 1)
        .round()
        .clamp(0, widget.config.totalWeeks - 1);
    final adjustedDelta = axisDirectionIsReversed(position.axisDirection)
        ? -physicalDelta
        : physicalDelta;
    final direction = (-adjustedDelta).sign.toInt();
    if (direction == 0) return;

    _manualEdgeDrag = true;
    _manualOriginPage = originPage;
    _manualDirection = direction;
    _manualProgressPixels = 0;
    _reportPageScrolling(true);
    if (mounted) setState(() {});
    _applyManualPageDelta(physicalDelta);
  }

  void _applyManualPageDelta(double physicalDelta) {
    final originPage = _manualOriginPage;
    if (!_manualEdgeDrag ||
        originPage == null ||
        !widget.controller.hasClients) {
      return;
    }
    final position = widget.controller.position;
    if (!position.hasViewportDimension || position.viewportDimension <= 0) {
      return;
    }
    final adjustedDelta = axisDirectionIsReversed(position.axisDirection)
        ? -physicalDelta
        : physicalDelta;
    final originPixels = originPage * position.viewportDimension;
    final destinationPage = (originPage + _manualDirection).clamp(
      0,
      widget.config.totalWeeks - 1,
    );
    final maximumProgress =
        (destinationPage - originPage).abs() * position.viewportDimension;
    final progressDelta = -adjustedDelta * _manualDirection;
    _manualProgressPixels = (_manualProgressPixels + progressDelta).clamp(
      0,
      maximumProgress,
    );
    if (SkedMotionPolicy.of(context).spatialAnimationsEnabled) {
      final nextPixels =
          (originPixels + _manualDirection * _manualProgressPixels).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
      if ((nextPixels - position.pixels).abs() >= 0.01) {
        widget.controller.jumpTo(nextPixels);
      }
    }
  }

  Future<void> _finishManualEdgeDrag(double physicalVelocity) async {
    if (!_manualEdgeDrag || _manualSettleInProgress) return;
    final originPage = _manualOriginPage;
    if (originPage == null || !widget.controller.hasClients) {
      _resetManualDrag();
      return;
    }
    _manualEdgeDrag = false;
    _manualSettleInProgress = true;
    if (mounted) setState(() {});

    final position = widget.controller.position;
    final progress = position.viewportDimension <= 0
        ? 0.0
        : _manualProgressPixels / position.viewportDimension;
    final adjustedVelocity = axisDirectionIsReversed(position.axisDirection)
        ? -physicalVelocity
        : physicalVelocity;
    final pageVelocity = -adjustedVelocity * _manualDirection;
    final shouldAdvance =
        progress >= 0.35 || (pageVelocity >= 700 && progress >= 0.05);
    final targetPage = shouldAdvance
        ? (originPage + _manualDirection).clamp(0, widget.config.totalWeeks - 1)
        : originPage;

    try {
      final motion = SkedMotionPolicy.of(context);
      if (!motion.spatialAnimationsEnabled) {
        widget.controller.jumpToPage(targetPage);
      } else {
        await widget.controller.animateToPage(
          targetPage,
          duration: motion.effects(SkedMotionSpeed.standard),
          curve: motion.scheme.standardCurve,
        );
      }
      if (mounted && targetPage != widget.committedWeek - 1) {
        await widget.onWeekSettled(targetPage + 1);
      }
    } finally {
      _resetManualDrag();
    }
  }

  void _resetManualDrag() {
    _manualEdgeDrag = false;
    _manualSettleInProgress = false;
    _manualOriginPage = null;
    _manualDirection = 0;
    _manualProgressPixels = 0;
    _reportPageScrolling(false);
    if (mounted) setState(() {});
  }

  Widget _buildWeekPage(BuildContext context, int index) {
    final pageWeek = index + 1;
    final weekStart = startOfWeekFor(widget.config, pageWeek);
    final now = _now();
    final realCurrentWeek = currentWeekFor(widget.config, now: now);
    final liveCourseTarget = widget.snapshot.liveCourseOutlineEnabled
        ? currentOrNextCourseTargetFor(
            timetable: widget.timetable,
            periodTimes: widget.snapshot.periodTimes,
            selectedWeek: pageWeek,
            realCurrentWeek: realCurrentWeek,
            now: now,
            showPastEndedCourses: widget.snapshot.showPastEndedCourses,
            showFutureCourses: widget.snapshot.showFutureCourses,
            displayedCourseIdForConflict:
                widget.snapshot.displayedCourseIdForConflict,
          )
        : null;
    final liveCourseOutlineColorValue =
        widget.snapshot.liveCourseOutlineFollowTheme
        ? deriveLiveCourseOutlineColorFromSeed(
            Color(widget.snapshot.themeSeedColorValue),
          ).toARGB32()
        : widget.snapshot.liveCourseOutlineColorValue;
    final horizontalHandoffEnabled =
        widget.swipeEnabled &&
        (widget.viewMode == _StudentTimetableView.day ||
            (widget.viewMode == _StudentTimetableView.week &&
                !widget.fitWeekColumnsToWidth));
    final currentPageInteractive =
        widget.interactive && pageWeek == widget.committedWeek;

    if (widget.viewMode == _StudentTimetableView.day) {
      return KeyedSubtree(
        key: ValueKey('student-week-page-$pageWeek'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.dayHorizontalInset),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StudentDayStrip(
                    weekStart: weekStart,
                    selectedWeekday: widget.selectedWeekday,
                    enabled: currentPageInteractive && widget.active,
                    fitToWidth: widget.fitDaySelectorToWidth,
                    horizontalScrollLocked:
                        _manualEdgeDrag || _manualSettleInProgress,
                    onHorizontalPointerDown: horizontalHandoffEnabled
                        ? _markInnerHorizontalPointer
                        : null,
                    onHorizontalEdgeDrag: horizontalHandoffEnabled
                        ? _beginManualEdgeDrag
                        : null,
                    onSelected: widget.onWeekdaySelected,
                  ),
                  Expanded(
                    child: RepaintBoundary(
                      child: TimetableDayAgenda(
                        key: ValueKey('student-day-agenda-$pageWeek'),
                        showEmptyAddCourseAction: false,
                        timetable: widget.timetable,
                        periodTimes: widget.snapshot.periodTimes,
                        weekDateStart: weekStart,
                        selectedWeek: pageWeek,
                        realCurrentWeek: realCurrentWeek,
                        localeCode: widget.snapshot.localeCode,
                        selectedWeekday: widget.selectedWeekday,
                        showPastEndedCourses:
                            widget.snapshot.showPastEndedCourses,
                        showFutureCourses: widget.snapshot.showFutureCourses,
                        themeColorMode: widget.snapshot.themeColorMode,
                        courseNameColorValues:
                            widget.snapshot.courseNameColorValues,
                        colorfulCourseTextColorMode:
                            widget.snapshot.colorfulCourseTextColorMode,
                        colorfulCourseTextColorValue: widget
                            .snapshot
                            .colorfulUiColorValues[colorfulCourseTextColorKey],
                        displayedCourseIdForConflict:
                            widget.snapshot.displayedCourseIdForConflict,
                        liveCourseTarget: liveCourseTarget,
                        liveCourseOutlineEnabled:
                            widget.snapshot.liveCourseOutlineEnabled,
                        liveCourseOutlineMode:
                            widget.snapshot.liveCourseOutlineMode,
                        liveCourseOutlineColorValue:
                            liveCourseOutlineColorValue,
                        liveCourseOutlineWidth:
                            widget.snapshot.liveCourseOutlineWidth,
                        bottomContentInset: widget.bottomContentInset,
                        onCourseTap: currentPageInteractive && widget.active
                            ? widget.onCourseTap
                            : null,
                        onAddCourse: currentPageInteractive && widget.active
                            ? widget.onAddCourse
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: ValueKey('student-week-page-$pageWeek'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: WorkbenchChromeMetrics.compactTouch(context) ? 0 : 4,
              ),
              child: RepaintBoundary(
                child: TimetableGrid(
                  key: ValueKey('student-timetable-grid-$pageWeek'),
                  timetable: widget.timetable,
                  periodTimes: widget.snapshot.periodTimes,
                  weekDateStart: weekStart,
                  selectedWeek: pageWeek,
                  realCurrentWeek: realCurrentWeek,
                  localeCode: widget.snapshot.localeCode,
                  preserveGaps: widget.snapshot.preserveTimetableGaps,
                  showPastEndedCourses: widget.snapshot.showPastEndedCourses,
                  showFutureCourses: widget.snapshot.showFutureCourses,
                  showGridLines: widget.snapshot.showTimetableGridLines,
                  themeColorMode: widget.snapshot.themeColorMode,
                  courseNameColorValues: widget.snapshot.courseNameColorValues,
                  colorfulCourseTextColorMode:
                      widget.snapshot.colorfulCourseTextColorMode,
                  colorfulCourseTextColorValue: widget
                      .snapshot
                      .colorfulUiColorValues[colorfulCourseTextColorKey],
                  displayedCourseIdForConflict:
                      widget.snapshot.displayedCourseIdForConflict,
                  liveCourseTarget: liveCourseTarget,
                  liveCourseOutlineEnabled:
                      widget.snapshot.liveCourseOutlineEnabled,
                  liveCourseOutlineMode: widget.snapshot.liveCourseOutlineMode,
                  liveCourseOutlineColorValue: liveCourseOutlineColorValue,
                  liveCourseOutlineWidth:
                      widget.snapshot.liveCourseOutlineWidth,
                  fitVisibleDaysToWidth: widget.fitWeekColumnsToWidth,
                  bottomContentInset: widget.bottomContentInset,
                  horizontalScrollLocked:
                      _manualEdgeDrag || _manualSettleInProgress,
                  onHorizontalPointerDown:
                      horizontalHandoffEnabled &&
                          widget.viewMode == _StudentTimetableView.week
                      ? _markInnerHorizontalPointer
                      : null,
                  onHorizontalEdgeDrag:
                      horizontalHandoffEnabled &&
                          widget.viewMode == _StudentTimetableView.week
                      ? _beginManualEdgeDrag
                      : null,
                  onCourseTap: currentPageInteractive
                      ? widget.onCourseTap
                      : (_) {},
                  onEmptySlotTap: currentPageInteractive
                      ? widget.onEmptySlotTap
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageView = ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        onPointerPanZoomStart: _handlePointerPanZoomStart,
        onPointerPanZoomUpdate: _handlePointerPanZoomUpdate,
        onPointerPanZoomEnd: _handlePointerPanZoomEnd,
        child: PageView.builder(
          key: const ValueKey('student-week-pager'),
          controller: widget.controller,
          physics: const NeverScrollableScrollPhysics(),
          // The manual pointer state machine owns both drag progress and the
          // release animation. Implicit snapping would start a ballistic
          // spring after every jumpTo and fight slow mouse drags.
          pageSnapping: false,
          itemCount: widget.config.totalWeeks,
          itemBuilder: _buildWeekPage,
        ),
      ),
    );
    final shortcutsEnabled = _shortcutsEnabled && widget.interactive;
    return CallbackShortcuts(
      bindings: shortcutsEnabled
          ? {
              const SingleActivator(LogicalKeyboardKey.pageUp): () {
                unawaited(widget.onJumpWeekBy(-1));
              },
              const SingleActivator(LogicalKeyboardKey.pageDown): () {
                unawaited(widget.onJumpWeekBy(1));
              },
            }
          : const <ShortcutActivator, VoidCallback>{},
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: widget.shortcutFocusNode == null && shortcutsEnabled,
        canRequestFocus: shortcutsEnabled,
        // Arrow keys remain available for directional focus and inner controls,
        // including when a narrow timetable can scroll horizontally.
        descendantsAreFocusable: _shortcutsEnabled && widget.interactive,
        descendantsAreTraversable: _shortcutsEnabled && widget.interactive,
        child: pageView,
      ),
    );
  }
}

@visibleForTesting
Duration timetableLiveRefreshDelayUntilNextMinute(DateTime now) {
  final elapsedInMinute = Duration(
    seconds: now.second,
    milliseconds: now.millisecond,
    microseconds: now.microsecond,
  );
  return const Duration(minutes: 1) - elapsedInMinute;
}

class _EmptyTimetableState extends StatelessWidget {
  const _EmptyTimetableState({
    required this.onCreate,
    required this.onImport,
    required this.onImportFromText,
    required this.onImportFromWeb,
  });

  final Future<void> Function(BuildContext anchorContext)? onCreate;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onImportFromText;
  final Future<void> Function()? onImportFromWeb;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final importEnabled =
        onImport != null || onImportFromText != null || onImportFromWeb != null;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ExpressiveEmptyState(
            icon: Icons.event_busy_outlined,
            title: l10n.noTimetableTitle,
            message: l10n.noTimetableMessage,
            actions: [
              Builder(
                builder: (anchor) => FilledButton.icon(
                  onPressed: onCreate == null ? null : () => onCreate!(anchor),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.createTimetable),
                ),
              ),
              _EmptyTimetableImportMenu(
                enabled: importEnabled,
                onImport: onImport,
                onImportFromText: onImportFromText,
                onImportFromWeb: onImportFromWeb,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTimetableToolbar extends StatelessWidget {
  const _EmptyTimetableToolbar({
    super.key,
    required this.title,
    required this.showSettingsAction,
    required this.settingsFocusNode,
    required this.onOpenSettings,
    this.onManagePeriodTimeSets,
  });

  final String title;
  final bool showSettingsAction;
  final FocusNode? settingsFocusNode;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onManagePeriodTimeSets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final layout = WorkspaceCanvasScope.maybeOf(context);
    final titleInSidebar =
        layout?.resources == true &&
        layout!.resourceWidth >=
            AppBreakpoints.resourcePane * metrics.textScale;
    final compactTouch = WorkbenchChromeMetrics.compactTouch(context);
    if (metrics.desktop) {
      final scope = WorkspaceResourceScope.maybeOf(context);
      final resourceAction = layout?.resources == true
          ? null
          : IconButton(
              key: const ValueKey('student-empty-resources'),
              tooltip: l10n.timetable,
              onPressed: scope?.open,
              icon: const Icon(Icons.view_sidebar_outlined),
            );
      final settings = IconButton(
        key: const ValueKey('empty-timetable-settings-button'),
        focusNode: settingsFocusNode,
        onPressed: onOpenSettings,
        tooltip: l10n.settings,
        icon: const Icon(Icons.settings_outlined),
      );
      return WorkbenchCommandBar(
        navigation: [
          if (needsWorkspaceMenu(context)) const WorkspaceModeMenu(),
          ?resourceAction,
          if (!titleInSidebar) Text(title),
        ],
        actions: [if (showSettingsAction) settings],
        compactBuilder: (context) => Row(
          children: [
            ?resourceAction,
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (showSettingsAction) settings,
          ],
        ),
      );
    }
    if (compactTouch) {
      final navigation = context
          .select<
            SettingsViewState,
            ({
              List<String> order,
              List<String> hiddenIds,
              String hiddenBehavior,
            })
          >(
            (view) => (
              order: view.studentToolbarNavigationOrder,
              hiddenIds: view.studentHiddenToolbarNavigationIds,
              hiddenBehavior: view.studentToolbarHiddenItemsBehavior,
            ),
          );
      final placement = MobileToolbarLayout.resolve(
        order: navigation.order,
        hiddenIds: navigation.hiddenIds,
        hiddenBehavior: navigation.hiddenBehavior,
        defaultOrder: studentToolbarNavigationDefaultOrder,
        hasFixedMenuItems: onManagePeriodTimeSets != null,
        availableIds: {
          if (needsMobileWorkspaceMenu(context)) 'workspace',
          if (showSettingsAction) 'settings',
        },
      );
      final enabled =
          WorkspaceNavigationScope.maybeOf(context)?.enabled ?? true;
      return SkedWorkspaceToolbar(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            for (final id in placement.toolbarIds)
              switch (id) {
                'workspace' => const WorkspaceModeMenu(),
                'settings' => IconButton(
                  key: const ValueKey('empty-timetable-settings-button'),
                  focusNode: settingsFocusNode,
                  tooltip: l10n.settings,
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                _ => SkedPopupMenuButton<String>(
                  key: const ValueKey('student-toolbar-more-button'),
                  focusNode: placement.menuIds.contains('settings')
                      ? settingsFocusNode
                      : null,
                  tooltip: l10n.more,
                  enabled: enabled,
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (id) {
                    if (!context.mounted || !enabled) return;
                    switch (id) {
                      case 'settings':
                        onOpenSettings?.call();
                      case 'periods':
                        onManagePeriodTimeSets?.call();
                      case 'student':
                        selectWorkspace(context, AppMode.student);
                      case 'general':
                        selectWorkspace(context, AppMode.general);
                    }
                  },
                  itemBuilder: (_) => [
                    if (onManagePeriodTimeSets != null)
                      SkedPopupMenuItem<String>(
                        key: const ValueKey('student-more-periods'),
                        value: 'periods',
                        child: Text(l10n.managePeriodTimeSets),
                      ),
                    for (final id in placement.menuIds)
                      if (id == 'workspace')
                        ...workspaceMenuItems<String>(
                          context,
                          valueFor: (mode) => mode.value,
                          keyPrefix: 'student-more-workspace',
                        )
                      else
                        SkedPopupMenuItem<String>(
                          key: const ValueKey('student-more-settings'),
                          value: 'settings',
                          enabled: onOpenSettings != null,
                          child: Text(l10n.settings),
                        ),
                  ],
                ),
              },
          ],
        ),
      );
    }
    final padding = EdgeInsetsDirectional.fromSTEB(
      12,
      compactTouch ? 0 : 6,
      6,
      compactTouch ? 0 : 6,
    );
    return SkedWorkspaceToolbar(
      padding: padding,
      title: SizedBox(
        height: metrics.desktop
            ? metrics.toolbarHeight - padding.vertical
            : null,
        child: Row(
          children: [
            Expanded(
              // An expanded paragraph would hit-test the blank toolbar space
              // and prevent the drag region behind it from receiving gestures.
              child: titleInSidebar
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      heightFactor: 1,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metrics.desktop
                            ? Theme.of(context).textTheme.titleMedium
                            : null,
                      ),
                    ),
            ),
            if (needsWorkspaceMenu(context)) const WorkspaceModeMenu(),
            if (onManagePeriodTimeSets != null)
              IconButton(
                key: const ValueKey('student-manage-periods'),
                onPressed: onManagePeriodTimeSets,
                tooltip: l10n.managePeriodTimeSets,
                icon: const Icon(Icons.schedule_outlined),
              ),
            if (showSettingsAction)
              SizedBox.square(
                dimension: metrics.desktop ? metrics.iconTarget : 48,
                child: IconButton(
                  key: const ValueKey('empty-timetable-settings-button'),
                  focusNode: settingsFocusNode,
                  style: metrics.desktop ? metrics.iconStyle : null,
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: l10n.settings,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _EmptyTimetableImportAction { files, text, schoolWeb }

class _EmptyTimetableImportMenu extends StatefulWidget {
  const _EmptyTimetableImportMenu({
    required this.enabled,
    required this.onImport,
    required this.onImportFromText,
    required this.onImportFromWeb,
  });

  final bool enabled;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onImportFromText;
  final Future<void> Function()? onImportFromWeb;

  @override
  State<_EmptyTimetableImportMenu> createState() =>
      _EmptyTimetableImportMenuState();
}

class _EmptyTimetableImportMenuState extends State<_EmptyTimetableImportMenu> {
  final _anchorKey = GlobalKey();
  bool _menuOpen = false;
  RelativeRect? _lastMenuPosition;

  double _menuHeightForWidth(double width) {
    final menu = SkedMenuStyle.of(context);
    final popupTheme = PopupMenuTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final labelWidth = math.max(
      0.0,
      width -
          menu.padding.horizontal -
          menu.itemMargin.horizontal -
          menu.itemPadding.horizontal -
          menu.iconSize -
          menu.iconGap,
    );
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: _EmptyTimetableImportMenuLabel.maxLines,
      ellipsis: '…',
    );
    var height = menu.padding.vertical;
    try {
      for (final (label, enabled) in [
        (l10n.importTimetableFiles, widget.onImport != null),
        (l10n.importTimetableText, widget.onImportFromText != null),
        (l10n.schoolWebImportEntry, widget.onImportFromWeb != null),
      ]) {
        final states = <WidgetState>{if (!enabled) WidgetState.disabled};
        var labelStyle =
            popupTheme.labelTextStyle?.resolve(states) ??
            popupTheme.textStyle ??
            menu.labelStyle(states);
        if (MediaQuery.boldTextOf(context)) {
          labelStyle = labelStyle.merge(
            const TextStyle(fontWeight: FontWeight.bold),
          );
        }
        painter.text = TextSpan(text: label, style: labelStyle);
        painter.layout(maxWidth: labelWidth);
        height +=
            math.max(
              menu.itemHeight,
              math.max(menu.iconSize, painter.height) +
                  menu.itemPadding.vertical,
            ) +
            menu.itemMargin.vertical;
      }
      return height;
    } finally {
      painter.dispose();
    }
  }

  RelativeRect _menuPositionBuilder(
    BoxConstraints constraints,
    double menuWidth,
  ) {
    final fallback =
        _lastMenuPosition ??
        RelativeRect.fromLTRB(
          16,
          16,
          math.max(0, constraints.maxWidth - menuWidth - 16),
          math.max(0, constraints.maxHeight - 16),
        );
    if (!mounted) return fallback;

    final anchor = _anchorKey.currentContext?.findRenderObject();
    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (anchor is! RenderBox ||
        overlay is! RenderBox ||
        !anchor.attached ||
        !overlay.attached) {
      return fallback;
    }

    final anchorRect = Rect.fromPoints(
      anchor.localToGlobal(Offset.zero, ancestor: overlay),
      anchor.localToGlobal(
        anchor.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    final media = MediaQuery.of(context);
    final scrollable = Scrollable.maybeOf(context)?.context.findRenderObject();
    final scrollableRect = scrollable is RenderBox && scrollable.attached
        ? Rect.fromPoints(
            scrollable.localToGlobal(Offset.zero, ancestor: overlay),
            scrollable.localToGlobal(
              scrollable.size.bottomRight(Offset.zero),
              ancestor: overlay,
            ),
          )
        : Offset.zero & overlay.size;
    final safeTop = math.max(media.padding.top + 8, scrollableRect.top + 8);
    final safeBottom = math.max(
      safeTop,
      math.min(
        overlay.size.height -
            math.max(media.padding.bottom, media.viewInsets.bottom) -
            8,
        scrollableRect.bottom - 8,
      ),
    );
    final effectiveMenuWidth = math.min(
      menuWidth,
      math.max(0.0, overlay.size.width - 32),
    );
    final menuHeight = _menuHeightForWidth(effectiveMenuWidth);
    const gap = 8.0;
    final spaceBelow = safeBottom - anchorRect.bottom - gap;
    final spaceAbove = anchorRect.top - safeTop - gap;
    final openBelow = spaceBelow >= menuHeight || spaceBelow >= spaceAbove;
    final requestedTop = openBelow
        ? anchorRect.bottom + gap
        : anchorRect.top - gap - menuHeight;
    final maxMenuTop = math.max(safeTop, safeBottom - menuHeight);
    final menuTop = requestedTop.clamp(safeTop, maxMenuTop).toDouble();
    final idealLeft = anchorRect.center.dx - effectiveMenuWidth / 2;
    final maxMenuLeft = math.max(
      16.0,
      overlay.size.width - effectiveMenuWidth - 16,
    );
    final menuLeft = idealLeft.clamp(16.0, maxMenuLeft).toDouble();
    return _lastMenuPosition = RelativeRect.fromLTRB(
      menuLeft,
      menuTop,
      math.max(0, overlay.size.width - menuLeft - effectiveMenuWidth),
      math.max(0, overlay.size.height - menuTop),
    );
  }

  Future<void> _showMenu() async {
    if (_menuOpen || !widget.enabled) return;
    final anchor = _anchorKey.currentContext?.findRenderObject();
    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (anchor is! RenderBox || overlay is! RenderBox) return;
    final menuWidth = math
        .min(320.0, overlay.size.width - 32)
        .clamp(0.0, 320.0)
        .toDouble();
    if (menuWidth <= 0) return;
    final l10n = AppLocalizations.of(context);

    _lastMenuPosition = null;
    setState(() => _menuOpen = true);
    _EmptyTimetableImportAction? selected;
    try {
      selected = await showSkedMenu<_EmptyTimetableImportAction>(
        context: context,
        positionBuilder: (_, constraints) =>
            _menuPositionBuilder(constraints, menuWidth),
        constraints: BoxConstraints.tightFor(width: menuWidth),
        items: [
          SkedPopupMenuItem(
            key: const ValueKey('empty-timetable-import-files'),
            value: _EmptyTimetableImportAction.files,
            enabled: widget.onImport != null,
            child: _EmptyTimetableImportMenuLabel(
              icon: Icons.file_download_outlined,
              label: l10n.importTimetableFiles,
            ),
          ),
          SkedPopupMenuItem(
            key: const ValueKey('empty-timetable-import-text'),
            value: _EmptyTimetableImportAction.text,
            enabled: widget.onImportFromText != null,
            child: _EmptyTimetableImportMenuLabel(
              icon: Icons.paste_outlined,
              label: l10n.importTimetableText,
            ),
          ),
          SkedPopupMenuItem(
            key: const ValueKey('empty-timetable-import-web'),
            value: _EmptyTimetableImportAction.schoolWeb,
            enabled: widget.onImportFromWeb != null,
            child: _EmptyTimetableImportMenuLabel(
              icon: Icons.language_outlined,
              label: l10n.schoolWebImportEntry,
            ),
          ),
        ],
      );
    } finally {
      if (mounted) setState(() => _menuOpen = false);
    }
    if (!mounted || selected == null) return;
    switch (selected) {
      case _EmptyTimetableImportAction.files:
        await widget.onImport?.call();
        break;
      case _EmptyTimetableImportAction.text:
        await widget.onImportFromText?.call();
        break;
      case _EmptyTimetableImportAction.schoolWeb:
        await widget.onImportFromWeb?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      key: _anchorKey,
      child: OutlinedButton.icon(
        key: const ValueKey('empty-timetable-import-button'),
        onPressed: widget.enabled && !_menuOpen ? _showMenu : null,
        icon: const Icon(Icons.file_download_outlined),
        label: Text(l10n.importTimetable),
      ),
    );
  }
}

class _EmptyTimetableImportMenuLabel extends StatelessWidget {
  const _EmptyTimetableImportMenuLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
  static const maxLines = 2;

  @override
  Widget build(BuildContext context) {
    return SkedMenuItemContent(
      leading: Icon(icon),
      child: Text(label, maxLines: maxLines, overflow: TextOverflow.ellipsis),
    );
  }
}
