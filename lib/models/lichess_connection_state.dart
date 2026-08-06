/// Represents the authorization and connection states of the Lichess integration.
enum LichessConnectionState {
  /// User is not logged in or active session is deleted.
  disconnected,

  /// Active connection or authentication flow in progress.
  connecting,

  /// Successfully authenticated and session is active.
  connected,

  /// An error occurred during authentication (e.g. user denied permission).
  authenticationFailed,

  /// Network requests failed or offline status detected.
  networkUnavailable,
}
