import 'dart:typed_data';

import 'school_site_store_stub.dart'
    if (dart.library.io) 'school_site_store_io.dart';

enum SchoolSiteStoreArtifact { primary, temporary, backup, browser }

enum SchoolSiteStoreIssueType { invalidEncoding, readFailure, recoveryArtifact }

class SchoolSiteStoreIssue {
  const SchoolSiteStoreIssue({
    required this.artifact,
    required this.type,
    required this.error,
    this.stackTrace,
  });

  final SchoolSiteStoreArtifact artifact;
  final SchoolSiteStoreIssueType type;
  final Object error;
  final StackTrace? stackTrace;
}

class SchoolSiteStoreCandidate {
  const SchoolSiteStoreCandidate({
    required this.source,
    this.artifact = SchoolSiteStoreArtifact.primary,
    Future<void> Function()? promote,
    Future<void> Function(bool preservePrimaryAsBackup)? promoteWithContext,
  }) : _promote = promote,
       _promoteWithContext = promoteWithContext;

  final String source;
  final SchoolSiteStoreArtifact artifact;
  final Future<void> Function()? _promote;
  final Future<void> Function(bool preservePrimaryAsBackup)?
  _promoteWithContext;

  Future<void> promote({bool preservePrimaryAsBackup = true}) async {
    final contextualAction = _promoteWithContext;
    if (contextualAction != null) {
      await contextualAction(preservePrimaryAsBackup);
      return;
    }
    final action = _promote;
    if (action != null) {
      await action();
    }
  }
}

class SchoolSiteStoreLoadResult {
  const SchoolSiteStoreLoadResult({
    required this.candidates,
    this.issues = const <SchoolSiteStoreIssue>[],
    required this.hasArtifacts,
    this.recoveryArtifacts = const <String>[],
    this.historicalRecoveryArtifacts = const <String>[],
    this.isolateForRecovery,
  });

  const SchoolSiteStoreLoadResult.empty()
    : candidates = const <SchoolSiteStoreCandidate>[],
      issues = const <SchoolSiteStoreIssue>[],
      hasArtifacts = false,
      recoveryArtifacts = const <String>[],
      historicalRecoveryArtifacts = const <String>[],
      isolateForRecovery = null;

  final List<SchoolSiteStoreCandidate> candidates;
  final List<SchoolSiteStoreIssue> issues;
  final bool hasArtifacts;
  final List<String> recoveryArtifacts;
  final List<String> historicalRecoveryArtifacts;
  final Future<List<String>> Function()? isolateForRecovery;

  bool get hasReadFailures =>
      issues.any((issue) => issue.type == SchoolSiteStoreIssueType.readFailure);
}

class SchoolSiteStoreReadException implements Exception {
  const SchoolSiteStoreReadException(this.issues);

  final List<SchoolSiteStoreIssue> issues;

  @override
  String toString() => 'Unable to read one or more school-site snapshots.';
}

class SchoolSiteStoreRecoveryArtifactException implements Exception {
  const SchoolSiteStoreRecoveryArtifactException(this.path);

  final String path;

  @override
  String toString() =>
      'A previous failed write left an uncommitted school-site snapshot at '
      '$path.';
}

class SchoolSiteStoreWriteException implements Exception {
  const SchoolSiteStoreWriteException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class SchoolSiteStoreStaleCandidateException
    extends SchoolSiteStoreWriteException {
  const SchoolSiteStoreStaleCandidateException()
    : super('School-site storage changed before recovery could be applied.');
}

class SchoolSiteStoreRecoveryBlockedException
    extends SchoolSiteStoreWriteException {
  const SchoolSiteStoreRecoveryBlockedException()
    : super(
        'School-site writes are blocked until storage recovery is resolved.',
      );
}

class SchoolSiteStoreStateUnknownException
    extends SchoolSiteStoreRecoveryBlockedException {
  const SchoolSiteStoreStateUnknownException({
    required this.writeError,
    required this.rollbackError,
  });

  final Object writeError;
  final Object rollbackError;

  @override
  String toString() =>
      'School-site storage could not confirm its state after a failed write. '
      'Write error: $writeError; rollback error: $rollbackError';
}

abstract class SchoolSiteStore {
  factory SchoolSiteStore() = PlatformSchoolSiteStore;

  const SchoolSiteStore.base();

  Future<String?> load();

  Future<SchoolSiteStoreLoadResult> loadResult() async {
    final candidates = await loadCandidates();
    return SchoolSiteStoreLoadResult(
      candidates: candidates,
      hasArtifacts: candidates.isNotEmpty,
    );
  }

  Future<List<SchoolSiteStoreCandidate>> loadCandidates() async {
    final source = await load();
    if (source == null) {
      return const <SchoolSiteStoreCandidate>[];
    }
    return [SchoolSiteStoreCandidate(source: source)];
  }

  Future<void> save(String source);

  Future<void> saveAfterRecovery(String source) => save(source);

  Future<List<String>> isolateForRecovery() async => const <String>[];

  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async => null;

  Future<String?> filePath();
}
