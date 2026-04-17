/// Strategy interface for WebSocket reconnection delays.
abstract class ReconnectPolicy {
  /// Returns the duration to wait before the next connection attempt.
  Duration nextDelay();

  /// Resets the policy after a successful connection.
  void reset();
}

/// Immediate reconnect, then exponential backoff up to 30s.
class ExponentialBackoffPolicy implements ReconnectPolicy {
  int _attempts = 0;

  @override
  Duration nextDelay() {
    final ms = (500 * (1 << _attempts.clamp(0, 6))).clamp(500, 30000);
    _attempts++;
    return Duration(milliseconds: ms);
  }

  @override
  void reset() => _attempts = 0;
}

/// Fixed interval reconnect (useful for testing).
class FixedIntervalPolicy implements ReconnectPolicy {
  const FixedIntervalPolicy({this.interval = const Duration(seconds: 2)});
  final Duration interval;

  @override
  Duration nextDelay() => interval;

  @override
  void reset() {}
}
