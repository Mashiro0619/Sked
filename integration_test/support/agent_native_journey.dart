import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_transcript.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/theme/sked_expressive_theme.dart';

import 'agent_native_session.dart';
import '../../test/support/agent_workspace_navigation.dart';

const agentNativeJourneyProtocol = 'agent-native-journey-v1';

class AgentNativeJourneyFailure implements Exception {
  const AgentNativeJourneyFailure(this.report, this.cause, this.stackTrace);
  final Map<String, Object?> report;
  final Object cause;
  final StackTrace stackTrace;
  @override
  String toString() => 'Agent native journey failed: $cause';
}

/// Functional evidence only. No engine frame listener, RSS or performance
/// sampling is installed by this journey.
Future<Map<String, Object?>> runAgentNativeJourney(
  WidgetTester tester, {
  required AgentNativeConfig config,
}) async {
  final checkpoints = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'protocol': agentNativeJourneyProtocol,
    'measurement': 'native-functional',
    'status': 'running',
    'label': config.label,
    'startedAt': DateTime.now().toUtc().toIso8601String(),
    'source': {
      'revision': config.revision,
      'note': config.sourceNote,
      'revisionScope': 'caller-supplied source revision for this native build',
    },
    'configuration': config.toJson(),
    'inputScope':
        'framework taps/drags and registered test keyboard on native Flutter',
    'checkpoints': checkpoints,
  };
  Object? primaryError;
  StackTrace? primaryStack;
  AgentNativeSession? session;
  _Journey? activeJourney;
  final httpGuard = AgentNativeHttpGuard();

  Future<void> checkpoint(
    String name,
    Future<Map<String, Object?>> Function() action,
  ) async {
    final result = <String, Object?>{'name': name, 'status': 'running'};
    checkpoints.add(result);
    try {
      result['observations'] = await action();
      _checkFramework(tester);
      result['status'] = 'complete';
    } catch (error, stack) {
      result.addAll({'status': 'failed', 'error': '$error', 'stack': '$stack'});
      try {
        final journey = activeJourney;
        if (journey != null) {
          result['lastObservedState'] = journey.state();
          result['lastObservedAnchor'] = journey.readAnchor()?.toJson();
        }
      } catch (diagnosticError) {
        result['diagnosticError'] = '$diagnosticError';
      }
      rethrow;
    }
  }

  try {
    await checkpoint('environment', () async {
      config.validate();
      if (kIsWeb || (!Platform.isWindows && !Platform.isAndroid)) {
        throw StateError(
          'This entry requires Windows or Android native Flutter.',
        );
      }
      if (Platform.resolvedExecutable.toLowerCase().contains(
        'flutter_tester',
      )) {
        throw StateError(
          'A host VM flutter_tester run is not native evidence.',
        );
      }
      final view = tester.view;
      final logical = view.physicalSize / view.devicePixelRatio;
      if (Platform.isWindows &&
          (logical.width < 1100 || logical.height < 600)) {
        throw StateError(
          'Use an actual Windows window of at least 1100 by 600 logical pixels.',
        );
      }
      final environment = <String, Object?>{
        'platform': Platform.operatingSystem,
        'operatingSystemVersion': Platform.operatingSystemVersion,
        'pid': pid,
        'executable': Platform.resolvedExecutable,
        'dartVersion': Platform.version,
        'abi': Abi.current().toString(),
        'buildMode': kProfileMode
            ? 'profile'
            : (kReleaseMode ? 'release' : 'debug'),
        'physicalWidth': view.physicalSize.width,
        'physicalHeight': view.physicalSize.height,
        'logicalWidth': logical.width,
        'logicalHeight': logical.height,
        'devicePixelRatio': view.devicePixelRatio,
        'refreshRate': view.display.refreshRate,
        'surfaceOverrides': false,
        'nativeSemanticsEnabled':
            tester.binding.platformDispatcher.semanticsEnabled,
        'nativeAccessibilityFeatures':
            '${tester.binding.platformDispatcher.accessibilityFeatures}',
        'accessibilityScope':
            'observed framework flags; no native accessibility acceptance',
      };
      if (Platform.isAndroid) {
        Future<String> property(String name) async {
          final result = await Process.run('/system/bin/getprop', [
            name,
          ]).timeout(const Duration(seconds: 5));
          if (result.exitCode != 0) {
            throw StateError(
              'Cannot record Android property $name: ${result.stderr}',
            );
          }
          return '${result.stdout}'.trim();
        }

        final api = await property('ro.build.version.sdk');
        final abi = await property('ro.product.cpu.abi');
        final emulator = await property('ro.kernel.qemu');
        environment.addAll({
          'androidApi': api,
          'androidAbi': abi,
          'androidQemu': emulator,
          'deviceKind': emulator == '1'
              ? 'emulator'
              : 'unclassified Android native surface',
        });
        _require(
          int.tryParse(api) != null && abi.isNotEmpty,
          'Android provenance is incomplete.',
        );
      } else {
        environment['deviceKind'] = 'Windows native window';
      }
      httpGuard.install();
      report['environment'] = environment;
      return environment;
    });

    late _Journey journey;
    await checkpoint('runtime-loaded', () async {
      final native = session = AgentNativeSession();
      journey = _Journey(tester, native, config);
      activeJourney = journey;
      report['fixture'] = native.fixtureReport();
      await native.app.lifecycle.load().timeout(const Duration(seconds: 20));
      _require(
        native.app.lifecycle.isLoaded && native.app.lifecycle.canWrite,
        'The explicit main store did not load into a writable runtime.',
      );
      _require(
        !native.app.agent.isInitialized && native.conversationLoads == 0,
        'The conversation archive was opened before the user entered Agent.',
      );
      _require(
        native.controlledProvider.requests.isEmpty,
        'Startup contacted the model.',
      );
      return {
        'agentInitialized': native.app.agent.isInitialized,
        'storage': native.storageReport(),
        'applicationOwner': native.app.runtimeType.toString(),
      };
    });
    await checkpoint('product-entry', journey.openProduct);
    await checkpoint('long-history-scroll', journey.scrollLongHistory);
    await checkpoint('stream-and-draft', journey.streamAndDraft);
    await checkpoint('host-continuity', journey.hostContinuity);
    await checkpoint(
      'completion-and-history',
      journey.completeAndSwitchHistory,
    );
    _require(
      httpGuard.attempts == 0,
      'Unexpected HTTP operation was attempted.',
    );
    final native = session!;
    report['providerBeforeCleanup'] = native.controlledProvider.toJson();
    report['storageBeforeCleanup'] = native.storageReport();
  } catch (error, stack) {
    primaryError = error;
    primaryStack = stack;
    report['failure'] = {'error': '$error', 'stack': '$stack'};
  } finally {
    try {
      await checkpoint('cleanup', () async {
        final cleanup = <String, Object?>{};
        try {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          _checkFramework(tester);
          cleanup['unmount'] = 'complete';
        } catch (error, stack) {
          cleanup['unmount'] = {
            'status': 'failed',
            'error': '$error',
            'stack': '$stack',
          };
        }
        final cleanupSession = session;
        if (cleanupSession != null) {
          cleanup['owners'] = await cleanupSession.close();
          cleanup['provider'] = cleanupSession.providerReport();
          cleanup['storage'] = cleanupSession.storageReport();
        }
        try {
          httpGuard.restore();
          cleanup['httpGuardRestored'] = true;
        } catch (error, stack) {
          cleanup['httpGuardRestored'] = false;
          cleanup['httpGuardFailure'] = {'error': '$error', 'stack': '$stack'};
        }
        cleanup['httpOperationAttempts'] = httpGuard.attempts;
        cleanup['httpClientsCreated'] = httpGuard.clientsCreated;
        report['cleanup'] = cleanup;
        final owners = cleanup['owners'];
        _require(
          cleanup['unmount'] == 'complete' &&
              cleanup['httpGuardRestored'] == true &&
              httpGuard.attempts == 0 &&
              (session == null ||
                  owners is Map && owners['status'] == 'complete'),
          'Native cleanup was not completely confirmed; see cleanup observations.',
        );
        return cleanup;
      });
    } catch (error, stack) {
      report['cleanupFailure'] = {'error': '$error', 'stack': '$stack'};
      primaryError ??= error;
      primaryStack ??= stack;
    }
  }
  report['status'] = primaryError == null ? 'passed' : 'failed';
  report['finishedAt'] = DateTime.now().toUtc().toIso8601String();
  if (primaryError != null) {
    throw AgentNativeJourneyFailure(report, primaryError, primaryStack!);
  }
  return report;
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _checkFramework(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null) throw StateError('Native Flutter reported: $error');
}

class _Anchor {
  const _Anchor({
    required this.messageId,
    required this.fraction,
    required this.messageRect,
    required this.viewport,
    required this.pixels,
    required this.extentBefore,
    required this.extentAfter,
    required this.visibleIds,
    required this.renderedText,
    required this.followLatest,
    required this.unread,
  });
  final String messageId;
  final double fraction;
  final Rect messageRect;
  final Rect viewport;
  final double pixels;
  final double extentBefore;
  final double extentAfter;
  final List<String> visibleIds;
  final String renderedText;
  final bool followLatest;
  final bool unread;

  bool sameReading(_Anchor other) {
    // Fraction refers to the actual visible message, including across widths.
    // Normalize a four-logical-pixel tolerance by the smaller message height.
    final tolerance =
        4 / math.min(messageRect.height, other.messageRect.height);
    return messageId == other.messageId &&
        (fraction - other.fraction).abs() <= tolerance;
  }

  Map<String, Object?> toJson() => {
    'messageId': messageId,
    'messageFraction': fraction,
    'messageTop': messageRect.top,
    'messageHeight': messageRect.height,
    'viewportTop': viewport.top,
    'viewportWidth': viewport.width,
    'viewportHeight': viewport.height,
    'scrollPixels': pixels,
    'extentBefore': extentBefore,
    'extentAfter': extentAfter,
    'visibleMessageIds': visibleIds,
    'renderedTextSha256': agentNativeDigest(renderedText),
    'followLatest': followLatest,
    'unread': unread,
  };
}

class _Journey {
  _Journey(this.tester, this.session, this.config);
  final WidgetTester tester;
  final AgentNativeSession session;
  final AgentNativeConfig config;
  _Anchor? _streamAnchor;
  _Anchor? _lastObservedAnchor;
  _Anchor? _lastExpectedAnchor;
  TextEditingValue? _streamInput;
  String _draft = 'Next question while the reply is streaming';
  String? _mainBefore;
  String? _homeEntry;

  Finder key(String value) => find.byKey(ValueKey(value));
  Finder get composer => key('agent-composer').hitTestable();
  Finder get homeNavigation => key('workspace-main-navigation');
  bool get homeEntryVisible =>
      key('workspace-agent-entry').hitTestable().evaluate().length == 1 ||
      homeNavigation.hitTestable().evaluate().length == 1;
  Finder transcript([String id = agentNativeLongId]) =>
      key('agent-transcript-$id').hitTestable();
  TextField get field => tester.widget<TextField>(composer);

  Future<void> until(bool Function() ready, String description) async {
    final watch = Stopwatch()..start();
    while (!ready()) {
      _checkFramework(tester);
      if (watch.elapsed > const Duration(seconds: 20)) {
        throw StateError(
          'Timed out waiting for $description. ${jsonEncode(state())}',
        );
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump();
    _checkFramework(tester);
  }

  Future<void> tap(Finder finder, String description) async {
    await until(() => finder.hitTestable().evaluate().length == 1, description);
    await tester.tap(finder.hitTestable());
    await tester.pump();
  }

  Map<String, Object?> state() => {
    'selectedId': session.app.agent.conversations.selectedId,
    'composerCount': composer.evaluate().length,
    'agentInitialized': session.app.agent.isInitialized,
    'homeAgentVisible':
        key('workspace-agent-entry').hitTestable().evaluate().length == 1,
    'homeNavigationVisible':
        homeNavigation.hitTestable().evaluate().length == 1,
    'lastObservedAnchor': _lastObservedAnchor?.toJson(),
    'lastExpectedAnchor': _lastExpectedAnchor?.toJson(),
    'provider': session.controlledProvider.toJson(),
    'storedDraft': session.app.agent.conversations
        .find(agentNativeLongId)
        ?.draft,
    'runActive': session.app.agent.runtime.state.value
        .runFor(agentNativeLongId)
        .isActive,
    if (composer.evaluate().length == 1) ...{
      'draft': field.controller!.text,
      'selectionBase': field.controller!.selection.baseOffset,
      'selectionExtent': field.controller!.selection.extentOffset,
      'composerFocused': field.focusNode!.hasFocus,
    },
  };

  void assertOwner() {
    _require(
      composer.evaluate().length == 1,
      'Exactly one visible composer must own input.',
    );
    final context = tester.element(composer);
    final view = tester.widget<AgentConversationView>(
      find.ancestor(of: composer, matching: find.byType(AgentConversationView)),
    );
    _require(
      identical(context.read<AgentApplication>(), session.app.agent),
      'Navigation replaced the production AgentApplication.',
    );
    _require(
      identical(context.read<AppSession>(), session.app.session),
      'Navigation replaced the production main session.',
    );
    _require(
      identical(view.repository, session.app.agent.conversations),
      'Navigation replaced the conversation repository.',
    );
    _require(
      session.app.agent.conversations.selectedId == agentNativeLongId,
      'Navigation changed the selected conversation.',
    );
    _require(
      Theme.of(context).brightness == config.brightness,
      'The active host did not receive the requested brightness.',
    );
    _require(
      (MediaQuery.textScalerOf(context).scale(14) / 14 - config.textScale)
              .abs() <
          0.001,
      'The active host did not receive the requested text scale.',
    );
    final motion = SkedMotionPolicy.of(context);
    _require(
      motion.reduceMotion == config.accessible && !motion.disableAnimations,
      'The active host did not receive the requested framework motion policy.',
    );
  }

  Future<void> openFromHome() async {
    _homeEntry = 'main shell navigation / Agent';
    await selectAgentShellDestination(tester, 'agent');
    await until(
      () => composer.evaluate().length == 1 && session.app.agent.isInitialized,
      'the product Agent composer',
    );
    _require(
      find.byType(AgentPage).hitTestable().evaluate().length == 1,
      'The production embedded Agent workspace did not open.',
    );
    _require(
      tester.widget<AgentPage>(find.byType(AgentPage)).embedded,
      'The native journey must use the shared main-shell content.',
    );
    assertOwner();
  }

  Future<Map<String, Object?>> openProduct() async {
    await tester.pumpWidget(AgentNativeApp(session: session, config: config));
    await until(
      () =>
          find.byType(AppHomeScreen).evaluate().length == 1 && homeEntryVisible,
      'the formal home entry',
    );
    _require(
      !session.app.agent.isInitialized && session.conversationLoads == 0,
      'Mounting the home page eagerly opened Agent history.',
    );
    _mainBefore = session.mainSource;
    await openFromHome();
    _require(
      session.app.agent.conversations.selected!.messages.length ==
          agentNativeMessageCount,
      'The full 512-message archive was not loaded.',
    );
    _require(
      field.controller!.text == agentNativeInitialDraft,
      'Opening the long conversation lost its seeded draft.',
    );
    final anchor = await stableAnchor();
    return {
      ...state(),
      'entry': _homeEntry,
      'host': 'AgentPage',
      'historyMessageCount':
          session.app.agent.conversations.selected!.messages.length,
      'anchor': anchor.toJson(),
      'storage': session.storageReport(),
      'sameApplicationAndRepository': true,
    };
  }

  _Anchor? readAnchor([String id = agentNativeLongId]) {
    final target = transcript(id);
    if (target.evaluate().length != 1) return null;
    final scroll = tester.widget<CustomScrollView>(target).controller;
    if (scroll == null ||
        !scroll.hasClients ||
        !scroll.position.hasContentDimensions) {
      return null;
    }
    final viewport = tester.getRect(target);
    if (viewport.height <= 0 || scroll.position.isScrollingNotifier.value) {
      return null;
    }
    final items = find.descendant(
      of: target,
      matching: find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('agent-message-group-');
      }),
    );
    final visible = <(String, Rect, Element)>[];
    for (final element in items.evaluate()) {
      final box = element.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.height <= 0 ||
          rect.bottom <= viewport.top ||
          rect.top >= viewport.bottom) {
        continue;
      }
      final id = (element.widget.key! as ValueKey<String>).value.substring(
        'agent-message-group-'.length,
      );
      visible.add((id, rect, element));
    }
    if (visible.isEmpty) return null;
    visible.sort((a, b) => a.$2.top.compareTo(b.$2.top));
    final first = visible.first;
    final texts = find.descendant(
      of: find.byElementPredicate((element) => identical(element, first.$3)),
      matching: find.byWidgetPredicate(
        (widget) => widget is RichText || widget is EditableText,
      ),
    );
    final rendered = texts
        .evaluate()
        .map((element) {
          // SelectableText (including selectable Markdown) publishes its body
          // through RenderEditable, while ordinary labels use RenderParagraph.
          if (element.widget is EditableText) {
            final state =
                (element as StatefulElement).state as EditableTextState;
            return state.renderEditable.text?.toPlainText() ?? '';
          }
          final paragraph = element.findRenderObject() as RenderParagraph;
          return paragraph.text.toPlainText();
        })
        .join('\n');
    if (first.$1.startsWith('native-message-')) {
      _require(
        rendered.contains(
          'Native history ${first.$1.substring('native-message-'.length)}',
        ),
        'The rendered reading anchor does not match its history message ID.',
      );
    }
    final widget = tester.widget<AgentTranscript>(
      find.ancestor(of: target, matching: find.byType(AgentTranscript)),
    );
    return _Anchor(
      messageId: first.$1,
      fraction: (viewport.top - first.$2.top) / first.$2.height,
      messageRect: first.$2,
      viewport: viewport,
      pixels: scroll.position.pixels,
      extentBefore: scroll.position.extentBefore,
      extentAfter: scroll.position.extentAfter,
      visibleIds: [for (final item in visible) item.$1],
      renderedText: rendered,
      followLatest: widget.position.followLatest,
      unread: widget.position.unread,
    );
  }

  Future<_Anchor> stableAnchor({
    String id = agentNativeLongId,
    _Anchor? expected,
  }) async {
    _lastExpectedAnchor = expected;
    _Anchor? previous;
    _Anchor? current;
    var stable = 0;
    await until(
      () {
        current = readAnchor(id);
        _lastObservedAnchor = current;
        if (current == null ||
            (expected != null && !expected.sameReading(current!))) {
          stable = 0;
          previous = current;
          return false;
        }
        if (previous != null &&
            previous!.sameReading(current!) &&
            (previous!.viewport.height - current!.viewport.height).abs() <
                0.5 &&
            (previous!.viewport.width - current!.viewport.width).abs() < 0.5 &&
            (previous!.viewport.top - current!.viewport.top).abs() < 0.5 &&
            (previous!.viewport.left - current!.viewport.left).abs() < 0.5) {
          stable++;
        } else {
          stable = 0;
        }
        previous = current;
        return stable >= 3;
      },
      expected == null
          ? 'a settled visible transcript anchor'
          : 'the saved message anchor ${expected.messageId} / ${expected.fraction}',
    );
    return current!;
  }

  Future<_Anchor> dragOlder() async {
    for (var index = 0; index < 3; index++) {
      final current = await stableAnchor();
      final distance = (current.viewport.height * 0.72).clamp(180.0, 520.0);
      await tester.drag(transcript(), Offset(0, distance));
      await stableAnchor();
    }
    final anchor = await stableAnchor();
    _require(
      !anchor.followLatest && anchor.extentAfter > 72,
      'Dragging did not leave the latest-reply region.',
    );
    return anchor;
  }

  Future<Map<String, Object?>> scrollLongHistory() async {
    final before = await stableAnchor();
    final after = await dragOlder();
    _require(
      before.messageId != after.messageId,
      'The drag sequence did not change the actual visible history message.',
    );
    _require(
      session.controlledProvider.requests.isEmpty,
      'Reading history contacted the model.',
    );
    return {
      'gesture': 'three downward transcript drags; 72% viewport, bounded 180–520 logical pixels',
      'before': before.toJson(),
      'after': after.toJson(),
      'originalHistorySha256': session.originalHistoryDigest,
    };
  }

  Future<void> enterDraft(String text) async {
    await tester.enterText(composer, text);
    await until(
      () =>
          field.controller!.text == text &&
          session.app.agent.conversations.selected!.draft == text,
      'the real persisted draft',
    );
  }

  void assertActiveRun() {
    _require(
      session.controlledProvider.requests.length == 1 &&
          !(session.controlledProvider.cancellation?.isCancelled ?? true),
      'The host change duplicated or cancelled the provider request.',
    );
    _require(
      session.app.agent.runtime.state.value.runFor(agentNativeLongId).isActive,
      'The controlled run stopped before explicit provider completion.',
    );
  }

  Future<Map<String, Object?>> streamAndDraft() async {
    await enterDraft(agentNativeRequest);
    await until(
      () =>
          key('agent-send').hitTestable().evaluate().length == 1 &&
          tester
                  .widget<IconButton>(key('agent-send').hitTestable())
                  .onPressed !=
              null,
      'the enabled Send action',
    );
    await tap(key('agent-send'), 'the real Send action');
    await until(
      () =>
          session.controlledProvider.started.isCompleted &&
          session.app.agent.runtime.state.value
              .runFor(agentNativeLongId)
              .isActive,
      'the production runtime provider request',
    );
    await enterDraft(_draft);
    await dragOlder();
    await tester.showKeyboard(composer);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: _draft,
        selection: const TextSelection(baseOffset: 3, extentOffset: 15),
      ),
    );
    await until(
      () =>
          field.controller!.selection ==
          const TextSelection(baseOffset: 3, extentOffset: 15),
      'the test keyboard selection',
    );
    final before = await stableAnchor();
    final input = field.controller!.value;
    final focused = field.focusNode!.hasFocus;
    _require(focused, 'The composer must own keyboard focus before the delta.');
    session.controlledProvider.emitDelta();
    await until(
      () =>
          session.app.agent.runtime.state.value
              .runFor(agentNativeLongId)
              .streamingText ==
          agentNativeReply,
      'the visible runtime streaming delta',
    );
    final after = await stableAnchor(expected: before);
    _require(
      field.controller!.value == input && field.focusNode!.hasFocus,
      'The streaming update replaced the draft, selection or keyboard focus.',
    );
    _require(
      after.unread &&
          key('agent-jump-latest').hitTestable().evaluate().length == 1,
      'Streaming while reading history did not expose the unread latest action.',
    );
    assertOwner();
    assertActiveRun();
    _streamAnchor = after;
    _streamInput = input;
    return {
      ...state(),
      'before': before.toJson(),
      'after': after.toJson(),
      'selection': {
        'base': input.selection.baseOffset,
        'extent': input.selection.extentOffset,
      },
      'draftAndFocusPreserved': true,
      'latestActionVisible': true,
    };
  }

  Future<void> closeFullPage() async {
    await selectAgentShellDestination(
      tester,
      session.app.workspaceView.activeMode.name,
    );
    await until(
      () => find.byType(AgentPage).hitTestable().evaluate().isEmpty,
      'the business destination after leaving Agent',
    );
    _require(
      find.byType(AgentPage, skipOffstage: false).evaluate().length == 1,
      'Leaving Agent must retain its existing main-shell host.',
    );
  }

  Future<Map<String, Object?>> hostContinuity() async {
    final before = _streamAnchor!;
    _require(
      field.controller!.text == _streamInput!.text,
      'The pending draft changed before navigation.',
    );
    final history = find
        .byKey(const PageStorageKey('agent-conversation-list'))
        .hitTestable();
    final wideHistory = history.evaluate().isNotEmpty;
    if (wideHistory) {
      final selected = find.descendant(
        of: history,
        matching: key('agent-history-$agentNativeLongId'),
      );
      _require(
        tester.widget<ListTile>(selected).selected,
        'The full workspace history does not mark the shared conversation.',
      );
    }
    _draft = 'Draft edited inside the full Agent workspace';
    await enterDraft(_draft);
    final edited = await stableAnchor(expected: before);
    await closeFullPage();
    _require(
      composer.evaluate().isEmpty,
      'Closing the full page left an interactive composer.',
    );
    assertActiveRun();
    await openFromHome();
    final reopened = await stableAnchor(expected: edited);
    assertOwner();
    assertActiveRun();
    _require(
      field.controller!.text == _draft &&
          session.app.agent.conversations.selected!.draft == _draft,
      'The visible host and stored draft diverged after navigation.',
    );
    return {
      'before': before.toJson(),
      'edited': edited.toJson(),
      'route': 'embedded Agent → main business destination → embedded Agent',
      'reopened': reopened.toJson(),
      'workspaceHistoryVisible': wideHistory,
      ...state(),
      'sameApplicationAndRepository': true,
    };
  }

  Future<void> selectHistory(String id) async {
    final list = find
        .byKey(const PageStorageKey('agent-conversation-list'))
        .hitTestable();
    if (list.evaluate().isEmpty) {
      await openAgentShellHistory(tester);
    }
    await until(
      () => list.evaluate().length == 1,
      'the conversation history list',
    );
    final row = key('agent-history-$id');
    for (
      var attempt = 0;
      attempt < 4 && row.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(list, const Offset(0, -180));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tap(row, 'the selected real conversation row');
    await until(
      () =>
          session.app.agent.conversations.selectedId == id &&
          key('workspace-resource-scrim').hitTestable().evaluate().isEmpty &&
          composer.hitTestable().evaluate().length == 1,
      'the selected conversation and closed history drawer',
    );
  }

  Future<Map<String, Object?>> completeAndSwitchHistory() async {
    assertActiveRun();
    await session.controlledProvider.completeReply().timeout(
      const Duration(seconds: 20),
    );
    await session.app.agent.runtime.waitForIdle().timeout(
      const Duration(seconds: 20),
    );
    await session.app.agent.conversations.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
    await until(
      () =>
          !session.app.agent.runtime.state.value
              .runFor(agentNativeLongId)
              .isActive &&
          key('agent-send').hitTestable().evaluate().length == 1,
      'the completed product run',
    );
    final long = session.app.agent.conversations.find(agentNativeLongId)!;
    _require(
      long.status == ConversationStatus.idle &&
          long.messages.length == agentNativeMessageCount + 2,
      'The single request did not produce exactly one input and one final reply.',
    );
    _require(
      AgentNativeSession.historyDigest(
            long.messages.take(agentNativeMessageCount),
          ) ==
          session.originalHistoryDigest,
      'The original 512-message archive changed.',
    );
    _require(
      long.messages.last.text == agentNativeReply &&
          long.messages.last.role == ConversationRole.assistant &&
          long.messages[agentNativeMessageCount].text == agentNativeRequest,
      'The saved final reply is missing, duplicated or unrelated to the request.',
    );
    await tap(key('agent-jump-latest'), 'the real Jump to latest action');
    await until(() {
      final anchor = readAnchor();
      return anchor != null &&
          anchor.extentAfter <= 2 &&
          anchor.followLatest &&
          !anchor.unread;
    }, 'the actual transcript end');
    final latest = await stableAnchor();
    _require(
      latest.visibleIds.contains(long.messages.last.id),
      'Returning to latest did not reveal the saved final reply.',
    );
    await selectHistory(agentNativeShortId);
    _require(
      field.controller!.text == agentNativeShortDraft,
      'Switching conversations replaced the independent short draft.',
    );
    const editedShortDraft = 'Short conversation edited independently';
    await enterDraft(editedShortDraft);
    await selectHistory(agentNativeLongId);
    _require(
      field.controller!.text == _draft,
      'Switching back lost the long conversation draft.',
    );
    await selectHistory(agentNativeShortId);
    _require(
      field.controller!.text == editedShortDraft,
      'The short draft was not retained independently.',
    );
    await selectHistory(agentNativeLongId);
    await session.app.agent.conversations.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
    final saved = ConversationArchive.decode(session.chatSource);
    final savedLong = saved.conversations.singleWhere(
      (item) => item.id == agentNativeLongId,
    );
    final savedShort = saved.conversations.singleWhere(
      (item) => item.id == agentNativeShortId,
    );
    _require(
      saved.selectedId == agentNativeLongId &&
          savedLong.draft == _draft &&
          savedShort.draft == editedShortDraft &&
          savedShort.messages.length == 2,
      'The stored archive did not confirm independent drafts and selection.',
    );
    _require(
      AgentNativeSession.historyDigest(
                savedLong.messages.take(agentNativeMessageCount),
              ) ==
              session.originalHistoryDigest &&
          savedLong.messages.length == agentNativeMessageCount + 2,
      'The persisted archive does not contain the intact original history and single reply.',
    );
    _require(
      session.controlledProvider.requests.length == 1 &&
          session.controlledProvider.completedReplies == 1,
      'Completion or history navigation duplicated the request.',
    );
    _require(
      savedLong.runs.length == 1 &&
          savedLong.runs.single.status == ConversationRunStatus.completed &&
          savedLong.runs.single.requests.length == 1 &&
          savedLong.runs.single.requests.single.outcome ==
              ConversationAttemptOutcome.completed,
      'The persisted run and its single request did not complete successfully.',
    );
    _require(
      session.mainSource == _mainBefore,
      'The text-only journey changed the main workspace snapshot.',
    );
    assertOwner();
    return {
      ...state(),
      'latest': latest.toJson(),
      'savedLongMessageCount': savedLong.messages.length,
      'savedShortMessageCount': savedShort.messages.length,
      'savedRunStatus': savedLong.runs.single.status.name,
      'savedRequestOutcome': savedLong.runs.single.requests.single.outcome.name,
      'savedLongHistorySha256': AgentNativeSession.historyDigest(
        savedLong.messages.take(agentNativeMessageCount),
      ),
      'independentDrafts': true,
      'mainSnapshotUnchanged': true,
      'storage': session.storageReport(),
    };
  }
}
