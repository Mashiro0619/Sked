import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../tool/merge_lcov.dart' as coverage;

void main() {
  const first = 'SF:lib/a.dart\nDA:1,1\nDA:2,0\nLF:2\nLH:1\nend_of_record\n';
  const second =
      'SF:lib/a.dart\nDA:1,2\nDA:2,4\nLF:2\nLH:2\nend_of_record\n'
      'SF:lib/b.dart\nDA:9,0\nLF:1\nLH:0\nend_of_record\n';
  test(
    'shards merge hit counts, source files and recalculated line totals',
    () {
      expect(
        coverage.mergeLcovReports([second, first]),
        'SF:lib/a.dart\nDA:1,3\nDA:2,4\nLF:2\nLH:2\nend_of_record\n'
        'SF:lib/b.dart\nDA:9,0\nLF:1\nLH:0\nend_of_record\n',
      );
    },
  );

  test('invalid or unsupported reports cannot silently lower coverage', () {
    for (final bad in [
      '',
      'SF:lib/a.dart\nDA:1,1\n',
      first.replaceFirst('DA:1,1', 'DA:1,-1'),
      first.replaceFirst('LF:2', 'LF:3'),
      first.replaceFirst('DA:2,0', 'DA:1,0'),
      first.replaceFirst('DA:2,0', 'BRDA:2,0,0,1'),
    ]) {
      expect(
        () => coverage.mergeLcovReports([first, bad]),
        throwsFormatException,
      );
    }
    expect(() => coverage.mergeLcovReports([]), throwsFormatException);
    expect(
      () => coverage.mergeLcovReports([
        first.replaceFirst('DA:1,1', 'DA:1,1,abc'),
        first.replaceFirst('DA:1,1', 'DA:1,1,def'),
      ]),
      throwsFormatException,
    );
  });

  test('a missing shard fails before replacing an earlier merged report', () {
    final root = Directory.systemTemp.createTempSync('sked-lcov-test-');
    addTearDown(() => root.deleteSync(recursive: true));
    final input = Directory(path.join(root.path, 'shards', '0'))
      ..createSync(recursive: true);
    File(path.join(input.path, 'lcov.info')).writeAsStringSync(first);
    final output = File(path.join(root.path, 'merged.info'))
      ..writeAsStringSync('previous');
    expect(
      () => coverage.main([input.parent.path, output.path, '2']),
      throwsStateError,
    );
    expect(output.readAsStringSync(), 'previous');
    final other = Directory(path.join(input.parent.path, '1'))..createSync();
    File(path.join(other.path, 'lcov.info')).writeAsStringSync(second);
    coverage.main([input.parent.path, output.path, '2']);
    expect(
      output.readAsStringSync(),
      coverage.mergeLcovReports([first, second]),
    );
  });
}
