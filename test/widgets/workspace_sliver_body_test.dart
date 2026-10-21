import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/workspace_view_panel.dart';

void main() {
  testWidgets(
    'sliver viewing tasks fit short content and bound long lists across resizing',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 800);
      addTearDown(tester.view.reset);
      final state = ValueNotifier((count: 1, height: 600.0, explicit: false));
      addTearDown(state.dispose);
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder(
                valueListenable: state,
                builder: (context, value, _) => SizedBox(
                  width: 480,
                  height: value.height,
                  child: WorkspaceViewTaskScope(
                    enabled: true,
                    onClose: () => closes++,
                    onContentHeight: (_) {},
                    child: WorkspaceViewLayoutScope(
                      compact: true,
                      explicitHeight: value.explicit,
                      child: WorkspaceViewPanel(
                        title: const Text('Reminders'),
                        bodyIsSliver: true,
                        child: SliverList.builder(
                          itemCount: value.count,
                          itemBuilder: (context, index) => SizedBox(
                            key: ValueKey('row-$index'),
                            height: 48,
                            child: Text('Row $index'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final body = find.byKey(const ValueKey('workspace-view-body'));
      expect(tester.getSize(body).height, lessThan(100));
      expect(find.text('Row 0'), findsOneWidget);

      state.value = (count: 300, height: 600.0, explicit: false);
      await tester.pumpAndSettle();
      expect(tester.getSize(body).height, greaterThan(400));
      expect(find.text('Row 299'), findsNothing);
      expect(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith('row-'),
            )
            .evaluate()
            .length,
        lessThan(30),
      );

      state.value = (count: 1, height: 600.0, explicit: true);
      await tester.pumpAndSettle();
      expect(tester.getSize(body).height, greaterThan(400));
      state.value = (count: 1, height: 600.0, explicit: false);
      await tester.pumpAndSettle();
      expect(tester.getSize(body).height, lessThan(100));

      state.value = (count: 300, height: 120.0, explicit: false);
      await tester.pumpAndSettle();
      expect(tester.getSize(body).height, lessThanOrEqualTo(120));
      await tester.tap(find.byKey(const ValueKey('workspace-inspector-close')));
      expect(closes, 1);
      expect(find.text('Row 299'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
