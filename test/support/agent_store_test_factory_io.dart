import 'dart:async';

import 'package:drift/native.dart';
import 'package:sked/agent/store/agent_store.dart';

import 'agent_store_test_lifecycle.dart';

AgentStore createTestAgentStore({Zone? lifecycleZone}) =>
    TestLifecycleAgentStore(
      AgentDatabase(NativeDatabase.memory()),
      lifecycleZone: lifecycleZone,
    );
