import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/calendar_management_actions.dart';

void main() {
  for (final compact in [false, true]) {
    testWidgets(
      'category menu keeps persistent anchor and density compact=$compact',
      (t) async {
        BuildContext? anchor;
        var deletes = 0, toggles = 0;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  CalendarVisibilityButton(
                    id: 'test',
                    visible: true,
                    enabled: true,
                    showTooltip: 'Show',
                    hideTooltip: 'Hide',
                    onPressed: () => toggles++,
                    compact: compact,
                  ),
                  CalendarManagementMenu(
                    id: 'test',
                    enabled: true,
                    tooltip: 'More',
                    renameLabel: 'Rename',
                    deleteLabel: 'Delete',
                    onRename: (c) => anchor = c,
                    onDelete: () => deletes++,
                    compact: compact,
                  ),
                ],
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const ValueKey('calendar-visibility-test')));
        expect(toggles, 1);
        await t.tap(find.byKey(const ValueKey('calendar-actions-test')));
        await t.pumpAndSettle();
        await t.tap(find.text('Rename'));
        await t.pumpAndSettle();
        expect(anchor?.mounted, isTrue);
        expect(find.text('Rename'), findsNothing);
        await t.tap(find.byKey(const ValueKey('calendar-actions-test')));
        await t.pumpAndSettle();
        await t.tap(find.text('Delete'));
        await t.pumpAndSettle();
        expect(deletes, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
}
