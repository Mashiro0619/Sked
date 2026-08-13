import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/settings_data_transfer_controller.dart';

void main() {
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
