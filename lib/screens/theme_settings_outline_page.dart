part of 'theme_settings_page.dart';

class _ThemeSettingsOutlinePage extends StatefulWidget {
  const _ThemeSettingsOutlinePage();

  @override
  State<_ThemeSettingsOutlinePage> createState() =>
      _ThemeSettingsOutlinePageState();
}

class _ThemeSettingsOutlinePageState extends State<_ThemeSettingsOutlinePage>
    with UiCommandRunner<_ThemeSettingsOutlinePage> {
  late final int _derivedThemeColorValue;
  late bool _enabled;
  late bool _followTheme;
  late int _customColorValue;
  late bool _customColorInitialized;
  late String _outlineMode;
  late double _outlineWidth;
  var _hasPopped = false;

  bool get _blocked => uiCommandBusy || _hasPopped;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TimetableProvider>();
    _derivedThemeColorValue = _derivedOutlineColorValue(
      provider.themeSeedColorValue,
    );
    _enabled = provider.liveCourseOutlineEnabled;
    _followTheme = provider.liveCourseOutlineFollowTheme;
    _customColorValue = provider.liveCourseOutlineColorValue;
    _customColorInitialized = provider.liveCourseOutlineCustomColorInitialized;
    _outlineMode = provider.liveCourseOutlineMode;
    _outlineWidth = provider.liveCourseOutlineWidth;
  }

  Future<void> _apply() async {
    if (_blocked) return;
    FocusScope.of(context).unfocus();
    final provider = context.read<TimetableProvider>();
    final saved = await runUiCommand(
      debugLabel: 'Update live course outline settings',
      command: () => provider.updateLiveCourseOutlineSettings(
        enabled: _enabled,
        followTheme: _followTheme,
        colorValue: _customColorValue,
        customColorInitialized: _customColorInitialized,
        mode: _outlineMode,
        width: _outlineWidth,
      ),
    );
    if (saved && mounted) {
      _popOnce();
    }
  }

  void _cancel() {
    if (_blocked) return;
    _popOnce();
  }

  void _popOnce() {
    if (_hasPopped) return;
    setState(() => _hasPopped = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveColorValue = _followTheme
        ? _derivedThemeColorValue
        : _customColorValue;
    return PopScope(
      canPop: !_blocked,
      child: FocusScope(
        key: const ValueKey('theme-outline-page-focus-scope'),
        canRequestFocus: !_blocked,
        descendantsAreFocusable: !_blocked,
        descendantsAreTraversable: !_blocked,
        child: Scaffold(
          key: const ValueKey('theme-outline-settings-page'),
          appBar: AppBar(
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: _blocked ? null : _cancel,
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(l10n.liveCourseOutlineSettings),
          ),
          body: Column(
            children: [
              UiCommandBusyIndicator(
                key: const ValueKey('theme-outline-page-busy-indicator'),
                semanticsKey: const ValueKey(
                  'theme-outline-page-busy-semantics',
                ),
                busy: uiCommandBusy,
              ),
              Expanded(
                child: AbsorbPointer(
                  key: const ValueKey('theme-outline-page-pointer-guard'),
                  absorbing: _blocked,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontalPadding = constraints.maxWidth < 600
                          ? 16.0
                          : 24.0;
                      return SingleChildScrollView(
                        key: const ValueKey('theme-outline-page-scroll-view'),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          24,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _PreviewBanner(
                                  title: l10n.liveCourseOutlineEffectiveColor,
                                  value:
                                      '${_formatColorHex(effectiveColorValue)} - ${l10n.liveCourseOutlineWidth} ${_formatOutlineWidthValue(context, _outlineWidth)}',
                                  preview: _OutlineColorPreview(
                                    colorValue: effectiveColorValue,
                                    borderWidth: _outlineWidth,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _SurfacePanel(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _OutlineSwitchRow(
                                        key: const ValueKey(
                                          'live-course-outline-enabled-row',
                                        ),
                                        icon: Icons.line_weight,
                                        value: _enabled,
                                        title: l10n.liveCourseOutlineEnabled,
                                        onChanged: (value) => setState(() {
                                          _enabled = value;
                                        }),
                                      ),
                                      Divider(
                                        height: 1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant
                                            .withValues(alpha: 0.4),
                                      ),
                                      _OutlineSwitchRow(
                                        key: const ValueKey(
                                          'live-course-outline-follow-theme-row',
                                        ),
                                        icon: Icons.palette_outlined,
                                        value: _followTheme,
                                        title:
                                            l10n.liveCourseOutlineFollowTheme,
                                        onChanged: (value) => setState(() {
                                          final initializingCustomColor =
                                              _followTheme &&
                                              !value &&
                                              !_customColorInitialized;
                                          _followTheme = value;
                                          if (initializingCustomColor) {
                                            _customColorValue =
                                                _derivedThemeColorValue;
                                            _customColorInitialized = true;
                                          }
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _SurfacePanel(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.liveCourseOutlineTarget,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 12),
                                      _ResponsiveSegmentedButton(
                                        key: const ValueKey(
                                          'live-course-outline-target',
                                        ),
                                        segments: [
                                          _SegmentOption(
                                            value:
                                                liveCourseOutlineModeCurrentOrNext,
                                            icon:
                                                Icons.event_available_outlined,
                                            label: l10n
                                                .liveCourseOutlineTargetCurrentOrNext,
                                          ),
                                          _SegmentOption(
                                            value:
                                                liveCourseOutlineModeAllDisplayed,
                                            icon: Icons.view_timeline_outlined,
                                            label: l10n
                                                .liveCourseOutlineTargetAllDisplayed,
                                          ),
                                        ],
                                        selected: {_outlineMode},
                                        onSelectionChanged: (selection) {
                                          if (selection.isEmpty) return;
                                          setState(() {
                                            _outlineMode = selection.first;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _SurfacePanel(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _OutlineWidthSummaryRow(
                                        width: _outlineWidth,
                                      ),
                                      Slider(
                                        key: const ValueKey(
                                          'live-course-outline-width-slider',
                                        ),
                                        value: _outlineWidth,
                                        min: minLiveCourseOutlineWidth,
                                        max: maxLiveCourseOutlineWidth,
                                        divisions: 6,
                                        label: _formatOutlineWidthValue(
                                          context,
                                          _outlineWidth,
                                        ),
                                        onChanged: (value) => setState(() {
                                          _outlineWidth = value;
                                        }),
                                      ),
                                      const SizedBox(height: 8),
                                      _ColorValueRow(
                                        title:
                                            l10n.liveCourseOutlineCustomColor,
                                        colorValue: _customColorValue,
                                        preview: _OutlineColorPreview(
                                          colorValue: _customColorValue,
                                          borderWidth: _outlineWidth,
                                        ),
                                      ),
                                      AnimatedSize(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        curve: Curves.easeInOut,
                                        alignment: Alignment.topCenter,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          switchInCurve: Curves.easeOut,
                                          switchOutCurve: Curves.easeIn,
                                          child: _followTheme
                                              ? const SizedBox.shrink(
                                                  key: ValueKey(
                                                    'outline-custom-hidden',
                                                  ),
                                                )
                                              : Padding(
                                                  key: const ValueKey(
                                                    'outline-custom-picker',
                                                  ),
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 12,
                                                      ),
                                                  child: Center(
                                                    child: _CompactColorPicker(
                                                      colorValue:
                                                          _customColorValue,
                                                      onColorChanged:
                                                          (
                                                            colorValue,
                                                          ) => setState(() {
                                                            _customColorValue =
                                                                colorValue;
                                                            _customColorInitialized =
                                                                true;
                                                          }),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _OutlineSettingsActions(
            busy: _blocked,
            onCancel: _cancel,
            onApply: () => unawaited(_apply()),
          ),
        ),
      ),
    );
  }
}

class _OutlineSettingsActions extends StatelessWidget {
  const _OutlineSettingsActions({
    required this.busy,
    required this.onCancel,
    required this.onApply,
  });

  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: AbsorbPointer(
            absorbing: busy,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 600
                    ? 16.0
                    : 24.0;
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 12,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.center,
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              key: const ValueKey('theme-outline-page-cancel'),
                              onPressed: busy ? null : onCancel,
                              child: Text(l10n.cancel),
                            ),
                            FilledButton.icon(
                              key: const ValueKey('theme-outline-page-apply'),
                              onPressed: busy ? null : onApply,
                              icon: const Icon(Icons.check),
                              label: Text(l10n.themeApplySettings),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
