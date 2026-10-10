import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/settings_data_transfer_controller.dart';

void main() {
  for (final scenario in [
    (
      platform: TargetPlatform.windows,
      locale: 'en',
      scale: 1.0,
      size: const Size(1000, 760),
    ),
    (
      platform: TargetPlatform.windows,
      locale: 'zh',
      scale: 2.0,
      size: const Size(480, 640),
    ),
    (
      platform: TargetPlatform.android,
      locale: 'en',
      scale: 1.0,
      size: const Size(390, 844),
    ),
  ]) {
    testWidgets(
      'backup heading and actions remain readable: ${scenario.platform} ${scenario.locale} ${scenario.scale}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.size;
        addTearDown(tester.view.reset);
        late BuildContext pageContext;
        SettingsAppDataAction? selected;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(scenario.locale),
            theme: ThemeData(platform: scenario.platform),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) {
                pageContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );
        final l10n = AppLocalizations.of(pageContext);
        final flow = const SettingsDataTransferController().runAppDataFlow(
          pageContext,
          hasRecoveryArtifacts: () => false,
          onAction: (action) async => selected = action,
        );
        await tester.pumpAndSettle();
        final desktop = scenario.platform == TargetPlatform.windows;
        final heading = find.text(l10n.appBackupTitle);
        final style = tester
            .widget<RichText>(
              find.descendant(of: heading, matching: find.byType(RichText)),
            )
            .text
            .style!;
        expect(style.fontSize, 16);
        expect(style.fontWeight, desktop ? FontWeight.w600 : FontWeight.w500);
        if (desktop) {
          expect(style.height, 1.35);
          expect(style.letterSpacing, 0);
        }
        final subtitleStyle = tester
            .widget<RichText>(
              find.descendant(
                of: find.text(l10n.appBackupSheetSubtitle),
                matching: find.byType(RichText),
              ),
            )
            .text
            .style!;
        expect(subtitleStyle.fontSize, desktop ? 12 : 14);
        expect(tester.takeException(), isNull);
        final saveAction = find.text(l10n.saveBackupTitle);
        await tester.ensureVisible(saveAction);
        await tester.pumpAndSettle();
        await tester.tap(saveAction);
        await tester.pumpAndSettle();
        await flow;
        expect(selected, SettingsAppDataAction.saveBackupFile);
        expect(heading, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('student sheet resolves localization when its builder runs', (
    tester,
  ) async {
    late BuildContext pageContext;
    late StateSetter rebuild;
    var locale = const Locale('en');

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return MaterialApp(
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                pageContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          );
        },
      ),
    );

    final flow = const SettingsDataTransferController().runStudentFlow(
      pageContext,
      onAction: (_) async {},
    );
    rebuild(() => locale = const Locale('zh'));
    await tester.pumpAndSettle();

    expect(find.text('导入导出数据'), findsOneWidget);
    expect(find.text('Import and export data'), findsNothing);

    Navigator.of(pageContext).pop();
    await tester.pumpAndSettle();
    await flow;
  });

  testWidgets('backup sheet reads recovery availability when builder runs', (
    tester,
  ) async {
    late BuildContext pageContext;
    var hasRecoveryArtifacts = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    final flow = const SettingsDataTransferController().runAppDataFlow(
      pageContext,
      hasRecoveryArtifacts: () => hasRecoveryArtifacts,
      onAction: (_) async {},
    );
    hasRecoveryArtifacts = true;
    await tester.pumpAndSettle();

    final recoveryAction = find.text('Show recovery files and locations');
    await tester.scrollUntilVisible(
      recoveryAction,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(recoveryAction, findsOneWidget);

    Navigator.of(pageContext).pop();
    await tester.pumpAndSettle();
    await flow;
  });
}
