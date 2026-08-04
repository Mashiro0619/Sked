import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/school_import_http_consent.dart';

void main() {
  test('only valid HTTP endpoints require confirmation', () {
    final store = SchoolImportHttpConsentStore();

    expect(store.requiresConfirmation('https://api.example.test/v1'), isFalse);
    expect(store.requiresConfirmation('ftp://api.example.test/v1'), isFalse);
    expect(store.requiresConfirmation('not a URL'), isFalse);
    expect(store.requiresConfirmation('http://api.example.test/v1'), isTrue);
  });

  test('approval is scoped to the normalized endpoint for this store', () {
    final store = SchoolImportHttpConsentStore();

    store.approve('HTTP://API.EXAMPLE.TEST:80/v1/');

    expect(store.requiresConfirmation('http://api.example.test/v1'), isFalse);
    expect(
      store.requiresConfirmation(
        'http://user:secret@api.example.test/v1?token=hidden#fragment',
      ),
      isFalse,
    );
    expect(
      store.displayEndpoint(
        'http://user:secret@api.example.test/v1?token=hidden#fragment',
      ),
      'http://api.example.test/v1',
    );
    expect(
      store.requiresConfirmation('http://api.example.test:8080/v1'),
      isTrue,
    );
    expect(store.requiresConfirmation('http://api.example.test/v2'), isTrue);
  });
}
