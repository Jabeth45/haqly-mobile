/// Injectable Clock interface to allow deterministic time in tests and domain calculations.
abstract class Clock {
  const Clock();

  DateTime now();
}

/// System Clock that uses actual device wall-clock time.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Fixed Clock for tests and predictable time simulations.
class FixedClock extends Clock {
  const FixedClock(this.fixedTime);

  final DateTime fixedTime;

  @override
  DateTime now() => fixedTime;
}
