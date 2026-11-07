/// A maintenance index for the executable failure suites. Registering a new
/// tool requires classifying its effect and naming its domain regression owner.
/// Shared commit failures are tested once at the actual coordinator boundary;
/// adapter-specific input, references and platform outcomes stay in that
/// adapter's suite. The inventory test also invokes every write entry with an
/// unknown argument and verifies that none has an effect.
enum WriteBoundary {
  mainCommit,
  externalCommit,
  credentialInput,
  receiptReadback,
  conversationInteraction,
}

class WriteToolCoverage {
  const WriteToolCoverage(this.boundary, this.domainSuite);
  final WriteBoundary boundary;
  final String domainSuite;
}

// These suites exercise permission/revocation, stale plans, dependency
// conflicts, storage failures, cancellation before/after acceptance, durable
// replay and unknown outcomes. This index does not turn the existence of a
// filename into a passing test result; the complete VM gate runs those suites.
const sharedFailureSuites = <WriteBoundary, List<String>>{
  WriteBoundary.conversationInteraction: [
    'test/agent/conversations/conversation_question_test.dart',
    'test/agent/runtime/agent_user_questions_test.dart',
  ],
  WriteBoundary.mainCommit: [
    'test/application/mutation_coordinator_test.dart',
    'test/application/mutation_undo_test.dart',
    'test/agent/runtime/operation_recovery_test.dart',
  ],
  WriteBoundary.externalCommit: [
    'test/application/external_operation_coordinator_test.dart',
    'test/agent/runtime/agent_runtime_controller_test.dart',
    'test/agent/runtime/agent_maintenance_queue_test.dart',
  ],
  WriteBoundary.credentialInput: [
    'test/agent/tools/agent_control_tool_adapters_test.dart',
    'test/agent/connection/agent_connection_manager_test.dart',
  ],
  WriteBoundary.receiptReadback: [
    'test/application/external_operation_coordinator_test.dart',
    'test/agent/runtime/operation_recovery_test.dart',
  ],
};

final writeToolCoverage = <String, WriteToolCoverage>{
  'update_plan': const WriteToolCoverage(
    WriteBoundary.conversationInteraction,
    'test/agent/runtime/agent_task_plan_runtime_test.dart',
  ),
  'ask_user': const WriteToolCoverage(
    WriteBoundary.conversationInteraction,
    'test/agent/runtime/agent_user_questions_test.dart',
  ),
  for (final name in ['mutation.apply', 'operations.undo'])
    name: const WriteToolCoverage(
      WriteBoundary.mainCommit,
      'test/application/resource_mutations_test.dart',
    ),
  for (final name in ['settings.update', 'agent_settings.update'])
    name: const WriteToolCoverage(
      WriteBoundary.mainCommit,
      'test/application/setting_registry_test.dart',
    ),
  'imports.apply': const WriteToolCoverage(
    WriteBoundary.mainCommit,
    'test/agent/imports/school_import_tool_adapter_test.dart',
  ),
  'file_imports.apply': const WriteToolCoverage(
    WriteBoundary.mainCommit,
    'test/agent/tools/workflow_tool_adapters_test.dart',
  ),
  for (final name in ['courses.display.apply', 'navigation.range.apply'])
    name: const WriteToolCoverage(
      WriteBoundary.mainCommit,
      'test/agent/tools/display_range_tool_adapters_test.dart',
    ),
  'external.reconcile': const WriteToolCoverage(
    WriteBoundary.receiptReadback,
    'test/agent/tools/platform_tool_adapters_test.dart',
  ),
  for (final name in [
    'notifications.permission.apply',
    'notifications.exact_alarm.apply',
    'notifications.settings.apply',
    'notifications.reconcile.apply',
    'notifications.snooze.apply',
    'notifications.test.apply',
    'school_sites.apply',
    'school_session.clear.apply',
  ])
    name: const WriteToolCoverage(
      WriteBoundary.externalCommit,
      'test/agent/tools/platform_tool_adapters_test.dart',
    ),
  for (final name in [
    'device.layout.apply',
    'device.preferences.apply',
    'platform.request_action',
    'window.apply',
  ])
    name: const WriteToolCoverage(
      WriteBoundary.externalCommit,
      'test/agent/tools/device_tool_adapters_test.dart',
    ),
  for (final name in [
    'exports.write',
    'maintenance.clear',
    'workspaces.apply',
    'navigation.open',
    'developer.sample.apply',
  ])
    name: const WriteToolCoverage(
      WriteBoundary.externalCommit,
      'test/agent/tools/workflow_tool_adapters_test.dart',
    ),
  'backups.restore': const WriteToolCoverage(
    WriteBoundary.externalCommit,
    'test/backup/selective_backup_tools_test.dart',
  ),
  for (final name in [
    'conversations.create',
    'conversations.rename',
    'conversations.delete',
    'conversations.archive',
    'conversations.export',
    'runs.stop',
    'runs.resume',
  ])
    name: const WriteToolCoverage(
      WriteBoundary.externalCommit,
      'test/agent/tools/conversation_tool_adapters_test.dart',
    ),
  for (final name in [
    'connection.apply',
    'connection.test.apply',
    'connection.models.apply',
  ])
    name: const WriteToolCoverage(
      WriteBoundary.externalCommit,
      'test/agent/tools/agent_control_tool_adapters_test.dart',
    ),
  for (final name in ['skills.apply', 'memories.apply', 'knowledge.undo.apply'])
    name: const WriteToolCoverage(
      WriteBoundary.externalCommit,
      'test/agent/tools/knowledge_tool_adapters_test.dart',
    ),
  'credentials.request_input': const WriteToolCoverage(
    WriteBoundary.credentialInput,
    'test/agent/tools/agent_control_tool_adapters_test.dart',
  ),
};

/// Pure discovery/preparation may retain scoped memory (Skills, selections or
/// artifacts), but cannot save business data, credentials or platform state.
final readOnlyToolInventory = <String>{
  'resources.describe',
  'selection.create',
  'selection.get',
  'capabilities.describe',
  'skills.search',
  'skills.load',
  'skills.get',
  'memories.search',
  'memories.get',
  'knowledge.changes.get',
  for (final family in [
    'timetables',
    'courses',
    'period_sets',
    'calendars',
    'events',
    'occurrences',
  ]) ...['$family.list', '$family.get'],
  'agenda.query',
  'agenda.free_slots',
  'courses.conflicts',
  'period_sets.references',
  'settings.describe',
  'settings.get',
  'agent_settings.describe',
  'operations.status',
  'conversation.get',
  'conversation.history',
  'conversation.read',
  'sources.describe',
  'sources.read',
  'external.status',
  'notifications.status',
  'notifications.reminders',
  'school_session.status',
  'school_sites.list',
  'school_sites.get',
  'school_sites.export',
  'agent.connection.get',
  'device.layout.describe',
  'device.preferences.describe',
  'platform.status',
  'window.status',
  'file_imports.inspect',
  'exports.generate',
  'backups.describe',
  'backups.inspect',
  'workspaces.describe',
  'navigation.status',
  'courses.display.list',
  'conversations.describe',
  'conversations.list',
  'conversations.get',
  'runs.status',
  'connection.describe',
  'connection.models.get',
};
