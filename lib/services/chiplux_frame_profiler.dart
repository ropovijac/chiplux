// Optional Chiplux rendering diagnostics for a connected physical device.
//
// Enable only while profiling with:
// flutter run --profile --dart-define=CHIPLUX_PROFILE_FRAMES=true
//
// Does not attach in debug/release builds or when the flag is absent.
// This collects rendering frame times; it does NOT measure app launch latency,
// network calls, actual displayed FPS, or provide route-specific attribution.
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart' show debugPrint, kProfileMode;
import 'package:flutter/scheduler.dart' show SchedulerBinding;

class ChipluxFrameProfiler {
  ChipluxFrameProfiler._();

  static const bool _enabled = bool.fromEnvironment(
    'CHIPLUX_PROFILE_FRAMES',
    defaultValue: false,
  );
  static const int _windowSize = 240;
  static const double _sixtyHertzBudgetMs = 1000 / 60;
  static const double _oneTwentyHertzBudgetMs = 1000 / 120;
  static bool _running = false;
  static final List<FrameTiming> _frames = <FrameTiming>[];

  static void start() {
    // Both conditions are compile-time constants. Release builds never attach
    // the callback, even when a dart-define is supplied by mistake.
    if (!kProfileMode || !_enabled || _running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    debugPrint(
      '[CHIPLUX FRAMES] Enabled: $_windowSize rendered frames per report. '
      'Reproduce one screen at a time; for attribution use Flutter DevTools.',
    );
  }

  static void _onTimings(List<FrameTiming> timings) {
    _frames.addAll(timings);
    while (_frames.length >= _windowSize) {
      final window = _frames.sublist(0, _windowSize);
      _frames.removeRange(0, _windowSize);
      _report(window);
    }
  }

  static void _report(List<FrameTiming> frames) {
    final ui = frames.map((e) => e.buildDuration.inMicroseconds / 1000).toList()..sort();
    final raster = frames.map((e) => e.rasterDuration.inMicroseconds / 1000).toList()..sort();
    final slow60 = frames.where((f) =>
      f.buildDuration.inMicroseconds / 1000 > _sixtyHertzBudgetMs ||
      f.rasterDuration.inMicroseconds / 1000 > _sixtyHertzBudgetMs,
    ).length;
    final slow120 = frames.where((f) =>
      f.buildDuration.inMicroseconds / 1000 > _oneTwentyHertzBudgetMs ||
      f.rasterDuration.inMicroseconds / 1000 > _oneTwentyHertzBudgetMs,
    ).length;

    // This is a reference-budget miss count, NOT a measured dropped-frame count:
    // compositor scheduling and a display's actual refresh rate also matter.
    debugPrint(
      '[CHIPLUX FRAMES] ${frames.length} rendered frames | '
      'UI ms p50=${_percentile(ui, 0.50).toStringAsFixed(1)} '
      'p95=${_percentile(ui, 0.95).toStringAsFixed(1)} '
      'max=${ui.last.toStringAsFixed(1)} | '
      'Raster ms p50=${_percentile(raster, 0.50).toStringAsFixed(1)} '
      'p95=${_percentile(raster, 0.95).toStringAsFixed(1)} '
      'max=${raster.last.toStringAsFixed(1)} | '
      'over 16.7ms=$slow60/${frames.length} | '
      'over 8.3ms=$slow120/${frames.length}',
    );
  }

  static double _percentile(List<double> sorted, double proportion) {
    if (sorted.isEmpty) return 0;
    // Nearest-rank percentile, where n = number of observed frames.
    final index = (sorted.length * proportion).ceil() - 1;
    final boundedIndex = index < 0
        ? 0
        : (index >= sorted.length ? sorted.length - 1 : index);
    return sorted[boundedIndex];
  }
}
