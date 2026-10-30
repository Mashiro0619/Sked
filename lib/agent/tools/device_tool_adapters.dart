import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart' show mutationDigest;
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../../services/android_productivity_bridge.dart';
import '../../services/desktop_layout_preferences.dart';
import '../../services/desktop_window_bridge.dart';
import '../../services/developer_ui_preferences.dart';
import '../provider/provider.dart';
import '../runtime/agent_runtime_controller.dart' show AgentApprovalRequester;
import 'application_tool_host.dart';

/// Device services belong to the mounted application. Binding never creates a
/// second native plugin owner, and plans cannot outlive their service binding.
class DeviceToolAdapters {
  DeviceToolAdapters({
    required this._host,
    required this._external,
    required void Function(String, ExternalEffect) registerReadBack,
  }) {
    registerReadBack('device.layout', _readLayout);
    registerReadBack('device.preferences', _readPreferences);
    registerReadBack('platform.batteryOptimization', _readBattery);
    registerReadBack(
      'platform.autostart',
      (_) async => ExternalEffectResult(
        state: ExternalEffectState.unknown,
        details: {'grant': 'unknown', 'replayed': false},
      ),
    );
    registerReadBack(
      'window.change',
      (_) async => ExternalEffectResult(
        state: ExternalEffectState.unknown,
        details: _windowSnapshot(),
      ),
    );
    _register();
  }

  final ApplicationToolHost _host;
  final ExternalOperationCoordinator _external;
  AndroidProductivityBridge? _android;
  DesktopWindowBridge? _window;
  DesktopLayoutPreferences? _layout;
  DeveloperUiPreferences? _developer;
  Future<ExternalEffectResult> Function(OperationScope)? _closeWindow;
  int _binding = 0;

  void bindServices({
    AndroidProductivityBridge? android,
    DesktopWindowBridge? desktopWindow,
    DesktopLayoutPreferences? layout,
    DeveloperUiPreferences? developerUi,
    Future<ExternalEffectResult> Function(OperationScope)? closeWindow,
  }) {
    _android = android;
    _window = desktopWindow;
    _layout = layout;
    _developer = developerUi;
    _closeWindow = closeWindow;
    _binding++;
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
      'device.layout.describe',
      'Read all device panel roles and their explicitly saved dimensions. Null means automatic layout; device geometry is excluded from backups.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        final layout = _layout;
        if (layout != null) await layout.load();
        return {
          'supported': layout != null,
          'ready': layout?.ready ?? false,
          'hasUnsavedChanges': layout?.hasUnsavedChanges ?? false,
          'dimensions': ['width', 'height', 'dockedWidth'],
          'roles': [
            for (final region in DesktopLayoutRegion.values)
              {
                'region': region.name,
                'values': layout?.preferenceFor(region)?.toJson() ?? const {},
              },
          ],
          'version': layout == null
              ? null
              : mutationDigest(_layoutSnapshot(layout)),
        };
      },
    );
    _add(
      'device.layout.prepare',
      'Prepare setting or resetting device panel dimensions. Set preserves omitted dimensions; null removes one dimension. Reset with region all resets every role. Commit with external.commit.',
      {
        'region': {
          'type': 'string',
          'enum': ['all', ...DesktopLayoutRegion.values.map((r) => r.name)],
        },
        'action': {
          'type': 'string',
          'enum': ['set', 'reset'],
        },
        'values': {
          'type': 'object',
          'properties': {
            for (final key in ['width', 'height', 'dockedWidth'])
              key: {
                'type': ['number', 'null'],
                'exclusiveMinimum': 0,
              },
          },
          'additionalProperties': false,
        },
        'operationId': _string,
      },
      _prepareLayout,
      required: ['region', 'action'],
    );
    _add(
      'device.preferences.describe',
      'Read the legacy developer preview preference and its reset value; it does not enable the production Agent.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        final service = _developer;
        if (service != null) await service.load();
        return {
          'supported': service != null,
          'ready': service?.ready ?? false,
          'key': 'device.assistantPreviewEnabled',
          'value': service?.assistantVisible,
          'default': service?.previewDefault,
        };
      },
    );
    _add(
      'device.preferences.prepare',
      'Prepare the existing developer preview preference. This never changes Agent permission or enables Agent. Commit with external.commit.',
      {
        'action': {
          'type': 'string',
          'enum': ['set', 'reset'],
        },
        'value': {'type': 'boolean'},
        'operationId': _string,
      },
      _preparePreferences,
      required: ['action'],
    );
    _add(
      'platform.status',
      'Read actual Android battery and vendor settings support. Autostart grant is always unknown because Android exposes no trustworthy grant reader.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        return _platformSnapshot();
      },
    );
    _add(
      'platform.request_action',
      'Prepare a battery-optimization or OEM autostart settings request. Opening a page does not grant permission. Commit with external.commit.',
      {
        'action': {
          'type': 'string',
          'enum': ['batteryOptimization', 'autostart'],
        },
        'operationId': _string,
      },
      _preparePlatform,
      required: ['action'],
    );
    _add(
      'window.status',
      'Read the real native window capability and observed state.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        return _windowSnapshot();
      },
    );
    _add(
      'window.prepare',
      'Prepare minimize, maximize, restore or a guarded close request for a supported native window. Commit with external.commit; close uses normal save and exit guards.',
      {
        'action': {
          'type': 'string',
          'enum': ['minimize', 'maximize', 'restore', 'close'],
        },
        'operationId': _string,
      },
      _prepareWindow,
      required: ['action'],
    );
  }

  Future<Map<String, Object?>> _prepareLayout(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'region', 'action', 'values', 'operationId'});
    final replay = _external.prepareRecorded(
      scope: scope,
      action: 'device.layout',
      request: _request(args),
      operationId: _optionalOperationId(args),
      readBack: _readLayout,
    );
    if (replay != null) return boundedToolReceipt(replay.summary());
    final service = _layout;
    if (service == null) _unsupported('Device layout service is unavailable.');
    await service.load();
    scope.checkActive();
    if (!service.ready || service.hasError || service.hasUnsavedChanges) {
      _busy(
        'Finish saving the current panel geometry before preparing a change.',
      );
    }
    final action = _text(args, 'action'), regionName = _text(args, 'region');
    if (!{'set', 'reset'}.contains(action)) _invalid('Unknown layout action.');
    final regions = regionName == 'all'
        ? DesktopLayoutRegion.values
        : DesktopLayoutRegion.values
              .where((r) => r.name == regionName)
              .toList();
    if (regions.isEmpty || (regionName == 'all' && action != 'reset')) {
      _invalid('Select one known role, or reset all roles.');
    }
    final values = _map(args['values'] ?? const {});
    _keys(values, {'width', 'height', 'dockedWidth'});
    if ((action == 'set' && values.isEmpty) ||
        (action == 'reset' && values.isNotEmpty)) {
      _invalid('Set requires dimensions; reset does not accept dimensions.');
    }
    for (final value in values.values) {
      if (value != null && (value is! num || !value.isFinite || value <= 0)) {
        _invalid('Dimensions must be finite positive numbers or null.');
      }
    }
    final before = _layoutSnapshot(service), desired = <String, Object?>{};
    final changes = <ResourceChange>[];
    for (final region in regions) {
      final old = service.preferenceFor(region)?.toJson() ?? <String, double>{};
      final next = <String, Object?>{...old};
      if (action == 'reset') {
        next.clear();
      } else {
        for (final entry in values.entries) {
          if (entry.value == null) {
            next.remove(entry.key);
          } else {
            next[entry.key] = (entry.value as num).toDouble();
          }
        }
      }
      desired[region.name] = next;
      for (final key in ['width', 'height', 'dockedWidth']) {
        if (old[key] != next[key]) {
          changes.add(
            ResourceChange(
              key: 'device.layout.${region.name}.$key',
              before: old[key],
              after: next[key],
            ),
          );
        }
      }
    }
    final binding = _binding, version = mutationDigest(before);
    final plan = _external.prepare(
      scope: scope,
      action: 'device.layout',
      arguments: {'request': _request(args), 'values': desired},
      version: version,
      changes: changes,
      operationId: args['operationId'] as String?,
      validate: () {
        if (_binding != binding ||
            !identical(_layout, service) ||
            service.hasUnsavedChanges ||
            mutationDigest(_layoutSnapshot(service)) != version) {
          _conflict();
        }
      },
      execute: (_) async {
        for (final region in regions) {
          final next = _map(desired[region.name]);
          service.setPreferredSize(
            region,
            PreferredRegionSize(
              width: (next['width'] as num?)?.toDouble(),
              height: (next['height'] as num?)?.toDouble(),
              dockedWidth: (next['dockedWidth'] as num?)?.toDouble(),
            ),
          );
        }
        if (!await service.flush()) {
          return ExternalEffectResult(
            state: ExternalEffectState.unknown,
            details: {'code': 'layoutSaveUnconfirmed'},
          );
        }
        return _observeLayout(desired);
      },
      readBack: _readLayout,
    );
    return boundedToolReceipt(plan.summary());
  }

  Map<String, Object?> _layoutSnapshot(DesktopLayoutPreferences service) => {
    for (final region in DesktopLayoutRegion.values)
      region.name: service.preferenceFor(region)?.toJson() ?? const {},
  };
  Future<ExternalEffectResult> _readLayout(
    ExternalOperationContext operation,
  ) async => _observeLayout(_map(operation.arguments['values']));
  Future<ExternalEffectResult> _observeLayout(
    Map<String, Object?> expected,
  ) async {
    final service = _layout;
    if (service == null) {
      return ExternalEffectResult(state: ExternalEffectState.unknown);
    }
    await service.load();
    final current = _layoutSnapshot(service);
    final matched = expected.entries.every(
      (e) => mutationDigest(current[e.key]) == mutationDigest(e.value),
    );
    return ExternalEffectResult(
      state:
          service.ready &&
              !service.hasError &&
              !service.hasUnsavedChanges &&
              matched
          ? ExternalEffectState.applied
          : ExternalEffectState.unknown,
      details: {
        'values': {for (final key in expected.keys) key: current[key]},
        'persistenceConfirmed': !service.hasUnsavedChanges && !service.hasError,
      },
    );
  }

  Future<Map<String, Object?>> _preparePreferences(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'action', 'value', 'operationId'});
    final replay = _external.prepareRecorded(
      scope: scope,
      action: 'device.preferences',
      request: _request(args),
      operationId: _optionalOperationId(args),
      readBack: _readPreferences,
    );
    if (replay != null) return boundedToolReceipt(replay.summary());
    final service = _developer;
    if (service == null) _unsupported('Developer preferences are unavailable.');
    await service.load();
    scope.checkActive();
    if (!service.ready || service.busy || service.hasError) {
      _busy('Developer preferences are not ready.');
    }
    final action = _text(args, 'action');
    final value = action == 'reset' ? service.previewDefault : args['value'];
    if (!{'set', 'reset'}.contains(action) ||
        value is! bool ||
        (action == 'reset' && args.containsKey('value'))) {
      _invalid('Use set with a boolean, or reset without a value.');
    }
    final before = service.assistantVisible, binding = _binding;
    final plan = _external.prepare(
      scope: scope,
      action: 'device.preferences',
      arguments: {'request': _request(args), 'value': value},
      version: before,
      changes: [
        ResourceChange(
          key: 'device.assistantPreviewEnabled',
          before: before,
          after: value,
        ),
      ],
      operationId: args['operationId'] as String?,
      validate: () {
        if (_binding != binding ||
            !identical(_developer, service) ||
            service.busy ||
            service.assistantVisible != before) {
          _conflict();
        }
      },
      execute: (_) async {
        final saved = await service.setAssistantVisible(value);
        return ExternalEffectResult(
          state: saved && service.assistantVisible == value
              ? ExternalEffectState.applied
              : ExternalEffectState.unknown,
          details: {
            'value': service.assistantVisible,
            'persistenceConfirmed': saved,
          },
        );
      },
      readBack: _readPreferences,
    );
    return boundedToolReceipt(plan.summary());
  }

  Future<ExternalEffectResult> _readPreferences(
    ExternalOperationContext operation,
  ) async {
    final service = _developer;
    if (service == null) {
      return ExternalEffectResult(state: ExternalEffectState.unknown);
    }
    await service.load();
    return ExternalEffectResult(
      state:
          service.ready &&
              !service.hasError &&
              !service.busy &&
              service.assistantVisible == operation.arguments['value']
          ? ExternalEffectState.applied
          : ExternalEffectState.unknown,
      details: {'value': service.assistantVisible},
    );
  }

  Future<Map<String, Object?>> _platformSnapshot() async {
    final bridge = _android;
    if (bridge == null || !bridge.isSupported) {
      return {'supported': false, 'platform': 'unsupported'};
    }
    try {
      final diagnostics = await bridge.notificationDiagnostics();
      final auto = await bridge.getAutostartSupport();
      return {
        'supported': diagnostics.isSupported,
        'platform': 'android',
        'batteryOptimization': diagnostics.isSupported
            ? (diagnostics.batteryOptimizationIgnored
                  ? 'allowed'
                  : 'notAllowed')
            : 'unknown',
        'autostart': {
          'vendor': auto.vendorId,
          'vendorEntryAvailable': auto.vendorEntryAvailable,
          'fallbackAvailable': auto.fallbackAvailable,
          'grant': 'unknown',
        },
      };
    } catch (_) {
      return {
        'supported': true,
        'platform': 'android',
        'batteryOptimization': 'unknown',
        'autostart': {'grant': 'unknown'},
        'readFailed': true,
      };
    }
  }

  Future<Map<String, Object?>> _preparePlatform(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'action', 'operationId'});
    final action = _text(args, 'action'), bridge = _android;
    if (!{'batteryOptimization', 'autostart'}.contains(action)) {
      _invalid('Unknown Android action.');
    }
    final replay = _external.prepareRecorded(
      scope: scope,
      action: 'platform.$action',
      request: _request(args),
      operationId: _optionalOperationId(args),
      readBack: action == 'batteryOptimization' ? _readBattery : null,
    );
    if (replay != null) return boundedToolReceipt(replay.summary());
    if (bridge == null || !bridge.isSupported) {
      _unsupported('This Android action is unavailable.');
    }
    final before = await _platformSnapshot(), binding = _binding;
    scope.checkActive();
    if (before['supported'] != true) {
      _unsupported('The native Android capability is unavailable.');
    }
    if (action == 'autostart') {
      final support = await bridge.getAutostartSupport();
      if (!support.vendorEntryAvailable && !support.fallbackAvailable) {
        _unsupported('No autostart settings page is available.');
      }
    }
    final plan = _external.prepare(
      scope: scope,
      action: 'platform.$action',
      arguments: {'request': _request(args), 'action': action},
      version: mutationDigest(before),
      changes: [
        ResourceChange(
          key: 'platform.$action',
          before: before[action],
          after: 'requestSettings',
        ),
      ],
      operationId: args['operationId'] as String?,
      validate: () {
        if (_binding != binding ||
            !identical(_android, bridge) ||
            !bridge.isSupported) {
          _conflict();
        }
      },
      execute: (_) async {
        if (action == 'autostart') {
          final result = await bridge.openAutostartSettings();
          return ExternalEffectResult(
            state: result.opened
                ? ExternalEffectState.applied
                : ExternalEffectState.failed,
            details: {
              'opened': result.opened,
              'target': result.target.name,
              'grant': 'unknown',
            },
          );
        }
        await bridge.openBatteryOptimizationSettings();
        return _readBattery(null);
      },
      readBack: action == 'batteryOptimization' ? _readBattery : null,
    );
    return boundedToolReceipt(plan.summary());
  }

  Future<ExternalEffectResult> _readBattery(ExternalOperationContext? _) async {
    final snapshot = await _platformSnapshot();
    return ExternalEffectResult(
      state: snapshot['batteryOptimization'] == 'allowed'
          ? ExternalEffectState.applied
          : ExternalEffectState.unknown,
      details: {'platform': snapshot, 'openingIsNotPermission': true},
    );
  }

  Map<String, Object?> _windowSnapshot() => {
    'supported': _window?.available ?? false,
    if (_window?.available ?? false) ...{
      'maximized': _window!.maximized,
      'focused': _window!.focused,
      'closing': _window!.closing,
    },
  };
  Future<Map<String, Object?>> _prepareWindow(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'action', 'operationId'});
    final action = _text(args, 'action'), window = _window, binding = _binding;
    if (!{'minimize', 'maximize', 'restore', 'close'}.contains(action)) {
      _invalid('Unknown window action.');
    }
    final replay = _external.prepareRecorded(
      scope: scope,
      action: 'window.change',
      request: _request(args),
      operationId: _optionalOperationId(args),
    );
    if (replay != null) return boundedToolReceipt(replay.summary());
    if (window == null ||
        !window.available ||
        (action == 'close' && _closeWindow == null)) {
      _unsupported('This native window action is unavailable.');
    }
    final plan = _external.prepare(
      scope: scope,
      action: 'window.change',
      arguments: {'request': _request(args), 'action': action},
      version: _windowSnapshot(),
      changes: [
        ResourceChange(key: 'window', before: _windowSnapshot(), after: action),
      ],
      operationId: args['operationId'] as String?,
      validate: () {
        if (_binding != binding ||
            !identical(_window, window) ||
            !window.available) {
          _conflict();
        }
      },
      execute: (_) async {
        if (action == 'close') return _closeWindow!(scope);
        if (action == 'minimize') {
          await window.command('minimize');
        } else if (window.maximized != (action == 'maximize')) {
          await window.command('toggleMaximize');
        }
        // The channel acknowledges requesting the operation; later native state
        // events remain authoritative for the resulting window geometry.
        return ExternalEffectResult(
          state: ExternalEffectState.applied,
          details: {
            'requestCompleted': true,
            'action': action,
            'observed': _windowSnapshot(),
          },
        );
      },
    );
    return boundedToolReceipt(plan.summary());
  }
}

const _string = {'type': 'string'};
Map<String, Object?> _request(Map<String, Object?> args) =>
    Map<String, Object?>.of(args)..remove('operationId');
String? _optionalOperationId(Map<String, Object?> args) =>
    args['operationId'] == null ? null : _text(args, 'operationId');
void _keys(Map<String, Object?> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    _invalid('Unknown argument.');
  }
}

String _text(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is! String || value.trim().isEmpty || value.length > 4096) {
    _invalid('Missing or invalid $key.');
  }
  return value;
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    _invalid('Expected an object.');
  }
  return Map<String, Object?>.from(value);
}

Never _invalid(String message) =>
    throw OperationProblem(OperationErrorCode.invalidArgument, message);
Never _unsupported(String message) =>
    throw OperationProblem(OperationErrorCode.unsupported, message);
Never _busy(String message) =>
    throw OperationProblem(OperationErrorCode.busy, message);
Never _conflict() => throw const OperationProblem(
  OperationErrorCode.conflict,
  'The device state changed; prepare a new plan.',
);
