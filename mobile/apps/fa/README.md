# FA app

The Orbit Shifting Field Assistant app (Android, Telugu first, English as an option): enrol farmers, plan and
log visits, answer alerts, and keep working in villages with no signal. It runs on mock data today; the
offline engine (snapshot down, commands up, conflicts) is the real logic and stays when the API and Drift land.

```bash
cd mobile/apps/fa
flutter run --flavor dev                                            # mock data (default in dev)
flutter run --flavor dev --dart-define=ORBIT_MOCK_SCENARIO=offline  # start in a scenario
```

Mock logins (all in [data/README.md](lib/src/data/README.md#logins)):

| Login ID | Password | What happens |
|---|---|---|
| `FA-KDP-014` | `orbit2026` | Suresh Kumar, Kondapur and Gachibowli: the main mock world (46 farmers) |
| `FA-KDP-099` | `temp1234` | temporary password: must set his own first |
| `FA-KDP-077` | `temp5678` | temporary password expired: "call HO" |
| `FA-CVL-002` | `chevella2026` | another FA (Chevella), owns the farmers that clash at lookup and sync |

Consent OTP `123456`; HO helpline 1800 123 4567.

The dev menu (dev builds on mock data only) opens from the gear on the sign-in screens and from Me. It
switches the mock scenario (offline, slow, server error, phone removed, update required, sync conflict,
partial failure, session expired), moves the mock GPS, acts as HO (edits Padma S's Plot 2, sends a note, a
call-back request) to demo sync and conflicts, forces a sync, and resets the mock server or the phone.

Where things are:

- [`lib/src/data/README.md`](lib/src/data/README.md): models, repositories, the mock server and its world,
  scenarios, the session (login, PIN, heartbeat), and how to swap in the real API.
- [`lib/src/local/README.md`](lib/src/local/README.md): the offline engine (territory, outbox, push and pull,
  conflicts, photos) and the Drift / orbit_sync plan.
- `lib/src/features/<feature>/`: one folder per screen group (auth, farmers, farmer360, enrol, calendar,
  visit_log, alerts, sync, me, blocked, dev); `lib/src/routing/` the router and tab shell; `lib/src/shared/`
  widgets and helpers several features use.
- `test/` mirrors `lib/`; `test/support/harness.dart` signs in Suresh on a fresh mock (`createFaTest`,
  `pumpFaScreen`, `pumpFaApp`).

What is not done yet is listed in [mobile/README.md](../../README.md#not-done-yet).
