import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';

class _FakeSchoolSiteStore extends SchoolSiteStore {
  const _FakeSchoolSiteStore(this.source) : super.base();

  final String? source;

  @override
  Future<String?> load() async => source;

  @override
  Future<void> save(String source) async {}

  @override
  Future<String?> filePath() async => 'memory://school-sites';
}

class _CandidateSchoolSiteStore extends SchoolSiteStore {
  _CandidateSchoolSiteStore(this.candidates) : super.base();

  final List<SchoolSiteStoreCandidate> candidates;

  @override
  Future<String?> load() async {
    return candidates.isEmpty ? null : candidates.first.source;
  }

  @override
  Future<List<SchoolSiteStoreCandidate>> loadCandidates() async => candidates;

  @override
  Future<void> save(String source) async {}

  @override
  Future<String?> filePath() async => 'memory://school-sites';
}

class _StructuredSchoolSiteStore extends SchoolSiteStore {
  _StructuredSchoolSiteStore(
    this.result, {
    this.isolatedArtifacts = const <String>[],
    this.saveError,
    this.recoverySaveError,
    this.isolateError,
    this.resultAfterIsolation,
  }) : super.base();

  SchoolSiteStoreLoadResult result;
  final List<String> isolatedArtifacts;
  final Object? saveError;
  final Object? recoverySaveError;
  final Object? isolateError;
  final SchoolSiteStoreLoadResult? resultAfterIsolation;
  var saveCount = 0;
  var recoverySaveCount = 0;
  var isolateCount = 0;

  @override
  Future<String?> load() async => null;

  @override
  Future<SchoolSiteStoreLoadResult> loadResult() async => result;

  @override
  Future<List<String>> isolateForRecovery() async {
    isolateCount += 1;
    final error = isolateError;
    if (error != null) throw error;
    final nextResult = resultAfterIsolation;
    if (nextResult != null) result = nextResult;
    return isolatedArtifacts;
  }

  @override
  Future<void> save(String source) async {
    saveCount += 1;
    final error = saveError;
    if (error != null) throw error;
  }

  @override
  Future<void> saveAfterRecovery(String source) async {
    recoverySaveCount += 1;
    final error = recoverySaveError;
    if (error != null) throw error;
    await save(source);
  }

  @override
  Future<String?> filePath() async => 'memory://school-sites';
}

class _ControlledSchoolSiteStore extends SchoolSiteStore {
  _ControlledSchoolSiteStore(this.source) : super.base();

  String source;
  Completer<void>? saveStarted;
  Completer<void>? allowSave;
  var saveCount = 0;

  @override
  Future<String?> load() async => source;

  @override
  Future<SchoolSiteStoreLoadResult> loadResult() async =>
      SchoolSiteStoreLoadResult(
        candidates: [SchoolSiteStoreCandidate(source: source)],
        hasArtifacts: true,
      );

  @override
  Future<void> save(String source) async {
    saveCount += 1;
    final started = saveStarted;
    if (started != null && !started.isCompleted) started.complete();
    await allowSave?.future;
    this.source = source;
  }

  @override
  Future<String?> filePath() async => 'memory://coordinated-school-sites';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockSchoolSitesAsset(String source) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key != SchoolSiteService.schoolSitesAssetPath) {
        return null;
      }
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
  }

  group('SchoolSiteService.loadSites', () {
    test('blocks ordinary writes until storage has been loaded', () async {
      final store = _StructuredSchoolSiteStore(
        const SchoolSiteStoreLoadResult.empty(),
      );
      final service = SchoolSiteService(store: store);

      await expectLater(
        service.saveSites(const []),
        throwsA(isA<SchoolSiteWriteBlockedException>()),
      );

      expect(store.saveCount, 0);
    });

    test(
      'reports invalid stored JSON without substituting bundled sites',
      () async {
        final service = SchoolSiteService(
          store: _FakeSchoolSiteStore('{ broken json'),
        );

        final result = await service.loadSitesResult();

        expect(result.sites, isEmpty);
        expect(
          result.recoveryStatus,
          SchoolSiteRecoveryStatus.storedDataCorrupt,
        );
        expect(result.canWrite, isFalse);
        await expectLater(
          service.loadSites(),
          throwsA(isA<SchoolSiteRecoveryException>()),
        );
      },
    );

    test(
      'does not silently discard invalid entries from stored sites',
      () async {
        mockSchoolSitesAsset('[]');
        final service = SchoolSiteService(
          store: _FakeSchoolSiteStore(
            jsonEncode([
              {'name': 'Valid University', 'loginUrl': 'https://valid.test'},
              {'name': 'Broken University', 'loginUrl': 42},
            ]),
          ),
        );

        final result = await service.loadSitesResult();

        expect(
          result.recoveryStatus,
          SchoolSiteRecoveryStatus.storedDataCorrupt,
        );
        expect(result.canWrite, isFalse);
        expect(result.invalidArtifacts, [SchoolSiteStoreArtifact.primary]);
      },
    );

    test(
      'future storage version blocks fallback, isolation, and writes',
      () async {
        final futureSource = jsonEncode({
          'schema': schoolSiteStorageSchema,
          'version': schoolSiteStorageVersion + 1,
          'data': {'sites': const []},
        });
        final store = _StructuredSchoolSiteStore(
          SchoolSiteStoreLoadResult(
            candidates: [
              SchoolSiteStoreCandidate(
                source: futureSource,
                artifact: SchoolSiteStoreArtifact.primary,
              ),
              SchoolSiteStoreCandidate(
                source: encodeSchoolSites(const [
                  SchoolSite(
                    name: 'Older Backup',
                    loginUrl: 'https://backup.test',
                  ),
                ]),
                artifact: SchoolSiteStoreArtifact.backup,
              ),
            ],
            hasArtifacts: true,
            recoveryArtifacts: const ['active/main', 'active/backup'],
          ),
        );
        final service = SchoolSiteService(store: store);

        final result = await service.loadSitesResult();

        expect(
          result.recoveryStatus,
          SchoolSiteRecoveryStatus.unsupportedVersion,
        );
        expect(result.sites, isEmpty);
        expect(result.canWrite, isFalse);
        expect(result.canReplaceAfterRecovery, isFalse);
        expect(result.recoveryArtifacts, const [
          'active/main',
          'active/backup',
        ]);
        expect(store.isolateCount, 0);
        expect(store.saveCount, 0);
        await expectLater(
          service.replaceSitesAfterRecovery(const []),
          throwsA(isA<SchoolSiteWriteBlockedException>()),
        );
      },
    );

    test('new school-site writes use the versioned storage schema', () async {
      final coordinator = SchoolSiteStorageCoordinator();
      final store = _ControlledSchoolSiteStore('[]');
      final service = SchoolSiteService(store: store, coordinator: coordinator);
      await service.loadSitesResult();

      await service.saveSites(const [
        SchoolSite(name: 'Saved', loginUrl: 'https://saved.test'),
      ]);

      final encoded = jsonDecode(store.source) as Map<String, dynamic>;
      expect(encoded['schema'], schoolSiteStorageSchema);
      expect(encoded['version'], schoolSiteStorageVersion);
      expect(decodeSchoolSitesStrict(store.source).single.name, 'Saved');
    });

    test('blocks recovery when invalid snapshots cannot be isolated', () async {
      mockSchoolSitesAsset(
        jsonEncode([
          {'name': 'Bundled University', 'loginUrl': 'https://bundled.test'},
        ]),
      );
      var promoted = false;
      final service = SchoolSiteService(
        store: _CandidateSchoolSiteStore([
          const SchoolSiteStoreCandidate(source: '{ broken json'),
          SchoolSiteStoreCandidate(
            source: jsonEncode([
              {'name': 'Backup University', 'loginUrl': 'https://backup.test'},
            ]),
            promote: () async => promoted = true,
          ),
        ]),
      );

      final result = await service.loadSitesResult();

      expect(result.sites, hasLength(1));
      expect(result.sites.single.name, 'Backup University');
      expect(result.sites.single.loginUrl, 'https://backup.test');
      expect(
        result.recoveryStatus,
        SchoolSiteRecoveryStatus.recoveryWriteFailed,
      );
      expect(result.canWrite, isFalse);
      expect(promoted, isFalse);
    });

    test(
      'does not promote temporary data before invalid primary is isolated',
      () async {
        bool? preservePrimaryAsBackup;
        final service = SchoolSiteService(
          store: _CandidateSchoolSiteStore([
            SchoolSiteStoreCandidate(
              source: jsonEncode([
                {'name': 'Pending University', 'loginUrl': 'https://tmp.test'},
              ]),
              artifact: SchoolSiteStoreArtifact.temporary,
              promoteWithContext: (preserve) async {
                preservePrimaryAsBackup = preserve;
              },
            ),
            const SchoolSiteStoreCandidate(
              source: '{ broken primary',
              artifact: SchoolSiteStoreArtifact.primary,
            ),
          ]),
        );

        final result = await service.loadSitesResult();

        expect(result.canWrite, isFalse);
        expect(
          result.recoveryStatus,
          SchoolSiteRecoveryStatus.recoveryWriteFailed,
        );
        expect(result.sites.single.name, 'Pending University');
        expect(preservePrimaryAsBackup, isNull);
      },
    );

    test(
      'preserves mixed snapshots before rebuilding from a valid backup',
      () async {
        final store = _StructuredSchoolSiteStore(
          SchoolSiteStoreLoadResult(
            candidates: [
              const SchoolSiteStoreCandidate(
                source: '{ broken primary',
                artifact: SchoolSiteStoreArtifact.primary,
              ),
              SchoolSiteStoreCandidate(
                source: jsonEncode([
                  {
                    'name': 'Backup University',
                    'loginUrl': 'https://backup.test',
                  },
                ]),
                artifact: SchoolSiteStoreArtifact.backup,
              ),
            ],
            hasArtifacts: true,
            recoveryArtifacts: const ['active/main', 'active/backup'],
          ),
          isolatedArtifacts: const ['recovery/main', 'recovery/backup'],
        );
        final service = SchoolSiteService(store: store);

        final result = await service.loadSitesResult();

        expect(result.canWrite, isTrue);
        expect(result.sites.single.name, 'Backup University');
        expect(result.invalidArtifacts, [SchoolSiteStoreArtifact.primary]);
        expect(result.recoveryArtifacts, const [
          'recovery/main',
          'recovery/backup',
        ]);
        expect(store.isolateCount, 1);
        expect(store.recoverySaveCount, 1);
      },
    );

    test('mixed snapshot isolation failure keeps writes blocked', () async {
      final store = _StructuredSchoolSiteStore(
        SchoolSiteStoreLoadResult(
          candidates: [
            const SchoolSiteStoreCandidate(
              source: '{ broken primary',
              artifact: SchoolSiteStoreArtifact.primary,
            ),
            SchoolSiteStoreCandidate(
              source: jsonEncode([
                {
                  'name': 'Backup University',
                  'loginUrl': 'https://backup.test',
                },
              ]),
              artifact: SchoolSiteStoreArtifact.backup,
            ),
          ],
          hasArtifacts: true,
          recoveryArtifacts: const ['active/main', 'active/backup'],
        ),
        isolateError: Exception('isolation failed'),
      );
      final service = SchoolSiteService(store: store);

      final result = await service.loadSitesResult();

      expect(result.canWrite, isFalse);
      expect(
        result.recoveryStatus,
        SchoolSiteRecoveryStatus.recoveryWriteFailed,
      );
      expect(result.recoveryArtifacts, const ['active/main', 'active/backup']);
      expect(store.recoverySaveCount, 0);
      await expectLater(
        service.saveSites(result.sites),
        throwsA(isA<SchoolSiteWriteBlockedException>()),
      );
    });

    test(
      'blocks writes when a valid recovery candidate cannot be promoted',
      () async {
        final store = _CandidateSchoolSiteStore([
          SchoolSiteStoreCandidate(
            source: jsonEncode([
              {'name': 'Backup University', 'loginUrl': 'https://backup.test'},
            ]),
            artifact: SchoolSiteStoreArtifact.backup,
            promote: () async => throw Exception('promotion failed'),
          ),
        ]);
        final service = SchoolSiteService(store: store);

        final result = await service.loadSitesResult();

        expect(
          result.recoveryStatus,
          SchoolSiteRecoveryStatus.recoveryWriteFailed,
        );
        expect(result.canWrite, isFalse);
        expect(result.sites.single.name, 'Backup University');
        await expectLater(
          service.saveSites(result.sites),
          throwsA(isA<SchoolSiteWriteBlockedException>()),
        );
      },
    );

    test('reports corrupt stored artifacts and blocks later writes', () async {
      mockSchoolSitesAsset('[]');
      final store = _StructuredSchoolSiteStore(
        const SchoolSiteStoreLoadResult(
          candidates: [
            SchoolSiteStoreCandidate(
              source: '{ broken main',
              artifact: SchoolSiteStoreArtifact.primary,
            ),
            SchoolSiteStoreCandidate(
              source: '{ broken temp',
              artifact: SchoolSiteStoreArtifact.temporary,
            ),
            SchoolSiteStoreCandidate(
              source: '{ broken backup',
              artifact: SchoolSiteStoreArtifact.backup,
            ),
          ],
          hasArtifacts: true,
        ),
        isolatedArtifacts: const [
          'memory://recovery/Sked_school_sites.json',
          'memory://recovery/Sked_school_sites.json.bak',
          'memory://recovery/Sked_school_sites.json.tmp',
        ],
      );
      final service = SchoolSiteService(store: store);

      final result = await service.loadSitesResult();

      expect(result.recoveryStatus, SchoolSiteRecoveryStatus.storedDataCorrupt);
      expect(result.canWrite, isFalse);
      expect(result.canReplaceAfterRecovery, isTrue);
      expect(result.recoveryArtifacts, hasLength(3));
      expect(store.isolateCount, 1);
      await expectLater(
        service.saveSites(const []),
        throwsA(isA<SchoolSiteWriteBlockedException>()),
      );
      expect(store.saveCount, 0);
      await service.replaceSitesAfterRecovery(const []);
      expect(store.saveCount, 1);
      expect(store.recoverySaveCount, 1);
    });

    test('normal replacement cannot bypass a newly blocked store', () async {
      mockSchoolSitesAsset('[]');
      final store = _StructuredSchoolSiteStore(
        const SchoolSiteStoreLoadResult.empty(),
        saveError: const SchoolSiteStoreRecoveryBlockedException(),
      );
      final service = SchoolSiteService(store: store);
      final result = await service.loadSitesResult();
      expect(result.canWrite, isTrue);

      await expectLater(
        service.replaceSitesAfterRecovery(const []),
        throwsA(isA<SchoolSiteStoreRecoveryBlockedException>()),
      );

      expect(store.saveCount, 1);
      expect(store.recoverySaveCount, 0);
      expect(service.canWrite, isFalse);
    });

    test(
      'reports storage read failures instead of using bundled data',
      () async {
        mockSchoolSitesAsset('[]');
        final error = Exception('read denied');
        final store = _StructuredSchoolSiteStore(
          SchoolSiteStoreLoadResult(
            candidates: const [],
            issues: [
              SchoolSiteStoreIssue(
                artifact: SchoolSiteStoreArtifact.primary,
                type: SchoolSiteStoreIssueType.readFailure,
                error: error,
              ),
            ],
            hasArtifacts: true,
          ),
        );
        final service = SchoolSiteService(store: store);

        final result = await service.loadSitesResult();

        expect(
          result.recoveryStatus,
          SchoolSiteRecoveryStatus.storageReadFailed,
        );
        expect(result.canWrite, isFalse);
        expect(result.canReplaceAfterRecovery, isFalse);
        expect(store.isolateCount, 0);
        expect(result.storageIssues.single.error, same(error));
        await expectLater(
          service.replaceSitesAfterRecovery(const []),
          throwsA(isA<SchoolSiteWriteBlockedException>()),
        );
        expect(store.saveCount, 0);
        await expectLater(
          service.loadSites(),
          throwsA(isA<SchoolSiteRecoveryException>()),
        );
      },
    );

    test(
      'blocks later writes when a failed save leaves storage unknown',
      () async {
        mockSchoolSitesAsset('[]');
        final store = _StructuredSchoolSiteStore(
          const SchoolSiteStoreLoadResult.empty(),
          saveError: const SchoolSiteStoreStateUnknownException(
            writeError: 'write failed',
            rollbackError: 'rollback failed',
          ),
        );
        final service = SchoolSiteService(store: store);
        await service.loadSitesResult();

        await expectLater(
          service.saveSites(const []),
          throwsA(isA<SchoolSiteStoreStateUnknownException>()),
        );

        expect(service.canWrite, isFalse);
        await expectLater(
          service.saveSites(const []),
          throwsA(isA<SchoolSiteWriteBlockedException>()),
        );
        expect(store.saveCount, 1);
      },
    );

    test(
      'restore waits for an active writer and rejects stale external snapshots',
      () async {
        final coordinator = SchoolSiteStorageCoordinator();
        final store = _ControlledSchoolSiteStore(
          jsonEncode([
            {'name': 'Initial', 'loginUrl': 'https://initial.test'},
          ]),
        );
        final writer = SchoolSiteService(
          store: store,
          coordinator: coordinator,
        );
        final restorer = SchoolSiteService(
          store: store,
          coordinator: coordinator,
        );
        final stalePage = SchoolSiteService(
          store: store,
          coordinator: coordinator,
        );
        await writer.loadSitesResult();
        await restorer.loadSitesResult();
        await stalePage.loadSitesResult();

        store.saveStarted = Completer<void>();
        store.allowSave = Completer<void>();
        final activeWrite = writer.saveSites(const [
          SchoolSite(name: 'Writer', loginUrl: 'https://writer.test'),
        ]);
        await store.saveStarted!.future;

        var restoreAcquired = false;
        final leaseFuture = restorer.reserveRestore().then((lease) {
          restoreAcquired = true;
          return lease;
        });
        await Future<void>.delayed(Duration.zero);
        expect(restoreAcquired, isFalse);
        await expectLater(
          stalePage.saveSites(const [
            SchoolSite(name: 'Stale', loginUrl: 'https://stale.test'),
          ]),
          throwsA(isA<SchoolSiteWriteBlockedException>()),
        );

        store.allowSave!.complete();
        await activeWrite;
        final lease = await leaseFuture;
        final loadedDuringRestore = await lease.loadSitesResult();
        expect(loadedDuringRestore.sites.single.name, 'Writer');
        await lease.replaceSitesAfterRecovery(const [
          SchoolSite(name: 'Restored', loginUrl: 'https://restored.test'),
        ]);
        await lease.release();

        await expectLater(
          stalePage.saveSites(const [
            SchoolSite(name: 'Stale', loginUrl: 'https://stale.test'),
          ]),
          throwsA(isA<SchoolSiteStaleWriteException>()),
        );
        expect(decodeSchoolSitesStrict(store.source).single.name, 'Restored');
      },
    );

    test(
      'failed rebuild after isolation blocks every coordinated writer',
      () async {
        final coordinator = SchoolSiteStorageCoordinator();
        final isolatedArtifacts = const [
          'memory://recovery/Sked_school_sites.json',
          'memory://recovery/Sked_school_sites.json.bak',
        ];
        final store = _StructuredSchoolSiteStore(
          const SchoolSiteStoreLoadResult(
            candidates: [SchoolSiteStoreCandidate(source: '[]')],
            hasArtifacts: true,
          ),
          isolatedArtifacts: isolatedArtifacts,
          recoverySaveError: const SchoolSiteStoreWriteException(
            'rebuild failed',
          ),
          resultAfterIsolation: SchoolSiteStoreLoadResult(
            candidates: [],
            hasArtifacts: false,
            recoveryArtifacts: isolatedArtifacts,
          ),
        );
        final previouslyLoadedWriter = SchoolSiteService(
          store: store,
          coordinator: coordinator,
        );
        await previouslyLoadedWriter.loadSitesResult();

        store.result = SchoolSiteStoreLoadResult(
          candidates: [
            const SchoolSiteStoreCandidate(
              source: '{ broken primary',
              artifact: SchoolSiteStoreArtifact.primary,
            ),
            SchoolSiteStoreCandidate(
              source: jsonEncode([
                {'name': 'Backup', 'loginUrl': 'https://backup.test'},
              ]),
              artifact: SchoolSiteStoreArtifact.backup,
            ),
          ],
          hasArtifacts: true,
        );
        final recoveryService = SchoolSiteService(
          store: store,
          coordinator: coordinator,
        );

        final result = await recoveryService.loadSitesResult();

        expect(
          result.recoveryStatus,
          SchoolSiteRecoveryStatus.recoveryWriteFailed,
        );
        expect(result.canWrite, isFalse);
        expect(result.recoveryArtifacts, isolatedArtifacts);
        expect(store.isolateCount, 1);
        expect(store.recoverySaveCount, 1);
        final artifactsBeforeRejectedWrite = List<String>.of(
          store.result.recoveryArtifacts,
        );
        final saveCountBeforeRejectedWrite = store.saveCount;

        await expectLater(
          previouslyLoadedWriter.saveSites(const []),
          throwsA(isA<SchoolSiteWriteBlockedException>()),
        );
        expect(store.saveCount, saveCountBeforeRejectedWrite);
        expect(store.result.recoveryArtifacts, artifactsBeforeRejectedWrite);
        expect(recoveryService.canWrite, isFalse);
      },
    );
  });
}
