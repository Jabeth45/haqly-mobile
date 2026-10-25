import 'package:haqly_mobile/domain/models/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract for persistent authentication and guest session management.
/// Follows docs/ARCHITECTURE.md Section 7 and docs/RULES.md.
abstract class SessionRepository {
  /// Restores session state from local persistent storage.
  Future<AuthState> restoreSession();

  /// Persists local guest sentinel session.
  Future<void> setGuestMode();

  /// Clears persisted session state.
  Future<void> clearSession();
}

/// [SessionRepository] implementation backed by [SharedPreferences]
/// with an optional in-memory fallback for headless automated testing.
class LocalSessionRepository implements SessionRepository {
  LocalSessionRepository({SharedPreferences? sharedPreferences})
    : _prefs = sharedPreferences;

  /// In-memory constructor for unit testing without platform channels.
  factory LocalSessionRepository.inMemory({
    bool isGuest = false,
    String? userId,
  }) {
    final repo = LocalSessionRepository();
    repo._inMemoryStorage = <String, Object>{};
    if (isGuest) {
      repo._inMemoryStorage![_keyIsGuest] = true;
      repo._inMemoryStorage![_keyUserId] = AuthState.localSentinel;
    } else if (userId != null) {
      repo._inMemoryStorage![_keyUserId] = userId;
      repo._inMemoryStorage![_keyIsGuest] = false;
    }
    return repo;
  }

  static const String _keyIsGuest = 'haqly_is_guest';
  static const String _keyUserId = 'haqly_user_id';

  final SharedPreferences? _prefs;
  Map<String, Object>? _inMemoryStorage;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  @override
  Future<AuthState> restoreSession() async {
    if (_inMemoryStorage != null) {
      final isGuest = _inMemoryStorage![_keyIsGuest] as bool? ?? false;
      final userId = _inMemoryStorage![_keyUserId] as String?;
      if (isGuest) {
        return const AuthState.guest();
      }
      if (userId != null && userId != AuthState.localSentinel) {
        return AuthState.authenticated(userId: userId);
      }
      return const AuthState.unauthenticated();
    }

    final prefs = await _getPrefs();
    final isGuest = prefs.getBool(_keyIsGuest) ?? false;
    final userId = prefs.getString(_keyUserId);

    if (isGuest) {
      return const AuthState.guest();
    }
    if (userId != null && userId != AuthState.localSentinel) {
      return AuthState.authenticated(userId: userId);
    }
    return const AuthState.unauthenticated();
  }

  @override
  Future<void> setGuestMode() async {
    if (_inMemoryStorage != null) {
      _inMemoryStorage![_keyIsGuest] = true;
      _inMemoryStorage![_keyUserId] = AuthState.localSentinel;
      return;
    }

    final prefs = await _getPrefs();
    await prefs.setBool(_keyIsGuest, true);
    await prefs.setString(_keyUserId, AuthState.localSentinel);
  }

  @override
  Future<void> clearSession() async {
    if (_inMemoryStorage != null) {
      _inMemoryStorage!.remove(_keyIsGuest);
      _inMemoryStorage!.remove(_keyUserId);
      return;
    }

    final prefs = await _getPrefs();
    await prefs.remove(_keyIsGuest);
    await prefs.remove(_keyUserId);
  }
}
