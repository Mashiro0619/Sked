import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/desktop_window_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/window');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });
  test('native state, commands and guarded close stay serialized', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return call.method == 'initialize'
          ? {'maximized': true, 'focused': true}
          : null;
    });
    final bridge = DesktopWindowBridge(channel: channel);
    await bridge.initialize();
    expect(bridge.available, isTrue);
    expect(bridge.maximized, isTrue);
    await bridge.command('minimize');
    Future<void> incoming(String method, Object? arguments) async {
      final reply = Completer<void>();
      // Flutter's test messenger models the native-to-Dart method channel.
      // ignore: deprecated_member_use
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) => reply.complete(),
      );
      await reply.future;
    }

    await incoming('state', {
      'maximized': false,
      'focused': false,
      'maximizeHovered': true,
    });
    expect(bridge.maximized, isFalse);
    expect(bridge.focused, isFalse);
    expect(bridge.maximizeHovered, isTrue);
    bridge.prepareClose = () async => false;
    await incoming('closeRequested', null);
    bridge.prepareClose = () async => false;
    await bridge.requestClose();
    expect(methods, isNot(contains('confirmClose')));
    final decision = Completer<bool>();
    bridge.prepareClose = () => decision.future;
    final close = bridge.requestClose();
    await bridge.requestClose();
    expect(bridge.closing, isTrue);
    decision.complete(true);
    await close;
    expect(methods.where((v) => v == 'confirmClose').length, 1);
    expect(bridge.closing, isFalse);
    bridge.prepareClose = () async => throw StateError('save failed');
    await expectLater(bridge.requestClose(), throwsStateError);
    expect(bridge.closing, isFalse);
    bridge.dispose();
  });
  test(
    'non-Windows and missing native bridge never expose caption controls',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final bridge = DesktopWindowBridge(channel: channel);
      await bridge.initialize();
      await bridge.command('minimize');
      await bridge.requestClose();
      expect(bridge.available, isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await bridge.initialize();
      expect(bridge.available, isFalse);
      bridge.dispose();
    },
  );
  test('measured caption geometry follows text scale, skips duplicates and retries failed configuration', () async {
    var reject = false;
    final geometries = <Map<Object?, Object?>>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') return {'maximized': false};
      if (call.method == 'configureChrome') {
        geometries.add(call.arguments as Map<Object?, Object?>);
        if (reject) throw PlatformException(code: 'native');
      }
      return null;
    });
    final b = DesktopWindowBridge(channel: channel);
    addTearDown(b.dispose);
    await b.initialize();
    await b.configureChrome(width: 1440, height: 48, buttonWidth: 46);
    await b.configureChrome(width: 1440, height: 48, buttonWidth: 46);
    expect(geometries, hasLength(1));
    expect(geometries.single['maximizeLeft'], 1348);
    expect(geometries.single['maximizeHeight'], 48);
    reject = true;
    await b.configureChrome(width: 1280, height: 64, buttonWidth: 46);
    reject = false;
    await b.configureChrome(width: 1280, height: 64, buttonWidth: 46);
    expect(geometries, hasLength(3));
    expect(geometries.last['maximizeHeight'], 64);
    await b.configureChrome(
      width: double.infinity,
      height: 48,
      buttonWidth: 46,
    );
    await b.configureChrome(width: 100, height: 48, buttonWidth: 46);
    expect(geometries, hasLength(3));
    messenger.setMockMethodCallHandler(channel, null);
    await b.configureChrome(width: 800, height: 48, buttonWidth: 46);
  });
}
