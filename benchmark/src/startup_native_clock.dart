import 'dart:ffi';

import 'startup_clock.dart';

class StartupClock {
  StartupClock() {
    entry = stamp();
  }

  final stopwatch = Stopwatch()..start();
  final samples = <StartupNativeClockSample>[];
  final issues = <String>[];
  late final Map<String, int> entry;
  _Win32ClockReader? _reader;
  bool _readerFailed = false;

  Map<String, int> stamp() {
    final before = stopwatch.elapsedMicroseconds;
    if (!_readerFailed) {
      try {
        final reading = (_reader ??= _Win32ClockReader()).read();
        final diagnosticUtc = DateTime.now().toUtc().microsecondsSinceEpoch;
        final after = stopwatch.elapsedMicroseconds;
        final sample = StartupNativeClockSample(
          index: samples.length,
          qpcFrequencyBefore: reading.frequencyBefore,
          qpcBeforeTicks: reading.before,
          preciseFileTimeTicks: reading.fileTime,
          qpcAfterTicks: reading.after,
          qpcFrequencyAfter: reading.frequencyAfter,
          elapsedBeforeUs: before,
          elapsedAfterUs: after,
          dartUtcUsDiagnostic: diagnosticUtc,
        );
        samples.add(sample);
        return {
          'utcUs': sample.utcUs,
          'elapsedBeforeUs': before,
          'elapsedAfterUs': after,
          'nativeSampleIndex': sample.index,
          'utcSourceIsPrecise': 1,
          'dartUtcUsDiagnostic': diagnosticUtc,
        };
      } catch (error, stack) {
        _readerFailed = true;
        issues.add('Independent Win32 clock sampling failed: $error\n$stack');
      }
    }
    // Failure evidence only. Missing native samples make validation fail; this
    // fallback can never produce an accepted v2 duration.
    return {
      'utcUs': DateTime.now().toUtc().microsecondsSinceEpoch,
      'elapsedBeforeUs': before,
      'elapsedAfterUs': stopwatch.elapsedMicroseconds,
      'nativeSampleIndex': -1,
      'utcSourceIsPrecise': 0,
    };
  }
}

class _Win32ClockReading {
  const _Win32ClockReading({
    required this.frequencyBefore,
    required this.before,
    required this.fileTime,
    required this.after,
    required this.frequencyAfter,
  });

  final int frequencyBefore;
  final int before;
  final int fileTime;
  final int after;
  final int frequencyAfter;
}

class _Win32ClockReader {
  _Win32ClockReader() {
    final kernel = DynamicLibrary.open('kernel32.dll');
    _counter = kernel
        .lookupFunction<
          Int32 Function(Pointer<Int64>),
          int Function(Pointer<Int64>)
        >('QueryPerformanceCounter');
    _frequency = kernel
        .lookupFunction<
          Int32 Function(Pointer<Int64>),
          int Function(Pointer<Int64>)
        >('QueryPerformanceFrequency');
    _preciseTime = kernel
        .lookupFunction<
          Void Function(Pointer<Uint64>),
          void Function(Pointer<Uint64>)
        >('GetSystemTimePreciseAsFileTime');
    _processHeap = kernel.lookupFunction<IntPtr Function(), int Function()>(
      'GetProcessHeap',
    );
    _allocate = kernel
        .lookupFunction<
          Pointer<Void> Function(IntPtr, Uint32, UintPtr),
          Pointer<Void> Function(int, int, int)
        >('HeapAlloc');
    _free = kernel
        .lookupFunction<
          Int32 Function(IntPtr, Uint32, Pointer<Void>),
          int Function(int, int, Pointer<Void>)
        >('HeapFree');
  }

  late final int Function(Pointer<Int64>) _counter;
  late final int Function(Pointer<Int64>) _frequency;
  late final void Function(Pointer<Uint64>) _preciseTime;
  late final int Function() _processHeap;
  late final Pointer<Void> Function(int, int, int) _allocate;
  late final int Function(int, int, Pointer<Void>) _free;

  _Win32ClockReading read() {
    final heap = _processHeap();
    final memory = _allocate(heap, 0x00000008, 40); // HEAP_ZERO_MEMORY
    if (memory.address == 0) {
      throw StateError('Win32 clock scratch allocation failed.');
    }
    try {
      final slots = memory.cast<Int64>();
      final frequencyBefore = slots;
      final before = slots + 1;
      final wall = (slots + 2).cast<Uint64>();
      final after = slots + 3;
      final frequencyAfter = slots + 4;
      if (_frequency(frequencyBefore) == 0) {
        throw StateError(
          'QueryPerformanceFrequency failed before calibration.',
        );
      }
      if (_counter(before) == 0) {
        throw StateError('QueryPerformanceCounter failed before FILETIME.');
      }
      _preciseTime(wall);
      if (_counter(after) == 0) {
        throw StateError('QueryPerformanceCounter failed after FILETIME.');
      }
      if (_frequency(frequencyAfter) == 0) {
        throw StateError('QueryPerformanceFrequency failed after calibration.');
      }
      return _Win32ClockReading(
        frequencyBefore: frequencyBefore.value,
        before: before.value,
        fileTime: wall.value,
        after: after.value,
        frequencyAfter: frequencyAfter.value,
      );
    } finally {
      _free(heap, 0, memory);
    }
  }
}
