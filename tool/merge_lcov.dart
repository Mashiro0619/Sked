import 'dart:convert';
import 'dart:io';

/// Merges Flutter's default line-coverage LCOV records. Unknown record types
/// fail instead of silently dropping function or branch data if CI changes.
String mergeLcovReports(Iterable<String> reports) {
  final merged = <String, Map<int, (int hits, String? checksum)>>{};
  var reportCount = 0;
  for (final report in reports) {
    reportCount++;
    String? source;
    var lines = <int, (int, String?)>{};
    int? declaredFound;
    int? declaredHit;
    var records = 0;
    for (final line in const LineSplitter().convert(report)) {
      if (line.isEmpty || line.startsWith('TN:')) continue;
      if (line.startsWith('SF:')) {
        if (source != null || line.length == 3) {
          throw const FormatException('Invalid or unterminated LCOV source.');
        }
        source = line.substring(3);
        continue;
      }
      if (source == null) {
        throw FormatException('LCOV record has no source: $line');
      }
      if (line.startsWith('DA:')) {
        final parts = line.substring(3).split(',');
        if (parts.length < 2 || parts.length > 3) {
          throw FormatException('Invalid LCOV line: $line');
        }
        final number = int.tryParse(parts[0]);
        final hits = int.tryParse(parts[1]);
        if (number == null ||
            number <= 0 ||
            hits == null ||
            hits < 0 ||
            lines.containsKey(number)) {
          throw FormatException('Invalid or duplicate LCOV line: $line');
        }
        lines[number] = (hits, parts.length == 3 ? parts[2] : null);
      } else if (line.startsWith('LF:') || line.startsWith('LH:')) {
        final count = int.tryParse(line.substring(3));
        if (count == null || count < 0) {
          throw FormatException('Invalid LCOV summary: $line');
        }
        if (line.startsWith('LF:')) {
          declaredFound = count;
        } else {
          declaredHit = count;
        }
      } else if (line == 'end_of_record') {
        if ((declaredFound != null && declaredFound != lines.length) ||
            (declaredHit != null &&
                declaredHit !=
                    lines.values.where((value) => value.$1 > 0).length)) {
          throw FormatException('LCOV summary does not match $source.');
        }
        final target = merged.putIfAbsent(source, () => {});
        for (final entry in lines.entries) {
          final previous = target[entry.key];
          final checksum = entry.value.$2;
          if (previous != null &&
              previous.$2 != null &&
              checksum != null &&
              previous.$2 != checksum) {
            throw FormatException(
              'Conflicting LCOV checksum: $source:${entry.key}',
            );
          }
          target[entry.key] = (
            (previous?.$1 ?? 0) + entry.value.$1,
            previous?.$2 ?? checksum,
          );
        }
        records++;
        source = null;
        lines = {};
        declaredFound = declaredHit = null;
      } else {
        throw FormatException('Unsupported LCOV record: $line');
      }
    }
    if (source != null || records == 0) {
      throw const FormatException('Empty or incomplete LCOV report.');
    }
  }
  if (reportCount == 0) throw const FormatException('No LCOV reports found.');
  final output = StringBuffer();
  for (final source in merged.keys.toList()..sort()) {
    final lines = merged[source]!;
    output.writeln('SF:$source');
    for (final number in lines.keys.toList()..sort()) {
      final (hits, checksum) = lines[number]!;
      output.writeln('DA:$number,$hits${checksum == null ? '' : ',$checksum'}');
    }
    output
      ..writeln('LF:${lines.length}')
      ..writeln('LH:${lines.values.where((value) => value.$1 > 0).length}')
      ..writeln('end_of_record');
  }
  return output.toString();
}

void main(List<String> args) {
  if (args.length != 3 ||
      int.tryParse(args[2]) == null ||
      int.parse(args[2]) < 1) {
    throw ArgumentError(
      'Usage: merge_lcov.dart <input-directory> <output-file> <expected-shards>',
    );
  }
  final inputs =
      Directory(args[0])
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.uri.pathSegments.last == 'lcov.info')
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (inputs.length != int.parse(args[2])) {
    throw StateError(
      'Expected ${args[2]} shard reports, found ${inputs.length}.',
    );
  }
  final merged = mergeLcovReports(
    inputs.map((file) => file.readAsStringSync()),
  );
  final output = File(args[1]);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(merged);
  stdout.writeln(
    'Merged ${inputs.length} shard reports: ${output.absolute.path}',
  );
}
