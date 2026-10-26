/// Pure Dart authentication and guest identity state.
/// Follows docs/ARCHITECTURE.md Section 6 & 7 and ADR-004.
class AuthState {
  const AuthState({
    required this.userId,
    required this.isGuest,
    required this.isAuthenticated,
    required this.isLoading,
    this.email,
  });

  /// Default local guest sentinel value.
  static const String localSentinel = 'LOCAL';

  /// Initial boot state while storage/session is being restored.
  const AuthState.initial()
    : userId = localSentinel,
      isGuest = false,
      isAuthenticated = false,
      isLoading = true,
      email = null;

  /// Pure local guest mode (M1 offline-first).
  const AuthState.guest()
    : userId = localSentinel,
      isGuest = true,
      isAuthenticated = false,
      isLoading = false,
      email = null;

  /// Authenticated remote user.
  const AuthState.authenticated({required this.userId, this.email})
    : isGuest = false,
      isAuthenticated = true,
      isLoading = false;

  /// Unauthenticated state (fresh install before guest/login choice).
  const AuthState.unauthenticated()
    : userId = localSentinel,
      isGuest = false,
      isAuthenticated = false,
      isLoading = false,
      email = null;

  /// Unique user identifier (`LOCAL` sentinel for offline guests).
  final String userId;

  /// True when operating as a local guest.
  final bool isGuest;

  /// True when authenticated with a remote Supabase account.
  final bool isAuthenticated;

  /// True while initial session check or restore is executing.
  final bool isLoading;

  /// User's email if authenticated with email/password.
  final String? email;

  /// Whether the user can access protected application routes (Home, etc.).
  bool get hasSession => isGuest || isAuthenticated;

  AuthState copyWith({
    String? userId,
    bool? isGuest,
    bool? isAuthenticated,
    bool? isLoading,
    String? email,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      isGuest: isGuest ?? this.isGuest,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          isGuest == other.isGuest &&
          isAuthenticated == other.isAuthenticated &&
          isLoading == other.isLoading &&
          email == other.email;

  @override
  int get hashCode =>
      Object.hash(userId, isGuest, isAuthenticated, isLoading, email);

  @override
  String toString() {
    return 'AuthState(userId: $userId, isGuest: $isGuest, '
        'isAuthenticated: $isAuthenticated, isLoading: $isLoading)';
  }
}
