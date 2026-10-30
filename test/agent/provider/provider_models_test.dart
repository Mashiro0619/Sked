import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';

void main() {
  test(
    'empty unconstrained schemas and JSON maps retain their JSON meaning',
    () {
      final properties = <dynamic, dynamic>{'value': <dynamic, dynamic>{}};
      final tool = ToolDefinition(
        name: 'settings.prepare',
        description: 'Prepare settings',
        parameters: {'type': 'object', 'properties': properties},
      );
      properties['value'] = 'mutated';
      expect(tool.parameters['properties'], {'value': <String, Object?>{}});
      expect(
        () => (tool.parameters['properties'] as Map)['bad'] = true,
        throwsUnsupportedError,
      );
    },
  );

  test('non JSON, cyclic and deeply nested arguments are rejected', () {
    final cyclic = <String, Object?>{};
    cyclic['again'] = cyclic;
    for (final value in [
      cyclic,
      {'key': double.infinity},
      {
        'key': {2: 'bad'},
      },
    ]) {
      expect(() => freezeProviderMap(value), throwsA(isA<ProviderException>()));
    }
  });
}
