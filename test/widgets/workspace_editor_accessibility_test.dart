import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    testWidgets(
      'desktop date and time fields retain localized action hints: $locale',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(1440, 1000);
        addTearDown(t.view.reset);
        final p = await workspaceProvider(
          mode: AppMode.general,
          locale: locale,
        );
        addTearDown(p.dispose);
        await t.pumpWidget(
          WorkspaceHarness(provider: p, locale: Locale(locale)),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('general-add-event')));
        await t.pumpAndSettle();
        final editor = find.byType(GeneralEventEditorSheet);
        final l = AppLocalizations.of(t.element(editor));
        expect(
          find.descendant(of: editor, matching: find.byTooltip(l.pickDate)),
          findsNWidgets(2),
        );
        expect(
          find.descendant(of: editor, matching: find.byTooltip(l.pickTime)),
          findsNWidgets(2),
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
