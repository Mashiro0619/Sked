import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sked/agent/conversations/conversation_models.dart';

import '../../integration_test/support/agent_native_session.dart';
import 'agent_persistence_backend.dart';

const agentPersistenceProtocol = 'agent-persistence-v1';

class AgentPersistenceFailure implements Exception {
  const AgentPersistenceFailure(this.report, this.cause, this.stack);
  final Map<String, Object?> report;
  final Object cause;
  final StackTrace stack;
}

Future<Map<String, Object?>> runAgentPersistencePerformance({
  required String revision,
  required String label,
}) async {
  if (!kProfileMode || !(Platform.isWindows || Platform.isAndroid)) {
    throw StateError(
      'Persistence evidence requires a Windows or Android Profile process.',
    );
  }
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(revision)) {
    throw ArgumentError('A full source SHA is required.');
  }
  final phases = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'protocol': agentPersistenceProtocol,
    'backend': persistenceBackend,
    'sourceRevision': revision,
    'label': label,
    'buildMode': 'profile',
    'platform': Platform.operatingSystem,
    'platformVersion': Platform.operatingSystemVersion,
    'dartVersion': Platform.version,
    'pid': pid,
    'requiredIndependentProcesses': 3,
    'longMessageCount': agentNativeMessageCount,
    'shortMessageCount': 2,
    'updateCount': 32,
    'phases': phases,
    'timing': 'Timeline.now around awaited production repository operations; digest and file inspection outside timed windows. First draft update includes any lazy hydration.',
  };
  Future<void> measure(String name, Future<void> Function() action) async {
    final row = <String, Object?>{
      'name': name,
      'startUs': developer.Timeline.now,
      'rssBeforeBytes': ProcessInfo.currentRss,
    };
    phases.add(row);
    try {
      await action();
      row['status'] = 'passed';
    } catch (error) {
      row['status'] = 'failed';
      row['error'] = '$error';
      rethrow;
    } finally {
      row['endUs'] = developer.Timeline.now;
      row['wallTimeUs'] = (row['endUs'] as int) - (row['startUs'] as int);
      row['rssAfterBytes'] = ProcessInfo.currentRss;
    }
  }

  Directory? directory;
  PersistenceOwner? owner;
  Object? failure;
  StackTrace? failureStack;
  try {
    directory = await Directory.systemTemp.createTemp(
      'sked-agent-persistence-',
    );
    final fixture = agentNativeConversationFixture();
    final long = fixture.conversations.first;
    final short = fixture.conversations.last;
    String messagesDigest(Iterable<ConversationMessage> messages) =>
        agentNativeDigest(
          jsonEncode([
            for (final message in messages)
              {
                'id': message.id,
                'role': message.role.name,
                'text': message.text,
                'createdAt': message.createdAt.toUtc().toIso8601String(),
              },
          ]),
        );
    final longDigest = messagesDigest(long.messages);
    final shortDigest = messagesDigest(short.messages);
    report['fixture'] = {
      'longSha256': longDigest,
      'shortSha256': shortDigest,
      'selectedId': fixture.selectedId,
      'draft': long.draft,
      'shortDraft': short.draft,
    };
    owner = PersistenceOwner(directory);
    await measure('seed.persist', () => owner!.seed(fixture));
    await owner.close();
    owner = PersistenceOwner(directory);
    await measure('cold.repository_load', owner.repository.load);
    report['loadedMessagesAfterColdLoad'] =
        owner.repository.selected!.messages.length;
    for (var index = 0; index < 32; index++) {
      await measure('draft.update.$index', () async {
        await owner!.repository.update(
          agentNativeLongId,
          (value) => value.copyWith(draft: 'Persistence draft $index'),
        );
      });
    }
    await owner.repository.waitForPendingWrites();
    await owner.close();
    owner = PersistenceOwner(directory);
    await measure('reopen.repository_load', owner.repository.load);
    final restored = await owner.readArchive();
    final restoredLong = restored.conversations.singleWhere(
      (value) => value.id == agentNativeLongId,
    );
    final restoredShort = restored.conversations.singleWhere(
      (value) => value.id == agentNativeShortId,
    );
    if (restored.conversations.length != 2 ||
        restored.selectedId != agentNativeLongId ||
        restored.revision != fixture.revision + 32 ||
        restoredLong.draft != 'Persistence draft 31' ||
        restoredShort.draft != short.draft ||
        messagesDigest(restoredLong.messages) != longDigest ||
        messagesDigest(restoredShort.messages) != shortDigest) {
      throw StateError(
        'The persisted updates or untouched histories differ after reopening.',
      );
    }
    report['readback'] = {
      'verified': true,
      'revision': restored.revision,
      'longSha256': messagesDigest(restoredLong.messages),
      'shortSha256': messagesDigest(restoredShort.messages),
      'draft': restoredLong.draft,
      'shortDraft': restoredShort.draft,
    };
    await owner.close();
    owner = null;
    final files = <Map<String, Object?>>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        files.add({
          'name': entity.path.substring(directory.path.length + 1),
          'bytes': await entity.length(),
        });
      }
    }
    files.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    report['persistedFilesAfterClose'] = files;
    report['persistedBytesAfterClose'] = files.fold<int>(
      0,
      (sum, file) => sum + (file['bytes'] as int),
    );
    report['status'] = 'passed';
  } catch (error, stack) {
    failure = error;
    failureStack = stack;
    report['status'] = 'failed';
    report['failure'] = '$error';
  } finally {
    try {
      await owner?.close();
      if (directory != null) await directory.delete(recursive: true);
      report['cleanup'] = 'complete';
    } catch (error, stack) {
      failure ??= error;
      failureStack ??= stack;
      report['status'] = 'failed';
      report['cleanup'] = '$error';
    }
  }
  if (failure != null) {
    throw AgentPersistenceFailure(report, failure, failureStack!);
  }
  return report;
}
