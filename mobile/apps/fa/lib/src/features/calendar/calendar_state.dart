// State the visit screens share: the calendar's picked day, the notice the
// calendar shows after a write (planned, moved, cancelled, visit saved), the
// visit being moved to another day, and the FA's last GPS fix for distances.
//
// Plan visit and the visit log set these before they leave, so the calendar
// shows the right day and notice however the FA gets back to it (Back to
// calendar, the back arrow, Android back).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';

import '../../data/data.dart';
import '../../device/device.dart';

/// The day the calendar shows; null follows today.
final calendarDayProvider = NotifierProvider<CalendarDayController, LocalDate?>(
  CalendarDayController.new,
);

/// Holds the calendar's picked day.
class CalendarDayController extends Notifier<LocalDate?> {
  @override
  LocalDate? build() => null;

  /// Shows [day] (null: today).
  void show(LocalDate? day) => state = day;
}

/// What a [VisitNotice] says.
enum VisitNoticeKind {
  /// A visit log was saved ("Visit saved · Ravi K marked Done").
  saved,

  /// A visit was planned.
  planned,

  /// A planned visit was moved to another day.
  moved,

  /// A planned visit was cancelled.
  cancelled,
}

/// The line the calendar shows on [day] after a write, until the FA closes
/// it or a newer one replaces it.
final class VisitNotice {
  /// Creates a notice.
  const VisitNotice({
    required this.kind,
    required this.farmerId,
    required this.visitId,
    required this.day,
    this.hasAdvice = false,
  });

  /// What happened.
  final VisitNoticeKind kind;

  /// The farmer (the name is picked in the UI language when shown).
  final String farmerId;

  /// The visit concerned (for "advice sent" once it synced).
  final String visitId;

  /// The calendar day it is shown on.
  final LocalDate day;

  /// For [VisitNoticeKind.saved]: the log carries advice (an issue with a
  /// salt rule), so the farmer gets an SMS. Without it nothing is sent.
  final bool hasAdvice;
}

/// The calendar's notice, or null.
final visitNoticeProvider =
    NotifierProvider<VisitNoticeController, VisitNotice?>(
      VisitNoticeController.new,
    );

/// Holds the calendar's notice.
class VisitNoticeController extends Notifier<VisitNotice?> {
  @override
  VisitNotice? build() => null;

  /// Shows [notice] (and replaces any other).
  void show(VisitNotice notice) => state = notice;

  /// Closes the notice.
  void clear() => state = null;
}

/// The planned visit "Move to another day" opened Plan a visit for, or null.
/// Plan a visit reads it once when it opens (and clears it); saving re-plans
/// this visit (`FaActions.replanVisit`).
final rescheduleRequestProvider =
    NotifierProvider<RescheduleRequestController, String?>(
      RescheduleRequestController.new,
    );

/// Holds the visit being moved.
class RescheduleRequestController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Asks Plan a visit to move [visitId].
  void request(String visitId) => state = visitId;

  /// Takes the request (null when there is none) and clears it.
  String? take() {
    final id = state;
    state = null;
    return id;
  }
}

/// Where the FA is now, for "0.8 km" on visit cards and nearest-first
/// farmers; null when the GPS gives no fix (distances are left out).
final currentFixProvider = FutureProvider.autoDispose<LocationFix?>((
  ref,
) async {
  try {
    return await ref.watch(locationServiceProvider).currentFix();
  } on LocationUnavailable {
    return null;
  }
});

/// The FA's point from [currentFixProvider], or null.
LatLng? currentPoint(AsyncValue<LocationFix?> fix) => fix.value?.point;
