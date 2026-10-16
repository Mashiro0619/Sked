import 'dart:ffi';
import 'dart:io';

final class _NativeRect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class _NativePoint extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

/// Read-only Win32 evidence for the actual runner window. No ShowWindow,
/// foreground activation, resize, synthetic HWND, or window title fallback.
/// Only SDK dart:ffi is used, so both comparison sides need no package changes.
class StartupNativeWindowProbe {
  static const runnerClass = 'FLUTTER_RUNNER_WIN32_WINDOW';
  final _user32 = DynamicLibrary.open('user32.dll');
  final _kernel32 = DynamicLibrary.open('kernel32.dll');
  final _dwmapi = DynamicLibrary.open('dwmapi.dll');

  late final _findWindow = _user32
      .lookupFunction<
        IntPtr Function(IntPtr, IntPtr, Pointer<Uint16>, Pointer<Uint16>),
        int Function(int, int, Pointer<Uint16>, Pointer<Uint16>)
      >('FindWindowExW');
  late final _windowProcess = _user32
      .lookupFunction<
        Uint32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetWindowThreadProcessId');
  late final _isWindow = _user32
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsWindow');
  late final _isVisible = _user32
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
        'IsWindowVisible',
      );
  late final _isIconic = _user32
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsIconic');
  late final _isEnabled = _user32
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
        'IsWindowEnabled',
      );
  late final _foreground = _user32
      .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');
  late final _clientRect = _user32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<_NativeRect>),
        int Function(int, Pointer<_NativeRect>)
      >('GetClientRect');
  late final _windowRect = _user32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<_NativeRect>),
        int Function(int, Pointer<_NativeRect>)
      >('GetWindowRect');
  late final _clientToScreen = _user32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<_NativePoint>),
        int Function(int, Pointer<_NativePoint>)
      >('ClientToScreen');
  late final _monitorFromRect = _user32
      .lookupFunction<
        IntPtr Function(Pointer<_NativeRect>, Uint32),
        int Function(Pointer<_NativeRect>, int)
      >('MonitorFromRect');
  late final _dwmAttribute = _dwmapi
      .lookupFunction<
        Int32 Function(IntPtr, Uint32, Pointer<Void>, Uint32),
        int Function(int, int, Pointer<Void>, int)
      >('DwmGetWindowAttribute');
  late final _processHeap = _kernel32
      .lookupFunction<IntPtr Function(), int Function()>('GetProcessHeap');
  late final _heapAlloc = _kernel32
      .lookupFunction<
        Pointer<Void> Function(IntPtr, Uint32, UintPtr),
        Pointer<Void> Function(int, int, int)
      >('HeapAlloc');
  late final _heapFree = _kernel32
      .lookupFunction<
        Int32 Function(IntPtr, Uint32, Pointer<Void>),
        int Function(int, int, Pointer<Void>)
      >('HeapFree');

  Map<String, Object?> observe() {
    final heap = _processHeap();
    // Aligned scratch slots for DWORDs, RECTs, POINT, and the UTF-16 class.
    final allocation = _heapAlloc(heap, 0x00000008, 256); // HEAP_ZERO_MEMORY
    if (allocation.address == 0) {
      throw StateError('Win32 probe allocation failed.');
    }
    try {
      final bytes = allocation.cast<Uint8>();
      final process = bytes.cast<Uint32>();
      final cloak = (bytes + 4).cast<Uint32>();
      final outer = (bytes + 8).cast<_NativeRect>();
      final client = (bytes + 24).cast<_NativeRect>();
      final origin = (bytes + 40).cast<_NativePoint>();
      final screenClient = (bytes + 48).cast<_NativeRect>();
      final className = (bytes + 64).cast<Uint16>();
      className
          .asTypedList(runnerClass.length + 1)
          .setRange(0, runnerClass.length, runnerClass.codeUnits);

      final handles = <int>[];
      var previous = 0;
      var enumerated = 0;
      var enumerationComplete = false;
      while (enumerated < 256) {
        final handle = _findWindow(0, previous, className, nullptr);
        if (handle == 0) {
          enumerationComplete = true;
          break;
        }
        enumerated++;
        process.value = 0;
        final thread = _windowProcess(handle, process);
        if (thread != 0 && process.value == pid) handles.add(handle);
        previous = handle;
      }
      final failures = <String>[];
      if (!enumerationComplete) {
        failures.add('Runner-window enumeration was incomplete.');
      }
      if (handles.length != 1) {
        failures.add(
          'Expected one runner window owned by PID $pid; found ${handles.length}.',
        );
      }
      final result = <String, Object?>{
        'probe': 'Win32 user32/dwmapi',
        'processId': pid,
        'runnerClass': runnerClass,
        'matchingOwnedWindowHandles': handles,
        'matchingOwnedWindowCount': handles.length,
        'enumerationComplete': enumerationComplete,
        'failures': failures,
        'validatedVisible': false,
      };
      if (failures.isNotEmpty) return result;

      final handle = handles.single;
      process.value = 0;
      final threadId = _windowProcess(handle, process);
      final exists = _isWindow(handle) != 0;
      final visible = _isVisible(handle) != 0;
      final minimized = _isIconic(handle) != 0;
      final enabled = _isEnabled(handle) != 0;
      final outerOk = _windowRect(handle, outer) != 0;
      final clientOk = _clientRect(handle, client) != 0;
      final cloakResult = _dwmAttribute(
        handle,
        14,
        cloak.cast<Void>(),
        4,
      ); // DWMWA_CLOAKED
      final clientWidth = client.ref.right - client.ref.left;
      final clientHeight = client.ref.bottom - client.ref.top;
      origin.ref.x = client.ref.left;
      origin.ref.y = client.ref.top;
      final originOk = clientOk && _clientToScreen(handle, origin) != 0;
      screenClient.ref.left = origin.ref.x;
      screenClient.ref.top = origin.ref.y;
      screenClient.ref.right = origin.ref.x + clientWidth;
      screenClient.ref.bottom = origin.ref.y + clientHeight;
      final monitor = originOk && clientWidth > 0 && clientHeight > 0
          ? _monitorFromRect(screenClient, 0) // MONITOR_DEFAULTTONULL
          : 0;
      if (!exists || threadId == 0 || process.value != pid) {
        failures.add(
          'The observed runner HWND no longer belongs to this process.',
        );
      }
      if (!visible) failures.add('IsWindowVisible returned false.');
      if (minimized) failures.add('IsIconic returned true.');
      if (!enabled) failures.add('IsWindowEnabled returned false.');
      if (cloakResult != 0 || cloak.value != 0) {
        failures.add('DWM cloak query failed or the window is cloaked.');
      }
      if (!outerOk ||
          outer.ref.right <= outer.ref.left ||
          outer.ref.bottom <= outer.ref.top) {
        failures.add('The native window rectangle is unavailable or empty.');
      }
      if (!clientOk ||
          !originOk ||
          clientWidth <= 0 ||
          clientHeight <= 0 ||
          monitor == 0) {
        failures.add(
          'The native client rectangle is empty, unavailable, or outside all monitors.',
        );
      }
      result.addAll({
        'hwnd': handle,
        'hwndHex': '0x${handle.toRadixString(16)}',
        'observedOwnerProcessId': process.value,
        'threadId': threadId,
        'isWindow': exists,
        'isWindowVisible': visible,
        'isIconic': minimized,
        'isWindowEnabled': enabled,
        'dwmCloakHresult': cloakResult,
        'dwmCloaked': cloak.value,
        'windowRectAvailable': outerOk,
        'windowRect': _rect(outer.ref),
        'clientRectAvailable': clientOk,
        'clientRect': _rect(client.ref),
        'clientWidth': clientWidth,
        'clientHeight': clientHeight,
        'clientScreenRectAvailable': originOk,
        'clientScreenRect': _rect(screenClient.ref),
        'intersectsMonitor': monitor != 0,
        'monitorHandle': monitor,
        'isForeground': _foreground() == handle,
        'validatedVisible': failures.isEmpty,
      });
      return result;
    } finally {
      _heapFree(heap, 0, allocation);
    }
  }

  static Map<String, int> _rect(_NativeRect rect) => {
    'left': rect.left,
    'top': rect.top,
    'right': rect.right,
    'bottom': rect.bottom,
  };
}
