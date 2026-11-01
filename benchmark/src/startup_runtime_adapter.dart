import 'package:flutter/foundation.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/services/device_preferences_store.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/main.dart' show AppBootstrap;
import 'package:sked/models/timetable_models.dart';

import 'startup_protocol.dart';
import '../../test/support/memory_conversation_storage.dart';

AppBootstrap createStartupRoot(
  StartupDependencies dependencies,
  void Function(StartupRuntime) onCreated,
) => AppBootstrap(
  lease: dependencies.lease,
  startupDependencies: dependencies.services,
  runtimeFactory: () {
    final repository = AppRepository(storage: dependencies.storage);
    final app = AppRuntime(
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
      devicePreferences: DevicePreferencesStore.memory(),
      repository: repository,
      secretStore: dependencies.secrets,
      schoolSiteService: dependencies.sites,
      backupRestoreJournal: dependencies.journal,
      systemLocaleCodeResolver: () => 'zh',
      // Keep the production codec, save debounce, and scoped runtime lock.
    );
    onCreated(_CurrentStartupRuntime(app, repository));
    return app;
  },
);

class _CurrentStartupRuntime implements StartupRuntime {
  _CurrentStartupRuntime(this.app, this.repository);
  final AppRuntime app;
  @override
  final AppRepository repository;
  @override
  AppData get data => app.session.data;
  @override
  bool get loaded => app.session.isLoaded;
  @override
  bool get loading => app.session.isLoading;
  @override
  bool get writable => app.session.canWrite;
  @override
  bool get privacyAccepted => app.lifecycle.hasAcceptedCurrentPrivacyPolicy;
  @override
  Listenable get changes => app.session.readiness;
}
