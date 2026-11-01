/// Where the farmer is in sign-in and sign-up. The router redirects on this.
///
/// The session store saves the last one of a signed-in farmer
/// ([SavedSessionPhase.saved]), so an offline start resumes there.
enum SessionPhase {
  /// Reading the saved session at start: show a splash.
  restoring,

  /// No session: phone entry (F1).
  signedOut,

  /// OTP sent: code entry (F1), the session's phone and OTP
  /// are set.
  otpSent,

  /// Signed in, self sign-up: programme consent (F1a).
  needsConsent,

  /// Consent given: village picker.
  needsVillage,

  /// Village picked (kept in the session, not saved): name entry, then complete.
  needsName,

  /// Normal use: Home and the rest of the app.
  active,

  /// Deactivated by HO: "Account paused, call helpline".
  inactive,
}

/// The phase a signed-in farmer goes back to on an offline start, from the
/// last phase saved with the session. Null for phases that are not saved.
extension SavedSessionPhase on SessionPhase {
  /// What to save for this phase: the village picked on [needsName] is not
  /// saved, so that resumes at [needsVillage]; phases without a session
  /// return null.
  SessionPhase? get saved => switch (this) {
    SessionPhase.needsConsent ||
    SessionPhase.needsVillage ||
    SessionPhase.active ||
    SessionPhase.inactive => this,
    SessionPhase.needsName => SessionPhase.needsVillage,
    SessionPhase.restoring ||
    SessionPhase.signedOut ||
    SessionPhase.otpSent => null,
  };
}
