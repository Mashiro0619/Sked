import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_knowledge_view.dart';
import 'package:sked/agent/ui/agent_model_settings_form.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/agent/ui/agent_preferences_form.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/agent_settings_page.dart';
import 'package:sked/theme/sked_expressive_theme.dart';

import 'agent_native_session.dart';

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

class _RejectingClient extends http.BaseClient {
  var attempts = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    throw StateError('The MSAA fixture must not use HTTP transport.');
  }
}

/// Only provider events are scripted. Capability discovery, preparation,
/// approval, persistence and receipt rendering use the production application.
class _PreviewProvider extends ProviderClient {
  _PreviewProvider._(this.name, this.transport) : super(client: transport);
  factory _PreviewProvider(String name) =>
      _PreviewProvider._(name, _RejectingClient());

  final String name;
  final _RejectingClient transport;
  final tools = <String>[];
  var requests = 0;
  var closed = false;
  Map<String, dynamic>? prepared;
  Map<String, dynamic>? result;

  Map<String, dynamic> _lastTool(ProviderRequest request) => jsonDecode(
    request.messages.lastWhere((item) => item.role == ProviderRole.tool).text,
  ) as Map<String, dynamic>;

  ProviderResponse _call(String tool, Map<String, Object?> arguments) {
    tools.add(tool);
    return ProviderResponse(
      text: '',
      toolCalls: [
        ProviderToolCall(
          id: 'native-msaa-$name-$requests',
          name: tool,
          arguments: jsonEncode(arguments),
        ),
      ],
      finishReason: 'tool_calls',
    );
  }

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    expect(closed, isFalse);
    expect(apiKey, isEmpty);
    expect(request.endpoint.host, 'native-ui.invalid');
    expect(request.model, 'native-ui-fixture');
    expect(cancellation, isNotNull);
    expect(cancellation!.isCancelled, isFalse);
    requests++;
    final ProviderResponse response;
    switch (requests) {
      case 1:
        expect(
          request.messages
              .lastWhere((item) => item.role == ProviderRole.user)
              .text,
          _draft(name),
        );
        response = _call('capabilities.describe', {
          'names': ['mutation.prepare', 'mutation.commit'],
        });
      case 2:
        expect(
          (_lastTool(request)['tools'] as List).map((tool) => tool['name']),
          containsAll(['mutation.prepare', 'mutation.commit']),
        );
        response = _call('mutation.prepare', {
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
        });
      case 3:
        prepared = _lastTool(request);
        expect(prepared!['planId'], isA<String>());
        expect(prepared!['changeCount'], _changeCount);
        response = _call('mutation.commit', {'planId': prepared!['planId']});
      case 4:
        result = _lastTool(request);
        response = ProviderResponse(
          text: _completedReply,
          toolCalls: const [],
          finishReason: 'stop',
        );
      default:
        throw StateError(
          'Unexpected extra model request in MSAA fixture: $requests.',
        );
    }
    yield ProviderCompleted(response);
  }

  Map<String, Object?> toJson() => {
    'requests': requests,
    'requestedTools': tools,
    'transportAttempts': transport.attempts,
    'closed': closed,
    'preparedPlanId': prepared?['planId'],
    'result': result,
  };

  @override
  void close() {
    if (closed) return;
    closed = true;
    super.close();
    transport.close();
  }
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
  for (final name in ['baseline', 'accessible']) {
    final config = AgentNativeConfig(
      name: name,
      revision: revision,
      label: 'msaa-$name',
    );
    final report = <String, Object?>{
      'protocol': 'agent-msaa-v2',
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
    _PreviewProvider? provider;
    Object? failure;
    StackTrace? failureStack;
    try {
      config.validate();
      guard.install();
      final scripted = provider = _PreviewProvider(name);
      final native = session = AgentNativeSession(provider: scripted);
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
        report['storageAfterCleanup'] = native.storageReport();
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
          expect(finalProvider.transport.attempts, 0);
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
  final _PreviewProvider provider;
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
    // Text and Tab labels can merge into an actionable ancestor. Do not search
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
      final roles = purpose == 'tab'
          ? {37, 43}
          : purpose == 'button'
          ? {43, 56, 57, 58, 62}
          : {41, 42};
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
    const homeControls = [
      'assistant-toggle',
      'general-desktop-toolbar-more',
      'general-toolbar-more-button',
    ];
    await at('mount', () async {
      await session.app.lifecycle.load().timeout(const Duration(seconds: 20));
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
      if (homeControl != 'assistant-toggle') {
        await tap(key(homeControl));
      }
      await tap(key('assistant-toggle'));
      await until(
        () =>
            composer.evaluate().length == 1 && session.app.agent.isInitialized,
        'the production Agent composer',
      );
      await tap(key('agent-new'));
      await until(
        () =>
            session.app.agent.conversations.selectedId != agentNativeLongId &&
            session.app.agent.conversations.selected!.messages.isEmpty &&
            composer.evaluate().length == 1,
        'the actual new conversation',
      );
      conversationId = session.app.agent.conversations.selectedId!;
      await tap(key('agent-open-workspace'));
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
        'path': 'home Agent toggle → new conversation → full AgentPage',
        'homeControl': homeControl == 'assistant-toggle'
            ? homeControl
            : '$homeControl / assistant-toggle',
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
      l.agentModelSettings,
      l.agentRunPreferences,
      l.agentSkills,
      l.agentMemories,
    ];
    final suffixes = [
      'settings-model',
      'settings-preferences',
      'settings-skills',
      'settings-memory',
    ];
    final tabs = <Map<String, Object?>>[];
    report['settingsTabs'] = tabs;
    await at('settings-open', () async {
      await tap(key('agent-conversation-menu'));
      await tap(key('agent-settings'));
      await until(
        () =>
            find.byType(AgentSettingsPage).hitTestable().evaluate().length == 1,
        'the independent Agent settings page',
      );
    });
    for (var index = 0; index < labels.length; index++) {
      await at(suffixes[index], () async {
        final tab = find.widgetWithText(Tab, labels[index]);
        await tap(tab);
        final controller = DefaultTabController.of(tester.element(tab));
        await until(
          () => controller.index == index && !controller.indexIsChanging,
          'the selected settings tab',
        );
        final content = switch (index) {
          0 => find.byType(AgentModelSettingsForm),
          1 => find.byType(AgentPreferencesForm),
          2 => find.byWidgetPredicate(
            (widget) =>
                widget is AgentKnowledgeView &&
                widget.kind == KnowledgeKind.skill,
          ),
          _ => find.byWidgetPredicate(
            (widget) =>
                widget is AgentKnowledgeView &&
                widget.kind == KnowledgeKind.memory,
          ),
        };
        await until(
          () => content.hitTestable().evaluate().length == 1,
          'the selected real settings form',
        );
        final node = actionEvidence(tab.hitTestable());
        expect(node['role'], 'tab');
        expect(node['selected'], isTrue);
        expect(node['label'], contains(labels[index]));
        tabs.add({
          'index': index,
          'title': labels[index],
          'contentType': tester
              .widget(content.hitTestable())
              .runtimeType
              .toString(),
          if (index >= 2) 'knowledgeKind': index == 2 ? 'skill' : 'memory',
          ...node,
        });
        await native(suffixes[index], labels[index], 'tab');
      });
    }
    expect(tabs.map((item) => item['id']).toSet(), hasLength(4));
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
        'return from independent settings',
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
      expect(approval.id, provider.prepared!['planId']);
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
      expect(provider.requests, 3);
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
      await until(() {
        final runtime = session.app.agent.runtime;
        report['decisionObservation'] = runtime.describeRun(conversationId);
        return !runtime.isRunning(conversationId) &&
            !runtime.state.value.runFor(conversationId).isActive;
      }, 'the completed host decision');
      await session.app.agent.runtime.waitForIdle().timeout(
        const Duration(seconds: 20),
      );
      await drain();
      expect(provider.requests, approve ? 4 : 3);
      expect(provider.tools, [
        'capabilities.describe',
        'mutation.prepare',
        'mutation.commit',
      ]);
      expect(preview, findsNothing);
      expect(
        session.app.agent.conversations.selected!.mode,
        AgentPermissionMode.ask,
      );
      // The real host terminates cancelled writes after persisting the tool
      // result. Only approval reaches the provider's final reply round.
      final conversation = session.app.agent.conversations.find(
        conversationId,
      )!;
      final storedConversation = ConversationArchive.decode(session.chatSource)
          .conversations
          .singleWhere((item) => item.id == conversationId);
      expect(storedConversation.toJson(), conversation.toJson());
      final commitCallId = 'native-msaa-${config.name}-3';
      final toolMessages = storedConversation.messages
          .where((item) => item.role == ConversationRole.tool)
          .toList();
      expect(toolMessages.map((item) => item.toolCallId), [
        for (var index = 1; index <= 3; index++)
          'native-msaa-${config.name}-$index',
      ]);
      final toolMessage = toolMessages.singleWhere(
        (item) => item.toolCallId == commitCallId,
      );
      final toolResult = jsonDecode(toolMessage.text) as Map<String, dynamic>;
      final run = storedConversation.runs.single;
      final display = session.app.agent.runtime.state.value.runFor(
        conversationId,
      );
      expect(storedConversation.runId, run.id);
      expect(
        storedConversation.status,
        approve ? ConversationStatus.idle : ConversationStatus.interrupted,
      );
      expect(
        run.status,
        approve
            ? ConversationRunStatus.completed
            : ConversationRunStatus.interrupted,
      );
      expect(run.settledAt, isNotNull);
      expect(run.requests, hasLength(approve ? 4 : 3));
      expect(
        run.requests.map((item) => item.outcome),
        everyElement(ConversationAttemptOutcome.completed),
      );
      expect(run.tools.map((item) => item.name), provider.tools);
      expect(run.tools.map((item) => item.outcome), [
        ConversationAttemptOutcome.completed,
        ConversationAttemptOutcome.completed,
        approve
            ? ConversationAttemptOutcome.completed
            : ConversationAttemptOutcome.failed,
      ]);
      expect(display.isActive, isFalse);
      expect(display.pendingApproval, isNull);
      expect(display.recoveryRequired, isFalse);
      expect(display.phase.name, approve ? 'idle' : 'failed');
      expect(display.errorMessage, approve ? isNull : 'operation.cancelled');
      expect(
        storedConversation.messages.last.role,
        approve ? ConversationRole.assistant : ConversationRole.tool,
      );
      if (approve) {
        expect(provider.result, toolResult);
        expect(storedConversation.messages.last.text, _completedReply);
      } else {
        expect(provider.result, isNull);
        expect(storedConversation.messages.last.toolCallId, commitCallId);
      }
      final saved = AppData.decodeStorageSnapshot(session.mainSource);
      final current = session.app.session.committedData;
      expect(saved.toJson(), current.toJson());
      final result = <String, Object?>{
        'action': approve ? 'approve' : 'reject',
        'beforeCommittedSha256': agentNativeDigest(beforeSource),
        'beforeStoredSha256': agentNativeDigest(beforeStored),
        'afterCommittedSha256': agentNativeDigest(current.encode()),
        'afterStoredSha256': agentNativeDigest(session.mainSource),
        'eventCountBefore': before.generalMode.schedules.single.events.length,
        'eventCountAfter': saved.generalMode.schedules.single.events.length,
        'toolCallId': commitCallId,
        'toolResult': toolResult,
        'terminal': {
          'runtimeActive': session.app.agent.runtime.isRunning(conversationId),
          'phase': display.phase.name,
          'errorCode': display.errorMessage,
          'pendingApproval': display.pendingApproval != null,
          'recoveryRequired': display.recoveryRequired,
          'conversationStatus': storedConversation.status.name,
          'conversationSha256': agentNativeDigest(
            jsonEncode(conversation.toJson()),
          ),
          'storedConversationSha256': agentNativeDigest(
            jsonEncode(storedConversation.toJson()),
          ),
          'runStatus': run.status.name,
          'settled': run.settledAt != null,
          'requestCount': run.requests.length,
          'requestOutcomes': [
            for (final item in run.requests) item.outcome.name,
          ],
          'toolOutcomes': [for (final item in run.tools) item.outcome.name],
          'lastMessageRole': storedConversation.messages.last.role.name,
          'lastMessageToolCallId': storedConversation.messages.last.toolCallId,
          'finalProviderReply': approve,
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
        result['receiptCount'] = 0;
        result['errorCode'] = 'cancelled';
      } else {
        expect(provider.result!['status'], 'committed');
        expect(saved.generalMode.schedules, hasLength(1));
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
                .singleWhere((item) => item.id == original.id)
                .toJson(),
            original.toJson(),
          );
        }
        for (final entry in created.entries) {
          expect(
            calendar.events
                .singleWhere((item) => item.id == entry.key)
                .toJson(),
            entry.value,
          );
        }
        // Compare the complete non-ledger snapshot after removing only the 21
        // newly created events; no unrelated preference or resource may drift.
        final withoutNew = saved.copyWith(
          applicationLedger: before.applicationLedger,
          generalMode: saved.generalMode.copyWith(
            schedules: [
              calendar.copyWith(
                events: calendar.events
                    .where((item) => !created.containsKey(item.id))
                    .toList(),
              ),
            ],
          ),
        );
        expect(withoutNew.toJson(), before.toJson());
        final receipt = saved.applicationLedger!.receipts.single;
        expect(receipt.operationId, provider.result!['operationId']);
        expect(receipt.result['status'], 'committed');
        expect(receipt.result['changeCount'], _changeCount);
        final receiptChanges = receipt.result['changes'] as List;
        expect(receiptChanges, hasLength(_changeCount));
        expect(
          receiptChanges.map((item) => (item as Map)['ref']['id']).toSet(),
          created.keys.toSet(),
        );
        for (final change in receiptChanges) {
          expect((change as Map)['action'], 'created');
        }
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
          'receiptCount': 1,
          'operationId': receipt.operationId,
          'receiptStatus': receipt.result['status'],
          'receiptChangeCount': receiptChanges.length,
          'receiptIds': receiptChanges
              .map((item) => (item as Map)['ref']['id'])
              .toList(),
          'verifiedCreatedIds': created.keys.toList(),
          'unrelatedSnapshotPreserved': true,
          'committedReceiptCard': true,
        });
      }
      expect(
        AgentNativeSession.historyDigest(
          session.app.agent.conversations.find(agentNativeLongId)!.messages,
        ),
        session.originalHistoryDigest,
      );
      result['originalLongHistoryPreserved'] = true;
    });
  }
}
