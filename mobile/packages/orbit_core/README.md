# orbit_core

Pure-Dart foundations shared by the Farmer and FA apps. No Flutter imports, so it also works in background
isolates (WorkManager sync) and CLI tools.

```dart
import 'package:orbit_core/orbit_core.dart';
```

| What | API | Notes |
|---|---|---|
| API errors | `ApiError`, `ApiErrorCode` | Mirrors `{error: {code, message, details}}` + HTTP status + `Retry-After`. `ApiError.network()` for no response: code `network`, or `timeout` with `timeout: true` (its own "network is slow" text in orbit_l10n); `isNetwork` is true for both. `ApiErrorCode` also has the FA sync rejection reasons (`registered_with_another_fa`, `not_in_your_area`, `server_could_not_apply`). Helpers: `isNetwork`, `isTimeout`, `isRetryable`, `isUnauthorized`, `isExpiredToken`, `isDeviceRevoked`, `attemptsLeft`, `fieldErrors`. `ApiError.fromResponse(status, body, retryAfterHeader:)` is for the HTTP layer. Every repository, mock or real, throws only this type for expected failures. |
| Environment | `OrbitEnv`, `Flavor`, `DataSource` | `OrbitEnv.parse(flavor:, dataSource:, apiBaseUrl:)` from plain strings (`appFlavor`, dart-defines). Dev defaults to mock; staging and prod refuse mock (`StateError`). Base URLs: dev `http://10.0.2.2:8080` (Android emulator; pass `ORBIT_API_BASE_URL=http://localhost:8080` for the iOS simulator), staging and prod are **TBD placeholders** on `.invalid` hosts. |
| Paging | `CursorPage<T>{items, nextCursor}` | The API's `{items, next_cursor}`. Named `CursorPage`, not `Page`, so it never clashes with Flutter's navigator `Page`. |
| Money | `formatInr(paise)`, `groupIndian(n)` | `formatInr(10000000)` is `₹1,00,000`; paise shown only when not zero. |
| Dates | `LocalDate`, `toIstWallClock`, `istOffset` | API `format: date` (`YYYY-MM-DD`) values are IST calendar days: keep them as `LocalDate` (`parse`, `toIso`, `addDays`, `daysUntil`, `LocalDate.todayIst(clock)`). `format: date-time` values stay `DateTime` in UTC; use `toIstWallClock` only for display. |
| Phones | `normalizeIndianMobile`, `isValidIndianMobile`, `maskPhone`, `formatIndianMobile` | Same rules as `backend/internal/platform/phone` (E.164 `+91XXXXXXXXXX`, mask `+91******2345`). |
| Season codes | `SeasonCode.isValid`, `seasonCodesOn(date)` | Pattern `^[a-z]+-[0-9]{4}(-[0-9]{2})?$`; calendar mirrors `backend/internal/masters/seasons.go`. The server's `season_codes` is the source of truth. |
| Area | `AcresGuntas`, `guntasToAcres`, `acresToGuntas` | 1 acre = 40 guntas; `AcresGuntas.fromAcres(2.1)` is 2 acres 4 guntas. Any positive area is at least 1 gunta (`fromAcres(0.01)` is 0 acres 1 gunta); guntas are 0-39. |
| Time | `Clock`, `SystemClock`, `FixedClock` | Always UTC. Inject a `FixedClock` in tests. |

Planned here later (see `mobile/implementation-plan.md`): dio client and interceptors, single-flight refresh,
clock offset from heartbeats, connectivity, logging.

## Tests

```bash
cd mobile/packages/orbit_core
dart test
flutter analyze --fatal-infos
```
