import 'support/capture_scene_registry.dart';

/// Captures a selected current UI journey on a native Flutter renderer.
/// Documentation screenshots and native behavior-only tests remain separate.
void main() {
  const scene = String.fromEnvironment('SKED_CAPTURE_SCENE');
  final register = captureSceneRegistry[scene];
  if (register == null) {
    throw ArgumentError.value(
      scene,
      'SKED_CAPTURE_SCENE',
      'Select one current capture group: ${captureSceneRegistry.keys.join(', ')}',
    );
  }
  register();
}
