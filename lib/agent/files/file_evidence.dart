import 'dart:convert';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show AnyhowException;

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../bridge/generated/api/file_contracts.dart';
import '../operations/tool_outcome.dart';

const fileWriteAction = 'files.write';

Map<String, Object?> fileResourceJson(FileResourceRef value) => {
  'kind': value.kind.name,
  'value': value.value,
};

Map<String, Object?> fileVersionJson(FileVersion value) => {
  'resourceId': value.resourceId,
  'version': value.version,
  'sha256': ?value.sha256,
  'byteLength': ?value.byteLength,
  'modifiedAtMs': ?value.modifiedAtMs,
};

Map<String, Object?> fileEntryJson(FileEntry value) => {
  'resource': fileResourceJson(value.resource),
  'name': value.name,
  'kind': value.kind.name,
  'version': fileVersionJson(value.version),
  'isLink': value.isLink,
};

Map<String, Object?> fileSnapshotJson(FileSnapshot value) => {
  'id': value.id,
  if (value.source case final source?) 'source': fileResourceJson(source),
  if (value.sourceVersion case final version?)
    'sourceVersion': fileVersionJson(version),
  'content': fileResourceJson(value.content),
  'contentVersion': fileVersionJson(value.contentVersion),
};

Map<String, Object?> fileErrorJson(FileError value) => {
  'code': value.code.name,
  'message': value.message,
  'osCode': ?value.osCode,
};

Map<String, Object?>? fileErrorFromException(Object error) {
  if (error is! AnyhowException) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(error.message);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, Object?>) return null;
  final code = decoded['code'];
  if (decoded['message'] is! String ||
      !FileErrorCode.values.any((entry) => entry.name == code) ||
      decoded['osCode'] != null && decoded['osCode'] is! int) {
    return null;
  }
  return {
    'code': decoded['code'],
    'message': decoded['message'],
    'osCode': ?decoded['osCode'],
  };
}

Map<String, Object?> fileWriteRequestJson(FileWriteRequest value) => {
  'target': fileResourceJson(value.target),
  if (value.expected case final expected?)
    'expected': fileVersionJson(expected),
  'contentSnapshotId': value.contentSnapshotId,
};

Map<String, Object?> fileWritePreviewJson(FileWritePreview value) =>
    immutableMutationJson({
      'writeId': value.writeId,
      'specDigest': value.specDigest,
      'target': fileResourceJson(value.target),
      'resolvedTarget': fileResourceJson(value.resolvedTarget),
      'parent': fileEntryJson(value.parent),
      if (value.expected case final expected?)
        'expected': fileVersionJson(expected),
      'content': fileSnapshotJson(value.content),
    }) as Map<String, Object?>;

FileWriteIdentity fileIdentityFromOperation(
  ExternalOperationContext operation,
) {
  final preview = operation.arguments['write'];
  if (operation.action != fileWriteAction ||
      preview is! Map<String, Object?> ||
      preview['writeId'] is! String ||
      preview['specDigest'] is! String ||
      preview['specDigest'] != operation.version) {
    throw const OperationProblem(
      OperationErrorCode.outcomeUnknown,
      'The original file write identity cannot be recovered.',
    );
  }
  return FileWriteIdentity(
    writeId: preview['writeId']! as String,
    operationId: operation.operationId,
    specDigest: preview['specDigest']! as String,
  );
}

Map<String, Object?> fileWriteIdentityJson(FileWriteIdentity value) => {
  'writeId': value.writeId,
  'operationId': value.operationId,
  'specDigest': value.specDigest,
};

Map<String, Object?> fileWriteReceiptJson(FileWriteReceipt value) => {
  'identity': fileWriteIdentityJson(value.identity),
  'state': value.state.name,
  'targetChanged': value.targetChanged,
  'target': fileResourceJson(value.target),
  if (value.currentVersion case final version?)
    'currentVersion': fileVersionJson(version),
  if (value.originalSnapshot case final snapshot?)
    'originalSnapshot': fileSnapshotJson(snapshot),
  'recoveryResources': [
    for (final value in value.recoveryResources) fileEntryJson(value),
  ],
  if (value.error case final error?) 'error': fileErrorJson(error),
};

/// A terminal conflict can have known file effects. Native Conflict requires
/// finalized evidence; an interrupted journal is reported as Unknown instead.
ExternalEffectResult fileWriteEffect(
  FileWriteReceipt receipt, {
  required FileWriteIdentity expected,
}) {
  if (receipt.identity.writeId != expected.writeId ||
      receipt.identity.operationId != expected.operationId ||
      receipt.identity.specDigest != expected.specDigest) {
    return ExternalEffectResult(
      state: ExternalEffectState.unknown,
      dataStatus: ExternalDataState.unknown,
      details: const {
        'error': {
          'code': 'identityMismatch',
          'message': 'The file receipt does not match the original operation.',
        },
      },
    );
  }
  final state = switch ((receipt.state, receipt.targetChanged)) {
    (FileWriteState.published, true) when receipt.currentVersion != null =>
      ExternalEffectState.applied,
    (FileWriteState.conflict, true)
        when receipt.originalSnapshot != null &&
            receipt.recoveryResources.isNotEmpty =>
      ExternalEffectState.applied,
    (FileWriteState.notStarted || FileWriteState.conflict, false) =>
      ExternalEffectState.failed,
    _ => ExternalEffectState.unknown,
  };
  return ExternalEffectResult(
    state: state,
    dataStatus: switch (state) {
      ExternalEffectState.applied => ExternalDataState.committed,
      ExternalEffectState.failed => ExternalDataState.unchanged,
      _ => ExternalDataState.unknown,
    },
    details: {'file': fileWriteReceiptJson(receipt)},
  );
}

Map<String, Object?> fileCommitResultJson(
  ExternalMutationCommitResult result,
) => projectFileResult({
  ...result.toJson(),
  'completedAt': result.receipt.completedAtIso,
});

/// The external ledger records observed effects. Publication success is taken
/// from the original file receipt, including in status queries and recovery.
Map<String, Object?> projectFileResult(Map<String, Object?> value) {
  if (ToolOutcome.fromResult(value).kind ==
      ToolOutcomeKind.needsReconciliation) {
    return value;
  }
  final effect = value['effectResult'];
  final file = effect is Map ? effect['file'] : null;
  if (file is! Map) return value;
  final error = file['error'];
  return switch (file['state']) {
    'published' => value,
    'conflict' => {
      ...value,
      'status': 'failed',
      'error':
          error ??
          const {
            'code': 'conflict',
            'message':
                'The destination changed before the new content was published.',
          },
    },
    'notStarted' => {
      ...value,
      'status': error is Map && error['code'] == 'cancelled'
          ? 'cancelled'
          : 'failed',
      'error':
          error ??
          const {
            'code': 'notStarted',
            'message': 'The file write did not start.',
          },
    },
    _ => value,
  };
}

Map<String, Object?> fileDirectoryPageJson(FileDirectoryPage value) => {
  'directory': fileEntryJson(value.directory),
  'entries': [for (final entry in value.entries) fileEntryJson(entry)],
  'issues': [for (final issue in value.issues) _fileIssueJson(issue)],
  'nextCursor': value.nextCursor,
};

Map<String, Object?> fileSearchPageJson(FileSearchPage value) => {
  'hits': [
    for (final hit in value.hits)
      {
        'entry': fileEntryJson(hit.entry),
        'byteOffset': ?hit.byteOffset,
        'line': ?hit.line,
        'matchedText': hit.matchedText,
      },
  ],
  'issues': [for (final issue in value.issues) _fileIssueJson(issue)],
  'nextCursor': value.nextCursor,
};

Map<String, Object?> _fileIssueJson(FileIssue value) => {
  'resource': fileResourceJson(value.resource),
  'error': fileErrorJson(value.error),
};
