import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/school_web_session_service.dart';

class _NativeView extends Fake implements InAppWebViewController {
  @override
  dynamic getViewId() => 42;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Windows waits for native view disposal before clearing the profile',
    () async {
      final disposed = Completer<void>();
      var profileCleared = false;
      final service = SchoolWebSessionService(
        platform: TargetPlatform.windows,
        disposeWindowsView: (id) async {
          expect(id, 42);
          await disposed.future;
        },
        clearWindowsProfile: () async => profileCleared = true,
      );
      service.registerBrowser(
        () => service.finishClosingBrowser(_NativeView()),
      );

      final clearing = service.clear();
      await Future<void>.delayed(Duration.zero);
      expect(profileCleared, isFalse);
      disposed.complete();
      await clearing;
      expect(profileCleared, isTrue);
    },
  );

  test('failed native disposal prevents profile cleanup', () async {
    var profileCleared = false;
    final service = SchoolWebSessionService(
      platform: TargetPlatform.windows,
      disposeWindowsView: (_) async => throw StateError('view still active'),
      clearWindowsProfile: () async => profileCleared = true,
    );
    service.registerBrowser(() => service.finishClosingBrowser(_NativeView()));

    await expectLater(service.clear(), throwsStateError);
    expect(profileCleared, isFalse);
  });

  test(
    'Windows view disposal uses the pinned plugin acknowledgement',
    () async {
      const channel = MethodChannel(
        'com.pichillilorenzo/flutter_inappwebview_manager',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'dispose');
        expect(call.arguments, {'id': 42});
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await SchoolWebSessionService(platform: TargetPlatform.windows)
          .finishClosingBrowser(_NativeView());
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform clears cookies, website storage, and cache after closing views',
      () async {
        final calls = <String>[];
        final service = SchoolWebSessionService(
          platform: platform,
          clearCookies: () async => calls.add('cookies'),
          clearStorage: () async => calls.add('storage'),
          clearCache: () async => calls.add('cache'),
        );
        final unregister = service.registerBrowser(
          () async => calls.add('close'),
        );

        await service.clear();

        expect(calls, ['close', 'cookies', 'storage', 'cache']);
        unregister();
        calls.clear();
        await service.clear();
        expect(calls, ['cookies', 'storage', 'cache']);
      },
    );
  }

  test(
    'Windows clears the actual profile and never invokes plugin stubs',
    () async {
      final calls = <String>[];
      final service = SchoolWebSessionService(
        platform: TargetPlatform.windows,
        clearWindowsProfile: () async => calls.add('profile'),
        clearCookies: () async => fail('Windows plugin cookie-only cleanup'),
        clearStorage: () async => fail('unimplemented Windows storage cleanup'),
        clearCache: () async => fail('unimplemented Windows cache cleanup'),
      );
      service.registerBrowser(() async => calls.add('close'));

      await service.clear();

      expect(calls, ['close', 'profile']);
    },
  );

  test('failed native clear propagates and a later retry can finish', () async {
    var failClear = true;
    final service = SchoolWebSessionService(
      platform: TargetPlatform.windows,
      clearWindowsProfile: () async {
        if (failClear) throw StateError('profile clear failed');
      },
    );

    await expectLater(service.clear(), throwsStateError);
    failClear = false;
    await expectLater(service.clear(), completes);
  });

  test('concurrent clear requests share one cleanup operation', () async {
    final proceed = Completer<void>();
    var calls = 0;
    final service = SchoolWebSessionService(
      platform: TargetPlatform.windows,
      clearWindowsProfile: () async {
        calls++;
        await proceed.future;
      },
    );

    final first = service.clear();
    final second = service.clear();
    expect(calls, 1);
    proceed.complete();
    await Future.wait([first, second]);
    expect(calls, 1);
  });

  test(
    'browsers registered while another is closing are also suspended',
    () async {
      final closed = Completer<void>();
      final calls = <String>[];
      final service = SchoolWebSessionService(
        platform: TargetPlatform.windows,
        clearWindowsProfile: () async => calls.add('clear'),
      );
      service.registerBrowser(() async {
        expect(service.isClearing, isTrue);
        calls.add('first');
        await closed.future;
      });
      final clearing = service.clear();
      service.registerBrowser(() async => calls.add('late'));
      closed.complete();
      await clearing;
      expect(calls, ['first', 'late', 'clear']);
    },
  );

  test(
    'registration during native cleanup causes another cleanup pass',
    () async {
      final cleared = Completer<void>();
      final calls = <String>[];
      final service = SchoolWebSessionService(
        platform: TargetPlatform.windows,
        clearWindowsProfile: () async {
          calls.add('clear');
          await cleared.future;
        },
      );
      final clearing = service.clear();
      service.registerBrowser(() async => calls.add('late'));
      cleared.complete();
      await clearing;
      expect(calls, ['clear', 'late', 'clear']);
    },
  );

  test(
    'Windows bridge failure is preserved while its controller is released',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(
        SchoolWebSessionService.windowsChannel,
        (call) async {
          calls.add(call.method);
          throw PlatformException(code: call.method);
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SchoolWebSessionService.windowsChannel,
          null,
        ),
      );
      final service = SchoolWebSessionService(platform: TargetPlatform.windows);

      await expectLater(
        service.clear(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'clear',
          ),
        ),
      );

      expect(calls, ['clear', 'release']);
    },
  );
}
