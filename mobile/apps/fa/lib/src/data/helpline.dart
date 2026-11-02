/// The HO helpline (digits only): the one number the app and the mock
/// server use. Read it in screens through `hoHelplineProvider`
/// (`shared/helpline.dart`).
///
/// TODO(contracts): neither the FA login response nor `AppConfig`
/// (`GET /v1/auth/app-config`, identity.yaml) carries a helpline yet. Once
/// the app-config contract has one, `hoHelplineProvider` reads it from
/// `SessionState.appConfig` and keeps this as the fallback before the first
/// app-config.
const hoHelplineNumber = '18001234567';
