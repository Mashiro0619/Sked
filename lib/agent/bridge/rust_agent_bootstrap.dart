import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'dart:convert';

import '../skills/shared_skill_loader.dart';
import '../../services/app_storage_layout_io.dart';
import 'generated/api.dart';
import 'generated/api/contracts.dart' as native;
import 'generated/api/models.dart' as view;
import 'generated/frb_generated.dart';

bool? _debugPlatformSupported;
@visibleForTesting
void debugSetRustAgentPlatformSupported(bool? value) =>
    _debugPlatformSupported = value;

bool get rustAgentPlatformSupported =>
    _debugPlatformSupported ??
    (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.android));

Future<void>? _nativeLibrary;

Future<AgentCore> openRustAgentCore({
  required List<native.ToolDefinition> tools,
  required String preamble,
  required bool generateTitles,
}) async {
  if (!rustAgentPlatformSupported) {
    throw UnsupportedError('Agent is not available on this platform.');
  }
  await (_nativeLibrary ??= RustLib.init());
  final root = await AppStorageLayout().directory();
  return AgentCore.initialize(
    config: native.CoreConfig(
      dataDirectory: path.join(root.path, 'agent-native'),
      preamble: preamble,
      tools: tools,
      generateTitles: generateTitles,
    ),
  );
}

Future<Directory> resolveAgentAttachmentStaging() async => Directory(
  path.join((await getTemporaryDirectory()).path, 'sked-agent-attachments'),
);

Future<List<view.ViewKnowledgeRecord>> loadRustBuiltinSkills(
  Set<String> tools,
) async {
  final loader = SharedSkillLoader(
    loadString: rootBundle.loadString,
    registeredTools: tools,
  );
  final records = <view.ViewKnowledgeRecord>[];
  for (final available in await loader.catalog()) {
    final skill = available.skill;
    final body = await rootBundle.loadString(
      '${SharedSkillLoader.assetRoot}${skill.asset}',
    );
    if (sha256.convert(utf8.encode(body)).toString() != skill.contentSha256) {
      throw const SkillPackException(SkillPackError.invalidManifest);
    }
    records.add(
      view.ViewKnowledgeRecord(
        kind: view.ViewKnowledgeKind.skill,
        id: skill.id,
        title: skill.title,
        body: body,
        summary: skill.summary,
        revision: 0,
        enabled: true,
        builtIn: true,
        usesOriginal: true,
        baseVersion: skill.version,
        baseSha256: skill.contentSha256,
        triggers: skill.triggers,
        sourceKinds: skill.sourceKinds,
        requiredTools: skill.requiredTools,
        optionalTools: skill.optionalTools,
        sourceNote: '',
        references: const [],
      ),
    );
  }
  return records;
}
