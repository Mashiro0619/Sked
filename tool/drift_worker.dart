import 'package:drift/wasm.dart';

/// Rebuild with: dart compile js -O4 --no-source-maps tool/drift_worker.dart
/// -o web/drift_worker.js
void main() => WasmDatabase.workerMainForOpen();
