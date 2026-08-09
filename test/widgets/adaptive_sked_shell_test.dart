import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/main.dart' show MyApp;
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/theme/app_theme.dart';

class _MemoryStorage implements TimetableStorage {
  _MemoryStorage(this.data);

  AppData? data;
  int saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://adaptive-shell';
}

class _BlockingStorage extends _MemoryStorage {
  _BlockingStorage(super.data, {this.fail = false});

  final firstSaveStarted = Completer<void>();
  final _allowSave = Completer<void>();
  final bool fail;

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    this.data = data;
    if (saveCount == 1) {
      firstSaveStarted.complete();
      await _allowSave.future;
      if (fail) throw StateError('workspace save failed');
    }
  }

  void completeSave() {
    if (!_allowSave.isCompleted) _allowSave.complete();
  }
}

AppData _shellData({AppMode mode = AppMode.student, bool populated = false}) {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: defaultLocaleCode,
  );
  if (!populated) {
    return initial.copyWith(
      activeMode: mode,
      privacyPolicyAcceptedVersion: bundledPrivacyPolicyVersion,
      privacyPolicyAcceptedAtIso: '2026-01-01T00:00:00.000',
    );
  }
  final timetable = TimetableData(
    id: 'adaptive-table',
    config: TimetableConfig(
      name: 'Adaptive timetable',
      startDate: DateTime(2026, 1, 5),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: const [],
  );
  return initial.copyWith(
    activeMode: mode,
    privacyPolicyAcceptedVersion: bundledPrivacyPolicyVersion,
    privacyPolicyAcceptedAtIso: '2026-01-01T00:00:00.000',
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: timetable.id,
      timetables: [timetable],
    ),
  );
}

Future<TimetableProvider> _providerFor(
  TimetableStorage storage, {
  AppMode mode = AppMode.student,
}) async {
  final provider = TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => defaultLocaleCode,
    uiStateSaveDelay: Duration.zero,
  );
  await provider.load();
  if (provider.activeMode != mode) await provider.switchMode(mode);
  return provider;
}

Widget _appFor(
  TimetableProvider provider, {
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  VoidCallback? onOpenSettings,
}) {
  return ChangeNotifierProvider<TimetableProvider>.value(
    value: provider,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
        themeColorMode: themeColorModeSingle,
        colorfulUiColorValues: const {},
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            disableAnimations: disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Selector<TimetableProvider, AppMode>(
        selector: (_, provider) => provider.activeMode,
        builder: (context, mode, child) => AdaptiveSkedShell(
          key: const ValueKey('adaptive-shell-test'),
          provider: context.read<TimetableProvider>(),
          activeMode: mode,
          onOpenSettings: () async => onOpenSettings?.call(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('adaptive shell uses the planned navigation breakpoints', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);

    Future<void> expectNavigation(
      double width,
      Finder expected, {
      bool? railExtended,
    }) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_appFor(provider));
      await tester.pumpAndSettle();
      expect(expected, findsOneWidget);
      if (railExtended != null) {
        expect(tester.widget<NavigationRail>(expected).extended, railExtended);
      }
      expect(tester.takeException(), isNull);
    }

    await expectNavigation(
      599,
      find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
    );
    await expectNavigation(
      600,
      find.byKey(const ValueKey('adaptive-shell-navigation-rail')),
      railExtended: false,
    );
    await expectNavigation(
      839,
      find.byKey(const ValueKey('adaptive-shell-navigation-rail')),
      railExtended: false,
    );
    await expectNavigation(
      840,
      find.byKey(const ValueKey('adaptive-shell-navigation-rail')),
      railExtended: true,
    );
    await expectNavigation(
      1199,
      find.byKey(const ValueKey('adaptive-shell-navigation-rail')),
      railExtended: true,
    );
    await expectNavigation(
      1200,
      find.byKey(const ValueKey('adaptive-shell-navigation-drawer')),
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('navigation keyboard focus survives adaptive layout changes', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(599, 800));
    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();

    FocusScopeNode navigationScope() =>
        tester
                .widget<FocusScope>(
                  find.byKey(
                    const ValueKey('adaptive-navigation-focus-bridge'),
                  ),
                )
                .focusNode!
            as FocusScopeNode;

    final initialScope = navigationScope();
    final firstDestination = initialScope.traversalDescendants.firstWhere(
      (node) => node.canRequestFocus,
    );
    firstDestination.requestFocus();
    await tester.pump();
    expect(firstDestination.hasFocus, isTrue);

    for (final width in [600.0, 840.0, 1200.0, 599.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpAndSettle();
      final scope = navigationScope();
      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(identical(scope, initialScope), isTrue);
      expect(
        scope.hasFocus,
        isTrue,
        reason: 'navigation focus should survive the ${width}px layout',
      );
      expect(primaryFocus, isNotNull);
      expect(
        identical(primaryFocus, scope) ||
            primaryFocus!.ancestors.contains(scope),
        isTrue,
      );
    }
  });

  testWidgets('global settings focus node moves between compact and wide UI', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(599, 800));
    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();

    final compactSettings = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.settings_outlined),
        matching: find.byType(IconButton),
      ),
    );
    final settingsFocusNode = compactSettings.focusNode!;
    settingsFocusNode.requestFocus();
    await tester.pump();
    expect(settingsFocusNode.hasFocus, isTrue);

    for (final width in [600.0, 840.0, 1200.0, 599.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpAndSettle();
      expect(settingsFocusNode.context, isNotNull);
      expect(
        settingsFocusNode.hasFocus,
        isTrue,
        reason: 'settings focus should survive the ${width}px layout',
      );
    }
  });

  testWidgets('empty timetable does not queue a future shortcut focus steal', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(430, 776));
    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('student-week-pager')), findsNothing);
    final settingsFocusNode = tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.settings_outlined),
            matching: find.byType(IconButton),
          ),
        )
        .focusNode!;
    settingsFocusNode.requestFocus();
    await tester.pump();
    expect(settingsFocusNode.hasFocus, isTrue);

    await provider.addTimetable();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('student-week-pager')), findsOneWidget);
    expect(settingsFocusNode.hasFocus, isTrue);
  });

  testWidgets(
    'both workspaces remain equally visible and only active is live',
    (tester) async {
      final provider = await _providerFor(_MemoryStorage(_shellData()));
      addTearDown(provider.dispose);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_appFor(provider));
      await tester.pumpAndSettle();

      expect(find.text('Student timetable'), findsOneWidget);
      expect(find.text('General schedule'), findsOneWidget);
      expect(
        tester
            .widget<NavigationBar>(
              find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
            )
            .selectedIndex,
        0,
      );

      void expectSlotState(
        int index, {
        required bool tickerEnabled,
        required bool semanticsExcluded,
        required bool inputIgnored,
      }) {
        expect(
          tester
              .widget<TickerMode>(
                find.byKey(
                  ValueKey('adaptive-workspace-ticker-$index'),
                  skipOffstage: false,
                ),
              )
              .enabled,
          tickerEnabled,
        );
        expect(
          tester
              .widget<ExcludeSemantics>(
                find.byKey(
                  ValueKey('adaptive-workspace-semantics-$index'),
                  skipOffstage: false,
                ),
              )
              .excluding,
          semanticsExcluded,
        );
        expect(
          tester
              .widget<IgnorePointer>(
                find.byKey(
                  ValueKey('adaptive-workspace-input-$index'),
                  skipOffstage: false,
                ),
              )
              .ignoring,
          inputIgnored,
        );
      }

      expectSlotState(
        0,
        tickerEnabled: true,
        semanticsExcluded: false,
        inputIgnored: false,
      );
      expectSlotState(
        1,
        tickerEnabled: false,
        semanticsExcluded: true,
        inputIgnored: true,
      );

      await tester.tap(find.text('General schedule'));
      await tester.pumpAndSettle();
      expect(provider.isGeneralMode, isTrue);
      expect(
        tester
            .widget<NavigationBar>(
              find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
            )
            .selectedIndex,
        1,
      );
      expectSlotState(
        0,
        tickerEnabled: false,
        semanticsExcluded: true,
        inputIgnored: true,
      );
      expectSlotState(
        1,
        tickerEnabled: true,
        semanticsExcluded: false,
        inputIgnored: false,
      );
      expect(find.byTooltip('Settings'), findsOneWidget);
    },
  );

  testWidgets(
    'workspace switch fades through fixed slots and reverses without remounting',
    (tester) async {
      final provider = await _providerFor(_MemoryStorage(_shellData()));
      addTearDown(provider.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_appFor(provider));
      await tester.pumpAndSettle();

      final transitionOpacity = find.byKey(
        const ValueKey('adaptive-workspace-transition-opacity'),
      );
      final stack = find.byKey(const ValueKey('adaptive-workspace-stack'));
      final studentSlot = find.byKey(
        const ValueKey('adaptive-workspace-slot-0'),
        skipOffstage: false,
      );
      final generalSlot = find.byKey(
        const ValueKey('adaptive-workspace-slot-1'),
        skipOffstage: false,
      );
      expect(transitionOpacity, findsOneWidget);
      expect(stack, findsOneWidget);
      expect(studentSlot, findsOneWidget);
      expect(generalSlot, findsOneWidget);

      await tester.tap(find.text('General schedule'));
      await tester.pump();
      expect(tester.widget<IndexedStack>(stack).index, 0);

      // The paint index switches after the outgoing fade and both keyed
      // workspace states remain mounted in the persistent IndexedStack.
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<IndexedStack>(stack).index, 1);
      expect(tester.widget<Opacity>(transitionOpacity).opacity, greaterThan(0));

      // Reverse before completion. The same two slots are reused and the
      // committed student workspace is restored without creating a third one.
      await tester.tap(find.text('Student timetable'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        find.byKey(
          const ValueKey('adaptive-workspace-slot-0'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('adaptive-workspace-slot-1'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(stack).index, 0);
      expect(
        tester.widget<Opacity>(transitionOpacity).opacity,
        closeTo(1, 0.001),
      );
    },
  );

  testWidgets('fade-through scale remains continuous when direction reverses', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();

    double transitionScale() => tester
        .widget<Transform>(
          find.byKey(const ValueKey('adaptive-workspace-transition-scale')),
        )
        .transform
        .getMaxScaleOnAxis();

    for (final elapsed in [
      const Duration(milliseconds: 60),
      const Duration(milliseconds: 120),
    ]) {
      await tester.tap(find.text('General schedule'));
      await tester.pump();
      await tester.pump(elapsed);
      final beforeReverse = transitionScale();

      await tester.tap(find.text('Student timetable'));
      await tester.pump();
      expect(transitionScale(), closeTo(beforeReverse, 0.0001));
      await tester.pumpAndSettle();
      expect(provider.activeMode, AppMode.student);
    }
  });

  testWidgets('workspace switch honors disabled animations', (tester) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(_appFor(provider, disableAnimations: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General schedule'));
    await tester.pump();

    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('adaptive-workspace-transition-opacity')),
          )
          .opacity,
      closeTo(1, 0.001),
    );
    expect(
      tester
          .widget<IndexedStack>(
            find.byKey(const ValueKey('adaptive-workspace-stack')),
          )
          .index,
      1,
    );
  });

  testWidgets('general workspace view state survives a mode round trip', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(430, 776));

    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Month'));
    await tester.pumpAndSettle();

    SegmentedButton<String> viewSelector() =>
        tester.widget(find.byType(SegmentedButton<String>));
    expect(viewSelector().selected, {generalViewMonth});

    await tester.tap(find.text('Student timetable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General schedule'));
    await tester.pumpAndSettle();

    expect(viewSelector().selected, {generalViewMonth});
    expect(
      find.byKey(const ValueKey('student-home'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('general-home'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets(
    'student week pager and keyboard shortcuts survive a mode round trip',
    (tester) async {
      final provider = await _providerFor(
        _MemoryStorage(_shellData(populated: true)),
      );
      addTearDown(provider.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await provider.setSelectedWeek(2);
      await tester.binding.setSurfaceSize(const Size(430, 776));

      await tester.pumpWidget(_appFor(provider));
      await tester.pumpAndSettle();

      final pager = find.byKey(
        const ValueKey('student-week-pager'),
        skipOffstage: false,
      );
      expect(pager, findsOneWidget);
      final initialPagerElement = tester.element(pager);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(provider.selectedWeek, 3);

      await tester.tap(find.text('General schedule'));
      await tester.pumpAndSettle();
      expect(identical(tester.element(pager), initialPagerElement), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(provider.selectedWeek, 3);

      await tester.tap(find.text('Student timetable'));
      await tester.pumpAndSettle();
      expect(provider.activeMode, AppMode.student);
      expect(
        tester
            .widget<NavigationBar>(
              find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
            )
            .selectedIndex,
        0,
      );
      expect(identical(tester.element(pager), initialPagerElement), isTrue);
      expect(
        tester
            .widget<IndexedStack>(
              find.byKey(const ValueKey('adaptive-workspace-stack')),
            )
            .index,
        0,
      );
      final shortcutFocus = tester
          .widgetList<Focus>(find.byType(Focus, skipOffstage: false))
          .singleWhere(
            (widget) =>
                widget.focusNode?.debugLabel ==
                'Student timetable week shortcuts',
          );
      expect(shortcutFocus.canRequestFocus, isTrue);
      expect(shortcutFocus.focusNode?.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(provider.selectedWeek, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('workspace state survives every adaptive navigation breakpoint', (
    tester,
  ) async {
    final storage = _MemoryStorage(_shellData());
    final provider = await _providerFor(storage);
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(599, 800));

    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Month'));
    await tester.pumpAndSettle();
    final saveCountBeforeResize = storage.saveCount;

    SegmentedButton<String> viewSelector() =>
        tester.widget(find.byType(SegmentedButton<String>));
    expect(viewSelector().selected, {generalViewMonth});

    for (final width in [600.0, 840.0, 1200.0, 599.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpAndSettle();
      expect(viewSelector().selected, {generalViewMonth});
      expect(
        find.byKey(const ValueKey('general-home'), skipOffstage: false),
        findsOneWidget,
      );
      expect(storage.saveCount, saveCountBeforeResize);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'incoming workspace becomes active only after it starts painting',
    (tester) async {
      final provider = await _providerFor(_MemoryStorage(_shellData()));
      addTearDown(provider.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_appFor(provider));
      await tester.pumpAndSettle();
      await tester.tap(find.text('General schedule'));
      await tester.pump();

      HomeScreen student() => tester.widget(
        find.byKey(const ValueKey('student-home'), skipOffstage: false),
      );
      GeneralScheduleHomeScreen general() => tester.widget(
        find.byKey(const ValueKey('general-home'), skipOffstage: false),
      );

      expect(student().active, isFalse);
      expect(general().active, isFalse);
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester
            .widget<Opacity>(
              find.byKey(
                const ValueKey('adaptive-workspace-transition-opacity'),
              ),
            )
            .opacity,
        greaterThan(0),
      );
      expect(general().active, isTrue);
    },
  );

  testWidgets('mode switching keeps the committed workspace while saving', (
    tester,
  ) async {
    final storage = _BlockingStorage(_shellData());
    final provider = await _providerFor(storage);
    var settingsCalls = 0;
    addTearDown(provider.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _appFor(provider, onOpenSettings: () => settingsCalls += 1),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('General schedule'));
    await storage.firstSaveStarted.future;
    await tester.pump();

    // The provider keeps the previously committed mode visible until the
    // pending snapshot has been accepted by storage.
    expect(provider.activeMode, AppMode.student);
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
          )
          .selectedIndex,
      0,
    );
    expect(find.byKey(const ValueKey('workspace-switch-busy')), findsOneWidget);
    expect(
      tester
          .widget<HomeScreen>(
            find.byKey(const ValueKey('student-home'), skipOffstage: false),
          )
          .active,
      isFalse,
    );
    expect(
      tester
          .widget<HomeScreen>(
            find.byKey(const ValueKey('student-home'), skipOffstage: false),
          )
          .interactive,
      isFalse,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find.byKey(const ValueKey('adaptive-workspace-semantics-0')),
          )
          .excluding,
      isFalse,
    );
    expect(
      tester
          .widget<TickerMode>(
            find.byKey(const ValueKey('adaptive-workspace-ticker-0')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const ValueKey('adaptive-workspace-input-0')),
          )
          .ignoring,
      isTrue,
    );

    // An unrelated provider notification must not expose the provider's
    // optimistic mode before the persistence command has completed.
    provider.notifyListeners();
    await tester.pump();
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
          )
          .selectedIndex,
      0,
    );

    await tester.tap(find.byTooltip('Settings'), warnIfMissed: false);
    await tester.pump();
    expect(settingsCalls, 0);

    await tester.tap(find.text('General schedule'), warnIfMissed: false);
    expect(storage.saveCount, 1);

    storage.completeSave();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
          )
          .selectedIndex,
      1,
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    expect(settingsCalls, 1);
  });

  testWidgets('pending mode save freezes general pager date writes', (
    tester,
  ) async {
    final storage = _BlockingStorage(_shellData(mode: AppMode.general));
    final provider = await _providerFor(storage, mode: AppMode.general);
    addTearDown(() {
      storage.completeSave();
      provider.dispose();
    });
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();
    final pagerFinder = find.byKey(
      const ValueKey<String>('general-week-pager'),
    );
    final initialPager = tester.widget<PageView>(pagerFinder);
    final nextPage = initialPager.controller!.page!.round() + 1;
    final initialDate = provider.selectedGeneralDate;

    await tester.tap(find.text('Student timetable'));
    await storage.firstSaveStarted.future;
    await tester.pump();

    expect(
      tester
          .widget<GeneralScheduleHomeScreen>(
            find.byKey(const ValueKey('general-home'), skipOffstage: false),
          )
          .active,
      isFalse,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find.byKey(const ValueKey('adaptive-workspace-semantics-1')),
          )
          .excluding,
      isFalse,
    );
    expect(
      tester
          .widget<TickerMode>(
            find.byKey(const ValueKey('adaptive-workspace-ticker-1')),
          )
          .enabled,
      isFalse,
    );

    tester.widget<PageView>(pagerFinder).onPageChanged!(nextPage);
    await tester.pump();
    expect(provider.selectedGeneralDate, initialDate);

    storage.completeSave();
    await tester.pumpAndSettle();
    expect(provider.activeMode, AppMode.student);
  });

  testWidgets('MyApp keeps the committed theme during a pending mode save', (
    tester,
  ) async {
    final base = _shellData().copyWith(
      studentMode: _shellData().studentMode.copyWith(
        themeMode: 'dark',
        themeSeedColorValue: 0xFF112233,
      ),
      generalMode: _shellData().generalMode.copyWith(
        themeMode: 'light',
        themeSeedColorValue: 0xFF445566,
      ),
    );
    final storage = _BlockingStorage(base);
    final provider = await _providerFor(storage);
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(MyApp(provider: provider));
    await tester.pumpAndSettle();
    MaterialApp materialApp() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp().themeMode, ThemeMode.dark);
    final modeSave = provider.switchMode(AppMode.general);
    await storage.firstSaveStarted.future;
    await tester.pump();
    expect(materialApp().themeMode, ThemeMode.dark);
    provider.notifyListeners();
    await tester.pump();
    expect(materialApp().themeMode, ThemeMode.dark);

    storage.completeSave();
    await modeSave;
    await tester.pumpAndSettle();
    expect(materialApp().themeMode, ThemeMode.light);
    expect(materialApp().theme!.colorScheme.primary, const Color(0xFF445566));
    expect(
      materialApp().darkTheme!.colorScheme.primary,
      const Color(0xFF445566),
    );
  });

  testWidgets('settings is a single global action on expanded layouts', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);

    for (final width in [600.0, 840.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_appFor(provider));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('workspace switch closes the nested timetable drawer', (
    tester,
  ) async {
    final provider = await _providerFor(
      _MemoryStorage(_shellData(populated: true)),
    );
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 800));

    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.tap(find.text('General schedule'));
    await tester.pumpAndSettle();
    expect(provider.activeMode, AppMode.general);

    await tester.tap(find.text('Student timetable'));
    await tester.pumpAndSettle();
    expect(provider.activeMode, AppMode.student);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('failed mode save keeps the committed workspace selected', (
    tester,
  ) async {
    final storage = _BlockingStorage(_shellData(), fail: true);
    final provider = await _providerFor(storage);
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('General schedule'));
    await storage.firstSaveStarted.future;
    provider.notifyListeners();
    await tester.pump();
    storage.completeSave();
    await tester.pumpAndSettle();

    expect(provider.activeMode, AppMode.student);
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
          )
          .selectedIndex,
      0,
    );
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('compact navigation remains usable with RTL large text', (
    tester,
  ) async {
    final provider = await _providerFor(
      _MemoryStorage(_shellData(populated: true)),
    );
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));

    await tester.pumpWidget(
      _appFor(
        provider,
        locale: const Locale('ar'),
        textScaler: const TextScaler.linear(1.8),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact rail scrolls on short large-text windows', (
    tester,
  ) async {
    final provider = await _providerFor(
      _MemoryStorage(_shellData(populated: true)),
    );
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(600, 360));

    await tester.pumpWidget(
      _appFor(
        provider,
        locale: const Locale('ar'),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('adaptive-shell-navigation-rail')),
    );
    expect(rail.scrollable, isTrue);
    expect(tester.takeException(), isNull);
  });
}
