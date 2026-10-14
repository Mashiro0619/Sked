import 'dart:async';

import 'package:flutter/foundation.dart' show ComputeCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/controllers/app_data_maintenance.dart';
import 'package:sked/controllers/app_persistence.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/controllers/data_transfer_controller.dart';
import 'package:sked/controllers/general_view_state.dart';
import 'package:sked/controllers/student_view_state.dart';
import 'package:sked/controllers/workspace_transactions.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/data_transfer_codec.dart';

import '../support/data_transfer_codec.dart';
import '../support/timetable_storage_fakes.dart';

class _Fixture {
  _Fixture._(this.session, this.maintenance, this.transfers);

  final AppSession session;
  final AppDataMaintenance maintenance;
  final DataTransferController transfers;

  static Future<_Fixture> create({
    DataTransferCodec codec = inlineDataTransferCodec,
  }) async {
    final data = buildInitialAppData(buildDefaultPeriodTimes());
    final repository = AppRepository(storage: WorkspaceMemoryStorage(data));
    await repository.load();
    final maintenance = AppDataMaintenance(
      repository: repository,
      notifyViewChanged: () {},
    );
    final session = AppSession(
      repository: repository,
      initialData: data,
      requireMutationAllowed: maintenance.ensureMutationAllowed,
    );
    addTearDown(session.close);
    final student = StudentViewState(session);
    final persistence = AppPersistence(
      session: session,
      student: student,
      transactions: WorkspaceTransactions(),
      maintenance: maintenance,
      notifyViewChanged: () {},
    );
    return _Fixture._(
      session,
      maintenance,
      DataTransferController(
        session: session,
        student: student,
        general: GeneralViewState(session),
        persistence: persistence,
        maintenance: maintenance,
        codec: codec,
      ),
    );
  }

  TimetableData timetable(String id) => TimetableData(
    id: id,
    config: TimetableConfig(
      name: id,
      startDate: DateTime(2026, 8, 3),
      totalWeeks: 16,
      periodTimeSetId: session.data.studentMode.periodTimeSets.first.id,
    ),
    courses: const [],
  );

  String get source => encodeTimetableDataEnvelope(
    TimetableExportData(
      timetables: [timetable('imported')],
      periodTimeSets: session.data.studentMode.periodTimeSets,
    ),
  );
}

class _ControlledComputation {
  Completer<void>? gate;
  var count = 0;

  Future<R> run<M, R>(
    ComputeCallback<M, R> callback,
    M message, {
    String? debugLabel,
  }) async {
    count += 1;
    await gate?.future;
    return callback(message);
  }
}

void main() {
  test(
    'confirmation reuses its candidate and merges edits made after preview',
    () async {
      final computation = _ControlledComputation();
      final f = await _Fixture.create(
        codec: DataTransferCodec(run: computation.run),
      );
      final prepared = await f.transfers.prepareTimetables(f.source);
      final later = f.timetable('created-after-preview');
      f.session.replaceData(
        f.session.data.copyWith(
          hideHomeWorkspaceNavigation: true,
          studentMode: f.session.data.studentMode.copyWith(timetables: [later]),
        ),
      );
      final count = await f.transfers.applyTimetables(
        prepared,
        timetableIds: ['imported'],
        mode: TimetableImportMode.addAsNew,
      );
      expect(count, 1);
      expect(computation.count, 1);
      expect(f.session.data.studentMode.timetables.first, same(later));
      expect(f.session.data.hideHomeWorkspaceNavigation, isTrue);
      expect(
        f.session.repository.persisted!.studentMode.timetables,
        hasLength(2),
      );
    },
  );

  test('a late parse cannot outlive a restore reservation even when it was released', () async {
    final computation = _ControlledComputation()..gate = Completer<void>();
    final f = await _Fixture.create(
      codec: DataTransferCodec(run: computation.run),
    );
    final before = f.session.data;
    final pending = f.transfers.prepareTimetables(f.source);
    final rejected = expectLater(pending, throwsStateError);
    final reservation = f.maintenance.reserve();
    f.maintenance.release(reservation);
    computation.gate!.complete();
    await rejected;
    expect(f.session.data, same(before));
    expect(f.session.repository.persisted, same(before));
  });

  test('reactivating a workspace and replacing the controller invalidate candidates', () async {
    final f = await _Fixture.create();
    final other = await _Fixture.create();
    final prepared = await f.transfers.prepareTimetables(f.source);
    await expectLater(
      other.transfers.applyTimetables(
        prepared,
        timetableIds: ['imported'],
        mode: TimetableImportMode.addAsNew,
      ),
      throwsStateError,
    );
    f.session.replaceData(
      f.session.data.copyWith(
        activeMode: AppMode.general,
        enabledWorkspaces: {AppMode.general},
      ),
    );
    f.session.replaceData(
      f.session.data.copyWith(
        enabledWorkspaces: {AppMode.general, AppMode.student},
        workspaceReminderNotBefore: {AppMode.student: DateTime.utc(2026, 8, 4)},
      ),
    );
    expect(f.transfers.isCurrent(prepared), isFalse);
    await expectLater(
      f.transfers.applyTimetables(
        prepared,
        timetableIds: ['imported'],
        mode: TimetableImportMode.addAsNew,
      ),
      throwsStateError,
    );
    expect(f.session.data.studentMode.timetables, isEmpty);
    expect(other.session.data.studentMode.timetables, isEmpty);
  });
}
