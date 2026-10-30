import 'package:flutter/services.dart' show rootBundle;

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart' show mutationDigest;
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../../models/school_site_models.dart';
import '../../services/agenda_notification_service.dart';
import '../../services/agenda_notification_payload.dart';
import '../../services/android_productivity_bridge.dart';
import '../../services/desktop_layout_preferences.dart';
import '../../services/desktop_window_bridge.dart';
import '../../services/developer_ui_preferences.dart';
import '../../services/school_site_service.dart';
import '../../services/school_web_session_service.dart';
import '../connection/agent_connection_manager.dart';
import '../provider/provider.dart';
import 'application_tool_host.dart';
import 'device_tool_adapters.dart';

PlatformToolAdapters registerPlatformTools(
  ApplicationToolHost host, {
  required ExternalOperationCoordinator external,
  AgendaNotificationService? notifications,
  SchoolSiteService? schoolSites,
  SchoolWebSessionService? schoolWebSession,
  bool schoolWebSessionSupported = false,
  AgentConnectionManager? connectionManager,
  Future<String> Function()? loadBundledSchoolSites,
}) {
  final adapters = PlatformToolAdapters._(
    host: host,
    external: external,
    notifications: notifications,
    schoolSites: schoolSites,
    schoolWebSession: schoolWebSession,
    schoolWebSessionSupported: schoolWebSessionSupported,
    connectionManager: connectionManager,
    loadBundledSchoolSites:
        loadBundledSchoolSites ??
        () => rootBundle.loadString(SchoolSiteService.schoolSitesAssetPath),
  );
  adapters._register();
  return adapters;
}

/// Typed adapters preserve the existing service queues and expose only semantic
/// operations. Tool arguments cannot select a native method or arbitrary store.
class PlatformToolAdapters {
  PlatformToolAdapters._({
    required this._host,
    required this._external,
    required this._notifications,
    required this._schoolSites,
    required this._schoolWebSession,
    required this._schoolWebSessionSupported,
    required this._connectionManager,
    required this._loadBundledSchoolSites,
  });

  final ApplicationToolHost _host;
  final ExternalOperationCoordinator _external;
  AgendaNotificationService? _notifications;
  final SchoolSiteService? _schoolSites;
  SchoolWebSessionService? _schoolWebSession;
  bool _schoolWebSessionSupported;
  final AgentConnectionManager? _connectionManager;
  final Future<String> Function() _loadBundledSchoolSites;
  final _readBack = <String, ExternalEffect>{};
  late final DeviceToolAdapters devices;
  int _serviceBinding = 0;

  /// Rebinds the application's existing service owners when its mounted shell
  /// changes. Passing null unbinds a service instead of creating another owner.
  void bindServices({
    AgendaNotificationService? notifications,
    SchoolWebSessionService? schoolWebSession,
    bool schoolWebSessionSupported = false,
    AndroidProductivityBridge? android,
    DesktopWindowBridge? desktopWindow,
    DesktopLayoutPreferences? layout,
    DeveloperUiPreferences? developerUi,
    Future<ExternalEffectResult> Function(OperationScope)? closeWindow,
  }) {
    _notifications = notifications;
    _schoolWebSession = schoolWebSession;
    _schoolWebSessionSupported = schoolWebSessionSupported;
    _serviceBinding++;
    devices.bindServices(
      android: android,
      desktopWindow: desktopWindow,
      layout: layout,
      developerUi: developerUi,
      closeWindow: closeWindow,
    );
  }

  /// Additional host adapters may share the same external commit/recovery tools.
  /// A registered callback must read state only and must never replay an effect.
  void registerReadBack(String action, ExternalEffect readBack) {
    if (_readBack.containsKey(action)) {
      throw StateError('Duplicate external readback action: $action');
    }
    _readBack[action] = readBack;
  }

  void _add(
    String name,
    String description,
    Map<String, Object?> properties,
    ApplicationToolAction execute, {
    List<String> required = const [],
  }) => _host.register(
    ToolDefinition(
      name: name,
      description: description,
      parameters: {
        'type': 'object',
        'properties': properties,
        'required': required,
        'additionalProperties': false,
      },
    ),
    execute,
  );

  void _register() {
    _add(
      'external.commit',
      'Commit a concrete external plan under the current three-mode policy. Platform outcome and durable receipt are separate.',
      {'planId': _string},
      (args, scope, requestApproval) async {
        _keys(args, {'planId'});
        final plan = _external.plan(_text(args, 'planId'));
        if (plan == null) _expired();
        MutationApproval? approval;
        if (!plan.alreadyRecorded &&
            scope.policy.mode == AgentPermissionMode.ask) {
          approval = await requestApproval(plan);
          if (approval == null) {
            throw const OperationProblem(
              OperationErrorCode.cancelled,
              'The user declined this external change.',
            );
          }
        }
        final result = await _external.commit(
          planId: plan.id,
          scope: scope,
          approval: approval,
        );
        return boundedToolReceipt(result.toJson());
      },
      required: ['planId'],
    );
    _add(
      'external.status',
      'Read a durable external operation receipt without reissuing its action.',
      {'operationId': _string},
      (args, _, _) async {
        _keys(args, {'operationId'});
        final receipt = _external.status(_text(args, 'operationId'));
        return receipt == null
            ? {'status': 'notRecorded', 'operationId': args['operationId']}
            : boundedToolReceipt(receipt.result);
      },
      required: ['operationId'],
    );
    _add(
      'external.reconcile',
      'Read back an unresolved external action through its registered adapter. This never replays the action.',
      {'operationId': _string},
      (args, scope, _) async {
        _keys(args, {'operationId'});
        final operationId = _text(args, 'operationId');
        final receipt = _external.status(operationId);
        if (receipt == null) {
          throw const OperationProblem(
            OperationErrorCode.notFound,
            'No durable external receipt exists.',
          );
        }
        final readBack = _readBack[receipt.result['action']];
        if (readBack == null) {
          _unsupported('This action has no safe readback adapter.');
        }
        return boundedToolReceipt(
          (await _external.reconcile(
            operationId: operationId,
            readBack: readBack,
            scope: scope,
          )).toJson(),
        );
      },
      required: ['operationId'],
    );
    _registerNotifications();
    _registerNotificationActions();
    _registerSchoolSites();
    _registerSchoolSession();
    _registerConnection();
    devices = DeviceToolAdapters(
      host: _host,
      external: _external,
      registerReadBack: registerReadBack,
    );
  }

  void _registerNotifications() {
    _add(
      'notifications.status',
      'Read stored notification preferences and a live platform snapshot. Windows permission can remain unknown.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        return {
          'preferences': _host.session.committedData.notificationSettings
              .toJson(),
          'platform': await _notificationSnapshot(),
        };
      },
    );
    for (final action in [
      'permission',
      'exact_alarm',
      'settings',
      'reconcile',
    ]) {
      final name = 'notifications.$action';
      registerReadBack(name, (_) => _notificationReadBack(action));
      _add(
        '$name.prepare',
        switch (action) {
          'permission' => 'Prepare a system notification permission request; the actual granted, denied or unknown state is read back.',
          'exact_alarm' => 'Prepare an exact-alarm permission request on a supported platform.',
          'settings' => 'Prepare opening system notification settings. Opening settings does not mean permission was granted.',
          _ => 'Prepare rebuilding notifications for the committed application snapshot. This does not prove native delivery.',
        },
        {'operationId': _string},
        (args, scope, _) async {
          _keys(args, {'operationId'});
          final replay = _external.prepareRecorded(
            scope: scope,
            action: name,
            request: _request(args),
            operationId: _optionalOperationId(args),
            readBack: (_) => _notificationReadBack(action),
          );
          if (replay != null) return boundedToolReceipt(replay.summary());
          final service = _notifications;
          if (service == null || !service.isSupported) {
            _unsupported(
              'Notification operations are unavailable on this platform.',
            );
          }
          final snapshot = await _notificationSnapshot();
          scope.checkActive();
          if (snapshot['platform'] == 'unsupported') {
            _unsupported('The native notification gateway is unavailable.');
          }
          if (action == 'exact_alarm' && snapshot['platform'] != 'android') {
            _unsupported(
              'Exact alarms are only available through the Android notification gateway.',
            );
          }
          final dataVersion = _notificationDataVersion();
          final serviceBinding = _serviceBinding;
          final before = switch (action) {
            'permission' => snapshot['permission'],
            'exact_alarm' => snapshot['exactAlarm'],
            'settings' => 'notRequested',
            _ => {
              'dataVersion': dataVersion,
              'pendingCount': snapshot['pendingCount'],
            },
          };
          final after = switch (action) {
            'permission' => 'requestPermission',
            'exact_alarm' => 'requestExactAlarmPermission',
            'settings' => 'requestOpenSettings',
            _ => {
              'reconcileDataVersion': dataVersion,
              'deliveryVerified': false,
            },
          };
          final plan = _external.prepare(
            scope: scope,
            action: name,
            arguments: {'request': _request(args), 'dataVersion': dataVersion},
            version: dataVersion,
            changes: [ResourceChange(key: name, before: before, after: after)],
            validate: () {
              if (_serviceBinding != serviceBinding ||
                  !identical(_notifications, service)) {
                _conflict();
              }
              if (_notificationDataVersion() != dataVersion) _conflict();
            },
            execute: (_) => _executeNotification(action, service),
            readBack: (_) => _notificationReadBack(action),
            operationId: args['operationId'] as String?,
          );
          return boundedToolReceipt(plan.summary());
        },
      );
    }
  }

  void _registerNotificationActions() {
    _add(
      'notifications.reminders',
      'Read locally owned, current reminder cards and their version-bound handles. Candidate pagination can include expired entries; no notification or runtime state is changed.',
      {'offset': _integer, 'limit': _integer},
      (args, scope, _) async {
        _keys(args, {'offset', 'limit'});
        final service = _notifications;
        if (service == null || !service.isSupported) {
          _unsupported('Notification reminders are unavailable.');
        }
        final offset = _number(args, 'offset', 0, 0, 100000);
        final limit = _number(args, 'limit', 50, 1, 100);
        final keys = (await service.reminderActionKeys()).toList()..sort();
        final data = _host.session.committedData;
        final items = <Map<String, Object?>>[];
        for (final key in keys.skip(offset).take(limit)) {
          final request = await service.readActionableReminder(key, data);
          if (request == null) continue;
          final payload = AgendaNotificationPayload.tryDecode(request.payload)!;
          items.add({
            'key': request.key,
            'revision': mutationDigest(request.payload),
            'title': request.title,
            'fireAt': request.fireAt.toIso8601String(),
            'target': payload.target.toJson(),
            'snoozedUntil': (await service.readReminderSnooze(request.payload))
                ?.toIso8601String(),
          });
        }
        scope.checkActive();
        return {
          'items': items,
          'candidateCount': keys.length,
          'hasMore': offset + limit < keys.length,
          'nextOffset': offset + limit < keys.length ? offset + limit : null,
        };
      },
    );
    registerReadBack('notifications.snooze', (operation) async {
      final service = _notifications;
      if (service == null) {
        return ExternalEffectResult(state: ExternalEffectState.unknown);
      }
      final until = await service.readReminderSnooze(
        operation.arguments['payload'] as String,
      );
      return ExternalEffectResult(
        state: until == null
            ? ExternalEffectState.unknown
            : ExternalEffectState.applied,
        details: {
          'snoozedUntil': until?.toIso8601String(),
          'deliveryVerified': false,
        },
      );
    });
    _add(
      'notifications.snooze.prepare',
      'Prepare the existing ten-minute snooze for a reminder returned by notifications.reminders. Requires its exact key and revision. Commit with external.commit; delivery remains unverified.',
      {'key': _string, 'revision': _string, 'operationId': _string},
      (args, scope, _) async {
        _keys(args, {'key', 'revision', 'operationId'});
        final replay = _external.prepareRecorded(
          scope: scope,
          action: 'notifications.snooze',
          request: _request(args),
          operationId: _optionalOperationId(args),
          readBack: _readBack['notifications.snooze'],
        );
        if (replay != null) return boundedToolReceipt(replay.summary());
        final service = _notifications;
        if (service == null || !service.isSupported) {
          _unsupported('Notification reminders are unavailable.');
        }
        final dataVersion = _notificationDataVersion();
        final binding = _serviceBinding;
        final request = await service.readActionableReminder(
          _text(args, 'key'),
          _host.session.committedData,
        );
        if (request == null ||
            mutationDigest(request.payload) != _text(args, 'revision')) {
          _conflict();
        }
        scope.checkActive();
        final plan = _external.prepare(
          scope: scope,
          action: 'notifications.snooze',
          arguments: {'request': _request(args), 'payload': request.payload},
          version: dataVersion,
          changes: [
            ResourceChange(
              key: 'notification.${request.key}',
              before: {'fireAt': request.fireAt.toIso8601String()},
              after: {'snoozeMinutes': 10},
            ),
          ],
          operationId: _optionalOperationId(args),
          validate: () {
            if (_serviceBinding != binding ||
                !identical(_notifications, service) ||
                _notificationDataVersion() != dataVersion) {
              _conflict();
            }
          },
          execute: (_) async {
            final until = await service.snoozeReminder(
              request,
              _host.session.committedData,
            );
            return ExternalEffectResult(
              state: until == null
                  ? ExternalEffectState.failed
                  : ExternalEffectState.applied,
              details: {
                'snoozedUntil': until?.toIso8601String(),
                'accepted': until != null,
                'deliveryVerified': false,
              },
            );
          },
          readBack: _readBack['notifications.snooze'],
        );
        return boundedToolReceipt(plan.summary());
      },
      required: ['key', 'revision'],
    );
    _add(
      'notifications.test.prepare',
      'Prepare an immediate or thirty-second diagnostic notification, or clear only diagnostic notifications. Production reminders remain unchanged. Commit with external.commit.',
      {
        'action': {
          'type': 'string',
          'enum': ['immediate', 'thirty_seconds', 'clear_tests'],
        },
        'channel': {
          'type': 'string',
          'enum': AgendaNotificationTestChannel.values
              .map((v) => v.name)
              .toList(),
        },
        'operationId': _string,
      },
      (args, scope, _) async {
        _keys(args, {'action', 'channel', 'operationId'});
        final replay = _external.prepareRecorded(
          scope: scope,
          action: 'notifications.test',
          request: _request(args),
          operationId: _optionalOperationId(args),
        );
        if (replay != null) return boundedToolReceipt(replay.summary());
        final action = _text(args, 'action');
        if (!{'immediate', 'thirty_seconds', 'clear_tests'}.contains(action)) {
          _invalid('Unknown notification test action.');
        }
        final channel = AgendaNotificationTestChannel.values
            .where((v) => v.name == args['channel'])
            .firstOrNull;
        if ((action != 'clear_tests' && channel == null) ||
            (action == 'clear_tests' && args.containsKey('channel'))) {
          _invalid(
            'Select a channel for a test; clearing tests has no channel.',
          );
        }
        final service = _notifications;
        if (service == null ||
            !service.isSupported ||
            service.gateway is! AgendaNotificationTestGateway) {
          _unsupported('Diagnostic notifications are unavailable.');
        }
        final binding = _serviceBinding;
        final locale = _host.session.committedData.localeCode;
        final plan = _external.prepare(
          scope: scope,
          action: 'notifications.test',
          arguments: {'request': _request(args), 'localeCode': locale},
          version: 1,
          changes: [
            ResourceChange(
              key: 'notifications.test',
              before: null,
              after: {
                'action': action,
                if (channel != null) 'channel': channel.name,
              },
            ),
          ],
          operationId: _optionalOperationId(args),
          validate: () {
            if (_serviceBinding != binding ||
                !identical(_notifications, service)) {
              _conflict();
            }
          },
          execute: (_) async {
            switch (action) {
              case 'immediate':
                await service.showImmediateNotificationTest(
                  channel!,
                  localeCode: locale,
                );
              case 'thirty_seconds':
                await service.scheduleDeveloperNotificationTest(
                  channel!,
                  localeCode: locale,
                );
              case 'clear_tests':
                await (service.gateway as AgendaNotificationTestGateway)
                    .clearTestNotifications();
            }
            return ExternalEffectResult(
              state: ExternalEffectState.applied,
              details: {
                'requestCompleted': true,
                'action': action,
                'deliveryVerified': false,
                'productionRemindersChanged': false,
              },
            );
          },
        );
        return boundedToolReceipt(plan.summary());
      },
      required: ['action'],
    );
  }

  String _notificationDataVersion() {
    final data = _host.session.committedData.toJson()
      ..remove('applicationLedger');
    return mutationDigest(data);
  }

  Future<Map<String, Object?>> _notificationSnapshot() async {
    final service = _notifications;
    if (service == null || !service.isSupported) {
      return const {
        'platform': 'unsupported',
        'permission': 'unsupported',
        'exactAlarm': 'notApplicable',
      };
    }
    final gateway = service.gateway;
    if (gateway is! AgendaNotificationPlatformDiagnosticsGateway) {
      return const {
        'platform': 'unknown',
        'permission': 'unknown',
        'exactAlarm': 'unknown',
      };
    }
    try {
      final snapshot =
          await (gateway as AgendaNotificationPlatformDiagnosticsGateway)
              .platformSnapshot();
      return {
        'platform': snapshot.platform.name,
        'permission': snapshot.permissionState.name,
        'exactAlarm': snapshot.exactAlarmState.name,
        'sampledAt': snapshot.sampledAt.toUtc().toIso8601String(),
        'pendingCount': snapshot.pendingCount,
        'activeCount': snapshot.activeCount,
        'hasPackageIdentity': snapshot.hasPackageIdentity,
      };
    } catch (_) {
      return const {
        'platform': 'unknown',
        'permission': 'unknown',
        'exactAlarm': 'unknown',
        'readFailed': true,
      };
    }
  }

  Future<ExternalEffectResult> _executeNotification(
    String action,
    AgendaNotificationService service,
  ) async {
    try {
      switch (action) {
        case 'permission':
          await service.gateway.requestPermission();
          return await _notificationReadBack(action, requestCompleted: true);
        case 'exact_alarm':
          await service.gateway.requestExactAlarmPermission();
          return await _notificationReadBack(action, requestCompleted: true);
        case 'settings':
          final opened = await service.gateway.openNotificationSettings();
          return ExternalEffectResult(
            state: opened
                ? ExternalEffectState.applied
                : ExternalEffectState.failed,
            details: {
              'opened': opened,
              'permissionGrantedByOpening': false,
              'platform': await _notificationSnapshot(),
            },
          );
        case 'reconcile':
          final before = service.status;
          final version = _notificationDataVersion();
          final result = await service.reconcile(_host.session.committedData);
          final state =
              identical(before, result) || _notificationDataVersion() != version
              ? ExternalEffectState.unknown
              : result.lastError == null
              ? ExternalEffectState.applied
              : ExternalEffectState.unknown;
          return ExternalEffectResult(
            state: state,
            details: {
              'dataVersion': version,
              'directScheduledCount': result.directScheduledCount,
              'retainedPendingCount': result.retainedPendingCount,
              'coverage': result.coverage.name,
              'deliveryVerified': false,
              'platform': await _notificationSnapshot(),
            },
          );
      }
    } catch (_) {
      return ExternalEffectResult(
        state: ExternalEffectState.unknown,
        details: const {'code': 'platformOutcomeUnknown'},
      );
    }
    return ExternalEffectResult(state: ExternalEffectState.unknown);
  }

  Future<ExternalEffectResult> _notificationReadBack(
    String action, {
    bool requestCompleted = false,
  }) async {
    final snapshot = await _notificationSnapshot();
    final status = switch (action) {
      'permission' => snapshot['permission'],
      'exact_alarm' => snapshot['exactAlarm'],
      _ => 'unknown',
    };
    final state = switch (status) {
      'granted' || 'exact' => ExternalEffectState.applied,
      'denied' ||
      'inexact' ||
      'unsupported' ||
      'notApplicable' => ExternalEffectState.failed,
      _ => ExternalEffectState.unknown,
    };
    return ExternalEffectResult(
      state: state,
      details: {
        'platform': snapshot,
        if (requestCompleted) 'requestCompleted': true,
        if (action == 'settings' || action == 'reconcile')
          'exactOperationVerified': false,
      },
    );
  }

  void _registerSchoolSession() {
    _add(
      'school_session.status',
      'Read whether local embedded school-web session cleanup is supported or running.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        return {
          'supported': _schoolWebSessionSupported && _schoolWebSession != null,
          'clearing': _schoolWebSession?.isClearing ?? false,
          'scope': 'localEmbeddedSchoolBrowser',
          'remoteSessionsAffected': false,
        };
      },
    );
    registerReadBack(
      'school_session.clear',
      (_) async => ExternalEffectResult(
        state: ExternalEffectState.unknown,
        details: const {
          'code': 'historicalCleanupCannotBeReadBack',
          'remoteSessionsAffected': false,
        },
      ),
    );
    _add(
      'school_session.clear.prepare',
      'Prepare clearing local school-browser cookies, storage and cache through the existing browser suspension workflow. Remote sessions are unaffected.',
      {'operationId': _string},
      (args, scope, _) async {
        _keys(args, {'operationId'});
        final replay = _external.prepareRecorded(
          scope: scope,
          action: 'school_session.clear',
          request: _request(args),
          operationId: _optionalOperationId(args),
          readBack: _readBack['school_session.clear'],
        );
        if (replay != null) return boundedToolReceipt(replay.summary());
        final service = _schoolWebSession;
        if (!_schoolWebSessionSupported || service == null) {
          _unsupported(
            'This platform does not provide the embedded school-browser cleanup workflow.',
          );
        }
        final binding = _serviceBinding;
        void validate() {
          if (_serviceBinding != binding ||
              !identical(_schoolWebSession, service) ||
              !_schoolWebSessionSupported) {
            _conflict();
          }
          if (service.isClearing) {
            throw const OperationProblem(
              OperationErrorCode.busy,
              'School-browser cleanup is already running.',
            );
          }
        }

        final plan = _external.prepare(
          scope: scope,
          action: 'school_session.clear',
          arguments: {
            'request': _request(args),
            'scope': 'localEmbeddedSchoolBrowser',
          },
          version: 1,
          changes: [
            ResourceChange(
              key: 'schoolSession',
              before: {'localSession': 'presentOrUnknown'},
              after: {
                'localSession': 'cleared',
                'remoteSessionsAffected': false,
              },
            ),
          ],
          validate: validate,
          execute: (_) async {
            try {
              await service.clear();
              return ExternalEffectResult(
                state: ExternalEffectState.applied,
                details: const {
                  'localSession': 'cleared',
                  'remoteSessionsAffected': false,
                },
              );
            } catch (_) {
              return ExternalEffectResult(
                state: ExternalEffectState.unknown,
                details: const {
                  'code': 'localCleanupMayBePartial',
                  'remoteSessionsAffected': false,
                },
              );
            }
          },
          readBack: _readBack['school_session.clear'],
          operationId: args['operationId'] as String?,
        );
        return boundedToolReceipt(plan.summary());
      },
    );
  }

  void _registerSchoolSites() {
    _add(
      'school_sites.list',
      'Read school sites with handles bound to the current source version. Handles are not unversioned list indexes.',
      {'offset': _integer, 'limit': _integer},
      (args, _, _) async {
        _keys(args, {'offset', 'limit'});
        final snapshot = await _sites();
        final offset = _number(args, 'offset', 0, 0, 100000);
        final limit = _number(args, 'limit', 50, 1, 100);
        return {
          'version': snapshot.version,
          'items': [
            for (
              var index = offset;
              index < snapshot.sites.length && index < offset + limit;
              index++
            )
              {
                'handle': _siteHandle(
                  snapshot.version,
                  index,
                  snapshot.sites[index],
                ),
                ...snapshot.sites[index].toJson(),
              },
          ],
          'total': snapshot.sites.length,
          'hasMore': offset + limit < snapshot.sites.length,
        };
      },
    );
    _add(
      'school_sites.get',
      'Read a school site by its version-bound handle.',
      {'handle': _string},
      (args, _, _) async {
        _keys(args, {'handle'});
        final snapshot = await _sites();
        final index = _siteIndex(
          _text(args, 'handle'),
          snapshot.version,
          snapshot.sites,
        );
        return {
          'version': snapshot.version,
          'handle': args['handle'],
          ...snapshot.sites[index].toJson(),
        };
      },
      required: ['handle'],
    );
    _add(
      'school_sites.export',
      'Export the current school-site list as JSON text; this does not create or share a file.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        final snapshot = await _sites();
        return {
          'version': snapshot.version,
          'format': 'school-sites-json',
          'count': snapshot.sites.length,
          'text': encodeSchoolSites(snapshot.sites),
          'fileWritten': false,
        };
      },
    );
    registerReadBack('school_sites.replace', _readBackSites);
    _add(
      'school_sites.prepare',
      'Prepare add, patch, delete, JSON import or restoring bundled school sites. Existing targets require the handle returned by list/get.',
      {
        'action': {
          'type': 'string',
          'enum': ['create', 'patch', 'delete', 'import', 'restore'],
        },
        'handle': _string,
        'site': {
          'type': 'object',
          'properties': {'name': _string, 'loginUrl': _string},
          'additionalProperties': false,
        },
        'source': _string,
        'mode': {
          'type': 'string',
          'enum': ['append', 'replace'],
        },
        'operationId': _string,
      },
      (args, scope, _) async {
        _keys(args, {
          'action',
          'handle',
          'site',
          'source',
          'mode',
          'operationId',
        });
        final operationId = args['operationId'];
        if (operationId != null) {
          if (operationId is! String) _invalid('operationId must be a string.');
          final existing = _external.status(operationId);
          if (existing != null) {
            final recorded =
                existing.result['arguments'] as Map<String, Object?>;
            final request = Map<String, Object?>.of(args)
              ..remove('operationId');
            if (existing.result['action'] != 'school_sites.replace' ||
                mutationDigest(recorded['request']) !=
                    mutationDigest(request)) {
              throw const OperationProblem(
                OperationErrorCode.duplicateMismatch,
                'This operation ID belongs to another school-site request.',
              );
            }
            final retry = _external.prepare(
              scope: scope,
              action: 'school_sites.replace',
              arguments: recorded,
              version: existing.result['version'],
              changes: [
                ResourceChange(
                  key: 'schoolSites',
                  before: recorded['before'],
                  after: recorded['after'],
                ),
              ],
              validate: () {},
              execute: (_) async => throw StateError(
                'Recorded operations cannot be executed again.',
              ),
              readBack: _readBackSites,
              operationId: operationId,
            );
            return boundedToolReceipt(retry.summary());
          }
        }
        final snapshot = await _sites();
        final original = snapshot.sites;
        var candidate = List<SchoolSite>.of(original);
        final action = _text(args, 'action');
        switch (action) {
          case 'create':
            _keys(args, {'action', 'site', 'operationId'});
            candidate.add(_site(args['site']));
          case 'patch':
            _keys(args, {'action', 'handle', 'site', 'operationId'});
            final index = _siteIndex(
              _text(args, 'handle'),
              snapshot.version,
              original,
            );
            candidate[index] = _site(args['site'], base: original[index]);
          case 'delete':
            _keys(args, {'action', 'handle', 'operationId'});
            candidate.removeAt(
              _siteIndex(_text(args, 'handle'), snapshot.version, original),
            );
          case 'import':
            _keys(args, {'action', 'source', 'mode', 'operationId'});
            final imported = decodeSchoolSitesForImport(_text(args, 'source'));
            if (imported.issues.isNotEmpty) {
              _invalid(
                'Every imported school site must be valid; no entries were silently skipped.',
              );
            }
            final mode = args['mode'] ?? 'append';
            if (mode != 'append' && mode != 'replace') {
              _invalid('Import mode must be append or replace.');
            }
            candidate = mode == 'replace'
                ? List.of(imported.sites)
                : [...candidate, ...imported.sites];
          case 'restore':
            _keys(args, {'action', 'operationId'});
            candidate = decodeSchoolSitesStrict(
              await _loadBundledSchoolSites(),
            );
          default:
            _invalid('Unsupported school-site action.');
        }
        scope.checkActive();
        final before = [for (final site in original) site.toJson()];
        final after = [for (final site in candidate) site.toJson()];
        final service = _schoolSites!;
        final plan = _external.prepare(
          scope: scope,
          action: 'school_sites.replace',
          arguments: {
            'before': before,
            'after': after,
            'sourceVersion': snapshot.version,
            'request': Map<String, Object?>.of(args)..remove('operationId'),
          },
          version: snapshot.version,
          changes: [
            ResourceChange(key: 'schoolSites', before: before, after: after),
          ],
          validate: () {
            if (!service.canWrite || service.generation != snapshot.version) {
              _conflict();
            }
          },
          execute: (_) async {
            try {
              await service.saveSites(
                candidate,
                expectedVersion: snapshot.version,
              );
            } on SchoolSiteStaleWriteException {
              return ExternalEffectResult(
                state: ExternalEffectState.failed,
                details: const {'code': 'sourceVersionChanged'},
              );
            } on SchoolSiteWriteBlockedException {
              return ExternalEffectResult(
                state: ExternalEffectState.failed,
                details: const {'code': 'schoolSiteRecoveryRequired'},
              );
            } catch (_) {
              return ExternalEffectResult(
                state: ExternalEffectState.unknown,
                details: const {'code': 'schoolSiteWriteUnknown'},
              );
            }
            return ExternalEffectResult(
              state: ExternalEffectState.applied,
              details: {
                'count': candidate.length,
                'version': service.generation,
              },
            );
          },
          readBack: _readBackSites,
          operationId: args['operationId'] as String?,
        );
        return boundedToolReceipt(plan.summary());
      },
      required: ['action'],
    );
  }

  Future<({List<SchoolSite> sites, int version})> _sites() async {
    final service = _schoolSites;
    if (service == null) _unsupported('School-site storage is unavailable.');
    final loaded = await service.loadSitesResult();
    if (!loaded.canWrite) {
      throw const OperationProblem(
        OperationErrorCode.outcomeUnknown,
        'Recover school-site storage before using this list.',
      );
    }
    return (
      sites: List<SchoolSite>.unmodifiable(loaded.sites),
      version: service.generation,
    );
  }

  Future<ExternalEffectResult> _readBackSites(
    ExternalOperationContext operation,
  ) async {
    try {
      final snapshot = await _sites();
      final actual = mutationDigest([
        for (final site in snapshot.sites) site.toJson(),
      ]);
      final state = actual == mutationDigest(operation.arguments['after'])
          ? ExternalEffectState.applied
          : actual == mutationDigest(operation.arguments['before'])
          ? ExternalEffectState.failed
          : ExternalEffectState.unknown;
      return ExternalEffectResult(
        state: state,
        details: {
          'count': snapshot.sites.length,
          'version': snapshot.version,
          'targetVerified': state == ExternalEffectState.applied,
        },
      );
    } catch (_) {
      return ExternalEffectResult(
        state: ExternalEffectState.unknown,
        details: const {'code': 'schoolSiteReadbackUnknown'},
      );
    }
  }

  void _registerConnection() {
    _add(
      'agent.connection.get',
      'Read the active connection and credential availability without secret values, credential references or URL credentials/query/fragment.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        final settings = _host.session.committedData.agentSettings;
        final status = _connectionManager?.status;
        final endpoint = Uri.tryParse(settings.endpoint);
        return {
          'protocol': settings.protocol.name,
          'endpoint': endpoint == null || !endpoint.hasScheme
              ? ''
              : Uri(
                  scheme: endpoint.scheme,
                  host: endpoint.host,
                  port: endpoint.hasPort ? endpoint.port : null,
                  path: endpoint.path,
                ).toString(),
          'model': settings.model,
          'configured':
              settings.endpoint.isNotEmpty && settings.model.isNotEmpty,
          'credentialAvailable': status?.credentialAvailable ?? false,
          'initialized': status?.initialized ?? false,
          'needsRecovery': status?.needsRecovery ?? false,
          if (status != null) 'credentialStorage': status.storageKind.name,
        };
      },
    );
  }
}

const _string = {'type': 'string'};
const _integer = {'type': 'integer'};
Map<String, Object?> _request(Map<String, Object?> args) =>
    Map<String, Object?>.of(args)..remove('operationId');
String? _optionalOperationId(Map<String, Object?> args) =>
    args['operationId'] == null ? null : _text(args, 'operationId');

void _keys(Map<String, Object?> args, Set<String> allowed) {
  if (args.keys.any((key) => !allowed.contains(key))) {
    _invalid('Unexpected tool argument.');
  }
}

String _text(Map<String, Object?> args, String name) {
  final value = args[name];
  if (value is! String || value.trim().isEmpty) {
    _invalid('$name must be a nonempty string.');
  }
  return value;
}

int _number(
  Map<String, Object?> args,
  String name,
  int fallback,
  int min,
  int max,
) {
  final value = args[name] ?? fallback;
  if (value is! int || value < min || value > max) {
    _invalid('$name is outside the supported range.');
  }
  return value;
}

SchoolSite _site(Object? value, {SchoolSite? base}) {
  if (value is! Map<String, Object?> || value.isEmpty) {
    _invalid('Provide a school-site object.');
  }
  _keys(value, {'name', 'loginUrl'});
  final site = SchoolSite(
    name: value.containsKey('name') ? _text(value, 'name') : base?.name ?? '',
    loginUrl: value.containsKey('loginUrl')
        ? _text(value, 'loginUrl')
        : base?.loginUrl ?? '',
  );
  if (!site.isValid) {
    _invalid('School sites require a name and valid HTTP(S) login URL.');
  }
  return site;
}

String _siteHandle(int version, int index, SchoolSite site) =>
    '$version/$index/${mutationDigest(site.toJson()).substring(0, 16)}';
int _siteIndex(String handle, int version, List<SchoolSite> sites) {
  final parts = handle.split('/');
  final index = parts.length == 3 ? int.tryParse(parts[1]) : null;
  if (index == null ||
      index < 0 ||
      index >= sites.length ||
      handle != _siteHandle(version, index, sites[index])) {
    _expired();
  }
  return index;
}

Never _invalid(String message) =>
    throw OperationProblem(OperationErrorCode.invalidArgument, message);
Never _unsupported(String message) =>
    throw OperationProblem(OperationErrorCode.unsupported, message);
Never _expired() => throw const OperationProblem(
  OperationErrorCode.expired,
  'This plan or source handle has expired; read the current state again.',
);
Never _conflict() => throw const OperationProblem(
  OperationErrorCode.conflict,
  'The prepared source changed; prepare a new plan.',
);
