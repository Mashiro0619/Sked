import 'dart:convert';

import '../../application/mutation_coordinator.dart' show mutationDigest;
import '../../application/operation_contracts.dart' show OperationProblem;
import '../provider/provider_models.dart';

/// Projects a paired discovery reply for one request. The archive retains the
/// original reply, and tools absent from this request retain their definitions.
String projectCapabilityDiscoveryContext(
  String source, {
  required Iterable<ToolDefinition> requestTools,
}) {
  final tools = {for (final tool in requestTools) tool.name: tool};
  if (tools.isEmpty) return source;
  try {
    final result = jsonDecode(source);
    if (result is! Map<String, Object?> || result['tools'] is! List) {
      return source;
    }
    var changed = false;
    final entries = <Object?>[];
    for (final entry in result['tools'] as List) {
      final tool = entry is Map<String, Object?> ? tools[entry['name']] : null;
      if (tool != null &&
          entry.length == 3 &&
          entry['description'] == tool.description &&
          entry['parameters'] is Map<String, Object?> &&
          mutationDigest(entry['parameters']) ==
              mutationDigest(tool.parameters)) {
        entries.add({'name': tool.name, 'schemaInCurrentTools': true});
        changed = true;
      } else {
        entries.add(entry);
      }
    }
    return changed ? jsonEncode({...result, 'tools': entries}) : source;
  } on FormatException {
    return source;
  } on OperationProblem {
    // Historical input that exceeds canonicalization limits stays readable.
    return source;
  }
}
