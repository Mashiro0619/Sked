import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/widgets/assistant_pane.dart';

import 'agent_native_session.dart';

const agentFeatureJourneyProtocol = 'agent-native-feature-journey-v1';

/// Each feature owns its model script and any platform boundary it installs.
/// The shared native session continues to own the runtime and persistence.
abstract class AgentNativeFeature {
  String get name;
  ProviderClient get provider;
  Map<String, Object?> providerReport();
  Map<String, Object?> diagnostics();
  Future<void> exercise(AgentFeatureJourney journey);
  Future<Map<String, Object?>> releaseBoundaries();
}

class AgentFeatureJourneyFailure implements Exception {
  const AgentFeatureJourneyFailure(this.report, this.cause, this.stackTrace);
  final Map<String, Object?> report;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'Agent native feature journey failed: $cause';
}

typedef AgentFeatureCheckpoint = Future<void> Function(
  String name,
  Future<Map<String, Object?>> Function() action,
);

Future<Map<String, Object?>> runAgentFeatureJourney(
  WidgetTester tester, {
  required String featureName,
  required AgentNativeFeature Function(String name) createFeature,
  required AgentNativeConfig config,
}) async {
  final checkpoints = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'protocol': agentFeatureJourneyProtocol,
    'measurement': 'native-functional-feature',
    'feature': featureName,
    'status': 'running',
    'label': config.label,
    'startedAt': DateTime.now().toUtc().toIso8601String(),
    'source': {
      'revision': config.revision,
      'note': config.sourceNote,
      'revisionScope': 'caller-supplied source revision for this native build',
    },
    'configuration': config.toJson(),
    'inputScope': 'framework taps, scrolls and registered test keyboard on native Flutter',
    'checkpoints': checkpoints,
  };
  Object? primaryError;
  StackTrace? primaryStack;
  AgentNativeSession? session;
  AgentNativeFeature? feature;
  AgentFeatureJourney? activeJourney;
  final httpGuard = AgentNativeHttpGuard();
  var httpGuardInstalled = false;

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
        result['lastObservedState'] = activeJourney?.state();
        result['featureState'] = feature?.diagnostics();
        result['provider'] = feature?.providerReport();
      } catch (diagnosticError) {
        result['diagnosticError'] = '$diagnosticError';
      }
      rethrow;
    }
  }

  try {
    await checkpoint('environment', () async {
      config.validate();
      final environment = await _nativeEnvironment(tester);
      report['environment'] = environment;
      httpGuard.install();
      httpGuardInstalled = true;
      return environment;
    });

    late AgentFeatureJourney journey;
    await checkpoint('runtime-loaded', () async {
      final selected = feature = createFeature(featureName);
      requireAgentFeature(
        selected.name == featureName,
        'The feature dispatcher returned a different journey.',
      );
      final native = session = AgentNativeSession(provider: selected.provider);
      journey = AgentFeatureJourney(
        tester,
        native,
        config,
        selected,
        checkpoint,
      );
      activeJourney = journey;
      report['fixture'] = native.fixtureReport();
      await native.app.lifecycle.load().timeout(const Duration(seconds: 20));
      requireAgentFeature(
        native.app.lifecycle.isLoaded && native.app.lifecycle.canWrite,
        'The explicit main store did not load into a writable runtime.',
      );
      requireAgentFeature(
        !native.app.agent.isInitialized && native.conversationLoads == 0,
        'Agent history was opened before the real home entry.',
      );
      return {
        'agentInitialized': native.app.agent.isInitialized,
        'storage': native.storageReport(),
        'applicationOwner': native.app.runtimeType.toString(),
        'provider': selected.providerReport(),
      };
    });
    await checkpoint('product-entry', journey.openProduct);
    await feature!.exercise(journey);
    requireAgentFeature(
      httpGuard.attempts == 0,
      'Unexpected dart:io HTTP operation was attempted.',
    );
  } catch (error, stack) {
    primaryError = error;
    primaryStack = stack;
    report['failure'] = {'error': '$error', 'stack': '$stack'};
  } finally {
    try {
      report['providerBeforeCleanup'] = feature?.providerReport();
      report['storageBeforeCleanup'] = session?.storageReport();
    } catch (error, stack) {
      report['finalObservationFailure'] = {
        'error': '$error',
        'stack': '$stack',
      };
      primaryError ??= error;
      primaryStack ??= stack;
    }
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

        final native = session;
        try {
          cleanup['owners'] = native == null
              ? {'status': 'not-created'}
              : await native.close();
        } catch (error, stack) {
          cleanup['owners'] = {
            'status': 'failed',
            'error': '$error',
            'stack': '$stack',
          };
        }
        final selected = feature;
        try {
          // A constructor failure can leave the feature provider without a
          // session owner. Normal closure belongs exclusively to AppRuntime.
          if (native == null) selected?.provider.close();
          cleanup['provider'] = selected?.providerReport();
          cleanup['ownedProvider'] = native?.providerReport();
          cleanup['storage'] = native?.storageReport();
        } catch (error, stack) {
          cleanup['providerFailure'] = {'error': '$error', 'stack': '$stack'};
        }
        try {
          cleanup['featureBoundaries'] = selected == null
              ? {'status': 'not-created'}
              : await selected.releaseBoundaries().timeout(
                  const Duration(seconds: 15),
                );
        } catch (error, stack) {
          cleanup['featureBoundaries'] = {
            'status': 'failed',
            'error': '$error',
            'stack': '$stack',
          };
        }
        try {
          httpGuard.restore();
          cleanup['httpGuardRestored'] = true;
        } catch (error, stack) {
          cleanup['httpGuardRestored'] = false;
          cleanup['httpGuardFailure'] = {'error': '$error', 'stack': '$stack'};
        }
        cleanup['httpGuardInstalled'] = httpGuardInstalled;
        cleanup['httpOperationAttempts'] = httpGuard.attempts;
        cleanup['httpClientsCreated'] = httpGuard.clientsCreated;
        final owners = cleanup['owners'];
        final boundaries = cleanup['featureBoundaries'];
        final provider = cleanup['provider'];
        final complete =
            cleanup['unmount'] == 'complete' &&
            cleanup['httpGuardRestored'] == true &&
            httpGuard.attempts == 0 &&
            (native == null ||
                owners is Map && owners['status'] == 'complete') &&
            (selected == null ||
                boundaries is Map && boundaries['status'] == 'complete') &&
            (selected == null ||
                provider is Map && provider['closed'] == true) &&
            !cleanup.containsKey('providerFailure');
        cleanup['status'] = complete ? 'complete' : 'failed';
        report['cleanup'] = cleanup;
        requireAgentFeature(
          complete,
          'Native feature cleanup was not completely confirmed.',
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
    throw AgentFeatureJourneyFailure(report, primaryError, primaryStack!);
  }
  return report;
}

void requireAgentFeature(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _checkFramework(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null) throw StateError('Native Flutter reported: $error');
}

Future<Map<String, Object?>> _nativeEnvironment(WidgetTester tester) async {
  if (kIsWeb || (!Platform.isWindows && !Platform.isAndroid)) {
    throw StateError('This entry requires Windows or Android native Flutter.');
  }
  if (Platform.resolvedExecutable.toLowerCase().contains('flutter_tester')) {
    throw StateError('A host VM flutter_tester run is not native evidence.');
  }
  final view = tester.view;
  final logical = view.physicalSize / view.devicePixelRatio;
  if (Platform.isWindows && (logical.width < 1100 || logical.height < 600)) {
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
    requireAgentFeature(
      int.tryParse(api) != null && abi.isNotEmpty,
      'Android provenance is incomplete.',
    );
  } else {
    environment['deviceKind'] = 'Windows native window';
  }
  return environment;
}

/// Small product-UI helpers shared by explicitly dispatched feature journeys.
/// No viewport, DPR, navigation, application owner or persistence is replaced.
class AgentFeatureJourney {
  AgentFeatureJourney(
    this.tester,
    this.session,
    this.config,
    this.feature,
    this.checkpoint,
  );
  final WidgetTester tester;
  final AgentNativeSession session;
  final AgentNativeConfig config;
  final AgentNativeFeature feature;
  final AgentFeatureCheckpoint checkpoint;
  late String mainAtEntry;

  Finder key(String value) => find.byKey(ValueKey(value));
  Finder get composer => key('agent-composer').hitTestable();
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
    _checkFramework(tester);
  }

  Future<void> reveal(
    Finder finder,
    String description, {
    Finder? scrollable,
  }) async {
    if (scrollable != null) {
      for (
        var attempt = 0;
        attempt < 12 && finder.evaluate().isEmpty;
        attempt++
      ) {
        await until(
          () => scrollable.hitTestable().evaluate().length == 1,
          'the scrollable for $description',
        );
        await tester.drag(scrollable.hitTestable(), const Offset(0, -140));
        await tester.pump(const Duration(milliseconds: 16));
        _checkFramework(tester);
      }
    }
    await until(() => finder.evaluate().length == 1, description);
    await tester.ensureVisible(finder).timeout(const Duration(seconds: 20));
    await until(
      () => finder.hitTestable().evaluate().length == 1,
      'visible $description',
    );
  }

  Future<void> enterDraft(String draft) async {
    await tester.enterText(composer, draft);
    await until(
      () =>
          field.controller!.text == draft &&
          session.app.agent.conversations.find(agentNativeLongId)?.draft ==
              draft,
      'the visible and repository chat draft',
    );
    await session.app.agent.conversations.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
  }

  Map<String, Object?> state() => {
    'selectedId': session.app.agent.conversations.selectedId,
    'composerCount': composer.evaluate().length,
    'agentInitialized': session.app.agent.isInitialized,
    'storedDraft': session.app.agent.conversations
        .find(agentNativeLongId)
        ?.draft,
    'runActive': session.app.agent.runtime.state.value
        .runFor(agentNativeLongId)
        .isActive,
    'provider': feature.providerReport(),
    'storage': session.storageReport(),
    if (composer.evaluate().length == 1) 'visibleDraft': field.controller!.text,
  };

  Map<String, Object?> configurationAt(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final motion = SkedMotionPolicy.of(context);
    requireAgentFeature(
      brightness == config.brightness,
      'The product surface has the wrong brightness.',
    );
    requireAgentFeature(
      (textScale - config.textScale).abs() < 0.001,
      'The product surface has the wrong text scale.',
    );
    requireAgentFeature(
      motion.reduceMotion == config.accessible &&
          !motion.disableAnimations &&
          !MediaQuery.of(context).disableAnimations,
      'The product surface has the wrong framework motion configuration.',
    );
    return {
      'brightness': brightness.name,
      'textScale': textScale,
      'reduceMotion': motion.reduceMotion,
      'disableAnimations': motion.disableAnimations,
      'mediaQueryDisableAnimations': MediaQuery.of(context).disableAnimations,
    };
  }

  Map<String, Object?> assertOwner() {
    requireAgentFeature(
      composer.evaluate().length == 1,
      'Exactly one visible composer must own input.',
    );
    final context = tester.element(composer);
    final view = tester.widget<AgentConversationView>(
      find.ancestor(of: composer, matching: find.byType(AgentConversationView)),
    );
    requireAgentFeature(
      identical(context.read<AgentApplication>(), session.app.agent),
      'The AgentApplication owner changed.',
    );
    requireAgentFeature(
      identical(context.read<AppSession>(), session.app.session),
      'The main AppSession owner changed.',
    );
    requireAgentFeature(
      identical(view.repository, session.app.agent.conversations),
      'The conversation repository owner changed.',
    );
    requireAgentFeature(
      session.app.agent.conversations.selectedId == agentNativeLongId,
      'The selected conversation changed.',
    );
    return configurationAt(context);
  }

  Future<Map<String, Object?>> openProduct() async {
    await tester.pumpWidget(AgentNativeApp(session: session, config: config));
    const homeControls = [
      'assistant-toggle',
      'general-desktop-toolbar-more',
      'general-toolbar-more-button',
    ];
    await until(
      () =>
          find.byType(AppHomeScreen).evaluate().length == 1 &&
          homeControls.any(
            (id) => key(id).hitTestable().evaluate().length == 1,
          ),
      'the actual home Agent entry',
    );
    requireAgentFeature(
      !session.app.agent.isInitialized && session.conversationLoads == 0,
      'Mounting the home page eagerly opened Agent history.',
    );
    mainAtEntry = session.mainSource;
    final homeControl = homeControls.firstWhere(
      (id) => key(id).hitTestable().evaluate().length == 1,
    );
    if (homeControl != 'assistant-toggle') {
      await tap(key(homeControl), 'the visible general workspace More menu');
      await reveal(key('assistant-toggle'), 'the actual home Agent menu item');
    }
    await tap(key('assistant-toggle'), 'the home Agent entry');
    await until(
      () => composer.evaluate().length == 1 && session.app.agent.isInitialized,
      'the actual Agent composer',
    );
    requireAgentFeature(
      Platform.isWindows
          ? find.byType(AgentAssistantPane).hitTestable().evaluate().isNotEmpty
          : find.byType(AgentPage).hitTestable().evaluate().length == 1,
      'The expected native product host did not open.',
    );
    final observedConfig = assertOwner();
    requireAgentFeature(
      session.app.agent.conversations.selected!.messages.length ==
              agentNativeMessageCount &&
          field.controller!.text == agentNativeInitialDraft,
      'Opening Agent lost the seeded history or draft.',
    );
    return {
      ...state(),
      'entry': Platform.isWindows
          ? 'home assistant toggle'
          : 'home More menu / Agent',
      'entryControl': homeControl == 'assistant-toggle'
          ? homeControl
          : '$homeControl / assistant-toggle',
      'host': Platform.isWindows ? 'AgentAssistantPane' : 'AgentPage',
      'historyMessageCount':
          session.app.agent.conversations.selected!.messages.length,
      'initialDraft': field.controller!.text,
      'mainSha256': agentNativeDigest(mainAtEntry),
      'sameApplicationAndRepository': true,
      'configuration': observedConfig,
    };
  }
}
