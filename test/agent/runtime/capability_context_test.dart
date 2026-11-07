import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider_models.dart';
import 'package:sked/agent/runtime/capability_context.dart';

void main() {
  final tool = ToolDefinition(
    name: 'fixture.read',
    description: 'Read the selected synthetic object.',
    parameters: {
      'type': 'object',
      'properties': {
        'fields': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'query': {
          'type': 'string',
          'description': 'Synthetic query detail ' * 100,
        },
      },
      'additionalProperties': false,
    },
  );
  Map<String, Object?> entry() => {
    'name': tool.name,
    'description': tool.description,
    'parameters': tool.parameters,
  };
  Map<String, Object?> result(List<Object?> entries) => {
    'toolApiVersion': '1.0.0',
    'permissionMode': 'plan',
    'now': '2026-11-07T12:00:00+08:00',
    'workspace': 'general',
    'tools': entries,
    'totalMatches': 17,
    'hasMore': true,
    'nextOffset': 8,
  };

  test('matching schemas use the current request while preserving discovery metadata', () {
    final original = result([entry()]);
    final source = jsonEncode(original);
    final projected = projectCapabilityDiscoveryContext(
      source,
      requestTools: [tool],
    );
    final decoded = jsonDecode(projected) as Map;
    expect(decoded, {
      ...original,
      'tools': [
        {'name': tool.name, 'schemaInCurrentTools': true},
      ],
    });
    expect(
      utf8.encode(projected).length,
      lessThan(utf8.encode(source).length ~/ 4),
    );
    expect(original['tools'], [entry()]);
  });

  for (final mismatch in [
    'name',
    'description',
    'parameters',
    'additional field',
  ]) {
    test('a $mismatch mismatch preserves the original schema exactly', () {
      final changed = entry();
      switch (mismatch) {
        case 'name':
          changed['name'] = 'fixture.other';
          break;
        case 'description':
          changed['description'] = 'An older description';
          break;
        case 'parameters':
          changed['parameters'] = {
            'type': 'object',
            'required': ['old'],
          };
          break;
        case 'additional field':
          changed['origin'] = 'Earlier record';
          break;
      }
      final source = const JsonEncoder.withIndent('  ')
          .convert(result([changed]));
      expect(
        projectCapabilityDiscoveryContext(source, requestTools: [tool]),
        source,
      );
    });
  }

  test('partial pages retain unavailable definitions and entry order', () {
    final unavailable = {...entry(), 'name': 'fixture.unavailable'};
    final projected = jsonDecode(
      projectCapabilityDiscoveryContext(
        jsonEncode(result([unavailable, entry()])),
        requestTools: [tool],
      ),
    ) as Map;
    expect(projected['tools'], [
      unavailable,
      {'name': tool.name, 'schemaInCurrentTools': true},
    ]);
  });

  test(
    'equivalent nested object key order still matches the current schema',
    () {
      final reordered = {
        'additionalProperties': false,
        'properties': {
          'query': {
            'description': 'Synthetic query detail ' * 100,
            'type': 'string',
          },
          'fields': {
            'items': {'type': 'string'},
            'type': 'array',
          },
        },
        'type': 'object',
      };
      final projected = jsonDecode(
        projectCapabilityDiscoveryContext(
          jsonEncode(
            result([
              {...entry(), 'parameters': reordered},
            ]),
          ),
          requestTools: [tool],
        ),
      ) as Map;
      expect(projected['tools'], [
        {'name': tool.name, 'schemaInCurrentTools': true},
      ]);
    },
  );

  test('empty request tools and malformed historical content retain their exact source', () {
    final source = jsonEncode(result([entry()]));
    expect(
      projectCapabilityDiscoveryContext(source, requestTools: const []),
      source,
    );
    for (final malformed in [
      'legacy text',
      '[]',
      '{"tools":null}',
      '{"tools":[null,"legacy"]}',
    ]) {
      expect(
        projectCapabilityDiscoveryContext(malformed, requestTools: [tool]),
        malformed,
      );
    }
  });
}
