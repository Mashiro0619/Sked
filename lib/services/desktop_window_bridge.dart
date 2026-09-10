import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The native window is the authority. Widget tests and non-Windows platforms
/// keep this bridge inactive; they never pretend to implement OS window chrome.
class DesktopWindowBridge extends ChangeNotifier {
  DesktopWindowBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.mashiro.sked/window');
  static final instance = DesktopWindowBridge();
  final MethodChannel _channel;
  bool available = false;
  bool maximized = false;
  bool focused = true;
  bool maximizeHovered = false;
  bool closing = false;
  Future<bool> Function()? prepareClose;
  Map<String, double>? _chromeGeometry;

  /// Paint and native hit testing use the same measured logical coordinates.
  Future<void> configureChrome({
    required double width,
    required double height,
    required double buttonWidth,
  }) async {
    if (!width.isFinite ||
        !height.isFinite ||
        !buttonWidth.isFinite ||
        buttonWidth <= 0 ||
        height <= 0 ||
        width < buttonWidth * 3) {
      return;
    }
    final geometry = <String, double>{
      'maximizeLeft': width - buttonWidth * 2,
      'maximizeTop': 0,
      'maximizeWidth': buttonWidth,
      'maximizeHeight': height,
    };
    if (!available || mapEquals(_chromeGeometry, geometry)) return;
    _chromeGeometry = geometry;
    try {
      await _channel.invokeMethod<void>('configureChrome', geometry);
    } on MissingPluginException {
      _chromeGeometry = null;
    } on PlatformException {
      _chromeGeometry = null;
    }
  }

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    _channel.setMethodCallHandler(_handle);
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>(
        'initialize',
      );
      available = state != null;
      _chromeGeometry = null;
      _update(state);
    } on MissingPluginException {
      available = false;
    }
  }

  void _update(Map<String, dynamic>? state) {
    maximized = state?['maximized'] as bool? ?? maximized;
    focused = state?['focused'] as bool? ?? focused;
    maximizeHovered = state?['maximizeHovered'] as bool? ?? maximizeHovered;
    notifyListeners();
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method == 'state') {
      _update(Map<String, dynamic>.from(call.arguments as Map));
    }
    if (call.method == 'closeRequested') await requestClose();
  }

  Future<void> command(String name) async {
    if (available) await _channel.invokeMethod<void>(name);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> requestClose() async {
    if (closing || !available) return;
    closing = true;
    notifyListeners();
    try {
      if (await prepareClose?.call() ?? true) await command('confirmClose');
    } finally {
      closing = false;
      notifyListeners();
    }
  }
}
