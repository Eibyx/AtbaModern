import 'dart:async';

/// Schedules the next poll only after the previous one settles.
/// Pausing invalidates the current generation and cancels its timer.
class AdaptivePoller {
  final Future<bool> Function() poll;
  final void Function(Object error)? onError;
  final Duration activeInterval;
  final Duration idleInterval;
  Timer? _timer;
  Future<void>? _inFlight;
  bool _enabled = false;
  bool _disposed = false;
  int _generation = 0;
  int _failures = 0;

  AdaptivePoller({
    required this.poll,
    this.onError,
    this.activeInterval = const Duration(seconds: 6),
    this.idleInterval = const Duration(seconds: 30),
  });

  bool get isEnabled => _enabled && !_disposed;
  bool get isPolling => _inFlight != null;

  void start() {
    if (_disposed || _enabled) return;
    _enabled = true;
    _generation++;
    unawaited(refresh());
  }

  void pause() {
    _enabled = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    _timer?.cancel();
    final existing = _inFlight;
    if (existing != null) return existing;
    final generation = _generation;
    final completer = Completer<void>();
    _inFlight = completer.future;
    () async {
      var interval = idleInterval;
      try {
        final active = await poll();
        _failures = 0;
        interval = active ? activeInterval : idleInterval;
      } catch (error) {
        _failures = (_failures + 1).clamp(1, 5);
        interval = Duration(seconds: (4 * (1 << _failures)).clamp(8, 120));
        if (!_disposed) onError?.call(error);
      } finally {
        _inFlight = null;
        completer.complete();
        if (isEnabled) {
          // A resume while an older poll was in flight gets a fresh cycle.
          _timer = Timer(
            generation == _generation ? interval : Duration.zero,
            () => unawaited(refresh()),
          );
        }
      }
    }();
    return completer.future;
  }

  void dispose() {
    pause();
    _disposed = true;
  }
}
