import 'dart:async';

/// Abstract contract for querying network connection availability.
/// Connectivity is treated as a hint only; real success is determined by HTTP responses.
/// Follows docs/ARCHITECTURE.md Section 1 and docs/RULES.md Rule 11.
abstract class ConnectivityService {
  /// Stream emitting connectivity status changes (true = online, false = offline).
  Stream<bool> get onConnectivityChanged;

  /// Whether device currently reports an active network connection.
  Future<bool> get isConnected;

  /// Releases resources and stream controllers.
  void dispose();
}

/// In-memory test double of [ConnectivityService] for deterministic unit tests.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({bool initialConnected = true})
    : _isConnected = initialConnected;

  bool _isConnected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> get isConnected async => _isConnected;

  /// Simulates a connectivity transition.
  void setConnected(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _controller.add(connected);
    }
  }

  @override
  void dispose() {
    _controller.close();
  }
}
