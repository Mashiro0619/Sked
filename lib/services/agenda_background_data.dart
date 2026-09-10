import '../data/app_repository.dart';
import '../data/timetable_storage.dart';
import '../models/timetable_models.dart';

/// Only durable, write-safe data can authorize work outside the foreground UI.
class AgendaBackgroundDataSnapshot {
  const AgendaBackgroundDataSnapshot({
    required this.data,
    required this.canWrite,
  });
  final AppData? data;
  final bool canWrite;
}

typedef AgendaBackgroundDataLoader =
    Future<AgendaBackgroundDataSnapshot> Function();

Future<AgendaBackgroundDataSnapshot> loadPersistedAgendaBackgroundData() async {
  final repository = AppRepository(storage: TimetableStorage());
  final data = await repository.load();
  return AgendaBackgroundDataSnapshot(
    data: data,
    canWrite: repository.canWrite,
  );
}
