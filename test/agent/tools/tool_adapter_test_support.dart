import 'package:sked/agent/tools/workflow_tool_adapters.dart';
import 'package:sked/models/timetable_models.dart';

import '../../support/data_transfer_codec.dart';
import '../../support/timetable_storage_fakes.dart';
import 'platform_tool_test_support.dart';

class ToolAdapterHarness extends PlatformToolHarness {
  late final WorkflowToolAdapters workflows;

  @override
  Future<void> initialize({
    AppData? data,
    MemoryTimetableStorage? storageOverride,
  }) async {
    await super.initialize(data: data, storageOverride: storageOverride);
    workflows = registerWorkflowTools(
      host,
      external: external,
      platformTools: platform,
      codec: inlineDataTransferCodec,
    );
  }
}
