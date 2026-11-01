import 'package:flutter_test/flutter_test.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_backup_planner.dart';

const _period = BackupObjectKey(BackupObjectKind.periodTimeSet, 'shared');
BackupObjectKey _tableKey(String id) =>
    BackupObjectKey(BackupObjectKind.timetable, id);
BackupRecord _set(String name) => BackupRecord(
  key: _period,
  label: name,
  data: {'id': 'shared', 'name': name},
);
BackupRecord _table(String id, String name) => BackupRecord(
  key: _tableKey(id),
  label: name,
  data: {
    'entity': {
      'id': id,
      'name': name,
      'config': {'periodTimeSetId': 'shared'},
    },
    'displayChoices': <String, Object?>{},
  },
  dependencies: const [_period],
);
SelectiveBackupBundle _inventory(List<BackupRecord> records) =>
    SelectiveBackupBundle(
      records: records,
      roots: records.map((item) => item.key),
    );

void main() {
  const planner = SelectiveBackupPlanner();

  test('conflicting implicit dependency is copied and only selected objects are rebound', () {
    final current = _inventory([
      _set('Current periods'),
      _table('kept', 'Unselected'),
    ]);
    final source = _inventory([
      _set('Imported periods'),
      _table('selected', 'Imported'),
    ]);
    var sequence = 0;
    final plan = planner.prepare(
      source: source,
      current: current,
      selection: BackupSelection(objects: [_tableKey('selected')]),
      newId: () => 'id-${sequence++}',
    );
    final replacement = plan.mapping[_period]!;
    expect(replacement, isNot(_period));
    final merged = plan.mergeRecords(current.records);
    expect(merged.first.data['name'], 'Current periods');
    expect(merged[1].data, current.records[1].data);
    final imported = merged.singleWhere(
      (item) => item.key == _tableKey('selected'),
    );
    expect((imported.data['entity'] as Map)['config'], {
      'periodTimeSetId': replacement.id,
    });
    expect(
      merged.singleWhere((item) => item.key == replacement).data['name'],
      'Imported periods',
    );
  });

  test('explicit shared replacement requires selecting every existing referring object', () {
    final current = _inventory([_set('Current'), _table('kept', 'Unselected')]);
    final source = _inventory([_set('Imported')]);
    expect(
      () => planner.prepare(
        source: source,
        current: current,
        selection: BackupSelection(objects: const [_period]),
      ),
      throwsA(
        isA<SelectiveBackupException>().having(
          (error) => error.targets,
          'affected objects',
          [_tableKey('kept')],
        ),
      ),
    );
  });

  test('same IDs replace in place, absent IDs append and matching names do not merge', () {
    final current = _inventory([
      _set('Same periods'),
      _table('same', 'Original'),
      _table('kept', 'Same name'),
    ]);
    final source = _inventory([
      _set('Same periods'),
      _table('same', 'Replacement'),
      _table('new', 'Same name'),
    ]);
    final plan = planner.prepare(
      source: source,
      current: current,
      selection: BackupSelection(
        objects: [_tableKey('same'), _tableKey('new')],
      ),
    );
    expect(plan.mapping[_period], _period);
    final merged = plan.mergeRecords(current.records);
    expect(merged.map((item) => item.key.id), [
      'shared',
      'same',
      'kept',
      'new',
    ]);
    expect(merged[1].label, 'Replacement');
    expect(merged[2].data, current.records[2].data);
  });

  test('empty selection preserves every object and fresh dependent edits invalidate a plan', () {
    final current = _inventory([_set('Old')]);
    final source = _inventory([_set('New')]);
    final empty = planner.prepare(
      source: source,
      current: current,
      selection: BackupSelection(),
    );
    expect(empty.owners, isEmpty);
    expect(empty.mergeRecords(current.records), current.records);
    final plan = planner.prepare(
      source: source,
      current: current,
      selection: BackupSelection(objects: const [_period]),
    );
    expect(
      () => plan.validateCurrent(
        _inventory([_set('Old'), _table('later', 'New reference')]),
      ),
      throwsA(isA<SelectiveBackupException>()),
    );
    expect(
      () => plan.validateCurrent(_inventory([_set('Other edit')])),
      throwsA(isA<SelectiveBackupException>()),
    );
  });

  test('metadata-only attachment collision cannot bind imported chat to different local content', () {
    const file = BackupObjectKey(BackupObjectKind.attachment, 'file');
    const chat = BackupObjectKey(BackupObjectKind.conversation, 'chat');
    BackupRecord attachment(String digest) => BackupRecord(
      key: file,
      label: 'File',
      data: {'id': 'file', 'digest': digest},
    );
    final current = _inventory([attachment('local')]);
    final source = _inventory([
      attachment('imported'),
      BackupRecord(
        key: chat,
        label: 'Chat',
        data: {
          'id': 'chat',
          'attachments': [
            {'id': 'file', 'digest': 'imported'},
          ],
          'messages': [
            {
              'attachmentIds': ['file'],
            },
          ],
          'draftAttachmentIds': <String>[],
        },
        dependencies: const [file],
      ),
    ]);
    final plan = planner.prepare(
      source: source,
      current: current,
      selection: BackupSelection(objects: const [chat]),
    );
    final newId = plan.mapping[file]!.id;
    expect(newId, isNot('file'));
    final restored = plan.changes
        .singleWhere((change) => change.after.key == chat)
        .after;
    expect((restored.data['attachments'] as List).single['id'], newId);
    expect((restored.data['messages'] as List).single['attachmentIds'], [
      newId,
    ]);
    expect(plan.owners, {BackupOwner.mainData, BackupOwner.conversations});
    expect(
      () => planner.prepare(
        source: source,
        current: current,
        selection: BackupSelection(
          objects: const [chat],
          attachmentBytes: const ['file'],
        ),
      ),
      throwsA(
        isA<SelectiveBackupException>().having(
          (error) => error.code,
          'code',
          SelectiveBackupError.unavailable,
        ),
      ),
    );
  });
}
