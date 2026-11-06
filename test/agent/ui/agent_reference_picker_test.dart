import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/agent/ui/agent_reference_picker.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/theme/app_theme.dart';

void main() {
  final first = _resourceChoice();
  final unavailable = _skillChoice();
  Finder row(String key) => find.byKey(ValueKey('agent-reference-choice-$key'));
  Finder chip(String key) => find.byKey(ValueKey('agent-reference-chip-$key'));
  final more = find.byKey(const ValueKey('agent-reference-more'));
  final close = find.byKey(const ValueKey('agent-reference-dismiss'));

  Widget picker({
    String query = 'algebra',
    List<AgentReferenceChoice>? choices,
    bool hasMore = false,
    bool enabled = true,
    bool loading = false,
    bool error = false,
    Future<void> Function(AgentReferenceChoice)? onSelect,
    Future<void> Function()? onLoadMore,
    VoidCallback? onDismiss,
  }) => AgentReferencePicker(
    query: query,
    result: AgentReferenceSearchResult(
      choices: choices ?? [first, unavailable],
      hasMore: hasMore,
    ),
    enabled: enabled,
    loading: loading,
    error: error,
    onSelect: onSelect ?? (_) async {},
    onLoadMore: onLoadMore,
    onDismiss: onDismiss ?? () {},
  );

  AppLocalizations labels(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Card).first));

  testWidgets('choices expose their label type scope and selectable state', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    AgentReferenceChoice? selected;
    await _mount(
      tester,
      picker(
        onSelect: (value) async {
          selected = value;
        },
      ),
    );
    expect(find.text(first.label), findsOneWidget);
    expect(find.text('Course\nAutumn timetable'), findsOneWidget);
    expect(tester.widget<ListTile>(row(unavailable.key)).onTap, isNull);
    await tester.tap(row(first.key));
    await tester.pumpAndSettle();
    expect(selected, same(first));
    expect(selected!.value.resourceRef!.id, 'course-one');
    expect(more, findsNothing);
  });

  testWidgets(
    'select waits once and preserves choices on a safe retryable error',
    (tester) async {
      addTearDown(tester.view.reset);
      final release = Completer<void>();
      var selections = 0;
      await _mount(
        tester,
        picker(
          onSelect: (_) async {
            selections++;
            if (selections == 1) await release.future;
          },
        ),
      );
      final callback = tester.widget<ListTile>(row(first.key)).onTap!;
      callback();
      callback();
      await tester.pump();
      expect(selections, 1);
      expect(tester.widget<ListTile>(row(first.key)).onTap, isNull);
      expect(
        find.byKey(const ValueKey('agent-reference-loading')),
        findsOneWidget,
      );
      release.completeError(StateError('secret-not-for-display'));
      await tester.pumpAndSettle();
      expect(find.text(labels(tester).agentReferenceFailed), findsOneWidget);
      expect(find.textContaining('secret-not-for-display'), findsNothing);
      expect(row(first.key), findsOneWidget);
      await tester.tap(row(first.key));
      await tester.pumpAndSettle();
      expect(selections, 2);
    },
  );

  testWidgets('loading and controlled errors keep their distinct UI state', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await _mount(tester, picker(loading: true));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<ListTile>(row(first.key)).onTap, isNull);
    expect(tester.widget<IconButton>(close).onPressed, isNotNull);
    await _mount(tester, picker(error: true));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text(labels(tester).agentReferenceFailed), findsOneWidget);
    await _mount(tester, picker(choices: []));
    expect(find.byKey(const ValueKey('agent-reference-empty')), findsOneWidget);
    expect(find.text(labels(tester).agentReferenceEmpty), findsOneWidget);
  });

  testWidgets('more requests are explicit and protected while loading', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final release = Completer<void>();
    var requests = 0;
    await _mount(
      tester,
      picker(
        choices: [first],
        hasMore: true,
        onLoadMore: () async {
          requests++;
          await release.future;
        },
      ),
    );
    final callback = tester.widget<TextButton>(more).onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(requests, 1);
    expect(tester.widget<TextButton>(more).onPressed, isNull);
    release.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(more).onPressed, isNotNull);
  });

  for (final boundary in ['query', 'choices', 'enabled']) {
    testWidgets('old picker callbacks expire when $boundary changes', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      var selections = 0;
      var dismisses = 0;
      await _mount(
        tester,
        picker(
          onSelect: (_) async {
            selections++;
          },
          onDismiss: () {
            dismisses++;
          },
        ),
      );
      final select = tester.widget<ListTile>(row(first.key)).onTap!;
      final dismiss = tester.widget<IconButton>(close).onPressed!;
      await _mount(
        tester,
        picker(
          query: boundary == 'query' ? 'changed' : 'algebra',
          choices: boundary == 'choices' ? [unavailable] : [first, unavailable],
          enabled: boundary != 'enabled',
          onSelect: (_) async {
            selections++;
          },
          onDismiss: () {
            dismisses++;
          },
        ),
      );
      select();
      dismiss();
      await tester.pump();
      expect(selections, 0);
      expect(dismisses, 0);
    });
  }

  testWidgets('late results cannot show an old error in a different query', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final release = Completer<void>();
    await _mount(tester, picker(onSelect: (_) => release.future));
    await tester.tap(row(first.key));
    await tester.pump();
    await _mount(tester, picker(query: 'next', choices: [unavailable]));
    release.completeError(StateError('Old query failed'));
    await tester.pumpAndSettle();
    expect(find.text(labels(tester).agentReferenceFailed), findsNothing);
    expect(row(unavailable.key), findsOneWidget);
  });

  testWidgets('dismiss and dispose retire pending feedback', (tester) async {
    addTearDown(tester.view.reset);
    final release = Completer<void>();
    var dismissed = 0;
    await _mount(
      tester,
      picker(
        onSelect: (_) => release.future,
        onDismiss: () {
          dismissed++;
        },
      ),
    );
    await tester.tap(row(first.key));
    await tester.pump();
    await tester.tap(close);
    await tester.pump();
    expect(dismissed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    release.completeError(StateError('Retired result'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long 2x choices scroll within a small picker without taking editor focus',
    (tester) async {
      addTearDown(tester.view.reset);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final choices = [
        for (var i = 0; i < 12; i++)
          _resourceChoice(
            id: '$i',
            label: 'A long resource name that needs more than one line $i',
            detail: 'A long parent scope that distinguishes this result from similar resources',
          ),
      ];
      await _mount(
        tester,
        Column(
          children: [
            TextField(focusNode: focus),
            picker(choices: choices),
          ],
        ),
        size: const Size(320, 480),
        scale: 2,
      );
      focus.requestFocus();
      await tester.pump();
      await tester.scrollUntilVisible(
        row(choices.last.key),
        160,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('agent-reference-results')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(focus.hasFocus, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unavailable selected reference can still be removed', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    AgentReferenceChoice? removed;
    await _mount(
      tester,
      AgentReferenceChips(
        choices: [unavailable],
        onRemove: (value) async {
          removed = value;
        },
      ),
    );
    tester.widget<InputChip>(chip(unavailable.key)).onDeleted!();
    await tester.pumpAndSettle();
    expect(removed, same(unavailable));
  });

  testWidgets(
    'chip removal preserves input on failure and blocks duplicate work',
    (tester) async {
      addTearDown(tester.view.reset);
      final release = Completer<void>();
      var removals = 0;
      await _mount(
        tester,
        AgentReferenceChips(
          choices: [first],
          onRemove: (_) async {
            removals++;
            await release.future;
          },
        ),
      );
      final remove = tester.widget<InputChip>(chip(first.key)).onDeleted!;
      remove();
      remove();
      await tester.pump();
      expect(removals, 1);
      expect(tester.widget<InputChip>(chip(first.key)).onDeleted, isNull);
      release.completeError(StateError('Do not display this error'));
      await tester.pumpAndSettle();
      expect(chip(first.key), findsOneWidget);
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentReferenceChips)),
      );
      expect(find.text(l.agentOperationFailed), findsOneWidget);
      expect(tester.widget<InputChip>(chip(first.key)).onDeleted, isNotNull);
    },
  );

  testWidgets(
    'chip callbacks and feedback expire when their controlled list changes',
    (tester) async {
      addTearDown(tester.view.reset);
      final release = Completer<void>();
      var removals = 0;
      await _mount(
        tester,
        AgentReferenceChips(
          choices: [first],
          onRemove: (_) async {
            removals++;
            await release.future;
          },
        ),
      );
      final remove = tester.widget<InputChip>(chip(first.key)).onDeleted!;
      remove();
      await tester.pump();
      await _mount(
        tester,
        AgentReferenceChips(
          choices: [unavailable],
          onRemove: (_) async {
            removals++;
          },
        ),
      );
      remove();
      release.completeError(StateError('Old reference failed'));
      await tester.pumpAndSettle();
      expect(removals, 1);
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentReferenceChips)),
      );
      expect(find.text(l.agentOperationFailed), findsNothing);
      expect(chip(unavailable.key), findsOneWidget);
    },
  );

  testWidgets(
    'equal rebuilt choices retain saving while changed skill versions and digests retire it',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final change in ['version', 'digest']) {
        final release = Completer<void>();
        var removals = 0;
        final original = _skillChoice(enabled: true);
        Future<void> remove(AgentReferenceChoice choice) {
          removals++;
          return release.future;
        }

        await _mount(
          tester,
          AgentReferenceChips(choices: [original], onRemove: remove),
        );
        final oldRemove = tester
            .widget<InputChip>(chip(original.key))
            .onDeleted!;
        oldRemove();
        await tester.pump();
        final equal = _skillChoice(enabled: true);
        expect(identical(original, equal), false);
        expect(equal, original);
        expect(equal.hashCode, original.hashCode);
        await _mount(
          tester,
          AgentReferenceChips(choices: [equal], onRemove: remove),
        );
        expect(tester.widget<InputChip>(chip(original.key)).onDeleted, isNull);
        oldRemove();
        expect(removals, 1);
        final changed = _skillChoice(
          enabled: true,
          revision: change == 'version' ? 2 : 1,
          body: change == 'digest'
              ? 'Updated instructions'
              : 'Fixture instructions',
        );
        expect(changed.key, original.key);
        expect(changed, isNot(original));
        await _mount(
          tester,
          AgentReferenceChips(choices: [changed], onRemove: remove),
        );
        expect(
          tester.widget<InputChip>(chip(changed.key)).onDeleted,
          isNotNull,
        );
        oldRemove();
        release.completeError(StateError('An old skill failed'));
        await tester.pumpAndSettle();
        expect(removals, 1);
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentReferenceChips)),
        );
        expect(find.text(l.agentOperationFailed), findsNothing);
      }
    },
  );

  testWidgets('disabled chips retire old actions and fit long labels at 2x', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    var removals = 0;
    final choice = _resourceChoice(
      id: 'long',
      label: 'A very long reference label with enough words to wrap across multiple lines',
      detail: 'Complete parent name',
    );
    await _mount(
      tester,
      AgentReferenceChips(
        choices: [choice],
        onRemove: (_) async {
          removals++;
        },
      ),
      size: const Size(320, 480),
      scale: 2,
    );
    final remove = tester.widget<InputChip>(chip(choice.key)).onDeleted!;
    expect(tester.takeException(), isNull);
    await _mount(
      tester,
      AgentReferenceChips(
        choices: [choice],
        enabled: false,
        onRemove: (_) async {
          removals++;
        },
      ),
      size: const Size(320, 480),
      scale: 2,
    );
    remove();
    await tester.pump();
    expect(removals, 0);
    expect(tester.widget<InputChip>(chip(choice.key)).onDeleted, isNull);
    expect(tester.takeException(), isNull);
  });
}

AgentReferenceChoice _resourceChoice({
  String id = 'course-one',
  String label = 'Linear algebra',
  String detail = 'Autumn timetable',
}) => AgentReferenceChoice(
  label: label,
  detail: detail,
  type: 'Course',
  value: AgentComposerReference.resource(
    ref: ResourceRef(kind: ResourceKind.course, id: id, parentId: 'timetable'),
    datasetGeneration: 'fixture-data',
    label: label,
  ),
);

AgentReferenceChoice _skillChoice({
  bool enabled = false,
  int revision = 1,
  String body = 'Fixture instructions',
}) => AgentReferenceChoice(
  label: 'Task skill',
  detail: enabled ? 'Shared task instructions' : 'Unavailable',
  type: 'Skill',
  enabled: enabled,
  value: AgentComposerReference.skill(
    skill: SkillDescriptor.editable(
      id: 'task-skill',
      title: 'Task skill',
      summary: 'Fixture skill',
      body: body,
      revision: revision,
    ),
  ),
);

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(460, 820),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(
        seedColor: const Color(0xff6750a4),
        brightness: Brightness.light,
        themeColorMode: 'solid',
        colorfulUiColorValues: const {},
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}
