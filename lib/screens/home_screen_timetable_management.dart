part of 'home_screen.dart';

extension _HomeScreenTimetableManagement on _HomeScreenState {
  Future<void> _showTimetablePicker(
    BuildContext context, {
    required double availableWidth,
    BuildContext? anchorContext,
  }) async {
    if (_timetablePickerOpen || !mounted || !context.mounted) return;
    final student = context.read<StudentViewState>();
    _setTimetablePickerOpen(true);
    try {
      final panel = _TimetablePickerPanel(
        student: student,
        onSwitch: (pickerContext, timetable) =>
            _switchTimetableFromPicker(pickerContext, timetable),
        onEdit: (pickerContext, timetable) async {
          final editor = WorkspaceEditorConfiguration(
            anchorRect: WorkspaceEditorConfiguration(
              anchorContext: pickerContext,
            ).initialAnchor,
          );
          completeSkedTaskRoute(pickerContext);
          await WidgetsBinding.instance.endOfFrame;
          if (!context.mounted) return false;
          return _openTimetableItemDialog(context, timetable, editor: editor);
        },
        onCreate: (pickerContext) async {
          final editor = WorkspaceEditorConfiguration(
            anchorRect: WorkspaceEditorConfiguration(
              anchorContext: pickerContext,
            ).initialAnchor,
          );
          completeSkedTaskRoute(pickerContext);
          await WidgetsBinding.instance.endOfFrame;
          if (!context.mounted) return false;
          return _openCreateTimetableDialog(context, editor: editor);
        },
      );
      if (WorkbenchChromeMetrics.of(context).desktop) {
        await showSkedAdaptivePickerDialog<void>(
          context: context,
          routeName: 'timetable-picker',
          anchorContext: anchorContext,
          preferredWidth: 340,
          workspace: AppMode.student,
          builder: (_) => panel,
        );
      } else if (availableWidth < 720) {
        await showAppModalSheet<void>(
          context: context,
          maxWidth: appSheetWidthCompact,
          enableDrag: true,
          useSafeArea: true,
          builder: (_) => panel,
        );
      } else {
        await showExpressiveDialog<void>(
          context: context,
          builder: (_) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SkedSurface(
                role: SkedSurfaceRole.content,
                shape: skedShapeSchemeOf(context).dialog,
                clipBehavior: Clip.antiAlias,
                child: panel,
              ),
            ),
          ),
        );
      }
    } finally {
      _setTimetablePickerOpen(false);
    }
  }

  Future<void> _showWeekPicker(
    BuildContext context, {
    BuildContext? anchorContext,
  }) async {
    if (_weekPickerOpen ||
        !mounted ||
        !context.mounted ||
        !widget.active ||
        !widget.interactive ||
        _weekNavigationTarget != null ||
        _weekPageScrolling) {
      return;
    }
    final student = context.read<StudentViewState>();
    final workspace = context.read<WorkspaceViewState>();
    final maintenance = context.read<AppDataMaintenance>();
    final timetable = student.activeTimetableOrNull;
    if (timetable == null || !workspace.isEnabled(AppMode.student)) {
      return;
    }
    final config = timetable.config;
    final selectedWeek = student.selectedWeek;
    final dataSession = maintenance.dataSessionToken;
    final activeMode = workspace.activeMode;
    final resumeBoundary =
        workspace.data.workspaceReminderNotBefore[AppMode.student];
    final navigationGeneration = _weekNavigationGeneration;
    var selectionReturned = false;
    bool ownerCurrent() {
      final current = student.activeTimetableOrNull;
      return mounted &&
          context.mounted &&
          widget.active &&
          widget.interactive &&
          identical(maintenance.dataSessionToken, dataSession) &&
          workspace.isEnabled(AppMode.student) &&
          workspace.activeMode == activeMode &&
          workspace.data.workspaceReminderNotBefore[AppMode.student] ==
              resumeBoundary &&
          current?.id == timetable.id &&
          current?.config.startDate == config.startDate &&
          current?.config.totalWeeks == config.totalWeeks;
    }

    bool selectionCurrent() =>
        ownerCurrent() &&
        student.selectedWeek == selectedWeek &&
        navigationGeneration == _weekNavigationGeneration &&
        _weekNavigationTarget == null;
    _setWeekPickerOpen(true);
    try {
      final week = await showSkedWeekPicker(
        context: context,
        config: config,
        selectedWeek: selectedWeek,
        anchorContext: anchorContext,
        isSessionCurrent: () =>
            ownerCurrent() && (selectionReturned || selectionCurrent()),
      );
      final accepted = week != null && selectionCurrent();
      // Re-enable the trigger before the closing transition restores its focus.
      // The existing navigation target separately prevents reopening mid-animation.
      selectionReturned = accepted;
      _setWeekPickerOpen(false);
      if (accepted && week != selectedWeek) {
        await _animateToWeek(
          week,
          isSessionCurrent: () =>
              ownerCurrent() && student.selectedWeek == selectedWeek,
        );
      }
    } finally {
      _setWeekPickerOpen(false);
    }
  }

  Future<bool> _openCreateTimetableDialog(
    BuildContext context, {
    WorkspaceEditorConfiguration? editor,
  }) {
    if (!mounted || !context.mounted) return Future.value(false);
    final student = context.read<StudentViewState>();
    final l10n = AppLocalizations.of(context);
    final periodTimeSetId =
        student.activePeriodTimeSetOrNull?.id ??
        (student.periodTimeSets.isEmpty ? '' : student.periodTimeSets.first.id);
    return _openTimetableConfigDialog(
      context,
      editor: editor,
      initialConfig: TimetableConfig(
        name: l10n.newTimetableName,
        startDate: DateUtils.dateOnly(DateTime.now()),
        totalWeeks: 18,
        periodTimeSetId: periodTimeSetId,
      ),
    );
  }

  Future<bool> _openTimetableItemDialog(
    BuildContext context,
    TimetableData timetable, {
    WorkspaceEditorConfiguration? editor,
  }) {
    return _openTimetableConfigDialog(
      context,
      initialConfig: timetable.config,
      timetable: timetable,
      editor: editor,
    );
  }

  Future<bool> _openTimetableConfigDialog(
    BuildContext context, {
    required TimetableConfig initialConfig,
    TimetableData? timetable,
    WorkspaceEditorConfiguration? editor,
  }) async {
    final creating = timetable == null;
    if (_timetableItemDialogOpen ||
        _courseEditorOpen ||
        !mounted ||
        !context.mounted) {
      return false;
    }
    final student = context.read<StudentViewState>();
    final commands = context.read<StudentCommands>();
    _setTimetableItemDialogOpen(true);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: initialConfig.name);
    final weeksController = TextEditingController(
      text: initialConfig.totalWeeks.toString(),
    );
    final startDateAnchor = GlobalKey();
    final periodTimeSetAnchor = GlobalKey();
    var selectedStartDate = initialConfig.startDate;
    var selectedPeriodTimeSetId = initialConfig.periodTimeSetId;
    var startDatePickerOpen = false;
    var periodTimeSetPickerOpen = false;
    var busy = false;
    var deleteDialogOpen = false;
    try {
      final result = await showAppModalSheet<String>(
        context: context,
        workspacePane: _pane,
        layoutKey: DesktopLayoutRegion.timetableEditor,
        editor: (editor ?? _pane.takeEditorEntry()).withPreferredWidth(360),
        workspace: AppMode.student,
        isDismissible: false,
        selectionId: timetable == null
            ? 'timetable:new'
            : 'timetable:${timetable.id}',
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          var popped = false;
          void popWith(String? value) {
            if (!context.mounted || popped) return;
            popped = true;
            completeEditorRoute(context, value);
          }

          String formatDate(DateTime date) {
            final year = date.year.toString().padLeft(4, '0');
            final month = date.month.toString().padLeft(2, '0');
            final day = date.day.toString().padLeft(2, '0');
            return '$year-$month-$day';
          }

          return _TimetableDialogControllerOwner(
            nameController: nameController,
            weeksController: weeksController,
            fingerprint: () =>
                '${nameController.text}|${weeksController.text}|${selectedStartDate.toIso8601String()}|$selectedPeriodTimeSetId',
            isBlocked: () =>
                busy ||
                startDatePickerOpen ||
                periodTimeSetPickerOpen ||
                deleteDialogOpen,
            onExit: () => popWith(null),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final blocked =
                    busy ||
                    startDatePickerOpen ||
                    periodTimeSetPickerOpen ||
                    deleteDialogOpen;

                Future<void> saveChanges() async {
                  if (busy ||
                      startDatePickerOpen ||
                      periodTimeSetPickerOpen ||
                      deleteDialogOpen ||
                      popped) {
                    return;
                  }
                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }
                  if (student.periodTimeSetForId(selectedPeriodTimeSetId) ==
                      null) {
                    showUiFailureFeedback(
                      context: context,
                      message: l10n.noPeriodTimeAvailable,
                    );
                    return;
                  }
                  final totalWeeks = normalizeTimetableWeeks(
                    int.tryParse(weeksController.text) ??
                        initialConfig.totalWeeks,
                  );
                  weeksController.value = TextEditingValue(
                    text: totalWeeks.toString(),
                    selection: TextSelection.collapsed(
                      offset: totalWeeks.toString().length,
                    ),
                  );
                  setDialogState(() => busy = true);
                  final saved = await runUiCommandWithFeedback(
                    context: context,
                    debugLabel: creating
                        ? 'Create timetable'
                        : 'Update timetable',
                    command: () {
                      final config = initialConfig.copyWith(
                        name: nameController.text.trim(),
                        startDate: selectedStartDate,
                        totalWeeks: totalWeeks,
                        periodTimeSetId: selectedPeriodTimeSetId,
                      );
                      return creating
                          ? commands.addTimetable(config)
                          : commands.updateTimetableConfigFor(
                              timetable.id,
                              config,
                            );
                    },
                  );
                  if (!context.mounted) return;
                  if (saved) {
                    popWith('save');
                  } else {
                    setDialogState(() => busy = false);
                  }
                }

                Future<void> confirmDelete() async {
                  if (busy ||
                      startDatePickerOpen ||
                      periodTimeSetPickerOpen ||
                      deleteDialogOpen ||
                      popped) {
                    return;
                  }
                  setDialogState(() => deleteDialogOpen = true);
                  try {
                    final deleted = await showExpressiveDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      waitForTransitionComplete: true,
                      session: SkedTaskSessionScope.maybeOf(context)?.session,
                      builder: (_) => SkedMutationConfirmationDialog(
                        workspace: AppMode.student,
                        title: l10n.deleteTimetableTitle,
                        message: l10n.deleteTimetableMessage(
                          timetable!.config.name,
                        ),
                        confirmLabel: l10n.delete,
                        debugLabel: 'Delete timetable',
                        onConfirm: () => commands.deleteTimetable(timetable.id),
                      ),
                    );
                    if (!context.mounted || deleted != true) return;
                    popWith('delete');
                  } finally {
                    if (context.mounted && !popped) {
                      setDialogState(() => deleteDialogOpen = false);
                    } else {
                      deleteDialogOpen = false;
                    }
                  }
                }

                void requestClose() => unawaited(
                  context
                      .findAncestorStateOfType<
                        _TimetableDialogControllerOwnerState
                      >()!
                      .requestEditorExit(),
                );
                final form = Form(
                  key: formKey,
                  child: TimetableInformationDialogSurface(
                    embedded: true,
                    onClose: requestClose,
                    closeEnabled: !blocked,
                    busy: busy,
                    title: Text(
                      creating ? l10n.createTimetable : l10n.editTimetable,
                    ),
                    form: TimetableInformationForm(
                      startDateAnchorKey: startDateAnchor,
                      periodTimeSetAnchorKey: periodTimeSetAnchor,
                      nameController: nameController,
                      weeksController: weeksController,
                      startDateLabel: formatDate(selectedStartDate),
                      periodTimeSetSummary: () {
                        final selected = student.periodTimeSetForId(
                          selectedPeriodTimeSetId,
                        );
                        return selected == null
                            ? l10n.selectPeriodTimeSet
                            : l10n.periodTimeSetSummary(
                                selected.name,
                                selected.periodTimes.length,
                              );
                      }(),
                      enabled: !blocked,
                      nameValidator: (value) => value?.trim().isEmpty ?? true
                          ? l10n.timetableNameRequired
                          : null,
                      weeksInputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final text = newValue.text;
                          if (text.isEmpty) {
                            return newValue;
                          }
                          final value = int.tryParse(text);
                          if (value == null) {
                            return oldValue;
                          }
                          final clamped = normalizeTimetableWeeks(value);
                          if (clamped == value) {
                            return newValue;
                          }
                          final clampedText = clamped.toString();
                          return TextEditingValue(
                            text: clampedText,
                            selection: TextSelection.collapsed(
                              offset: clampedText.length,
                            ),
                          );
                        }),
                      ],
                      onPickStartDate: blocked
                          ? null
                          : () async {
                              if (busy ||
                                  startDatePickerOpen ||
                                  periodTimeSetPickerOpen ||
                                  deleteDialogOpen ||
                                  popped) {
                                return;
                              }
                              final firstDate = DateTime(2020);
                              final lastDate = DateTime(2035);
                              final boundedInitialDate =
                                  selectedStartDate.isBefore(firstDate)
                                  ? firstDate
                                  : selectedStartDate.isAfter(lastDate)
                                  ? lastDate
                                  : selectedStartDate;
                              setDialogState(() => startDatePickerOpen = true);
                              try {
                                final picked = await showSkedDatePicker(
                                  context: context,
                                  workspace: AppMode.student,
                                  anchorContext: startDateAnchor.currentContext,
                                  firstDate: firstDate,
                                  lastDate: lastDate,
                                  initialDate: boundedInitialDate,
                                );
                                if (!context.mounted ||
                                    picked == null ||
                                    picked == selectedStartDate) {
                                  return;
                                }
                                setDialogState(
                                  () => selectedStartDate = picked,
                                );
                              } finally {
                                if (context.mounted) {
                                  setDialogState(
                                    () => startDatePickerOpen = false,
                                  );
                                } else {
                                  startDatePickerOpen = false;
                                }
                              }
                            },
                      onPickPeriodTimeSet: blocked
                          ? null
                          : () async {
                              if (busy ||
                                  startDatePickerOpen ||
                                  periodTimeSetPickerOpen ||
                                  deleteDialogOpen ||
                                  popped) {
                                return;
                              }
                              setDialogState(
                                () => periodTimeSetPickerOpen = true,
                              );
                              try {
                                final selected =
                                    await showPeriodTimeSetPickerDialog(
                                      context,
                                      anchorContext:
                                          periodTimeSetAnchor.currentContext,
                                      selectedPeriodTimeSetId:
                                          selectedPeriodTimeSetId,
                                    );
                                if (!context.mounted || selected == null) {
                                  return;
                                }
                                setDialogState(
                                  () => selectedPeriodTimeSetId = selected,
                                );
                              } finally {
                                if (context.mounted) {
                                  setDialogState(
                                    () => periodTimeSetPickerOpen = false,
                                  );
                                } else {
                                  periodTimeSetPickerOpen = false;
                                }
                              }
                            },
                    ),
                    editorActions: SkedEditorActions(
                      enabled: !blocked,
                      busy: busy,
                      onCancel: requestClose,
                      onSubmit: () => unawaited(saveChanges()),
                      showDelete: !creating,
                      onDelete: creating
                          ? null
                          : () => unawaited(confirmDelete()),
                    ),
                  ),
                );
                return PopScope(canPop: !blocked && !popped, child: form);
              },
            ),
          );
        },
      );
      return result != null;
    } finally {
      _setTimetableItemDialogOpen(false);
    }
  }
}

class _TimetableDialogControllerOwner extends StatefulWidget {
  const _TimetableDialogControllerOwner({
    required this.nameController,
    required this.weeksController,
    required this.fingerprint,
    required this.isBlocked,
    required this.onExit,
    required this.child,
  });

  final TextEditingController nameController;
  final TextEditingController weeksController;
  final String Function() fingerprint;
  final bool Function() isBlocked;
  final VoidCallback onExit;
  final Widget child;

  @override
  State<_TimetableDialogControllerOwner> createState() =>
      _TimetableDialogControllerOwnerState();
}

class _TimetableDialogControllerOwnerState
    extends State<_TimetableDialogControllerOwner>
    with EditorExitGuard<_TimetableDialogControllerOwner> {
  bool _exitAuthorized = false;
  @override
  String get draftFingerprint => widget.fingerprint();
  @override
  bool get exitBlocked => widget.isBlocked();
  @override
  AppMode get editorWorkspace => AppMode.student;
  @override
  void initState() {
    super.initState();
    initializeDraftGuard();
  }

  @override
  void closeEditor() {
    if (_exitAuthorized) return;
    setState(() => _exitAuthorized = true);
    widget.onExit();
  }

  @override
  void dispose() {
    widget.nameController.dispose();
    widget.weeksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _exitAuthorized,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(requestEditorExit());
    },
    child: widget.child,
  );
}
