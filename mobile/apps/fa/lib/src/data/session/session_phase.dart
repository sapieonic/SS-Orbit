/// Where the FA is in sign-in, setup and unlock. The router redirects on this.
///
/// ```
/// restoring ─┬─ no session ─────────────────────────────> signedOut
///            ├─ temporary password ─────────────────────> mustChangePassword
///            ├─ grace over / PIN locked out / ended ────> passwordNeeded
///            ├─ no PIN ─────────────────────────────────> setup
///            └─ otherwise ──────────────────────────────> locked
/// signedOut / passwordNeeded / removed ── login ──> mustChangePassword | setup | active
/// mustChangePassword ── changePassword ──> setup ── setPin ──> active
/// locked ── unlock ──> active ── lock ──> locked
/// any ── app below min_version (outbox pushed first) ──> updateRequired
/// any ── device_revoked / heartbeat wipe ──> restoring (splash) while the
///        local data is deleted (retried at start and on resume) ──> removed
/// ```
///
/// The router shows a lock of an active FA over the open pages (they stay);
/// a cold start that is locked goes to the PIN page.
enum SessionPhase {
  /// Reading the saved session at start, or deleting the local data of a
  /// removed phone: show a splash. Never needs network.
  restoring,

  /// No session on this phone: the issued login (A1).
  signedOut,

  /// Signed in with a temporary password: set your own password (A1c). Every
  /// other `/v1/fa/*` call is refused until then.
  mustChangePassword,

  /// Signed in, no PIN yet (first login, or a password login after the PIN
  /// was locked out or set by another FA): language and PIN (A1d).
  setup,

  /// A PIN is set: PIN unlock (A1b). Works offline within the grace.
  locked,

  /// Normal use: the tabs and the rest of the app.
  active,

  /// The password is needed: the offline grace ended, the PIN was locked
  /// out, the server session ended for good, or the FA chose "Use password
  /// instead". Unsynced records are kept. See `SessionState.passwordNeededReason`.
  passwordNeeded,

  /// The app version is below the server's `min_version` (A12). The outbox
  /// was pushed first when the network allowed.
  updateRequired,

  /// HO removed this phone (`device_revoked` or a heartbeat `wipe`): local
  /// data, tokens and PIN are gone (A12).
  removed,
}
