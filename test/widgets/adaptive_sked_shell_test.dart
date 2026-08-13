import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
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
  EdgeInsets safePadding = EdgeInsets.zero,
  bool disableAnimations = false,
  VoidCallback? onOpenSettings,
}) {
  return ChangeNotifierProvider<TimetableProvider>.value(
    value: provider,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
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
            padding: safePadding,
            viewPadding: safePadding,
            disableAnimations: disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Selector<TimetableProvider, (AppMode, bool)>(
        selector: (_, provider) =>
            (provider.activeMode, provider.hideHomeWorkspaceNavigation),
        builder: (context, snapshot, child) => AdaptiveSkedShell(
          key: const ValueKey('adaptive-shell-test'),
          provider: context.read<TimetableProvider>(),
          activeMode: snapshot.$1,
          onOpenSettings: () async => onOpenSettings?.call(),
        ),
      ),
    ),
  );
}

NavigationIndicator _navigationIndicator(
  WidgetTester tester,
  String destinationKey,
) {
  final indicator = find.descendant(
    of: find.byKey(ValueKey(destinationKey)),
    matching: find.byType(NavigationIndicator),
  );
  return tester.widget<NavigationIndicator>(indicator);
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
      find.byKey(const ValueKey('adaptive-shell-navigation-drawer')),
    );
    await expectNavigation(
      1199,
      find.byKey(const ValueKey('adaptive-shell-navigation-drawer')),
    );
    await expectNavigation(
      1200,
      find.byKey(const ValueKey('adaptive-shell-navigation-drawer')),
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('permanent drawer anchors settings above the bottom safe area', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [840.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(
        _appFor(provider, safePadding: const EdgeInsets.only(bottom: 24)),
      );
      await tester.pumpAndSettle();

      final drawer = find.byKey(
        const ValueKey('adaptive-shell-navigation-drawer'),
      );
      final settings = find.byKey(
        const ValueKey('adaptive-shell-settings-action'),
      );
      final destinations = find.descendant(
        of: drawer,
        matching: find.byType(NavigationDrawerDestination),
      );
      final drawerRect = tester.getRect(drawer);
      final settingsRect = tester.getRect(settings);

      expect(destinations, findsNWidgets(2));
      expect(settingsRect.top, greaterThan(drawerRect.center.dy));
      expect(drawerRect.bottom - settingsRect.bottom, closeTo(36, 0.01));
      expect(
        tester.getRect(destinations.last).bottom,
        lessThan(settingsRect.top),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('permanent drawer aligns its brand icon and title', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();

    final icon = tester.getRect(
      find.byKey(const ValueKey('adaptive-shell-drawer-brand-icon')),
    );
    final title = tester.getRect(
      find.byKey(const ValueKey('adaptive-shell-drawer-brand-title')),
    );
    expect(icon.center.dy, closeTo(title.center.dy, 0.01));
    expect(icon.height, 32);
    expect(title.height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expanded workspace navigation replaces the empty timetable header',
    (tester) async {
      final provider = await _providerFor(_MemoryStorage(_shellData()));
      addTearDown(provider.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final width in [600.0, 840.0, 1200.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(_appFor(provider));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('student-workspace-toolbar')),
          findsNothing,
          reason: '${width}px',
        );
        expect(find.text('No timetable yet'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '${width}px');
      }

      await provider.updateHideHomeWorkspaceNavigation(true);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('student-workspace-toolbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('empty-timetable-settings-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short large-text drawer keeps settings reachable', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(840, 360));
    await tester.pumpWidget(
      _appFor(
        provider,
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    final drawer = find.byKey(
      const ValueKey('adaptive-shell-navigation-drawer'),
    );
    final settings = find.byKey(
      const ValueKey('adaptive-shell-settings-action'),
    );
    final drawerRect = tester.getRect(drawer);
    final settingsRect = tester.getRect(settings);

    expect(
      find.descendant(of: drawer, matching: find.byType(ListView)),
      findsOneWidget,
    );
    expect(settingsRect.top, greaterThanOrEqualTo(drawerRect.top));
    expect(settingsRect.bottom, lessThanOrEqualTo(drawerRect.bottom));
    expect(settingsRect.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden workspace navigation removes every adaptive navigation variant',
    (tester) async {
      final provider = await _providerFor(
        _MemoryStorage(
          _shellData(populated: true)
              .copyWith(hideHomeWorkspaceNavigation: true),
        ),
      );
      addTearDown(provider.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final width in [390.0, 600.0, 840.0, 1200.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(_appFor(provider));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('adaptive-shell-navigation-rail')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('adaptive-shell-navigation-drawer')),
          findsNothing,
        );
        final toolbar = tester.getRect(
          find.byKey(const ValueKey('student-workspace-toolbar')),
        );
        final settings = tester.getRect(
          find.byKey(const ValueKey('student-settings-button')),
        );
        final expectedTrailingInset = width < 600 ? 8.0 : 16.0;
        expect(
          toolbar.right - settings.right,
          closeTo(expectedTrailingInset, 0.01),
        );
        expect(
          settings.left,
          greaterThan(
            tester
                .getRect(
                  find.byKey(const ValueKey('student-view-toggle-button')),
                )
                .left,
          ),
        );
        expect(settings.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull, reason: '${width}px');
      }
    },
  );

  testWidgets(
    'hidden workspace navigation exposes settings in the general toolbar',
    (tester) async {
      var settingsCalls = 0;
      final provider = await _providerFor(
        _MemoryStorage(
          _shellData(mode: AppMode.general)
              .copyWith(hideHomeWorkspaceNavigation: true),
        ),
        mode: AppMode.general,
      );
      addTearDown(provider.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        _appFor(provider, onOpenSettings: () => settingsCalls += 1),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-shell-navigation-drawer')),
        findsNothing,
      );
      final toolbar = tester.getRect(
        find.byKey(const ValueKey('general-workspace-toolbar')),
      );
      final settingsFinder = find.byKey(
        const ValueKey('general-settings-button'),
      );
      final settings = tester.getRect(settingsFinder);
      expect(toolbar.right - settings.right, closeTo(12, 0.01));
      expect(settings.height, greaterThanOrEqualTo(48));

      await tester.tap(settingsFinder);
      await tester.pumpAndSettle();
      expect(settingsCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'workspace navigation visibility changes live and preserves settings focus',
    (tester) async {
      final provider = await _providerFor(
        _MemoryStorage(_shellData(populated: true)),
      );
      addTearDown(provider.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(840, 800));
      await tester.pumpWidget(_appFor(provider));
      await tester.pumpAndSettle();

      final drawerSettings = tester.widget<ListTile>(
        find.byKey(const ValueKey('adaptive-shell-settings-action')),
      );
      final settingsFocusNode = drawerSettings.focusNode!;
      settingsFocusNode.requestFocus();
      await tester.pump();
      expect(settingsFocusNode.hasFocus, isTrue);

      await provider.updateHideHomeWorkspaceNavigation(true);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-shell-navigation-drawer')),
        findsNothing,
      );
      final toolbarSettings = tester.widget<IconButton>(
        find.byKey(const ValueKey('student-settings-button')),
      );
      expect(toolbarSettings.focusNode, same(settingsFocusNode));
      expect(settingsFocusNode.hasFocus, isTrue);

      await provider.updateHideHomeWorkspaceNavigation(false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-shell-navigation-drawer')),
        findsOneWidget,
      );
      final restoredDrawerSettings = tester.widget<ListTile>(
        find.byKey(const ValueKey('adaptive-shell-settings-action')),
      );
      expect(restoredDrawerSettings.focusNode, same(settingsFocusNode));
      expect(settingsFocusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

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

    await provider.addTimetable(
      TimetableConfig(
        name: 'Added timetable',
        startDate: DateTime(2026, 8, 13),
        totalWeeks: 18,
        periodTimeSetId: provider.activePeriodTimeSet.id,
      ),
    );
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

  testWidgets('official compact indicator follows the committed workspace', (
    tester,
  ) async {
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(430, 776));
    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationIndicator), findsNWidgets(2));
    final navigationBar = find.byKey(
      const ValueKey('adaptive-shell-navigation-bar'),
    );
    final initialIndicator = _navigationIndicator(
      tester,
      'adaptive-shell-student-destination',
    );
    expect(tester.widget<NavigationBar>(navigationBar).selectedIndex, 0);
    expect(initialIndicator.animation.value, 1);
    expect(
      _navigationIndicator(
        tester,
        'adaptive-shell-general-destination',
      ).animation.value,
      0,
    );

    await tester.tap(find.text('General schedule'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    final settledIndicator = _navigationIndicator(
      tester,
      'adaptive-shell-general-destination',
    );

    expect(tester.widget<NavigationBar>(navigationBar).selectedIndex, 1);
    expect(settledIndicator.animation.value, 1);
    expect(
      _navigationIndicator(
        tester,
        'adaptive-shell-student-destination',
      ).animation.value,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'official compact navigation remains usable on a large-text phone',
    (tester) async {
      final provider = await _providerFor(_MemoryStorage(_shellData()));
      addTearDown(provider.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 568));
      await tester.pumpWidget(
        _appFor(provider, textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();

      final indicator = _navigationIndicator(
        tester,
        'adaptive-shell-student-destination',
      );
      final navigationBar = tester.getRect(
        find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
      );
      expect(
        tester
            .widget<NavigationBar>(
              find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
            )
            .height,
        80,
      );
      for (final (destinationKey, labelText) in const [
        ('adaptive-shell-student-destination', 'Student timetable'),
        ('adaptive-shell-general-destination', 'General schedule'),
      ]) {
        final label = find.descendant(
          of: find.byKey(ValueKey(destinationKey)),
          matching: find.text(labelText),
        );
        final effectiveTextScale =
            MediaQuery.textScalerOf(tester.element(label)).scale(16) / 16;
        expect(label, findsOneWidget);
        expect(effectiveTextScale, lessThanOrEqualTo(1.3));
      }
      expect(indicator.animation.value, 1);
      expect(navigationBar.height, 80);
      expect(navigationBar.bottom, closeTo(568, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact navigation consumes the Android bottom inset once', (
    tester,
  ) async {
    final provider = await _providerFor(
      _MemoryStorage(_shellData(populated: true)),
    );
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _appFor(
        provider,
        textScaler: const TextScaler.linear(2),
        safePadding: const EdgeInsets.only(top: 24, bottom: 24),
      ),
    );
    await tester.pumpAndSettle();

    final navigationFinder = find.byKey(
      const ValueKey('adaptive-shell-navigation-bar'),
    );
    final navigationRect = tester.getRect(navigationFinder);
    final pagerRect = tester.getRect(
      find.byKey(const ValueKey('student-week-pager')),
    );
    final timetableGridFinder = find.byKey(
      ValueKey('student-timetable-grid-${provider.selectedWeek}'),
    );
    expect(timetableGridFinder, findsOneWidget);
    final timetableGridRect = tester.getRect(timetableGridFinder);

    expect(tester.widget<NavigationBar>(navigationFinder).height, 80);
    expect(navigationRect.height, closeTo(104, 0.01));
    expect(navigationRect.bottom, closeTo(844, 0.01));
    expect(pagerRect.bottom, closeTo(navigationRect.top, 0.01));
    expect(timetableGridRect.bottom, closeTo(navigationRect.top, 0.01));
    expect(find.byKey(const ValueKey('workspace-switch-busy')), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
          )
          .animationDuration,
      Duration.zero,
    );
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

  testWidgets('compact navigation honors reduced motion', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final provider = await _providerFor(_MemoryStorage(_shellData()));
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const ValueKey('adaptive-shell-navigation-bar')),
          )
          .animationDuration,
      Duration.zero,
    );
    expect(tester.takeException(), isNull);
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
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    Finder viewSwitcher() =>
        find.byKey(const ValueKey('general-view-switcher'));
    expect(
      find.descendant(
        of: viewSwitcher(),
        matching: find.byIcon(Icons.calendar_view_month_outlined),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Student timetable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General schedule'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: viewSwitcher(),
        matching: find.byIcon(Icons.calendar_view_month_outlined),
      ),
      findsOneWidget,
    );
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
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    final saveCountBeforeResize = storage.saveCount;

    Finder viewSwitcher() =>
        find.byKey(const ValueKey('general-view-switcher'));
    void expectMonthView() {
      expect(
        find.descendant(
          of: viewSwitcher(),
          matching: find.byIcon(Icons.calendar_view_month_outlined),
        ),
        findsOneWidget,
      );
    }

    expectMonthView();

    for (final width in [600.0, 840.0, 1200.0, 599.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpAndSettle();
      expectMonthView();
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
    final navigationFinder = find.byKey(
      const ValueKey('adaptive-shell-navigation-bar'),
    );
    final workspaceFinder = find.byKey(
      const ValueKey('adaptive-workspace-stack'),
    );
    expect(find.byKey(const ValueKey('workspace-switch-busy')), findsNothing);
    expect(
      tester.getRect(workspaceFinder).bottom,
      closeTo(tester.getRect(navigationFinder).top, 0.01),
    );
    final navigationRectIdle = tester.getRect(navigationFinder);

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
    final busyRect = tester.getRect(
      find.byKey(const ValueKey('workspace-switch-busy')),
    );
    final navigationRectWhileBusy = tester.getRect(navigationFinder);
    expect(
      navigationRectWhileBusy.height,
      closeTo(navigationRectIdle.height, 0.01),
    );
    expect(busyRect.height, closeTo(4, 0.01));
    expect(busyRect.top, closeTo(navigationRectWhileBusy.top, 0.01));
    expect(busyRect.bottom, closeTo(navigationRectWhileBusy.top + 4, 0.01));
    expect(
      tester.getRect(workspaceFinder).bottom,
      closeTo(navigationRectWhileBusy.top, 0.01),
    );
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
    expect(tester.widget<NavigationBar>(navigationFinder).selectedIndex, 1);
    expect(find.byKey(const ValueKey('workspace-switch-busy')), findsNothing);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('adaptive-workspace-stack')))
          .bottom,
      closeTo(tester.getRect(navigationFinder).top, 0.01),
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

    expect(tester.widget<PageView>(pagerFinder).onPageChanged, isNull);
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

  testWidgets('student workspace is hosted by the shell scaffold', (
    tester,
  ) async {
    final provider = await _providerFor(
      _MemoryStorage(_shellData(populated: true)),
    );
    addTearDown(provider.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(800, 800));

    await tester.pumpWidget(_appFor(provider));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-workspace-toolbar')),
      findsOneWidget,
    );
    expect(find.byType(Drawer), findsNothing);
    expect(tester.takeException(), isNull);
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

  testWidgets('compact navigation remains usable with large text', (
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
        locale: const Locale('de'),
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
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('adaptive-shell-navigation-rail')),
    );
    expect(rail.scrollable, isTrue);
    final viewport = Offset.zero & const Size(600, 360);
    for (final key in const [
      'student-timetable-picker-button',
      'student-view-toggle-button',
      'student-week-picker-button',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.left, greaterThanOrEqualTo(viewport.left), reason: key);
      expect(rect.top, greaterThanOrEqualTo(viewport.top), reason: key);
      expect(rect.right, lessThanOrEqualTo(viewport.right), reason: key);
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom), reason: key);
      expect(rect.height, greaterThanOrEqualTo(48), reason: key);
    }
    expect(tester.takeException(), isNull);
  });
}
