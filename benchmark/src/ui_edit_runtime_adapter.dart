import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/services/device_preferences_store.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/developer_ui_preferences.dart';

import 'data_operations_runtime.dart';
import 'ui_edit_session.dart';
import 'ui_performance_harness.dart';
import '../../test/support/memory_conversation_storage.dart';

UiEditSession createUiEditSession(DataOperationsDependencies dependencies) =>
    _CurrentUiSession(dependencies);

class _CurrentUiSession implements UiEditSession, UiPerformanceSession {
  _CurrentUiSession(DataOperationsDependencies dependencies)
    : storage = dependencies.storage as UiEditDiskStorage {
    provider = AppRuntime(
      // Explicit test owners prevent this benchmark from opening user stores.
      // ignore: invalid_use_of_visible_for_testing_member
      agentConversationStorage: MemoryConversationStorage(),
      // ignore: invalid_use_of_visible_for_testing_member
      agentAttachmentStorage: MemoryAttachmentStorage(),
      // ignore: invalid_use_of_visible_for_testing_member
      agentKnowledgeStorage: MemoryKnowledgeStorage(),
      // ignore: invalid_use_of_visible_for_testing_member
      agentCredentialStore: MemoryAgentCredentialStore(),
      // ignore: invalid_use_of_visible_for_testing_member
      selectiveRestoreJournal: MemorySelectiveRestoreJournal(),
      // ignore: invalid_use_of_visible_for_testing_member
      backupStagingStorage: MemoryAttachmentStorage(),
      devicePreferences: DevicePreferencesStore(
        layout: layout,
        developerUi: developer,
      ),
      storage: dependencies.storage,
      secretStore: dependencies.secrets,
      schoolSiteService: dependencies.schoolSites,
      backupRestoreJournal: dependencies.journal,
      systemLocaleCodeResolver: () => dependencies.localeCode,
      // The existing UI host supplies a disabled memory notification service.
      // ignore: invalid_use_of_visible_for_testing_member
      workspaceMutationLock: (action) => action(),
    );
  }

  @override
  late final AppRuntime provider;
  @override
  final UiEditDiskStorage storage;
  @override
  final layout = DesktopLayoutPreferences.memory();
  @override
  final developer = DeveloperUiPreferences.memory(visible: false);
  @override
  Widget get app => UiPerformanceApp(session: this);
  @override
  AppData get data => provider.session.data;
  @override
  Future<void> load() async {
    await provider.lifecycle.load();
    await provider.studentCommands.setSelectedWeek(3);
  }

  @override
  Future<void> quiesce() => provider.shutdown.quiesce();
  @override
  Future<void> close() async {
    try {
      await quiesce();
      await layout.flush();
    } finally {
      provider.dispose();
      layout.dispose();
      developer.dispose();
    }
  }
}
