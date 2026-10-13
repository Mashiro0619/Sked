import 'dart:math' as math;

/// One engine frame. Timestamps and durations are monotonic microseconds.
class UiPerformanceFrame {
  const UiPerformanceFrame({
    required this.vsyncStart,
    required this.build,
    required this.raster,
    required this.total,
    required this.vsyncOverhead,
  });

  final int vsyncStart, build, raster, total, vsyncOverhead;

  Map<String, int> toJson() => {
    'vsyncStartUs': vsyncStart,
    'buildUs': build,
    'rasterUs': raster,
    'totalSpanUs': total,
    'vsyncOverheadUs': vsyncOverhead,
  };
}

/// Nearest-rank percentiles retain actual observations, including long tails.
/// An empty sample is unavailable, never a zero-duration success.
Map<String, num?> uiDurationDistribution(Iterable<int> values) {
  final sorted = values.toList()..sort();
  int? percentile(double fraction) => sorted.isEmpty
      ? null
      : sorted[math.max(0, (sorted.length * fraction).ceil() - 1)];
  return {
    'p50Us': percentile(.50),
    'p95Us': percentile(.95),
    'p99Us': percentile(.99),
    'maxUs': sorted.isEmpty ? null : sorted.last,
  };
}

Map<String, Object?> summarizeUiFrames(
  List<UiPerformanceFrame> frames, {
  required double frameBudgetUs,
}) {
  if (!frameBudgetUs.isFinite || frameBudgetUs <= 0) {
    throw ArgumentError.value(frameBudgetUs, 'frameBudgetUs');
  }
  final buildOver = frames.where((f) => f.build > frameBudgetUs).length;
  final rasterOver = frames.where((f) => f.raster > frameBudgetUs).length;
  final eitherOver = frames
      .where((f) => f.build > frameBudgetUs || f.raster > frameBudgetUs)
      .length;
  return {
    'frameCount': frames.length,
    'frameBudgetUs': frameBudgetUs,
    'build': uiDurationDistribution(frames.map((f) => f.build)),
    'raster': uiDurationDistribution(frames.map((f) => f.raster)),
    'totalSpan': uiDurationDistribution(frames.map((f) => f.total)),
    'vsyncOverhead': uiDurationDistribution(frames.map((f) => f.vsyncOverhead)),
    'overBudget': {
      'buildFrames': buildOver,
      'rasterFrames': rasterOver,
      'eitherStageFrames': eitherOver,
      'eitherStageRatio': frames.isEmpty ? null : eitherOver / frames.length,
    },
  };
}
