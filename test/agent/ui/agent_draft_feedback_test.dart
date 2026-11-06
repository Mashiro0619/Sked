import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  for (final boundary in [
    'repository',
    'delegate',
    'activity',
    'interaction',
    'current',
  ]) {
    testWidgets('draft failure feedback belongs to its $boundary source', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final storage = UiMemoryStorage();
      final repository = ConversationRepository(storage: storage);
      final replacement = ConversationRepository(storage: UiMemoryStorage());
      await repository.load();
      await replacement.load();
      final original = await repository.create(title: 'Original');
      await replacement.create(title: 'Replacement');
      final delegate = UiDelegate(repository);
      final replacementDelegate = UiDelegate(replacement);
      final refreshedDelegate = UiDelegate(repository);
      addTearDown(() {
        repository.dispose();
        replacement.dispose();
        delegate.state.dispose();
        replacementDelegate.state.dispose();
        refreshedDelegate.state.dispose();
      });
      var shownRepository = repository;
      var shownDelegate = delegate;
      Widget view({bool active = true, bool interactive = true}) =>
          AgentConversationView(
            repository: shownRepository,
            delegate: shownDelegate,
            active: active,
            interactive: interactive,
          );
      await mountAgentUi(tester, view());
      final state = tester.state(find.byType(AgentConversationView));
      final entered = Completer<void>();
      final release = Completer<void>();
      storage.beforeSave = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        throw StateError('Synthetic draft persistence failure');
      };
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        'Keep the original draft',
      );
      await tester.pump();
      expect(entered.isCompleted, true);
      switch (boundary) {
        case 'repository':
          shownRepository = replacement;
          shownDelegate = replacementDelegate;
        case 'delegate':
          shownDelegate = refreshedDelegate;
        case 'activity':
          await mountAgentUi(tester, view(active: false));
        case 'interaction':
          await mountAgentUi(tester, view(interactive: false));
      }
      await mountAgentUi(tester, view());
      expect(tester.state(find.byType(AgentConversationView)), same(state));
      release.complete();
      await tester.pumpAndSettle();
      await repository.waitForPendingWrites();
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      expect(
        find.text(l.agentOperationFailed),
        boundary == 'repository' ? findsNothing : findsOneWidget,
      );
      expect(repository.canWrite, false);
      expect(replacement.canWrite, true);
      expect(delegate.calls, isEmpty);
      // The original store remains blocked after a real failed write. Reload
      // it directly to distinguish that durable condition from a stale UI flag.
      storage.beforeSave = null;
      await repository.load();
      await tester.pumpAndSettle();
      expect(repository.canWrite, true);
      expect(
        find.text(l.agentOperationFailed),
        boundary == 'current' ? findsOneWidget : findsNothing,
      );
      if (boundary == 'current') {
        expect(repository.selectedId, original.id);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
              .controller!
              .text,
          'Keep the original draft',
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
