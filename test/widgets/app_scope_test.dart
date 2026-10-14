import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/controllers/settings_commands.dart';
import 'package:sked/controllers/settings_view_state.dart';
import 'package:sked/providers/app_scope.dart';

import '../support/workspace_harness.dart';

void main() {
  testWidgets('a captured route preserves its nearest scope and shared state', (
    tester,
  ) async {
    final outer = await workspaceProvider(locale: 'en');
    final inner = await workspaceProvider(locale: 'ja');
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    final navigator = GlobalKey<NavigatorState>();
    var sourceBuilds = 0;

    await tester.pumpWidget(
      AppScope(
        app: outer,
        child: MaterialApp(
          navigatorKey: navigator,
          home: MultiProvider(
            providers: AppScope.providersFor(inner),
            child: Builder(
              builder: (context) {
                sourceBuilds++;
                final captured = AppScope.capture(context)!;
                return TextButton(
                  onPressed: () => navigator.currentState!.push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => captured.wrap(
                        Scaffold(
                          body: Builder(
                            builder: (context) {
                              expect(context.read<AppSession>(), inner.session);
                              return TextButton(
                                onPressed: () => context
                                    .read<SettingsCommands>()
                                    .updateLocaleCode('zh'),
                                child: Text(
                                  context.watch<SettingsViewState>().localeCode,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open task'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open task'));
    await tester.pumpAndSettle();
    final buildsBeforeSave = sourceBuilds;
    await tester.tap(find.text('ja'));
    await tester.pumpAndSettle();
    expect(find.text('zh'), findsOneWidget);
    expect(inner.settingsView.localeCode, 'zh');
    expect(outer.settingsView.localeCode, 'en');
    expect(sourceBuilds, buildsBeforeSave);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await inner.settingsCommands.updateLocaleCode('en');
    expect(inner.settingsView.localeCode, 'en');
    expect(find.text('Open task'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
