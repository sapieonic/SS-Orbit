/// Pure-Dart foundations shared by the Orbit Farmer and FA apps: the API error
/// type, runtime environment, paging, and small value helpers (money, IST
/// dates, phone numbers, season codes, acres and guntas, clock).
///
/// No Flutter imports, so it also works in background isolates and CLI tools.
library;

export 'src/api_error.dart';
export 'src/area.dart';
export 'src/clock.dart';
export 'src/env.dart';
export 'src/local_date.dart';
export 'src/money.dart';
export 'src/page.dart';
export 'src/phone.dart';
export 'src/season_code.dart';
