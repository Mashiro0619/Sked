import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;

import '../../../services/app_storage_layout_io.dart';

QueryExecutor openAgentStoreExecutor({String? filePath}) =>
    LazyDatabase(() async {
      final target =
          filePath ??
          path.join(
            (await AppStorageLayout().directory()).path,
            'Sked_agent.sqlite',
          );
      return NativeDatabase.createInBackground(File(target));
    });
