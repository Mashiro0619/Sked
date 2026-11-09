import 'dart:convert';
import 'dart:io' show pid;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/ui/agent_knowledge_view.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/agent_connection_settings_page.dart';
import 'package:sked/screens/agent_preferences_settings_page.dart';
import 'package:sked/screens/agent_settings_page.dart';
import 'package:sked/theme/sked_expressive_theme.dart';

import '../../test/support/agent_workspace_navigation.dart';
import 'agent_native_accessibility_workspace.dart';

import 'package:sked/agent/bridge/generated/api/contracts.dart' as bridge;
import 'package:sked/agent/bridge/generated/frb_generated.dart';

const _changeCount = 21;
const _start = '2026-09-07T15:00:00.000';
const _end = '2026-09-07T16:00:00.000';
const _completedReply = 'The synthetic accessibility request has finished.';

String _draft(String name) =>
    'Prepare 21 synthetic accessibility events for $name.';
String _title(String name, int index) =>
    'MSAA $name event ${index.toString().padLeft(2, '0')}';
String _notes(String name, int index) =>
    'Native MSAA $name detail ${index.toString().padLeft(2, '0')}';

typedef AgentAccessibilityPhase = Future<void> Function(
  String name,
  Future<void> Function() action,
);
typedef AgentAccessibilityInput = Future<void> Function(
  Finder field,
  String value,
  List<Map<String, Object?>> diagnostics,
);

List<bridge.OfflineModelReply> _previewReplies(String name) {
  bridge.OfflineModelReply reply(
    int index, {
    String? tool,
    Map<String, Object?>? arguments,
  }) {
    final delta = tool == null
        ? {'role': 'assistant', 'content': _completedReply}
        : {
            'role': 'assistant',
            'tool_calls': [
              {
                'index': 0,
                'id': 'native-msaa-$name-$index',
                'type': 'function',
                'function': {
                  'name': tool.replaceAll('_', '_u').replaceAll('.', '__'),
                  'arguments': jsonEncode(arguments),
                },
              },
            ],
          };
    Map<String, Object?> chunk(Map<String, Object?> value, String? finish) => {
      'id': 'native-msaa-$name-$index',
      'object': 'chat.completion.chunk',
      'created': 0,
      'model': 'native-ui-fixture',
      'choices': [
        {'index': 0, 'delta': value, 'finish_reason': finish},
      ],
    };
    return bridge.OfflineModelReply(
      status: 200,
      contentType: 'text/event-stream',
      body:
          'data: ${jsonEncode(chunk(delta, null))}\n\n'
          'data: ${jsonEncode(chunk({}, tool == null ? 'stop' : 'tool_calls'))}\n\n'
          'data: [DONE]\n\n',
    );
  }

  return [
    reply(
      1,
      tool: 'capabilities.describe',
      arguments: {
        'names': ['mutation.apply'],
      },
    ),
    reply(
      2,
      tool: 'mutation.apply',
      arguments: {
        'commands': [
          for (var index = 1; index <= _changeCount; index++)
            {
              'kind': 'event',
              'action': 'create',
              'destinationParentId': 'native-calendar',
              'values': {
                'title': _title(name, index),
                'start': _start,
                'end': _end,
                'notes': _notes(name, index),
                'reminderBehavior': 'disabled',
              },
            },
        ],
      },
    ),
    reply(3),
  ];
}

/// Appended after the original workspace tree has been unmounted. The caller
/// retains its one lifetime semantics audit and its same-PID native probe.
Future<void> runAgentNativeAccessibility(
  WidgetTester tester, {
  required String revision,
  required AgentAccessibilityPhase phase,
  required Future<Map<String, dynamic>> Function(String expectedText) probe,
  required AgentAccessibilityInput enterText,
  required List<Map<String, dynamic>> nativeProbes,
  required List<Map<String, Object?>> scenarios,
}) async {
  await RustLib.init();
  for (final name in ['baseline', 'accessible']) {
    final config = AgentNativeConfig(
      name: name,
      revision: revision,
      label: 'msaa-$name',
    );
    final report = <String, Object?>{
      'protocol': 'agent-msaa-v3',
      'revision': revision,
      'processId': pid,
      'configuration': config.toJson(),
      'status': 'running',
      'textInputTransport': 'registered-flutter-test-client',
      'inputScope':
          'Flutter-injected input on native Windows; same-PID MSAA queries',
    };
    scenarios.add(report);
    final guard = AgentNativeHttpGuard();
    AgentNativeSession? session;
    NativeAccessibilityObservation? provider;
    Object? failure;
    StackTrace? failureStack;
    try {
      config.validate();
      guard.install();
      final native = session = await AgentNativeSession.create(
        name: name,
        replies: _previewReplies(name),
      );
      final scripted = provider = native.provider;
      report['fixture'] = native.fixtureReport();
      final journey = _MsaaScenario(
        tester,
        native,
        scripted,
        config,
        report,
        phase,
        probe,
        enterText,
        nativeProbes,
      );
      await journey.run();
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
      report['failure'] = {'error': '$error', 'stack': '$stack'};
    } finally {
      final cleanup = <String, Object?>{};
      report['cleanup'] = cleanup;
      Future<void> clean(String name, Future<void> Function() action) async {
        try {
          await action();
        } catch (error, stack) {
          cleanup['${name}Failure'] = {
            'status': 'failed',
            'error': '$error',
            'stack': '$stack',
          };
          failure ??= error;
          failureStack ??= stack;
        }
      }

      await clean('unmount', () async {
        await phase(
          'agent-$name-unmount',
          () => tester.pumpWidget(const SizedBox.shrink()),
        );
        cleanup['unmount'] = 'complete';
      });
      final native = session;
      if (native != null) {
        await clean('owners', () async {
          final owners = await native.close();
          cleanup['owners'] = owners;
          expect(owners['status'], 'complete');
        });
        report['storageAfterCleanup'] = await native.storageReport();
      }
      await clean('httpGuard', () async {
        guard.restore();
        cleanup['httpGuardRestored'] = true;
        expect(guard.attempts, 0);
      });
      report['httpOperationAttempts'] = guard.attempts;
      report['httpClientsCreated'] = guard.clientsCreated;
      report['provider'] = provider?.toJson();
      final finalProvider = provider;
      if (finalProvider != null) {
        await clean('provider', () async {
          expect(finalProvider.closed, isTrue);
        });
      }
    }
    report['status'] = failure == null ? 'passed' : 'failed';
    final error = failure;
    if (error != null) Error.throwWithStackTrace(error, failureStack!);
  }
}

class _MsaaScenario {
  _MsaaScenario(
    this.tester,
    this.session,
    this.provider,
    this.config,
    this.report,
    this.phase,
    this.probe,
    this.enterText,
    this.nativeProbes,
  );

  final WidgetTester tester;
  final AgentNativeSession session;
  final NativeAccessibilityObservation provider;
  final AgentNativeConfig config;
  final Map<String, Object?> report;
  final AgentAccessibilityPhase phase;
  final Future<Map<String, dynamic>> Function(String expectedText) probe;
  final AgentAccessibilityInput enterText;
  final List<Map<String, dynamic>> nativeProbes;
  late String conversationId;
  late AppData before;
  late String beforeSource;
  late String beforeStored;
  late List<Map<String, dynamic>> changes;

  Finder key(String value) => find.byKey(ValueKey(value));
  Finder get composer => key('agent-composer').hitTestable();
  Finder get preview => find.byType(AgentPlanPreview);
  Finder get previewRows =>
      find.descendant(of: preview, matching: find.byType(ExpansionTile));
  AppLocalizations get l => AppLocalizations.of(tester.element(composer));
  String stage(String suffix) => 'agent-${config.name}-$suffix';

  Future<void> at(String suffix, Future<void> Function() action) =>
      phase(stage(suffix), action);

  Future<void> until(bool Function() ready, String description) async {
    final watch = Stopwatch()..start();
    while (!ready()) {
      expect(tester.takeException(), isNull, reason: description);
      if (watch.elapsed > const Duration(seconds: 20)) {
        throw StateError(
          'Timed out waiting for $description in ${config.name}; '
          'requests=${provider.requests}, selected=${session.app.agent.conversations.selectedId}.',
        );
      }
      await tester.pump(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
      );
    }
    await tester.pump(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
    );
    expect(tester.takeException(), isNull, reason: description);
  }

  SemanticsNode publishedFrom(RenderObject? object) {
    while (object != null) {
      final node = object.debugSemantics;
      if (node != null && !node.isMergedIntoParent) return node;
      object = object.parent;
    }
    throw StateError('The rendered control has no published semantics node.');
  }

  Map<String, Object?> textEvidence(EditableTextState editable) {
    final node = publishedFrom(editable.renderEditable);
    final data = node.getSemanticsData();
    final reachable = <int>{};
    void visit(SemanticsNode current) {
      if (!reachable.add(current.id)) return;
      current.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(editable.renderEditable.owner!.semanticsOwner!.rootSemanticsNode!);
    return {
      'nodeId': node.id,
      'label': data.label,
      'value': data.value,
      'isHidden': data.flagsCollection.isHidden,
      'isReadOnly': data.flagsCollection.isReadOnly,
      'reachableFromRoot': reachable.contains(node.id),
      'rect': [
        node.rect.left,
        node.rect.top,
        node.rect.width,
        node.rect.height,
      ],
    };
  }

  Map<String, Object?> expansionEvidence(Finder detail, Finder row) {
    final rowObject = tester.renderObject(row);
    RenderObject? current = tester.renderObject(detail).parent;
    while (current != null && !identical(current, rowObject)) {
      if (current is RenderClipRect) {
        final alignment = current.child;
        if (alignment is RenderPositionedBox &&
            alignment.heightFactor != null &&
            alignment.child is RenderOffstage) {
          final body = alignment.child! as RenderOffstage;
          final complete =
              !body.offstage &&
              body.size.height > 0 &&
              (alignment.heightFactor! - 1).abs() < 0.000001 &&
              (current.size.height - body.size.height).abs() < 0.01;
          return {
            'heightFactor': alignment.heightFactor,
            'offstage': body.offstage,
            'clipHeight': current.size.height,
            'bodyHeight': body.size.height,
            'complete': complete,
          };
        }
      }
      current = current.parent;
    }
    throw StateError('The selected preview row has no expansion body clip.');
  }

  Map<String, Object?> actionEvidence(Finder finder) {
    final object = tester.renderObject(finder);
    final actions = <int, SemanticsNode>{};
    void collect(RenderObject render) {
      final node = render.debugSemantics;
      if (node != null && !node.isMergedIntoParent) {
        final data = node.getSemanticsData();
        if (data.hasAction(ui.SemanticsAction.tap) &&
            !data.flagsCollection.isHidden) {
          actions[node.id] = node;
        }
      }
      render.visitChildren(collect);
    }

    // Composite controls may publish their button below the keyed render
    // object. Searching ancestors first can select the whole route instead.
    collect(object);
    expect(
      actions.length,
      lessThanOrEqualTo(1),
      reason: 'The requested control must identify one published tap action.',
    );
    // Text and navigation labels can merge into an actionable ancestor. Do not search
    // that ancestor's other descendants for an unrelated action.
    final node = actions.isEmpty
        ? publishedFrom(object)
        : actions.values.single;
    final data = node.getSemanticsData();
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isHidden, isFalse);
    return {
      'id': node.id,
      'label': data.label,
      'role': data.role.name,
      'isButton': data.flagsCollection.isButton,
      'hasTap': data.hasAction(ui.SemanticsAction.tap),
      'selected': data.flagsCollection.isSelected == ui.Tristate.isTrue,
      'mergedIntoParent': node.isMergedIntoParent,
    };
  }

  Future<void> reveal(Finder finder) async {
    await until(
      () => finder.evaluate().length == 1,
      'the requested control to be built',
    );
    await tester.ensureVisible(finder);
    await until(
      () => finder.hitTestable().evaluate().length == 1,
      'the requested control to be visible',
    );
  }

  Future<void> tap(Finder finder) async {
    await reveal(finder);
    actionEvidence(finder.hitTestable());
    await tester.tap(finder.hitTestable());
    await tester.pump(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
    );
  }

  Future<void> native(String suffix, String expected, String purpose) async {
    await tester.pump(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
    );
    final result = await probe(expected);
    nativeProbes.add({
      'phase': stage(suffix),
      'configuration': config.name,
      'purpose': purpose,
      ...result,
    });
    expect(result['nativeApi'], 'MSAA');
    expect(result['processId'], pid);
    expect(result['matchedExpectedText'], greaterThan(0));
    final matches = [
      for (final root in result['roots'] as List)
        for (final match in (root as Map)['matches'] as List) match as Map,
    ];
    if (purpose == 'editable-value') {
      expect(result['matchedEditableValues'], greaterThan(0));
    } else {
      final roles = purpose == 'button' ? {43, 56, 57, 58, 62} : {41, 42};
      expect(
        matches.any(
          (match) =>
              roles.contains(match['role']) &&
              (match['nameMatched'] == true || match['valueMatched'] == true),
        ),
        isTrue,
        reason:
            'A matching container is insufficient for the $purpose observation.',
      );
    }
  }

  void unchanged() {
    expect(session.app.session.committedData.encode(), beforeSource);
    expect(session.mainSource, beforeStored);
  }

  Future<void> drain() async {
    await session.app.persistence.flushPendingUiStateSaves();
    await session.app.session.repository
        .waitForPendingWrites(propagateErrors: true)
        .timeout(const Duration(seconds: 20));
    await session.app.agent.conversations.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
  }

  Future<void> run() async {
    const homeControls = ['workspace-agent-entry', 'workspace-main-navigation'];
    await at('mount', () async {
      expect(session.app.lifecycle.canWrite, isTrue);
      expect(session.app.agent.isInitialized, isFalse);
      await tester.pumpWidget(AgentNativeApp(session: session, config: config));
      await until(
        () => homeControls.any(
          (id) => key(id).hitTestable().evaluate().length == 1,
        ),
        'the real home Agent entry',
      );
      expect(session.app.agent.isInitialized, isFalse);
    });
    await at('entry', () async {
      final homeControl = homeControls.firstWhere(
        (id) => key(id).hitTestable().evaluate().length == 1,
      );
      if (homeControl != 'workspace-agent-entry') {
        await tap(key(homeControl));
      }
      await tap(key('workspace-agent-entry'));
      await until(
        () =>
            composer.evaluate().length == 1 && session.app.agent.isInitialized,
        'the production Agent composer',
      );
      await openAgentShellHistory(tester);
      await tap(key('agent-history-new'));
      await until(
        () =>
            session.app.agent.conversations.selectedId != agentNativeLongId &&
            session.app.agent.conversations.selected!.messages.isEmpty &&
            composer.evaluate().length == 1,
        'the actual new conversation',
      );
      conversationId = session.app.agent.conversations.selectedId!;
      await until(
        () =>
            find.byType(AgentPage).hitTestable().evaluate().length == 1 &&
            composer.evaluate().length == 1,
        'the production full Agent workspace',
      );
      final context = tester.element(composer);
      final motion = SkedMotionPolicy.of(context);
      final observed = <String, Object?>{
        'brightness': Theme.of(context).brightness.name,
        'textScale': MediaQuery.textScalerOf(context).scale(14) / 14,
        'reduceMotion': motion.reduceMotion,
        'disableAnimations': motion.disableAnimations,
      };
      report['observedConfiguration'] = observed;
      expect(observed['brightness'], config.brightness.name);
      expect(observed['textScale'], closeTo(config.textScale, 0.001));
      expect(observed['reduceMotion'], config.accessible);
      expect(observed['disableAnimations'], isFalse);
      expect(provider.requests, 0);
      await drain();
      before = session.app.session.committedData;
      beforeSource = before.encode();
      beforeStored = session.mainSource;
      expect(beforeStored, beforeSource);
      report['entry'] = {
        'path': 'home side navigation / Agent → new conversation',
        'homeControl': homeControl == 'workspace-agent-entry'
            ? homeControl
            : '$homeControl / workspace-agent-entry',
        'conversationId': conversationId,
        'originalLongMessageCount': agentNativeMessageCount,
      };
    });
    final inputs = <Map<String, Object?>>[];
    report['textSemanticsDiagnostics'] = inputs;
    await at('composer-value', () async {
      await enterText(composer, _draft(config.name), inputs);
      await native('composer-value', _draft(config.name), 'editable-value');
    });
    await settings();
    await prepare();
    await inspectPreview();
    await decide();
  }

  Future<void> settings() async {
    final labels = [
      l.agentConnectionAndModels,
      l.agentRunPreferences,
      l.agentSkills,
      l.agentMemories,
    ];
    final suffixes = [
      'settings-connection',
      'settings-preferences',
      'settings-skills',
      'settings-memory',
    ];
    final destinations = [
      'agent-settings-connection',
      'agent-settings-preferences',
      'agent-settings-skills',
      'agent-settings-memories',
    ];
    final pages = <Map<String, Object?>>[];
    report['settingsPages'] = pages;
    report['settingsHierarchy'] = 'overview / category / item';
    await at('settings-open', () async {
      await tap(key('agent-conversation-menu'));
      await tap(key('agent-settings'));
      await until(
        () =>
            find.byType(AgentSettingsPage).hitTestable().evaluate().length == 1,
        'the Agent settings overview page',
      );
    });
    for (var index = 0; index < labels.length; index++) {
      await at(suffixes[index], () async {
        final destination = key(destinations[index]);
        await reveal(destination);
        final node = actionEvidence(destination.hitTestable());
        expect(node['isButton'], isTrue);
        expect(node['label'], contains(labels[index]));
        await native(suffixes[index], labels[index], 'button');
        await tap(destination);
        final content = switch (index) {
          0 => find.byType(AgentConnectionSettingsPage),
          1 => find.byType(AgentPreferencesSettingsPage),
          2 => find.byWidgetPredicate(
            (widget) =>
                widget is AgentKnowledgeView &&
                widget.pageEditor &&
                widget.kind == KnowledgeKind.skill,
          ),
          _ => find.byWidgetPredicate(
            (widget) =>
                widget is AgentKnowledgeView &&
                widget.pageEditor &&
                widget.kind == KnowledgeKind.memory,
          ),
        };
        await until(
          () => content.hitTestable().evaluate().length == 1,
          'the current child settings page',
        );
        expect(
          ModalRoute.of(tester.element(content.hitTestable()))?.isCurrent,
          isTrue,
        );
        expect(destination.hitTestable(), findsNothing);
        pages.add({
          'index': index,
          'destination': destinations[index],
          'title': labels[index],
          'currentChildRoute': true,
          'contentType': tester
              .widget(content.hitTestable())
              .runtimeType
              .toString(),
          if (index >= 2) 'knowledgeKind': index == 2 ? 'skill' : 'memory',
          ...node,
        });
        await tap(find.byType(BackButton).hitTestable());
        await until(
          () =>
              key('agent-settings-connection')
                  .hitTestable()
                  .evaluate()
                  .length ==
              1,
          'the settings overview after child-page Back',
        );
      });
    }
    expect(pages.map((item) => item['id']).toSet(), hasLength(4));
    await at('settings-return', () async {
      final back = find.descendant(
        of: find.byType(AgentSettingsPage),
        matching: find.byType(BackButton),
      );
      await tap(back);
      await until(
        () =>
            find.byType(AgentSettingsPage).evaluate().isEmpty &&
            composer.evaluate().length == 1,
        'return from the Agent settings overview',
      );
      expect(
        tester.widget<TextField>(composer).controller!.text,
        _draft(config.name),
      );
      expect(session.app.agent.conversations.selectedId, conversationId);
      expect(provider.requests, 0);
      await drain();
      unchanged();
      report['settingsReturn'] = {
        'draftPreserved': true,
        'mainSnapshotUnchanged': true,
        'providerRequests': provider.requests,
      };
    });
  }

  Future<void> prepare() async {
    await at('ask-prepare', () async {
      await tap(key('agent-mode-picker'));
      await tap(key('agent-mode-ask'));
      await until(
        () =>
            session.app.agent.conversations.selected!.mode ==
            AgentPermissionMode.ask,
        'the saved Ask mode',
      );
      await until(
        () => tester.widget<IconButton>(key('agent-send')).onPressed != null,
        'the enabled send action',
      );
      await tap(key('agent-send'));
      await until(
        () =>
            session.app.agent.runtime.state.value
                    .runFor(conversationId)
                    .pendingApproval !=
                null &&
            preview.evaluate().length == 1,
        'the real host mutation approval',
      );
      final approval = session.app.agent.runtime.state.value
          .runFor(conversationId)
          .pendingApproval!;
      expect(approval.id, isNotEmpty);
      expect(approval.details['operationId'], isA<String>());
      expect(approval.details['changeCount'], _changeCount);
      changes = (approval.details['changes'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      expect(changes, hasLength(_changeCount));
      final titles = <String>{};
      for (final change in changes) {
        expect(change['before'], isNull);
        final ref = change['ref'] as Map;
        final after = change['after'] as Map;
        expect(ref['kind'], 'event');
        expect(ref['parentId'], 'native-calendar');
        expect(ref['id'], after['id']);
        expect(after['calendarId'], 'native-calendar');
        final title = after['title'] as String;
        final index = int.parse(title.substring(title.length - 2));
        expect(title, _title(config.name, index));
        expect(after['notes'], _notes(config.name, index));
        expect(after['start'], _start);
        expect(after['end'], _end);
        expect(after['reminderBehavior'], 'disabled');
        expect(after['reminders'], isEmpty);
        titles.add(title);
      }
      expect(titles, {
        for (var index = 1; index <= _changeCount; index++)
          _title(config.name, index),
      });
      expect(provider.requests, 2);
      await drain();
      unchanged();
      report['approval'] = {
        'planId': approval.id,
        'mode': 'ask',
        'changeCount': changes.length,
        'beforeCommittedSha256': agentNativeDigest(beforeSource),
        'beforeStoredSha256': agentNativeDigest(beforeStored),
        'pendingCommittedSha256': agentNativeDigest(
          session.app.session.committedData.encode(),
        ),
        'pendingStoredSha256': agentNativeDigest(session.mainSource),
        'changes': changes,
      };
    });
    final actions = <Map<String, Object?>>[];
    report['approvalActions'] = actions;
    for (final (keyName, label, suffix) in [
      ('agent-approve', l.agentApprove, 'ask-approve-control'),
      ('agent-reject', l.agentReject, 'ask-reject-control'),
    ]) {
      await at(suffix, () async {
        await reveal(key(keyName));
        actions.add({
          'key': keyName,
          ...actionEvidence(key(keyName).hitTestable()),
        });
        await native(suffix, label, 'button');
        unchanged();
      });
    }
    expect(actions.map((item) => item['id']).toSet(), hasLength(2));
  }

  Future<void> inspectPreview() async {
    final details = <Map<String, Object?>>[];
    final observation = <String, Object?>{'details': details};
    report['preview'] = observation;
    await at('preview-pagination', () async {
      expect(previewRows, findsNWidgets(20));
      observation['initialRowCount'] = previewRows.evaluate().length;
      final tailTitle = (changes.last['after'] as Map)['title'] as String;
      expect(
        find.descendant(of: preview, matching: find.text(tailTitle)),
        findsNothing,
      );
      final more = find.descendant(
        of: preview,
        matching: find.widgetWithText(TextButton, l.agentShowMoreChanges),
      );
      await reveal(more);
      await native('preview-pagination', l.agentShowMoreChanges, 'button');
      await tap(more);
      await until(
        () => previewRows.evaluate().length == _changeCount,
        'all 21 preview rows',
      );
      expect(more, findsNothing);
      observation['fullRowCount'] = previewRows.evaluate().length;
      observation['orderedIds'] = [
        for (final change in changes) (change['after'] as Map)['id'],
      ];
      for (final change in changes) {
        expect(
          find.descendant(
            of: preview,
            matching: find.text((change['after'] as Map)['title'] as String),
          ),
          findsOneWidget,
        );
      }
      final transcript = key('agent-transcript-$conversationId');
      expect(transcript, findsOneWidget);
      final scrolling = find
          .descendant(of: transcript, matching: find.byType(Scrollable))
          .first;
      final scroll = tester.state<ScrollableState>(scrolling).position;
      final pixelsBefore = scroll.pixels;
      final viewport = tester.getRect(transcript);
      final distance = (viewport.height * 0.4).clamp(120.0, 240.0);
      // A real user drag suspends the transcript's ordinary follow-latest
      // behavior before inspecting older approval rows. Programmatic reveal
      // alone must not stand in for entering the product's reading state.
      await tester.timedDragFrom(
        Offset(viewport.left + 8, viewport.top + viewport.height * 0.3),
        Offset(0, distance),
        const Duration(milliseconds: 300),
      );
      await until(
        () =>
            key('agent-jump-latest').hitTestable().evaluate().length == 1 &&
            !scroll.isScrollingNotifier.value &&
            scroll.pixels < pixelsBefore &&
            scroll.extentAfter > 72,
        'the actual transcript drag to enter earlier-history reading',
      );
      observation['inspectionScroll'] = {
        'target': 'agent-transcript-$conversationId',
        'input': 'framework timed pointer drag',
        'distance': distance,
        'pixelsBefore': pixelsBefore,
        'pixelsAfter': scroll.pixels,
        'extentAfter': scroll.extentAfter,
        'jumpToLatestVisible': true,
      };
      unchanged();
    });
    for (final (position, change) in [
      ('first', changes.first),
      ('last', changes.last),
    ]) {
      await at('preview-$position-detail', () async {
        final after = change['after'] as Map;
        final label = find.descendant(
          of: preview,
          matching: find.text(after['title'] as String),
        );
        await tap(label);
        final detail = find.descendant(
          of: preview,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText &&
                (widget.data?.contains(after['notes'] as String) ?? false),
          ),
        );
        await until(
          () => detail.evaluate().length == 1,
          'the expanded $position full change detail',
        );
        await tester.ensureVisible(detail);
        await tester.pump(
          const Duration(milliseconds: 16),
          EnginePhase.sendSemanticsUpdate,
        );
        final row = find.ancestor(
          of: detail,
          matching: find.byType(ExpansionTile),
        );
        expect(row, findsOneWidget);
        final editable = tester.state<EditableTextState>(
          find.descendant(of: detail, matching: find.byType(EditableText)),
        );
        final initialExpansion = expansionEvidence(detail, row);
        final initialText = textEvidence(editable);
        final detailObservation = <String, Object?>{
          'position': position,
          'id': after['id'],
          'notes': after['notes'],
          'framePolicy': (tester.binding as LiveTestWidgetsFlutterBinding)
              .framePolicy
              .name,
          'expansionBeforeWait': initialExpansion,
          'textBeforeWait': initialText,
        };
        details.add(detailObservation);
        Map<String, Object?>? previousExpansion;
        var stableExpandedPumps = 0;
        // The active approval spinner never settles the whole tree. Wait for
        // this row's real clipping animation, then reveal the final geometry.
        await until(() {
          final current = expansionEvidence(detail, row);
          final stable =
              current['complete'] == true &&
              previousExpansion?['complete'] == true &&
              current['clipHeight'] == previousExpansion?['clipHeight'] &&
              current['bodyHeight'] == previousExpansion?['bodyHeight'];
          stableExpandedPumps = stable ? stableExpandedPumps + 1 : 0;
          previousExpansion = current;
          return stableExpandedPumps >= 2;
        }, 'the fully expanded $position detail with stable unclipped height');
        await tester.ensureVisible(detail);
        await tester.pump(
          const Duration(milliseconds: 16),
          EnginePhase.sendSemanticsUpdate,
        );
        final rendered = tester.widget<SelectableText>(detail).data!;
        final decoded = jsonDecode(rendered) as Map;
        expect(decoded[l.agentValueBefore], isNull);
        expect(decoded[l.agentValueAfter], after);
        final finalExpansion = expansionEvidence(detail, row);
        final finalText = textEvidence(editable);
        detailObservation.addAll({
          'expansionAfterWait': finalExpansion,
          'textAfterWait': finalText,
          'stableExpandedPumps': stableExpandedPumps,
        });
        expect(finalExpansion['complete'], isTrue);
        expect(finalText['isHidden'], isFalse);
        expect(finalText['isReadOnly'], isTrue);
        expect(finalText['reachableFromRoot'], isTrue);
        expect(finalText['label'], contains(after['notes']));
        expect(finalText['value'], rendered);
        detailObservation.addAll({
          'beforeIsNull': true,
          'completeAfterMatches': true,
          'afterSha256': agentNativeDigest(jsonEncode(after)),
        });
        await native(
          'preview-$position-detail',
          after['notes'] as String,
          'detail',
        );
        unchanged();
        // Collapse through the actual row before revealing the next large item.
        await tap(label);
        await until(
          () => detail.evaluate().isEmpty,
          'the collapsed $position change detail',
        );
      });
    }
  }

  Future<void> decide() async {
    final approve = config.accessible;
    await at(approve ? 'decision-approve' : 'decision-reject', () async {
      unchanged();
      await tap(key(approve ? 'agent-approve' : 'agent-reject'));
      await until(
        () => !session.app.agent.runtime.state.value
            .runFor(conversationId)
            .isActive,
        'the native host decision and final model response',
      );
      await session.app.agent.quiesce();
      await drain();
      expect(provider.requests, 3);
      expect(provider.tools, ['capabilities.describe', 'mutation.apply']);
      expect(preview, findsNothing);
      final conversation = await session.app.agent.conversations.read(
        conversationId,
      );
      final stored = await session.readStoredConversation(conversationId);
      final storedConversation = stored.conversation;
      final snapshot = stored.snapshot;
      final run = snapshot.runs.single;
      final lastMessage = snapshot.messages.last;
      expect(storedConversation.toJson(), conversation.toJson());
      final toolMessage = storedConversation.messages.singleWhere(
        (message) => message.toolCallId == 'native-msaa-${config.name}-2',
      );
      final toolResult = jsonDecode(toolMessage.text) as Map<String, dynamic>;
      final display = session.app.agent.runtime.state.value.runFor(
        conversationId,
      );
      expect(display.isActive, isFalse);
      expect(display.pendingApproval, isNull);
      expect(display.recoveryRequired, isFalse);
      expect(display.phase.name, 'idle');
      expect(snapshot.conversation.status.name, 'idle');
      expect(run.status.name, 'completed');
      expect(run.errorCode, isNull);
      expect(run.settledAt, isNotNull);
      expect(run.requests, hasLength(3));
      expect(
        run.requests.every((request) => request.settledAt != null),
        isTrue,
      );
      expect(run.requests.map((request) => request.outcome.name), [
        'completed',
        'completed',
        'completed',
      ]);
      expect(run.tools.map((tool) => tool.outcome.name), [
        'completed',
        approve ? 'completed' : 'cancelled',
      ]);
      expect(storedConversation.messages.last.text, _completedReply);
      expect(provider.result, toolResult);
      final saved = AppData.decodeStorageSnapshot(session.mainSource);
      final current = session.app.session.committedData;
      expect(saved.toJson(), current.toJson());
      final result = <String, Object?>{
        'action': approve ? 'approve' : 'reject',
        'toolCallId': toolMessage.toolCallId,
        'beforeCommittedSha256': agentNativeDigest(beforeSource),
        'beforeStoredSha256': agentNativeDigest(beforeStored),
        'afterCommittedSha256': agentNativeDigest(current.encode()),
        'afterStoredSha256': agentNativeDigest(session.mainSource),
        'eventCountBefore': before.generalMode.schedules
            .expand((calendar) => calendar.events)
            .length,
        'eventCountAfter': saved.generalMode.schedules
            .expand((calendar) => calendar.events)
            .length,
        'toolResult': toolResult,
        'terminal': {
          'runtimeActive': display.isActive,
          'phase': display.phase.name,
          'errorCode': run.errorCode,
          'pendingApproval': display.pendingApproval != null,
          'recoveryRequired': display.recoveryRequired,
          'conversationStatus': snapshot.conversation.status.name,
          'conversationSha256': agentNativeDigest(
            jsonEncode(conversation.toJson()),
          ),
          'storedConversationSha256': agentNativeDigest(
            jsonEncode(storedConversation.toJson()),
          ),
          'runStatus': run.status.name,
          'settled':
              run.settledAt != null &&
              run.requests.every((request) => request.settledAt != null),
          'requestCount': run.requests.length,
          'requestOutcomes': [
            for (final request in run.requests) request.outcome.name,
          ],
          'toolOutcomes': [for (final tool in run.tools) tool.outcome.name],
          'lastMessageRole': lastMessage.role.name,
          'lastMessageToolCallId': lastMessage.toolCallId,
          'finalProviderReply':
              lastMessage.role.name == 'assistant' &&
              lastMessage.text == _completedReply,
        },
      };
      report['decision'] = result;
      if (!approve) {
        unchanged();
        expect(toolResult['status'], 'not_executed');
        expect(
          toolResult['error'],
          isA<Map>().having((error) => error['code'], 'code', 'cancelled'),
        );
        expect(saved.applicationLedger!.receipts, isEmpty);
        result['receiptCount'] = saved.applicationLedger!.receipts.length;
        result['errorCode'] = (toolResult['error'] as Map)['code'];
      } else {
        expect(toolResult['status'], 'committed');
        final calendar = saved.generalMode.schedules.single;
        final originals = before.generalMode.schedules.single.events;
        final created = {
          for (final change in changes)
            (change['after'] as Map)['id']: change['after'],
        };
        expect(calendar.events, hasLength(originals.length + _changeCount));
        for (final original in originals) {
          expect(
            calendar.events
                .singleWhere((event) => event.id == original.id)
                .toJson(),
            original.toJson(),
          );
        }
        final verifiedCreatedIds = <String>[];
        for (final entry in created.entries) {
          final savedEvent = calendar.events.singleWhere(
            (event) => event.id == entry.key,
          );
          expect(savedEvent.toJson(), entry.value);
          verifiedCreatedIds.add(savedEvent.id);
        }
        final withoutNew = saved.copyWith(
          applicationLedger: before.applicationLedger,
          generalMode: saved.generalMode.copyWith(
            schedules: [
              calendar.copyWith(
                events: calendar.events
                    .where((event) => !created.containsKey(event.id))
                    .toList(),
              ),
            ],
          ),
        );
        expect(withoutNew.toJson(), before.toJson());
        final receipt = saved.applicationLedger!.receipts.single;
        expect(receipt.operationId, toolResult['operationId']);
        expect(receipt.result['changeCount'], _changeCount);
        final receiptIds = [
          for (final change in receipt.result['changes'] as List)
            ((change as Map)['ref'] as Map)['id'] as String,
        ];
        expect(receiptIds, hasLength(_changeCount));
        expect(receiptIds.toSet(), verifiedCreatedIds.toSet());
        final card = find.byWidgetPredicate(
          (widget) =>
              widget is AgentOperationCard &&
              widget.receipt['operationId'] == receipt.operationId &&
              widget.receipt['status'] == 'committed',
        );
        await until(
          () => card.evaluate().length == 1,
          'the actual committed receipt card',
        );
        result.addAll({
          'receiptCount': saved.applicationLedger!.receipts.length,
          'operationId': receipt.operationId,
          'receiptStatus': receipt.result['status'],
          'receiptChangeCount': receipt.result['changeCount'],
          'receiptIds': receiptIds,
          'verifiedCreatedIds': verifiedCreatedIds,
          'committedReceiptCard': true,
          'unrelatedSnapshotPreserved': true,
        });
      }
      expect(
        AgentNativeSession.historyDigest(
          (await session.app.agent.conversations.read(agentNativeLongId))
              .messages,
        ),
        session.originalHistoryDigest,
      );
      result['originalLongHistoryPreserved'] = true;
    });
  }
}
