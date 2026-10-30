import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_queries.dart';
import 'package:sked/application/resource_selection.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  late ResourceSelectionRegistry selections;
  late OperationScope scope;
  late DateTime now;
  setUp(() {
    now = DateTime.utc(2026, 10, 30);
    var id = 0;
    selections = ResourceSelectionRegistry(
      clock: () => now,
      id: () => 's-${id++}',
    );
    scope = OperationScope(id: 'run', policy: OperationPolicy(enabled: true));
  });

  test(
    'selection includes every page and hidden disabled owners without mutation',
    () {
      final reader = _reader(205);
      final selected = selections.create(
        reader: reader,
        query: ResourceQuery(kind: ResourceKind.event, limit: 1),
        scope: scope,
      );
      expect(selected.targets, hasLength(205));
      expect(selected.targets.map((ref) => ref.id).toSet(), hasLength(205));
      expect(selected.targets.every((ref) => ref.parentId == 'hidden'), isTrue);
      expect(selected.page()['hasMore'], isTrue);
      expect(selected.page(offset: 200)['items'], hasLength(5));
      expect(selected.page(offset: 200)['nextOffset'], isNull);
      expect(scope.policy.mode, AgentPermissionMode.ask);
    },
  );

  test(
    'an oversized filtered set is rejected rather than partially selected',
    () {
      expect(
        () => selections.create(
          reader: _reader(1001),
          query: ResourceQuery(kind: ResourceKind.event),
          scope: scope,
        ),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test('snapshot, generation, scope and expiry prevent retargeting', () {
    final reader = _reader(2);
    final selected = selections.create(
      reader: reader,
      query: ResourceQuery(kind: ResourceKind.event),
      scope: scope,
    );
    expect(
      () => selections.get(selected.id, _reader(3, revision: 2), scope),
      throwsA(_problem(OperationErrorCode.expired)),
    );
    expect(
      () => selections.get(
        selected.id,
        _reader(2, generation: 'restored'),
        scope,
      ),
      throwsA(_problem(OperationErrorCode.expired)),
    );
    final other = OperationScope(id: scope.id, policy: scope.policy);
    expect(
      () => selections.get(selected.id, reader, other),
      throwsA(_problem(OperationErrorCode.expired)),
    );
    now = now.add(const Duration(minutes: 31));
    expect(
      () => selections.get(selected.id, reader, scope),
      throwsA(_problem(OperationErrorCode.expired)),
    );
  });

  test('completion discards handles and a cancelled scope cannot select', () {
    final reader = _reader(2);
    final selected = selections.create(
      reader: reader,
      query: ResourceQuery(kind: ResourceKind.event),
      scope: scope,
    );
    selections.discardScope(scope);
    expect(
      () => selections.get(selected.id, reader, scope),
      throwsA(_problem(OperationErrorCode.expired)),
    );
    scope.cancel();
    expect(
      () => selections.create(
        reader: reader,
        query: ResourceQuery(kind: ResourceKind.event),
        scope: scope,
      ),
      throwsA(_problem(OperationErrorCode.cancelled)),
    );
  });
}

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((value) => value.code, 'code', code);

ResourceQueries _reader(
  int count, {
  int revision = 1,
  String generation = 'data',
}) => ResourceQueries(
  datasetGeneration: generation,
  snapshotRevision: revision,
  snapshot: AppData(
    activeMode: AppMode.student,
    enabledWorkspaces: const {AppMode.student},
    studentMode: const StudentModeData(
      activeTimetableId: '',
      timetables: [],
      periodTimeSets: [],
    ),
    generalMode: GeneralScheduleData(
      activeScheduleId: 'hidden',
      schedules: [
        GeneralSchedule(
          id: 'hidden',
          name: 'Hidden',
          isVisible: false,
          events: [
            for (var index = 0; index < count; index++)
              GeneralEvent(
                id: 'event-$index',
                title: 'Entry $index',
                startDateTimeIso: '2026-10-30T09:00:00',
                endDateTimeIso: '2026-10-30T10:00:00',
              ),
          ],
        ),
      ],
    ),
  ),
);
