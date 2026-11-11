import 'dart:collection';

import '../bridge/generated/api/contracts.dart' show HostModelContent;

/// Keeps ordinary result fields compatible with application tools while typed
/// model content crosses the host bridge separately from the JSON payload.
class ApplicationToolResult extends MapView<String, Object?> {
  ApplicationToolResult(
    Map<String, Object?> payload, {
    Iterable<HostModelContent> modelContent = const [],
  }) : modelContent = List.unmodifiable(modelContent),
       super(Map.unmodifiable(payload));

  final List<HostModelContent> modelContent;
}
