import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';

void main() {
  test(
    'usage DTO rejects inconsistent counts and duplicate request identities',
    () {
      final run = ConversationRunUsage(
        id: 'run-one',
        kind: ConversationRunKind.model,
        startedAt: DateTime.utc(2026, 10, 30, 9),
        protocol: 'chatCompletions',
        model: 'synthetic-model',
        requests: [
          ConversationRequestUsage(
            id: 'request-one',
            startedAt: DateTime.utc(2026, 10, 30, 9),
          ),
        ],
      );
      final invalidCount = run.toJson();
      (invalidCount['requests'] as List).single['usage'] = {
        'inputTokens': 3,
        'outputTokens': 2,
        'totalTokens': 4,
      };
      expect(
        () => ConversationRunUsage.fromJson(invalidCount),
        throwsFormatException,
      );
      final duplicate = run.toJson();
      (duplicate['requests'] as List).add(
        (duplicate['requests'] as List).single,
      );
      expect(
        () => ConversationRunUsage.fromJson(duplicate),
        throwsFormatException,
      );
      final unfinished = run.toJson()..['status'] = 'completed';
      expect(
        () => ConversationRunUsage.fromJson(unfinished),
        throwsFormatException,
      );
    },
  );
}
