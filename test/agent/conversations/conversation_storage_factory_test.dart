import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  String? source;

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);

  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
  }
}

void main() {
  test('default conversation storage uses the explicit test owner', () async {
    final previous = ConversationStorage();
    addTearDown(() => debugSetConversationStorageFactory(() => previous));
    final owned = _Storage();
    debugSetConversationStorageFactory(() => owned);
    final first = ConversationStorage();
    await first.save('synthetic archive', revision: 1);
    final restarted = ConversationStorage();
    expect(first, same(owned));
    expect(restarted, same(owned));
    expect((await restarted.load()).source, 'synthetic archive');
    // Replacing the factory leaves a previous runtime bound to its old store.
    final nextTest = _Storage();
    debugSetConversationStorageFactory(() => nextTest);
    await first.save('late result', revision: 2);
    expect((await ConversationStorage().load()).source, isNull);
    expect((await restarted.load()).source, 'late result');
  });
}
