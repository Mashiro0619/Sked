part of 'home_screen.dart';

extension _HomeScreenTimetableManagement on _HomeScreenState {
  Future<void> _showTimetablePicker(
    BuildContext context,
    TimetableProvider provider,
    TimetableData activeTimetable, {
    required double availableWidth,
  }) async {
    if (_timetablePickerOpen || !mounted) return;
    _setTimetablePickerOpen(true);
    try {
      final panel = _TimetablePickerPanel(
        provider: provider,
        activeTimetable: activeTimetable,
        onSwitch: (pickerContext, timetable) => _switchTimetableFromPicker(
          pickerContext,
          provider,
          activeTimetable,
          timetable,
        ),
        onEdit: (timetable) =>
            _openTimetableItemDialog(context, provider, timetable),
        onCreate: (pickerContext) =>
            _addTimetableOnce(provider, feedbackContext: pickerContext),
      );
      if (availableWidth < 720) {
        await showAppModalSheet<void>(
          context: context,
          maxWidth: appSheetWidthCompact,
          enableDrag: false,
          useSafeArea: true,
          builder: (_) => panel,
        );
      } else {
        await showExpressiveDialog<void>(
          context: context,
          builder: (_) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
    BuildContext context,
    TimetableProvider provider,
    int totalWeeks,
    int realCurrentWeek,
  ) async {
    if (_weekPickerOpen || !mounted) {
      return;
    }
    _setWeekPickerOpen(true);
    try {
      final week = await showExpressiveDialog<int>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final theme = Theme.of(context);
          final mediaQuery = MediaQuery.of(context);
          final dialogWidth = math.min(mediaQuery.size.width - 32, 360.0);
          const spacing = 10.0;
          const chipHeight = 48.0;
          final maxGridHeight = mediaQuery.size.height * 0.5;
          var popped = false;
          void popWith(int value) {
            if (popped) return;
            popped = true;
            Navigator.of(context).pop(value);
          }

          return AlertDialog(
            title: Text(l10n.jumpToWeek),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            content: SizedBox(
              width: dialogWidth,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final crossAxisCount = availableWidth >= 280 ? 4 : 3;
                  final chipWidth =
                      (availableWidth - ((crossAxisCount - 1) * spacing)) /
                      crossAxisCount;
                  final rowCount = (totalWeeks / crossAxisCount).ceil();
                  final fullGridHeight =
                      (rowCount * chipHeight) + ((rowCount - 1) * spacing);
                  final visibleRows = math.max(
                    1,
                    math.min(
                      rowCount,
                      ((maxGridHeight + spacing) / (chipHeight + spacing))
                          .floor(),
                    ),
                  );
                  final gridHeight = rowCount <= visibleRows
                      ? fullGridHeight
                      : (visibleRows * chipHeight) +
                            ((visibleRows - 1) * spacing);
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: gridHeight),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (var index = 0; index < totalWeeks; index++)
                            Builder(
                              builder: (context) {
                                final weekNumber = index + 1;
                                final isSelected =
                                    weekNumber == provider.selectedWeek;
                                final isRealCurrentWeek =
                                    weekNumber == realCurrentWeek;
                                final backgroundColor = isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      )
                                    : isRealCurrentWeek
                                    ? theme.colorScheme.surfaceContainerHighest
                                    : theme.colorScheme.surface;
                                return Semantics(
                                  key: ValueKey(
                                    'student-week-option-$weekNumber',
                                  ),
                                  button: true,
                                  selected: isSelected,
                                  label: l10n.weekLabel(weekNumber),
                                  onTap: () => popWith(weekNumber),
                                  child: ExcludeSemantics(
                                    child: SizedBox(
                                      width: chipWidth,
                                      height: chipHeight,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () => popWith(weekNumber),
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              color: backgroundColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                          .colorScheme
                                                          .outlineVariant,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$weekNumber',
                                                style:
                                                    theme.textTheme.titleMedium,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );

      if (week != null) {
        await _animateToWeek(provider, week);
      }
    } finally {
      _setWeekPickerOpen(false);
    }
  }

  Future<bool> _openTimetableItemDialog(
    BuildContext context,
    TimetableProvider provider,
    TimetableData timetable,
  ) async {
    if (_timetableItemDialogOpen || !mounted) {
      return false;
    }
    _setTimetableItemDialogOpen(true);
    final nameController = TextEditingController(text: timetable.config.name);
    final weeksController = TextEditingController(
      text: timetable.config.totalWeeks.toString(),
    );
    var selectedStartDate = timetable.config.startDate;
    var startDatePickerOpen = false;
    var busy = false;
    var deleteDialogOpen = false;
    try {
      final result = await showExpressiveDialog<String>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final viewInsets = MediaQuery.of(context).viewInsets;
          var popped = false;
          void popWith(String? value) {
            if (popped) return;
            popped = true;
            Navigator.of(context).pop(value);
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
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final blocked = busy || startDatePickerOpen || deleteDialogOpen;

                Future<void> saveChanges() async {
                  if (busy ||
                      startDatePickerOpen ||
                      deleteDialogOpen ||
                      popped) {
                    return;
                  }
                  final totalWeeks = normalizeTimetableWeeks(
                    int.tryParse(weeksController.text) ??
                        timetable.config.totalWeeks,
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
                    debugLabel: 'Update timetable',
                    command: () => provider.updateTimetableConfigFor(
                      timetable.id,
                      timetable.config.copyWith(
                        name: nameController.text.trim().isEmpty
                            ? timetable.config.name
                            : nameController.text.trim(),
                        startDate: selectedStartDate,
                        totalWeeks: totalWeeks,
                      ),
                    ),
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
                      deleteDialogOpen ||
                      popped) {
                    return;
                  }
                  setDialogState(() => deleteDialogOpen = true);
                  try {
                    final deleted = await showExpressiveDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => _DeleteTimetableConfirmationDialog(
                        provider: provider,
                        timetableId: timetable.id,
                        timetableName: timetable.config.name,
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

                return PopScope(
                  canPop: !blocked && !popped,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      viewInsets.bottom + 24,
                    ),
                    child: Center(
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 6,
                        borderRadius: BorderRadius.circular(28),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    24,
                                    24,
                                    0,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      UiCommandBusyIndicator(busy: busy),
                                      const SizedBox(height: 16),
                                      Text(
                                        l10n.timetable,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall,
                                      ),
                                      const SizedBox(height: 24),
                                      TextField(
                                        controller: nameController,
                                        enabled: !blocked,
                                        decoration: InputDecoration(
                                          labelText: l10n.timetableName,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: weeksController,
                                        enabled: !blocked,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          TextInputFormatter.withFunction((
                                            oldValue,
                                            newValue,
                                          ) {
                                            final text = newValue.text;
                                            if (text.isEmpty) {
                                              return newValue;
                                            }
                                            final value = int.tryParse(text);
                                            if (value == null) {
                                              return oldValue;
                                            }
                                            final clamped =
                                                normalizeTimetableWeeks(value);
                                            if (clamped == value) {
                                              return newValue;
                                            }
                                            final clampedText = clamped
                                                .toString();
                                            return TextEditingValue(
                                              text: clampedText,
                                              selection:
                                                  TextSelection.collapsed(
                                                    offset: clampedText.length,
                                                  ),
                                            );
                                          }),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: l10n.totalWeeks,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _TimetableStartDateTile(
                                  title: l10n.semesterStartDate,
                                  dateLabel: formatDate(selectedStartDate),
                                  enabled: !blocked,
                                  onTap: blocked
                                      ? null
                                      : () async {
                                          if (busy ||
                                              startDatePickerOpen ||
                                              deleteDialogOpen ||
                                              popped) {
                                            return;
                                          }
                                          final firstDate = DateTime(2020);
                                          final lastDate = DateTime(2035);
                                          final boundedInitialDate =
                                              selectedStartDate.isBefore(
                                                firstDate,
                                              )
                                              ? firstDate
                                              : selectedStartDate.isAfter(
                                                  lastDate,
                                                )
                                              ? lastDate
                                              : selectedStartDate;
                                          setDialogState(
                                            () => startDatePickerOpen = true,
                                          );
                                          try {
                                            final picked = await showDatePicker(
                                              context: context,
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
                                                () =>
                                                    startDatePickerOpen = false,
                                              );
                                            } else {
                                              startDatePickerOpen = false;
                                            }
                                          }
                                        },
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    24,
                                    24,
                                    24,
                                  ),
                                  child: ExpressiveActionArea(
                                    leading: TextButton(
                                      onPressed: blocked
                                          ? null
                                          : () => unawaited(confirmDelete()),
                                      child: Text(l10n.delete),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: blocked
                                            ? null
                                            : () => popWith(null),
                                        child: Text(l10n.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: blocked
                                            ? null
                                            : () => unawaited(saveChanges()),
                                        child: Text(l10n.save),
                                      ),
                                    ],
                                  ),
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
    required this.child,
  });

  final TextEditingController nameController;
  final TextEditingController weeksController;
  final Widget child;

  @override
  State<_TimetableDialogControllerOwner> createState() =>
      _TimetableDialogControllerOwnerState();
}

class _TimetableDialogControllerOwnerState
    extends State<_TimetableDialogControllerOwner> {
  @override
  void dispose() {
    widget.nameController.dispose();
    widget.weeksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DeleteTimetableConfirmationDialog extends StatefulWidget {
  const _DeleteTimetableConfirmationDialog({
    required this.provider,
    required this.timetableId,
    required this.timetableName,
  });

  final TimetableProvider provider;
  final String timetableId;
  final String timetableName;

  @override
  State<_DeleteTimetableConfirmationDialog> createState() =>
      _DeleteTimetableConfirmationDialogState();
}

class _DeleteTimetableConfirmationDialogState
    extends State<_DeleteTimetableConfirmationDialog> {
  var _busy = false;
  var _popped = false;

  Future<void> _delete() async {
    if (_busy || _popped) return;
    setState(() => _busy = true);
    final deleted = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Delete timetable',
      command: () => widget.provider.deleteTimetable(widget.timetableId),
    );
    if (!mounted) return;
    if (deleted) {
      _popped = true;
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  void _cancel() {
    if (_busy || _popped) return;
    _popped = true;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy && !_popped,
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            UiCommandBusyIndicator(busy: _busy),
            const SizedBox(height: 16),
            Text(l10n.deleteTimetableTitle),
          ],
        ),
        content: Text(l10n.deleteTimetableMessage(widget.timetableName)),
        actions: [
          TextButton(
            onPressed: _busy ? null : _cancel,
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _busy ? null : () => unawaited(_delete()),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _TimetableStartDateTile extends StatelessWidget {
  const _TimetableStartDateTile({
    required this.title,
    required this.dateLabel,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String dateLabel;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final contentColor = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.calendar_month_outlined, color: secondaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: contentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.calendar_month, color: secondaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
