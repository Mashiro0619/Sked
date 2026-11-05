import 'dart:convert';

import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/time_utils.dart';
import 'agent_conversation_timeline.dart';
import 'agent_setting_labels.dart';

class AgentActivitySummary {
  const AgentActivitySummary(this.title, this.detail);
  final String title;
  final String? detail;
}

/// A bounded reading aid, not a receipt. Only known tool fields are projected;
/// arguments describe the request and never establish that a change happened.
AgentActivitySummary summarizeAgentToolActivity(
  AgentToolActivity tool,
  AppLocalizations l,
) {
  final action = _actionLabel(tool.name, l);
  final args = _object(tool.arguments);
  final resource = _resourceKind(tool.name);
  final subject = resource != null
      ? _resourceLabel(resource, l)
      : switch (tool.name) {
          'agenda.query' => l.workspaceBoth,
          'agenda.free_slots' => l.agentActivityFreeSlots,
          'courses.conflicts' => l.agentActivityConflicts,
          'resources.describe' ||
          'selection.create' => _resourceLabel(args?['kind'], l),
          'period_sets.references' => l.periodTimeSets,
          'conversation.get' ||
          'conversations.get' ||
          'conversations.list' ||
          'conversations.describe' ||
          'runs.status' => l.agentConversations,
          'conversation.history' ||
          'conversation.read' => l.agentHistoryVersions,
          'sources.describe' || 'sources.read' => l.agentSourceMaterial,
          'skills.search' ||
          'skills.load' ||
          'skills.get' ||
          'skills.prepare' => l.agentSkills,
          'memories.search' ||
          'memories.get' ||
          'memories.prepare' => l.agentMemories,
          'agent_settings.describe' ||
          'agent_settings.prepare' => l.agentSettingsTitle,
          'connection.describe' ||
          'agent.connection.get' ||
          'connection.prepare' => l.agentModelSettings,
          'connection.test.prepare' => l.agentTestConnection,
          'connection.models.prepare' ||
          'connection.models.get' => l.agentLoadModels,
          'credentials.request_input' => l.agentApiKey,
          'school_sites.list' || 'school_sites.get' => l.schoolSitesPageTitle,
          'backups.describe' || 'backups.prepare' => l.selectiveBackupTitle,
          'workspaces.describe' || 'navigation.status' => l.workspaceFeatures,
          _ => null,
        };
  final details = <String>[];
  final isResourceQuery =
      resource != null ||
      const {
        'agenda.query',
        'agenda.free_slots',
        'courses.conflicts',
        'selection.create',
      }.contains(tool.name);
  if (args != null && isResourceQuery) {
    final start = _date(args['start'], l);
    final end = _date(args['end'], l);
    if (start != null && end != null) {
      details.add('$start → $end');
    } else if (start != null) {
      details.add('${l.startTime}: $start');
    } else if (end != null) {
      details.add('${l.endTime}: $end');
    }
  }
  if (args != null &&
      (isResourceQuery ||
          const {
            'capabilities.describe',
            'skills.search',
            'memories.search',
          }.contains(tool.name))) {
    final query = _text(args['query']);
    if (query != null) details.add('${l.agentKnowledgeSearch}: $query');
  }
  if (args != null && tool.name == 'settings.get') {
    final keys = args['keys'];
    if (keys is List) {
      final labels = keys
          .take(3)
          .map((key) => agentSettingLabel({'key': key}, l))
          .whereType<String>()
          .toSet();
      if (labels.isNotEmpty) details.add(labels.join(' · '));
    }
  }

  // Read object names only from a completed, identity-matching host projection.
  // Never scan nested metadata, model prose, source text, URLs or credential data.
  if (tool.status == AgentToolActivityStatus.completed && args != null) {
    final result = _object(tool.result);
    String? target;
    if (resource != null && tool.name.endsWith('.get') && result != null) {
      final ref = result['ref'];
      final data = result['data'];
      if (ref is Map &&
          data is Map &&
          args['id'] is String &&
          ref['kind'] == resource &&
          ref['id'] == args['id'] &&
          ref['parentId'] == args['parentId']) {
        target = _text(data['name'] ?? data['title']);
      }
    } else if (const {
          'conversations.get',
          'skills.get',
          'memories.get',
        }.contains(tool.name) &&
        args['id'] is String &&
        result?['id'] == args['id']) {
      target = _text(result?['title']);
    }
    if (target != null) details.insert(0, target);
  }
  return AgentActivitySummary(
    subject == null ? action : '$action · $subject',
    details.isEmpty ? null : details.join('\n'),
  );
}

String? _resourceKind(String name) {
  final parts = name.split('.');
  if (parts.length != 2 || !const {'get', 'list'}.contains(parts[1])) {
    return null;
  }
  return const {
    'timetables': 'timetable',
    'courses': 'course',
    'period_sets': 'periodTimeSet',
    'calendars': 'calendar',
    'events': 'event',
    'occurrences': 'occurrence',
  }[parts[0]];
}

String? _resourceLabel(Object? kind, AppLocalizations l) => switch (kind) {
  'timetable' => l.timetable,
  'course' => l.agentActivityCourses,
  'periodTimeSet' => l.periodTimeSets,
  'calendar' => l.calendars,
  'event' => l.themeWorkspaceSchedule,
  'occurrence' => l.workspaceBoth,
  _ => null,
};

Map<String, dynamic>? _object(String? source) {
  if (source == null || source.length > 128 * 1024) return null;
  try {
    final value = jsonDecode(source);
    return value is Map<String, dynamic> ? value : null;
  } on FormatException {
    return null;
  }
}

String? _text(Object? value) {
  if (value is! String || value.isEmpty || value.length > 4096) return null;
  final text = value
      .replaceAll(RegExp(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return null;
  final characters = text.runes.take(81).toList();
  return characters.length <= 80
      ? text
      : '${String.fromCharCodes(characters.take(80))}…';
}

String? _date(Object? value, AppLocalizations l) {
  if (value is! String || value.length > 64) return null;
  final date = tryParseStrictIsoDateTime(value);
  if (date == null) return null;
  final format = DateFormat.yMd(l.localeName);
  if (value.contains(':')) format.add_Hm();
  return format.format(date.toLocal());
}

String _actionLabel(String name, AppLocalizations l) {
  if (name == 'capabilities.describe' || name == 'resources.describe') {
    return l.agentActivityCapabilities;
  }
  if (name.endsWith('.prepare') || name == 'selection.create') {
    return l.agentActivityPrepare;
  }
  if (name.endsWith('.commit')) return l.agentActivityCommit;
  if (name.startsWith('notifications.')) return l.agentActivityNotifications;
  if (name.startsWith('skills.') ||
      name.startsWith('memories.') ||
      name.startsWith('knowledge.')) {
    return l.agentActivityKnowledge;
  }
  if (name.startsWith('settings.') || name.startsWith('agent_settings.')) {
    return l.agentActivitySettings;
  }
  if (name.startsWith('platform.') || name.startsWith('external.')) {
    return l.agentActivitySystem;
  }
  if (_resourceKind(name) != null ||
      name.startsWith('agenda.') ||
      name.startsWith('courses.') ||
      name.startsWith('sources.') ||
      name.startsWith('conversation.') ||
      name.startsWith('conversations.') ||
      name.startsWith('selection.') ||
      name.startsWith('resources.') ||
      name == 'operations.status') {
    return l.agentActivityRead;
  }
  return l.agentActivityTool;
}
