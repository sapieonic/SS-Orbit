// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'orbit_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class OrbitLocalizationsEn extends OrbitLocalizations {
  OrbitLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonAllow => 'Allow';

  @override
  String get commonAppName => 'Orbit Shifting';

  @override
  String get commonAudioError => 'Couldn\'t play the audio';

  @override
  String get commonAudioLoading => 'Loading audio…';

  @override
  String get commonAudioUnavailable => 'Audio not available yet';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCall => 'Call';

  @override
  String commonCallName({required String name}) {
    return 'Call $name';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonChoose => 'Choose';

  @override
  String get commonClose => 'Close';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String commonDateFull({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String commonDateShort({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String commonDateWeekday({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMEd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String commonDaysAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get commonDone => 'Done';

  @override
  String commonDotJoin({required String first, required String second}) {
    return '$first · $second';
  }

  @override
  String get commonEdit => 'Change';

  @override
  String get commonHelp => 'Help';

  @override
  String get commonHelpline => 'Helpline';

  @override
  String commonHoursAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h ago',
      one: '1 h ago',
    );
    return '$_temp0';
  }

  @override
  String get commonLater => 'Later';

  @override
  String get commonListen => 'Listen';

  @override
  String get commonLoading => 'Loading…';

  @override
  String commonMinutesAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String get commonNext => 'Continue';

  @override
  String get commonNo => 'No';

  @override
  String get commonOffline => 'No internet';

  @override
  String get commonOk => 'OK';

  @override
  String get commonOpenSettings => 'Open settings';

  @override
  String get commonRead => 'Read';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonSave => 'Save';

  @override
  String commonSavedAt({required DateTime time}) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Saved at $timeString';
  }

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String commonStepOf({required int step, required int total}) {
    return 'Step $step of $total';
  }

  @override
  String get commonStop => 'Stop';

  @override
  String get commonToday => 'Today';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonUpdateAvailable => 'A new version is available';

  @override
  String get commonUpdateButton => 'Update';

  @override
  String get commonUpdateRequiredBody => 'Install the new version to continue.';

  @override
  String get commonUpdateRequiredTitle => 'Update the app';

  @override
  String get commonWhatsapp => 'WhatsApp';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get enumAdviceStatusGiven => 'Advice given';

  @override
  String get enumAdviceStatusUnresolved => 'Advice pending';

  @override
  String get enumAreaSourceBoundary => 'Measured by walking the edge';

  @override
  String get enumAreaSourceTyped => 'Area as told by the farmer';

  @override
  String get enumAreaUnitAcre => 'Acres';

  @override
  String get enumAreaUnitGunta => 'Guntas';

  @override
  String get enumCallbackStatusCancelled => 'Cancelled';

  @override
  String get enumCallbackStatusClosed => 'FA called you';

  @override
  String get enumCallbackStatusOpen => 'Request sent';

  @override
  String get enumConsentMethodApp => 'In the app';

  @override
  String get enumConsentMethodFaOtp => 'Through your FA, with OTP';

  @override
  String get enumConsentMethodHo => 'By the Shanmukha office';

  @override
  String get enumConsentPurposeLoyalty => 'Cashback and rewards';

  @override
  String get enumConsentPurposeProgramme => 'Orbit programme';

  @override
  String get enumConsentPurposeSchemesFinance => 'Schemes, loans, insurance';

  @override
  String get enumConsentPurposeSoilPartner => 'Soil-test partner';

  @override
  String get enumConsentStateGranted => 'Agreed';

  @override
  String get enumConsentStateNeverAsked => 'Not asked yet';

  @override
  String get enumConsentStateWithdrawn => 'Withdrawn';

  @override
  String get enumCoverageLevelDistrict => 'District';

  @override
  String get enumCoverageLevelMandal => 'Mandal';

  @override
  String get enumCoverageLevelVillage => 'Village';

  @override
  String get enumFarmerPlanFree => 'Free';

  @override
  String get enumFarmerPlanPremium => 'Premium';

  @override
  String get enumFarmerStatusActive => 'Active';

  @override
  String get enumFarmerStatusInactive => 'Paused';

  @override
  String get enumFarmerStatusPendingProfile => 'Registration not complete';

  @override
  String get enumLanguageEn => 'English';

  @override
  String get enumLanguageTe => 'తెలుగు';

  @override
  String get enumNoticeSenderCiv => 'CIV';

  @override
  String get enumNoticeSenderFa => 'Your FA';

  @override
  String get enumNoticeSenderHo => 'Shanmukha';

  @override
  String get enumNoticeSenderSystem => 'Orbit';

  @override
  String get enumPlannedSlotAfternoon => 'Afternoon';

  @override
  String get enumPlannedSlotAny => 'Any time';

  @override
  String get enumPlannedSlotMorning => 'Morning';

  @override
  String get enumSeasonKindKharif => 'Kharif';

  @override
  String get enumSeasonKindRabi => 'Rabi';

  @override
  String get enumSeasonKindSummer => 'Summer';

  @override
  String get enumSeasonStatusAbandoned => 'Abandoned';

  @override
  String get enumSeasonStatusActive => 'Growing';

  @override
  String get enumSeasonStatusHarvested => 'Harvested';

  @override
  String get enumSeverityHigh => 'High';

  @override
  String get enumSeverityLow => 'Low';

  @override
  String get enumSeverityModerate => 'Moderate';

  @override
  String get enumVisitStatusCancelled => 'Cancelled';

  @override
  String get enumVisitStatusDone => 'Done';

  @override
  String get enumVisitStatusMissed => 'Missed';

  @override
  String get enumVisitStatusPlanned => 'Planned';

  @override
  String get errorActiveSeasonExists =>
      'This plot already has a crop. Close it first.';

  @override
  String get errorCallbackClosed => 'Your FA has already closed this request.';

  @override
  String errorDetailAttemptsLeft({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more tries left.',
      one: '1 more try left.',
      zero: 'No tries left. Ask for a new OTP.',
    );
    return '$_temp0';
  }

  @override
  String errorDetailRetryAfterSeconds({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Try again in $count seconds.',
      one: 'Try again in 1 second.',
    );
    return '$_temp0';
  }

  @override
  String get errorDeviceRevoked =>
      'This phone was signed out. Please sign in again.';

  @override
  String get errorForbidden => 'You can\'t do this.';

  @override
  String get errorInternal =>
      'Something went wrong on our side. Please try again.';

  @override
  String get errorInvalidCursor =>
      'This list is out of date. Please open it again.';

  @override
  String get errorInvalidRequest =>
      'Something in the request was wrong. Please try again.';

  @override
  String get errorNetwork =>
      'No internet. Check your connection and try again.';

  @override
  String get errorNoFaAssigned =>
      'No FA is assigned to you yet. Please call the helpline.';

  @override
  String get errorNotFound => 'We couldn\'t find this. Please open it again.';

  @override
  String get errorNotInYourArea =>
      'This farmer\'s village is not in your area.';

  @override
  String get errorOtpExpired => 'This OTP has expired. Ask for a new one.';

  @override
  String get errorOtpInvalid => 'Wrong OTP. Check the SMS and try again.';

  @override
  String get errorPasswordChangeRequired => 'Change your password to continue.';

  @override
  String get errorPayloadTooLarge => 'This is too large to send.';

  @override
  String get errorPhoneTaken => 'Another farmer already has this phone number.';

  @override
  String get errorPhotoAlreadyUploaded => 'This photo was already sent.';

  @override
  String get errorProfileAlreadyComplete =>
      'Your registration is already complete.';

  @override
  String get errorProfileIncomplete =>
      'Please complete your registration first.';

  @override
  String get errorRateLimited => 'Too many tries. Wait a little and try again.';

  @override
  String get errorRefreshReused =>
      'This sign-in was used elsewhere. Please sign in again.';

  @override
  String get errorRegisteredWithAnotherFa =>
      'This farmer is already registered with another FA.';

  @override
  String get errorSeasonExists =>
      'This plot already has a crop for this season.';

  @override
  String get errorSeasonNotActive => 'This season is already closed.';

  @override
  String get errorSessionRevoked =>
      'You were signed out. Please sign in again.';

  @override
  String get errorTempPasswordExpired =>
      'Your temporary password has expired. Call HO for a new one.';

  @override
  String get errorTimeout => 'The network is slow. Please try again.';

  @override
  String get errorUnauthorized => 'Please sign in again.';

  @override
  String get errorUnavailable =>
      'The service is down for now. Please try again in a while.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get errorUploadMissing => 'The photo didn\'t upload. Send it again.';

  @override
  String get errorValidationFailed =>
      'Some details are not right. Please check them.';

  @override
  String get errorVersionMismatch =>
      'HO changed this record. Open it again to see the latest.';

  @override
  String get faActionErrorAlreadyEnrolled => 'This farmer is already yours.';

  @override
  String get faActionErrorAreaTooSmall =>
      'This area is too small. Walk the boundary again or type the area.';

  @override
  String get faActionErrorBoundaryCrossesItself =>
      'The boundary crosses itself. Walk it again.';

  @override
  String get faActionErrorCannotClear =>
      'This can\'t be left empty here. Ask HO to remove it.';

  @override
  String get faActionErrorInvalidDate => 'Pick today or a later day.';

  @override
  String get faActionErrorInvalidPhone => 'This is not a valid mobile number.';

  @override
  String get faActionErrorInvalidSeasonCode =>
      'This season is closed. Pick another one.';

  @override
  String get faActionErrorLocationRequired =>
      'Walk the boundary or put a pin first.';

  @override
  String get faActionErrorNoData =>
      'Your farmers aren\'t on this phone yet. Sync once with internet first.';

  @override
  String get faActionErrorNoSeason =>
      'This plot has no crop yet. Add the crop first.';

  @override
  String get faActionErrorNotEditable =>
      'This visit was already sent to HO, so it can no longer be changed.';

  @override
  String get faActionErrorNotFound =>
      'This isn\'t on this phone any more. Go back and open it again.';

  @override
  String get faActionErrorNotPlanned =>
      'This visit is already done or cancelled.';

  @override
  String get faActionErrorNothingToChange =>
      'Nothing has changed, so there is nothing to save.';

  @override
  String get faActionErrorOutOfRange =>
      'This number is out of range. Check it.';

  @override
  String get faActionErrorProofInvalid =>
      'The consent OTP has expired. Send a new OTP.';

  @override
  String get faActionErrorRequired => 'Fill in all the details.';

  @override
  String get faActionErrorTooLong => 'This is too long.';

  @override
  String get faActionErrorTooMany =>
      'Too many photos or issues. Keep 20 at most.';

  @override
  String get faActionErrorWrongState =>
      'This has already changed. Look again and try once more.';

  @override
  String get faAlertsAcknowledged => 'Acknowledged · HO can see you read it';

  @override
  String get faAlertsCallFarmer => 'Call farmer';

  @override
  String get faAlertsCallPlanVisit => 'Call · plan visit';

  @override
  String get faAlertsCallbackClosed => 'Call-back closed';

  @override
  String get faAlertsCallbackHint => 'Closes when you log the call';

  @override
  String get faAlertsCloseCallback => 'Close call-back';

  @override
  String get faAlertsCloseCallbackHint =>
      'Spoke to the farmer? Close the request.';

  @override
  String faAlertsEarlier({required int count}) {
    return 'Earlier · $count';
  }

  @override
  String get faAlertsEmptyBody =>
      'New farmers, call-back requests and notes from HO show here.';

  @override
  String get faAlertsEmptyTabBody => 'No open alerts of this kind.';

  @override
  String get faAlertsEmptyTabTitle => 'Nothing here';

  @override
  String get faAlertsEmptyTitle => 'No alerts';

  @override
  String get faAlertsFinishEnrolment => 'Finish enrolment';

  @override
  String get faAlertsGotIt => 'Got it';

  @override
  String get faAlertsKindCallback => 'Call me back';

  @override
  String get faAlertsKindHoNote => 'Note from HO';

  @override
  String get faAlertsKindNewFarmer => 'New farmer';

  @override
  String get faAlertsKindOther => 'Alert';

  @override
  String get faAlertsOfflineBody =>
      'Showing the alerts saved on this phone. Pull down to refresh when you have network.';

  @override
  String get faAlertsOpenFarmer => 'Open farmer';

  @override
  String get faAlertsStatusClosed => 'Closed';

  @override
  String faAlertsSubtitle({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need action',
      one: '1 needs action',
      zero: 'Nothing needs action',
    );
    return '$_temp0';
  }

  @override
  String get faAlertsTabAll => 'All';

  @override
  String get faAlertsTabCallbacks => 'Call-backs';

  @override
  String get faAlertsTabHo => 'From HO';

  @override
  String get faAlertsTabNewFarmers => 'New farmers';

  @override
  String get faAlertsTabsLabel => 'Alert type';

  @override
  String faAuthCallFailed({required String phone}) {
    return 'Couldn\'t open the dialer. Call HO on $phone.';
  }

  @override
  String faAuthCallHo({required String phone}) {
    return 'Call HO · $phone';
  }

  @override
  String faAuthFarmersCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count farmers',
      one: '1 farmer',
    );
    return '$_temp0';
  }

  @override
  String get faAuthHide => 'Hide';

  @override
  String get faAuthHidePassword => 'Hide password';

  @override
  String get faAuthOfflineSaved =>
      'Offline · your farmers are saved on this phone';

  @override
  String get faAuthOnline => 'Online';

  @override
  String get faAuthPinDelete => 'Delete digit';

  @override
  String faAuthPinEntered({required int filled, required int length}) {
    return '$filled of $length digits entered';
  }

  @override
  String faAuthPlotsCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plots',
      one: '1 plot',
    );
    return '$_temp0';
  }

  @override
  String get faAuthRole => 'Field Assistant';

  @override
  String get faAuthShow => 'Show';

  @override
  String get faAuthShowPassword => 'Show password';

  @override
  String get faBlockedBefore => 'Before you update';

  @override
  String get faBlockedNewLogin => 'Log in with a new password';

  @override
  String get faBlockedNothingLost =>
      'Nothing is lost: we send your saved records before you leave the app.';

  @override
  String get faBlockedOpenStore => 'Open Play Store';

  @override
  String get faBlockedRemovedBody =>
      'HO removed your login from this phone. Farmer data has been deleted from it.';

  @override
  String get faBlockedRemovedNote =>
      'This happens when a phone is lost or changes hands. If you think it\'s a mistake, call HO; they can give you a new login.';

  @override
  String get faBlockedSendFailed =>
      'Couldn\'t send the records. Connect to the internet and try again. If you update now, they stay on this phone and go up after the update.';

  @override
  String get faBlockedSendThenUpdate => 'Send records, then update';

  @override
  String get faBlockedSending => 'Sending…';

  @override
  String get faBlockedStepNothing => 'All your records are sent';

  @override
  String faBlockedStepSend({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count saved records to HO',
      one: 'Send 1 saved record to HO',
    );
    return '$_temp0';
  }

  @override
  String faBlockedStepSending({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sending $count records…',
      one: 'Sending 1 record…',
    );
    return '$_temp0';
  }

  @override
  String faBlockedStepSent({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records sent to HO',
      one: '1 record sent to HO',
    );
    return '$_temp0';
  }

  @override
  String get faBlockedStepStore => 'Open Play Store and update';

  @override
  String get faBlockedStepUnlock => 'Unlock with your PIN as usual';

  @override
  String get faBlockedStoreFailed =>
      'Couldn\'t open Play Store. Open it yourself and update Orbit Shifting, or call HO.';

  @override
  String get faBlockedUpdateAnyway => 'Update without sending';

  @override
  String faBlockedUpdateBody({required String min, required String version}) {
    return 'This version ($version) is too old. HO needs everyone on $min or newer so records sync correctly.';
  }

  @override
  String faBlockedUpdateBodyPlain({required String version}) {
    return 'This version ($version) is too old. Update it so records sync correctly.';
  }

  @override
  String get faCalendarAdd => 'Add';

  @override
  String faCalendarCancelBody({required String date}) {
    return 'It was planned for $date. The farmer stops seeing it after the next sync.';
  }

  @override
  String faCalendarCancelTitle({required String name}) {
    return 'Cancel the visit to $name?';
  }

  @override
  String get faCalendarCancelVisit => 'Cancel visit';

  @override
  String faCalendarCancelled({required String name}) {
    return 'Visit to $name cancelled';
  }

  @override
  String faCalendarDayLabel({required int count, required String date}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits',
      one: '1 visit',
      zero: 'no visits',
    );
    return '$date, $_temp0';
  }

  @override
  String faCalendarDoneCount({required int count}) {
    return '$count done';
  }

  @override
  String get faCalendarEmptyBody =>
      'Pick farmers who are due and call them to fix a day.';

  @override
  String get faCalendarEmptyTitle => 'No visits planned';

  @override
  String get faCalendarFindDue => 'Find farmers due a visit';

  @override
  String get faCalendarFooterNote =>
      'A visit turns Done by itself when you save its log.';

  @override
  String get faCalendarKeepVisit => 'Keep it';

  @override
  String faCalendarMoved({required String date, required String name}) {
    return 'Visit moved · $name · $date';
  }

  @override
  String get faCalendarNextWeek => 'Next week';

  @override
  String get faCalendarOffline =>
      'No internet · visits are saved on this phone and sync later';

  @override
  String faCalendarPlanned({required String date, required String name}) {
    return 'Visit planned · $name · $date';
  }

  @override
  String get faCalendarPreviousWeek => 'Previous week';

  @override
  String get faCalendarReschedule => 'Move to another day';

  @override
  String faCalendarSavedNoAdvice({required String name}) {
    return 'Visit saved · $name marked Done';
  }

  @override
  String faCalendarSavedPending({required String name}) {
    return 'Visit saved · $name marked Done · advice goes by SMS when this syncs';
  }

  @override
  String faCalendarSavedSent({required String name}) {
    return 'Visit saved · $name marked Done · advice sent';
  }

  @override
  String get faCalendarStartVisit => 'Start visit';

  @override
  String get faCalendarStatusDone => 'Done';

  @override
  String get faCalendarStatusFirstVisit => 'New · first visit';

  @override
  String get faCalendarStatusOverdue => 'Overdue';

  @override
  String get faCalendarStatusPlanned => 'Planned';

  @override
  String get faCalendarThisWeek => 'This week';

  @override
  String get faCalendarTitle => 'Visit calendar';

  @override
  String faCalendarVisitCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits',
      one: '1 visit',
      zero: 'No visits',
    );
    return '$_temp0';
  }

  @override
  String faCalendarVisitOptions({required String name}) {
    return 'More for $name';
  }

  @override
  String faCalendarWeekOf({required String date}) {
    return 'Week of $date';
  }

  @override
  String get faChangePinAgain => 'Type the new PIN again';

  @override
  String get faChangePinChanged => 'PIN changed';

  @override
  String get faChangePinNew => 'Pick a new PIN';

  @override
  String get faChangePinOld => 'Enter your current PIN';

  @override
  String get faChangePinWrongOld => 'The current PIN is wrong';

  @override
  String faCommonArea({required int acres, required int guntas}) {
    return '$acres ac $guntas gunta';
  }

  @override
  String faCommonCallFailed({required String phone}) {
    return 'Couldn\'t open the dialer. Call $phone.';
  }

  @override
  String get faCommonDirectionsFailed => 'Couldn\'t open maps.';

  @override
  String faCommonDistanceKm({required String distance}) {
    return '$distance km';
  }

  @override
  String faCommonDistanceM({required int distance}) {
    return '$distance m';
  }

  @override
  String get faCommonErrorTitle => 'Something went wrong';

  @override
  String get faCommonLogOut => 'Log out';

  @override
  String get faCommonNotSynced => 'Not synced yet';

  @override
  String get faCommonOfflineBody =>
      'Try again when you have network. Your farmers are saved on this phone.';

  @override
  String get faCommonOfflineTitle => 'No internet';

  @override
  String faCommonTime({required DateTime time}) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$timeString';
  }

  @override
  String get faCommonWhatsappFailed =>
      'Couldn\'t open WhatsApp. Is it installed?';

  @override
  String get faConsentAgreed =>
      'The farmer agreed. Partners get data only if the farmer says yes later.';

  @override
  String get faConsentConfirm => 'Confirm';

  @override
  String get faConsentHow =>
      'An OTP goes to the farmer\'s phone. The farmer hears the consent in their language and reads the OTP out to you.';

  @override
  String get faConsentNeedsPhone => 'Type the farmer\'s mobile number first.';

  @override
  String get faConsentNotice =>
      'We use your details to send you crop advice and to bring your FA to your field. Your details stay safe with Shanmukha. We share them with partners only if you agree. If you agree, tell your FA the OTP you got.';

  @override
  String get faConsentOfflineBody =>
      'Without it the farmer stays \'consent pending\'. Record it from the farmer\'s page when you have network.';

  @override
  String get faConsentOfflineTitle => 'Consent needs internet';

  @override
  String get faConsentOtpLabel => 'OTP the farmer reads out';

  @override
  String get faConsentPlay => 'Play consent';

  @override
  String get faConsentPlayed => 'Played';

  @override
  String faConsentRecorded({required String time}) {
    return 'Consent recorded · $time';
  }

  @override
  String faConsentRecordedPlayed({
    required String language,
    required String time,
  }) {
    return 'Consent recorded · $time · $language audio played';
  }

  @override
  String get faConsentResend => 'Send OTP again';

  @override
  String faConsentResendIn({required int seconds}) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Send again in $seconds seconds',
      one: 'Send again in 1 second',
    );
    return '$_temp0';
  }

  @override
  String get faConsentSave => 'Save consent';

  @override
  String get faConsentSaved =>
      'Consent saved on this phone · syncs when online';

  @override
  String get faConsentSendOtp => 'Send consent OTP';

  @override
  String faConsentSent({required String phone}) {
    return 'OTP sent to $phone with the consent message in the farmer\'s language.';
  }

  @override
  String faConsentSheetTitle({required String name}) {
    return 'Record consent · $name';
  }

  @override
  String get faConsentTitle => 'Farmer\'s consent';

  @override
  String get faEnrolBackToFarmers => 'Back to farmers';

  @override
  String get faEnrolCallHo => 'Call HO';

  @override
  String get faEnrolCheckedAtSync =>
      'You can go on: the number is checked again at sync.';

  @override
  String get faEnrolChecking => 'Checking the number…';

  @override
  String get faEnrolContinueClaim => 'Continue · assign to me';

  @override
  String get faEnrolDeactivatedBody =>
      'HO has deactivated this farmer, so they can\'t be enrolled again.';

  @override
  String get faEnrolDeactivatedTitle => 'Farmer deactivated';

  @override
  String get faEnrolErrorAlreadyEnrolled => 'This farmer is already yours.';

  @override
  String get faEnrolErrorInvalidPhone => 'This is not a valid mobile number.';

  @override
  String get faEnrolErrorInvalidSeasonCode =>
      'This season is closed. Pick another one.';

  @override
  String get faEnrolErrorLocationRequired =>
      'Walk the boundary or put a pin first.';

  @override
  String get faEnrolErrorNoData =>
      'Your farmers aren\'t on this phone yet. Sync once with internet, then enrol.';

  @override
  String get faEnrolErrorOutOfRange => 'This number is out of range. Check it.';

  @override
  String get faEnrolErrorProofInvalid =>
      'The consent OTP has expired. Send a new OTP.';

  @override
  String get faEnrolErrorRequired => 'Fill in all the details.';

  @override
  String get faEnrolErrorTooLong => 'This is too long.';

  @override
  String get faEnrolFinishEnrolment => 'Finish enrolment';

  @override
  String get faEnrolLanguageLabel => 'Farmer\'s language';

  @override
  String get faEnrolLeaveBody => 'What you filled in here is not saved.';

  @override
  String get faEnrolLeaveConfirm => 'Leave';

  @override
  String get faEnrolLeaveStay => 'Stay';

  @override
  String get faEnrolLeaveTitle => 'Leave enrolment?';

  @override
  String get faEnrolLookupFailedTitle => 'Couldn\'t check the number';

  @override
  String faEnrolMineBody({required String name}) {
    return '$name is already one of your farmers.';
  }

  @override
  String get faEnrolMineBodyUnknown =>
      'This number is already one of your farmers.';

  @override
  String get faEnrolMineTitle => 'Already your farmer';

  @override
  String get faEnrolNameLabel => 'Farmer\'s name';

  @override
  String get faEnrolNameRequired => 'Enter the farmer\'s name.';

  @override
  String get faEnrolNameTeLabel => 'Name in Telugu (optional)';

  @override
  String get faEnrolNoConsentBody =>
      'The farmer stays \'consent pending\' until you record it from the farmer\'s page.';

  @override
  String get faEnrolNoConsentConfirm => 'Enrol without consent';

  @override
  String get faEnrolNoConsentTitle => 'Enrol without consent?';

  @override
  String get faEnrolOfflineBody =>
      'Enrol now: the number is checked again at sync. Consent and photo can be added later from the farmer\'s page.';

  @override
  String get faEnrolOfflineHint =>
      'Offline? The number is checked again at sync.';

  @override
  String get faEnrolOfflineTitle => 'No internet';

  @override
  String get faEnrolOpenFarmer => 'Open farmer';

  @override
  String get faEnrolOtherFaBody =>
      'This farmer is with another FA. Only HO can move a farmer. Call HO.';

  @override
  String get faEnrolOtherFaTitle => 'With another FA';

  @override
  String get faEnrolOtherNumber =>
      'To enrol someone else, type another number.';

  @override
  String get faEnrolOutsideBody =>
      'This farmer is registered in a village outside your area. Call HO to move them.';

  @override
  String get faEnrolOutsideTitle => 'Village outside your area';

  @override
  String get faEnrolPendingBody =>
      'This farmer signed up on their own. Finish the profile and consent here.';

  @override
  String get faEnrolPendingTitle => 'Signed up in the farmer app';

  @override
  String get faEnrolPhoneInvalid =>
      'Enter the farmer\'s 10-digit mobile number.';

  @override
  String get faEnrolPhoneLabel => 'Farmer\'s mobile number';

  @override
  String get faEnrolPhoto => 'Farmer photo';

  @override
  String get faEnrolPhotoAdded => 'Photo added';

  @override
  String get faEnrolPhotoFailed =>
      'Photo didn\'t go. Try again, or go on without it.';

  @override
  String get faEnrolPhotoNoCamera =>
      'Camera can\'t be opened. Check the camera permission.';

  @override
  String get faEnrolPhotoOffline =>
      'Photo needs internet. Add it later from the farmer\'s page.';

  @override
  String get faEnrolPhotoRetake => 'Retake';

  @override
  String get faEnrolPhotoUploading => 'Sending photo…';

  @override
  String get faEnrolRecordConsent => 'Record consent';

  @override
  String get faEnrolRegisteredBody =>
      'This farmer signed up on their own and has no FA yet. We\'ll add to their record, not make a new one.';

  @override
  String get faEnrolRegisteredTitle => 'Already registered';

  @override
  String get faEnrolStepCrop => 'Crop';

  @override
  String get faEnrolStepCurrent => 'current step';

  @override
  String get faEnrolStepDone => 'done';

  @override
  String get faEnrolStepFarm => 'Farm';

  @override
  String get faEnrolStepFarmer => 'Farmer';

  @override
  String get faEnrolStepsLabel => 'Steps';

  @override
  String get faEnrolTitle => 'Enrol farmer';

  @override
  String faEnrolTitleName({required String name}) {
    return 'Enrol · $name';
  }

  @override
  String get faEnrolUnknownBody => 'Call HO to check this number.';

  @override
  String get faEnrolUnknownTitle => 'Can\'t enrol this number';

  @override
  String get faEnrolCropBackToFarmers => 'Back to farmers';

  @override
  String get faEnrolCropConsentDone => 'Given ✓';

  @override
  String get faEnrolCropConsentPending =>
      'Pending · record it from the farmer\'s page';

  @override
  String faEnrolCropCropHeading({required String season}) {
    return 'Crop this season · $season';
  }

  @override
  String faEnrolCropEnrolled({required String name}) {
    return '$name is enrolled';
  }

  @override
  String get faEnrolCropErrorCrop => 'Choose the crop.';

  @override
  String get faEnrolCropErrorSowing => 'Choose the sowing date.';

  @override
  String get faEnrolCropFallow => 'Fallow / don\'t know';

  @override
  String get faEnrolCropFinish => 'Finish enrolment';

  @override
  String get faEnrolCropNotSown => 'Not sown yet';

  @override
  String get faEnrolCropNotSownNote =>
      'Without a sowing date the crop stage is not tracked.';

  @override
  String get faEnrolCropPlanVisit => 'Plan first visit';

  @override
  String get faEnrolCropPreviousLabel => 'Previous crop on this plot';

  @override
  String get faEnrolCropSavedOnPhone =>
      'Saved on this phone. It goes to HO when you\'re online.';

  @override
  String get faEnrolCropSeasonHeading => 'Season';

  @override
  String faEnrolCropSeasonLabel({
    required String season,
    required String year,
  }) {
    return '$season $year';
  }

  @override
  String faEnrolCropSmsNote({required String language, required String name}) {
    return '$name gets a welcome SMS in $language once this syncs.';
  }

  @override
  String faEnrolCropSowDay({required int day}) {
    return 'Day $day after sowing';
  }

  @override
  String faEnrolCropSowDayStage({required int day, required String stage}) {
    return 'Day $day · $stage stage';
  }

  @override
  String get faEnrolCropSowPick => 'Pick a date';

  @override
  String faEnrolCropSowToday({required String date}) {
    return 'Today · $date';
  }

  @override
  String faEnrolCropSowYesterday({required String date}) {
    return 'Yesterday · $date';
  }

  @override
  String get faEnrolCropSowingLabel => 'Sowing date';

  @override
  String get faEnrolCropSummary => 'Summary';

  @override
  String faEnrolCropSummaryAfter({required String crop}) {
    return 'after $crop';
  }

  @override
  String get faEnrolCropSummaryConsent => 'Consent';

  @override
  String get faEnrolCropSummaryCrop => 'Crop';

  @override
  String get faEnrolCropSummaryFarmer => 'Farmer';

  @override
  String get faEnrolCropSummaryNoCrop => 'Not chosen yet';

  @override
  String faEnrolCropSummarySown({required String date}) {
    return 'sown $date';
  }

  @override
  String get faEnrolCropThisSeason => 'This season';

  @override
  String faEnrolPlotAcresDecimal({required String acres}) {
    return '($acres ac)';
  }

  @override
  String get faEnrolPlotArea => 'Area';

  @override
  String get faEnrolPlotAreaNotYet => 'Not yet';

  @override
  String get faEnrolPlotChangeVillage => 'Change village';

  @override
  String get faEnrolPlotClose => 'Close boundary';

  @override
  String get faEnrolPlotClosed => 'Boundary closed';

  @override
  String get faEnrolPlotErrorTyped => 'Enter the area in acres and guntas.';

  @override
  String get faEnrolPlotErrorWalk =>
      'Walk the boundary and close it, or type the area.';

  @override
  String get faEnrolPlotGpsChecking => 'Checking GPS…';

  @override
  String get faEnrolPlotGpsCheckingBody =>
      'Hold the phone up and stay still for a few seconds.';

  @override
  String get faEnrolPlotGpsDenied => 'Location permission is off';

  @override
  String faEnrolPlotGpsGood({required int metres}) {
    return 'GPS ±$metres m · good';
  }

  @override
  String get faEnrolPlotGpsLowBody =>
      'Too rough to walk the boundary. Walk to open ground, away from trees and sheds, or type the area.';

  @override
  String faEnrolPlotGpsLowTitle({required int metres}) {
    return 'GPS is ±$metres m';
  }

  @override
  String get faEnrolPlotGpsNoFix => 'No GPS signal yet';

  @override
  String get faEnrolPlotGpsOff => 'Location is switched off';

  @override
  String get faEnrolPlotGpsProblemBody =>
      'Turn on location for this app, step out into open ground, or type the area.';

  @override
  String faEnrolPlotGpsRough({required int metres}) {
    return 'GPS ±$metres m · too rough';
  }

  @override
  String get faEnrolPlotGuntasPerAcre => '40 guntas = 1 acre';

  @override
  String get faEnrolPlotGuntasTooMany => 'Guntas must be under 40.';

  @override
  String faEnrolPlotLabel({required int number}) {
    return 'Plot $number';
  }

  @override
  String get faEnrolPlotMandal => 'Mandal';

  @override
  String faEnrolPlotMetresSoFar({required int metres}) {
    return '$metres m so far';
  }

  @override
  String get faEnrolPlotModeType => 'Type area';

  @override
  String get faEnrolPlotModeWalk => 'Walk boundary';

  @override
  String get faEnrolPlotNeedCorners =>
      'Walk to at least 3 corners to close the boundary.';

  @override
  String get faEnrolPlotPause => 'Pause';

  @override
  String faEnrolPlotPaused({required int metres}) {
    return 'Paused · $metres m';
  }

  @override
  String get faEnrolPlotPickVillage => 'Which village is this plot in?';

  @override
  String faEnrolPlotPinHere({required int metres}) {
    return 'Pin where you stand · GPS ±$metres m';
  }

  @override
  String get faEnrolPlotPinVillage =>
      'No GPS: the pin goes at the village centre.';

  @override
  String get faEnrolPlotReady => 'Stand at a corner, then tap Start point here';

  @override
  String faEnrolPlotRecording({required int metres}) {
    return 'Recording · $metres m';
  }

  @override
  String get faEnrolPlotResume => 'Resume';

  @override
  String get faEnrolPlotRoughWhileWalking =>
      'GPS is rough here: corners are skipped until it gets better.';

  @override
  String get faEnrolPlotSaveNext => 'Save & next';

  @override
  String get faEnrolPlotSavedNote => 'Saved on this phone · syncs when online';

  @override
  String faEnrolPlotSketchClosed({required String area}) {
    return 'Boundary closed, $area';
  }

  @override
  String get faEnrolPlotSketchPin => 'Pin where you stand';

  @override
  String faEnrolPlotSketchWalking({required int corners}) {
    String _temp0 = intl.Intl.pluralLogic(
      corners,
      locale: localeName,
      other: 'Plot sketch, $corners corners walked',
      one: 'Plot sketch, 1 corner walked',
      zero: 'Plot sketch, nothing walked yet',
    );
    return '$_temp0';
  }

  @override
  String get faEnrolPlotStart => 'Start point here';

  @override
  String get faEnrolPlotTypedNote =>
      'Use this when GPS is poor. The plot shows as a pin, not a boundary, until you walk it.';

  @override
  String get faEnrolPlotUndo => 'Undo last corner';

  @override
  String get faEnrolPlotVillage => 'Village';

  @override
  String get faEnrolPlotVillageFromGps => 'Village · from GPS';

  @override
  String get faEnrolPlotWalkAgain => 'Walk again';

  @override
  String get faEnrolPlotWalking => 'Walking…';

  @override
  String get faFarmer360ActionFailed =>
      'Couldn\'t save on this phone. Try again.';

  @override
  String faFarmer360Advised({required String advice}) {
    return 'Advised $advice';
  }

  @override
  String faFarmer360CallbackAsked({required String when}) {
    return 'Asked $when';
  }

  @override
  String get faFarmer360CallbackClose => 'Close call-back';

  @override
  String get faFarmer360CallbackClosed => 'Call-back closed.';

  @override
  String get faFarmer360ConflictKeepMine => 'Keep mine';

  @override
  String get faFarmer360ConflictKeepTheirs => 'Keep HO\'s';

  @override
  String get faFarmer360ConflictMeta =>
      'HO changed this profile while you were offline';

  @override
  String get faFarmer360ConflictMine => 'Yours';

  @override
  String get faFarmer360ConflictStatus => 'Conflict';

  @override
  String get faFarmer360ConflictTheirs => 'HO\'s';

  @override
  String faFarmer360ConflictTitle({required String name}) {
    return 'Profile · $name';
  }

  @override
  String faFarmer360ConsentCount({required int count, required int total}) {
    return '$count of $total agreed';
  }

  @override
  String get faFarmer360ConsentPending => 'Not recorded';

  @override
  String get faFarmer360EditLanguage => 'Farmer\'s language';

  @override
  String get faFarmer360EditName => 'Name (English)';

  @override
  String get faFarmer360EditNameTe => 'Name in Telugu';

  @override
  String get faFarmer360EditNothingChanged => 'Nothing changed.';

  @override
  String get faFarmer360EditProfile => 'Edit profile';

  @override
  String get faFarmer360EditRequired => 'Enter the name';

  @override
  String get faFarmer360EditSaved => 'Saved. HO gets it at the next sync.';

  @override
  String get faFarmer360EditTooLong => 'At most 100 letters';

  @override
  String get faFarmer360NextVisitNone => 'None planned';

  @override
  String get faFarmer360NoIssues => 'No issues found';

  @override
  String get faFarmer360NoPlot => 'No plot yet';

  @override
  String get faFarmer360NoVisit => 'No visit yet';

  @override
  String get faFarmer360PlanVisit => 'Plan a visit';

  @override
  String faFarmer360PlotDay({required int day}) {
    return 'day $day';
  }

  @override
  String get faFarmer360PlotNoCrop => 'No crop started';

  @override
  String faFarmer360PlotStageDay({required int day, required String stage}) {
    return '$stage · day $day';
  }

  @override
  String get faFarmer360RecordConsent => 'Record consent';

  @override
  String get faFarmer360RowCallback => 'Call-back';

  @override
  String get faFarmer360RowConsent => 'Consent';

  @override
  String get faFarmer360RowLastVisit => 'Last visit';

  @override
  String get faFarmer360RowNextVisit => 'Next visit';

  @override
  String get faFarmer360RowPlan => 'Plan';

  @override
  String get faFarmer360RowPlot => 'Plot';

  @override
  String get faFarmer360StartVisit => 'Start visit';

  @override
  String get faFarmer360SummaryLabel => 'Farmer summary';

  @override
  String get faFarmersActionDirections => 'Directions';

  @override
  String get faFarmersActionFinishEnrolment => 'Finish enrolment';

  @override
  String get faFarmersActionOpenFarmer => 'Open farmer';

  @override
  String faFarmersCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count farmers',
      one: '1 farmer',
    );
    return '$_temp0';
  }

  @override
  String get faFarmersEmptyAction => 'Enrol a farmer';

  @override
  String get faFarmersEmptyBody =>
      'Farmers you enrol show here, nearest first.';

  @override
  String get faFarmersEmptyTitle => 'No farmers yet';

  @override
  String get faFarmersFilter30Days => '30+ days';

  @override
  String get faFarmersFilterAll => 'All';

  @override
  String get faFarmersFilterFinishEnrolment => 'Finish enrolment';

  @override
  String get faFarmersFilterLabel => 'Filter farmers';

  @override
  String get faFarmersFilterNew => 'New';

  @override
  String get faFarmersFilterVisitDue => 'Visit due';

  @override
  String get faFarmersMapAttribution => '© OpenStreetMap contributors';

  @override
  String get faFarmersMapLegendOthers => 'Others';

  @override
  String get faFarmersMapOffline => 'Map needs internet for now';

  @override
  String get faFarmersMapSelected => 'Selected farmer';

  @override
  String get faFarmersMapYou => 'Your location';

  @override
  String faFarmersMetaDaysSinceVisit({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days since visit',
      one: '1 day since visit',
    );
    return '$_temp0';
  }

  @override
  String faFarmersMetaJoinedOn({required String date}) {
    return 'joined $date';
  }

  @override
  String get faFarmersMetaJoinedToday => 'joined today';

  @override
  String get faFarmersMetaJoinedYesterday => 'joined yesterday';

  @override
  String faFarmersMetaLastVisitDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'last visit $count days ago',
      one: 'last visit 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String faFarmersMetaNeverVisited({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'no visit in $count days',
      one: 'no visit in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get faFarmersMetaNoCrop => 'no crop yet';

  @override
  String faFarmersMetaVisitDueOn({required String day}) {
    return 'visit due $day';
  }

  @override
  String get faFarmersMetaVisitDueToday => 'visit due today';

  @override
  String get faFarmersMetaVisitOverdue => 'visit overdue';

  @override
  String get faFarmersMetaVisitedToday => 'visited today';

  @override
  String get faFarmersMetaVisitedYesterday => 'last visit yesterday';

  @override
  String get faFarmersNearestFirst => 'nearest first';

  @override
  String get faFarmersNoDataAction => 'Open sync';

  @override
  String get faFarmersNoDataBody =>
      'They download at the first sync. Connect to the internet and sync.';

  @override
  String get faFarmersNoDataTitle => 'Farmers are not on this phone yet';

  @override
  String get faFarmersNoMatchFilter =>
      'No farmers under this filter right now.';

  @override
  String faFarmersNoMatchSearch({required String query}) {
    return 'No farmer for \"$query\". Check the name or number.';
  }

  @override
  String get faFarmersNoMatchTitle => 'No farmers match';

  @override
  String get faFarmersSearchClear => 'Clear search';

  @override
  String get faFarmersSearchClose => 'Close search';

  @override
  String get faFarmersSearchHint => 'Name or phone number';

  @override
  String get faFarmersSearchOpen => 'Search by name or phone';

  @override
  String get faFarmersShowAll => 'Show all farmers';

  @override
  String faFarmersShown({required int count}) {
    return '$count shown';
  }

  @override
  String get faFarmersTagNew => 'New';

  @override
  String get faFarmersTagNewToday => 'New today';

  @override
  String get faFarmersTitle => 'Farmers near me';

  @override
  String get faFarmersViewList => 'List';

  @override
  String get faFarmersViewMap => 'Map';

  @override
  String get faLoginEndedBody =>
      'Your records are safe on this phone and go up after you log in with your password.';

  @override
  String get faLoginEndedTitle => 'Log in again to sync';

  @override
  String get faLoginErrorOfflineAgain =>
      'No internet. Log in with your password once you have network. Your records are safe on this phone.';

  @override
  String get faLoginErrorOfflineFirst =>
      'Needs network to log in. Turn on mobile data or Wi-Fi and try again.';

  @override
  String get faLoginErrorWrong =>
      'Login ID or password is wrong. Check and try again.';

  @override
  String faLoginExpiredBody({required int days}) {
    return 'Your PIN works offline for $days days. Log in with your password once you have network.';
  }

  @override
  String get faLoginExpiredTitle => 'Session ended';

  @override
  String faLoginFooterHo({required String phone}) {
    return 'HO $phone';
  }

  @override
  String faLoginFooterSynced({required String day, required String time}) {
    return 'last synced $day $time';
  }

  @override
  String faLoginFooterVersion({required String version}) {
    return 'Version $version';
  }

  @override
  String get faLoginForgot => 'Forgot password? Call HO';

  @override
  String get faLoginHoNote =>
      'Your login is issued by Head Office and is yours alone. If you move or leave, HO hands your farmers to the new FA; logins are never shared.';

  @override
  String get faLoginLockedBody =>
      'Log in with your password, then pick a new PIN. Your records are safe on this phone.';

  @override
  String get faLoginLockedTitle => 'Too many wrong PINs';

  @override
  String get faLoginLogIn => 'Log in';

  @override
  String get faLoginLoginId => 'Login ID';

  @override
  String faLoginOtherFaBody({required String code, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This phone has $count unsynced records of $code.',
      one: 'This phone has 1 unsynced record of $code.',
    );
    return '$_temp0 Logging in as another FA deletes them.';
  }

  @override
  String get faLoginOtherFaConfirm => 'Delete and log in';

  @override
  String get faLoginOtherFaTitle => 'Log in as another FA?';

  @override
  String get faLoginPassword => 'Password';

  @override
  String faLoginPinNote({required int length}) {
    return 'Next time, unlock with a $length-digit PIN, even offline';
  }

  @override
  String get faLoginTempExpiredTitle => 'Temporary password expired';

  @override
  String get faLoginUsePin => 'Unlock with PIN instead';

  @override
  String get faLoginWorksOffline => 'Works offline';

  @override
  String faMeArea({required String area}) {
    return 'Area: $area';
  }

  @override
  String get faMeCallHo => 'Call HO';

  @override
  String faMeCallHoSub({required String phone}) {
    return '$phone · 9 am to 6 pm';
  }

  @override
  String get faMeChangePassword => 'Change password';

  @override
  String get faMeChangePin => 'Change PIN';

  @override
  String faMeChangePinSub({required int days, required int left}) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: '$left days left',
      one: '1 day left',
    );
    return 'Works offline $days days · $_temp0';
  }

  @override
  String faMeFooter({required String id, required String version}) {
    return 'Version $version · phone ID $id';
  }

  @override
  String get faMeLanguage => 'App language';

  @override
  String get faMeLanguageSub => 'Farmer names and crops follow it';

  @override
  String get faMeLogInNow => 'Log in now';

  @override
  String get faMeLogoutAnyway => 'Log out anyway';

  @override
  String get faMeLogoutBody =>
      'To log in again you need your login ID, your password and network.';

  @override
  String get faMeLogoutTitle => 'Log out?';

  @override
  String faMeLogoutUnsynced({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records are not synced yet.',
      one: '1 record is not synced yet.',
    );
    return '$_temp0';
  }

  @override
  String get faMeLogoutUnsyncedBody =>
      'Sync first. If you log out now they stay on this phone and go up when you log in again.';

  @override
  String get faMeNeedsPasswordBody =>
      'You can keep working offline. Your records go up after you log in.';

  @override
  String get faMeNeedsPasswordTitle => 'Log in with your password to sync';

  @override
  String get faMePasswordSaved => 'Password changed';

  @override
  String get faMeProfile => 'Your profile';

  @override
  String faMeStatEnrolled({required String month}) {
    return 'enrolled in $month';
  }

  @override
  String faMeStatFarmers({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'farmers',
      one: 'farmer',
    );
    return '$_temp0';
  }

  @override
  String faMeStatVisits({required String month}) {
    return 'visits in $month';
  }

  @override
  String get faMeSubtitle => 'Profile and settings';

  @override
  String faMeSyncLast({required String day, required String time}) {
    return 'Last synced $day $time';
  }

  @override
  String get faMeSyncNever => 'Not synced yet';

  @override
  String get faMeSyncNow => 'Sync now';

  @override
  String faMeSyncWaiting({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count waiting',
      one: '1 waiting',
    );
    return '$_temp0';
  }

  @override
  String get faMeThisMonth => 'This month';

  @override
  String get faMeWifi => 'Upload photos on Wi-Fi only';

  @override
  String get faMeWifiOff => 'Off · photos also upload on mobile data';

  @override
  String get faMeWifiOn => 'On · records still sync on mobile data';

  @override
  String get faNavAlerts => 'Alerts';

  @override
  String get faNavCalendar => 'Calendar';

  @override
  String get faNavEnrol => 'Enrol';

  @override
  String get faNavFarmers => 'Farmers';

  @override
  String get faNewPasswordAgain => 'Type it again';

  @override
  String get faNewPasswordBackLabel => 'Back to login';

  @override
  String get faNewPasswordCurrent => 'Current password';

  @override
  String get faNewPasswordCurrentTemp => 'Temporary password';

  @override
  String get faNewPasswordLeaveBody =>
      'You\'ll be logged out. Log in again with the temporary password to finish.';

  @override
  String get faNewPasswordLeaveTitle => 'Leave without a new password?';

  @override
  String get faNewPasswordNeedsNetwork => 'Needs network';

  @override
  String get faNewPasswordNeedsNetworkFirst =>
      'Needs network · you can\'t use the app until this is done';

  @override
  String get faNewPasswordNew => 'New password';

  @override
  String get faNewPasswordNote =>
      'HO gave you a temporary password. It works for 72 hours; pick your own now so only you know it.';

  @override
  String get faNewPasswordOffline =>
      'Needs network to save the password. Connect and try again.';

  @override
  String get faNewPasswordRuleCurrent => 'Not the same as the old password';

  @override
  String get faNewPasswordRuleDone => 'done';

  @override
  String get faNewPasswordRuleLength => 'At least 8 characters';

  @override
  String get faNewPasswordRuleLetterDigit => 'Has a letter and a number';

  @override
  String get faNewPasswordRuleLoginId => 'Not your login ID';

  @override
  String get faNewPasswordRuleMatch => 'Both boxes match';

  @override
  String get faNewPasswordRuleNotYet => 'not yet';

  @override
  String get faNewPasswordRules => 'Password rules';

  @override
  String get faNewPasswordSave => 'Save password';

  @override
  String faNewPasswordSavedBody({required String code}) {
    return 'Use it with $code when you log in on network. Day to day, your PIN opens the app.';
  }

  @override
  String get faNewPasswordSavedTitle => 'Password saved';

  @override
  String get faNewPasswordStep => 'Step 1 of 2 · first login';

  @override
  String get faNewPasswordTitle => 'Set your own password';

  @override
  String get faNewPasswordWrongCurrent => 'The current password is wrong.';

  @override
  String get faNewPasswordWrongTemp =>
      'The temporary password is wrong. Type the one HO gave you.';

  @override
  String get faPlanVisitChangeFarmer => 'Change farmer';

  @override
  String get faPlanVisitDay => 'Day';

  @override
  String get faPlanVisitMove => 'Move visit';

  @override
  String faPlanVisitMovingFrom({required String date}) {
    return 'Now planned for $date';
  }

  @override
  String get faPlanVisitNearestFirst => 'Nearest first';

  @override
  String get faPlanVisitNoCrop => 'No crop yet';

  @override
  String faPlanVisitNoCropBody({required String name}) {
    return 'Add $name\'s crop first, then plan the visit.';
  }

  @override
  String get faPlanVisitNoCropTitle => 'No crop to visit yet';

  @override
  String get faPlanVisitNoMatch => 'No farmer matches this search';

  @override
  String get faPlanVisitOtherDate => 'Other date';

  @override
  String get faPlanVisitPickFarmer => 'Who are you visiting?';

  @override
  String get faPlanVisitPlot => 'Plot';

  @override
  String get faPlanVisitPurpose => 'Purpose';

  @override
  String get faPlanVisitPurposeAdviceFollowUp => 'Advice follow-up';

  @override
  String get faPlanVisitPurposeFirstVisit => 'First visit';

  @override
  String get faPlanVisitPurposeHint => 'Why, in a few words';

  @override
  String get faPlanVisitPurposeOther => 'Other';

  @override
  String get faPlanVisitPurposePestFollowUp => 'Pest follow-up';

  @override
  String get faPlanVisitPurposeRequired => 'Write why you are visiting';

  @override
  String get faPlanVisitPurposeSoilSample => 'Soil sample';

  @override
  String get faPlanVisitPurposeStageCheck => 'Stage check';

  @override
  String get faPlanVisitRescheduleTitle => 'Move visit';

  @override
  String get faPlanVisitSave => 'Save visit';

  @override
  String get faPlanVisitSavedOffline =>
      'Saved on this phone · goes to HO at next sync';

  @override
  String get faPlanVisitSearchHint => 'Search name or phone';

  @override
  String get faPlanVisitSlot => 'Time';

  @override
  String faSetupDoneTitle({required String name}) {
    return 'You\'re set up, $name';
  }

  @override
  String get faSetupDownloadFailed =>
      'Couldn\'t download your farmers yet. They download as soon as you have network.';

  @override
  String get faSetupDownloadLists =>
      'crop and advice lists · works offline from now';

  @override
  String get faSetupDownloadProgress => 'Download progress';

  @override
  String get faSetupDownloadTitle => 'Saving your area on this phone';

  @override
  String get faSetupDownloading => 'Downloading…';

  @override
  String get faSetupLanguageNote =>
      'Farmer names, crops and advice show in the language you pick. You can change this later in Me.';

  @override
  String get faSetupOpenFarmers => 'Open my farmers';

  @override
  String faSetupPasswordSaved({required String code}) {
    return 'Password saved. Use it with $code when you log in on network.';
  }

  @override
  String get faSetupPinAgain => 'Type the same PIN again';

  @override
  String get faSetupPinBackLabel => 'Back to language';

  @override
  String get faSetupPinHintAgain => 'One more time to be sure';

  @override
  String faSetupPinHintFirst({required int days}) {
    return 'Works offline for $days days at a time';
  }

  @override
  String get faSetupPinMismatch => 'PINs did not match. Start again.';

  @override
  String faSetupPinNote({required int tries}) {
    return 'Your PIN stays on this phone. Avoid 1234, 0000 or your birth year. $tries wrong tries and you need your password.';
  }

  @override
  String get faSetupPinPick => 'Pick a PIN to unlock the app';

  @override
  String get faSetupPinWeak => 'Too easy to guess. Pick another.';

  @override
  String get faSetupPinYear => 'Looks like a year. Pick another.';

  @override
  String get faSetupQuestion => 'Which language should the app use?';

  @override
  String get faSetupStepAgain => 'Set up this phone';

  @override
  String get faSetupStepFirst => 'Step 2 of 2 · first login';

  @override
  String get faSetupTeSub => 'Telugu · recommended';

  @override
  String get faSetupTitleDone => 'All set';

  @override
  String get faSetupTitleLanguage => 'App language';

  @override
  String faSetupTitlePin({required int length}) {
    return 'Set a $length-digit PIN';
  }

  @override
  String get faSetupToPin => 'Next · set PIN';

  @override
  String get faShellMe => 'Me · profile and settings';

  @override
  String get faShellSyncAllSynced => 'All records synced';

  @override
  String faShellSyncNeedsYou({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records need you',
      one: '1 record needs you',
    );
    return '$_temp0';
  }

  @override
  String get faShellSyncRunning => 'Syncing';

  @override
  String faShellSyncWaiting({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records waiting to sync',
      one: '1 record waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get faShellTitleDev => 'Dev menu';

  @override
  String get faShellTitleFarmer => 'Farmer';

  @override
  String get faShellTitleMe => 'Me';

  @override
  String get faShellTitlePlanVisit => 'Plan a visit';

  @override
  String get faShellTitleRemoved => 'This phone was removed';

  @override
  String get faShellTitleSync => 'Sync';

  @override
  String get faShellTitleVisitLog => 'Visit log';

  @override
  String faSyncAllSyncedBody({required String time}) {
    return 'HO has everything as of $time';
  }

  @override
  String get faSyncAllSyncedTitle => 'All synced';

  @override
  String get faSyncBusy => 'Another sync is running. Try again in a minute.';

  @override
  String get faSyncCallHo => 'Call HO';

  @override
  String get faSyncConflictMetaFarmer =>
      'HO changed this farmer while you were offline';

  @override
  String get faSyncConflictMetaOther =>
      'HO changed this while you were offline';

  @override
  String faSyncConflictMetaPlot({required String plot}) {
    return 'HO changed $plot while you were offline';
  }

  @override
  String get faSyncConflictOnlyTheirs =>
      'Only HO\'s version can be kept for this.';

  @override
  String get faSyncConflictWaiting =>
      'Your later change is waiting on this choice.';

  @override
  String get faSyncDismiss => 'Dismiss';

  @override
  String get faSyncDroppedHeading => 'Also not saved because of this:';

  @override
  String get faSyncErrorTitle => 'Couldn\'t sync';

  @override
  String get faSyncFirstSyncBody => 'Tap Sync now to get your farmers.';

  @override
  String get faSyncKeepMine => 'Keep mine';

  @override
  String get faSyncKeepTheirs => 'Keep HO\'s';

  @override
  String get faSyncLastSyncedJustNow => 'Last synced just now';

  @override
  String faSyncLastSyncedOn({required String date, required String time}) {
    return 'Last synced $date, $time';
  }

  @override
  String faSyncLastSyncedToday({required String time}) {
    return 'Last synced today $time';
  }

  @override
  String get faSyncMobileDataTitle => 'On mobile data';

  @override
  String get faSyncNeedsYouBody =>
      'Choose a version, or dismiss the red rows, to finish.';

  @override
  String faSyncNeedsYouTitle({required int count, required int synced}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$synced synced · $count need you',
      one: '$synced synced · 1 needs you',
    );
    return '$_temp0';
  }

  @override
  String get faSyncNeverSynced => 'Not synced yet';

  @override
  String faSyncOfflineBody({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count records are saved on this phone. They go up when you have network.',
      one: '1 record is saved on this phone. It goes up when you have network.',
      zero: 'Your work is saved on this phone.',
    );
    return '$_temp0';
  }

  @override
  String get faSyncOfflineTitle => 'No internet';

  @override
  String faSyncPhotosCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String faSyncPhotosHeld({required String size}) {
    return '$size of photos wait for Wi-Fi. Records still sync.';
  }

  @override
  String get faSyncPillConflict => 'Conflict';

  @override
  String get faSyncPillNotSaved => 'Not saved';

  @override
  String get faSyncPillSynced => 'Synced';

  @override
  String get faSyncPillUploading => 'Uploading';

  @override
  String get faSyncPillWaiting => 'Waiting';

  @override
  String get faSyncProgressLabel => 'Upload progress';

  @override
  String get faSyncReasonClient =>
      'The app could not send this. Please tell HO.';

  @override
  String get faSyncReasonConsentExpired =>
      'The consent code expired. Record consent again on the farmer\'s page.';

  @override
  String get faSyncReasonNotInArea => 'Village is outside your area';

  @override
  String get faSyncReasonOther => 'HO could not accept this';

  @override
  String get faSyncReasonOtherFa => 'This farmer is with another FA. Call HO.';

  @override
  String get faSyncReasonParent =>
      'Not sent: the record it needs was not saved';

  @override
  String get faSyncReasonServer => 'Could not save. HO has been told.';

  @override
  String faSyncResolvedMine({required String value}) {
    return 'Kept yours · $value';
  }

  @override
  String get faSyncResolvedReady => 'ready to sync';

  @override
  String faSyncResolvedTheirs({required String value}) {
    return 'Kept HO\'s · $value';
  }

  @override
  String faSyncRetryBody({required String time}) {
    return 'Next try at $time. Or tap Sync now.';
  }

  @override
  String get faSyncRetryTitle => 'Couldn\'t reach the server';

  @override
  String faSyncSizeKb({required String size}) {
    return '$size KB';
  }

  @override
  String faSyncSizeMb({required String size}) {
    return '$size MB';
  }

  @override
  String get faSyncSyncNow => 'Sync now';

  @override
  String faSyncSyncedToday({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records synced today',
      one: '1 record synced today',
      zero: 'No records synced today',
    );
    return '$_temp0';
  }

  @override
  String get faSyncSyncingBody => 'Uploading records';

  @override
  String faSyncSyncingBodyPhotos({required String size}) {
    return 'Uploading records and $size of photos';
  }

  @override
  String get faSyncSyncingTitle => 'Syncing…';

  @override
  String get faSyncTheirs => 'HO\'s';

  @override
  String get faSyncTypeAlert => 'Alert read';

  @override
  String get faSyncTypeCallback => 'Call-back';

  @override
  String get faSyncTypeCancel => 'Visit cancelled';

  @override
  String get faSyncTypeConsent => 'Consent';

  @override
  String get faSyncTypeEnrol => 'Enrolment';

  @override
  String get faSyncTypeFarmer => 'Farmer details';

  @override
  String get faSyncTypePlan => 'Visit plan';

  @override
  String get faSyncTypePlot => 'Plot';

  @override
  String get faSyncTypeSeason => 'Crop';

  @override
  String get faSyncTypeVisit => 'Visit log';

  @override
  String get faSyncUnknownFarmer => 'Farmer';

  @override
  String get faSyncValueBoundaryWalked => 'Boundary walked';

  @override
  String get faSyncValueEmpty => 'Not set';

  @override
  String get faSyncValueNoBoundary => 'No boundary';

  @override
  String get faSyncValueNoPhoto => 'No photo';

  @override
  String get faSyncValuePhoto => 'New photo';

  @override
  String faSyncValueVersion({required int version}) {
    return 'Version $version';
  }

  @override
  String faSyncWaitingRecords({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records waiting',
      one: '1 record waiting',
    );
    return '$_temp0';
  }

  @override
  String faSyncWaitingRecordsPhotos({
    required int count,
    required String size,
  }) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records and $size of photos waiting',
      one: '1 record and $size of photos waiting',
      zero: '$size of photos waiting',
    );
    return '$_temp0';
  }

  @override
  String get faSyncWaitingTitle => 'Waiting to sync';

  @override
  String get faSyncWifiOff => 'Off · photos also upload on mobile data';

  @override
  String get faSyncWifiOn => 'On · records still sync on mobile data';

  @override
  String get faSyncWifiTitle => 'Upload photos on Wi-Fi only';

  @override
  String get faSyncYours => 'Yours';

  @override
  String faUnlockEnterPin({required int length}) {
    return 'Enter your $length-digit PIN';
  }

  @override
  String faUnlockGraceNote({required int days}) {
    return 'PIN works offline for $days days. After that, log in with your password once you have network.';
  }

  @override
  String faUnlockTriesLeft({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tries left',
      one: '1 try left',
    );
    return '$_temp0';
  }

  @override
  String get faUnlockUsePassword => 'Use password instead';

  @override
  String faUnlockWelcome({required String name}) {
    return 'Welcome back, $name';
  }

  @override
  String get faUnlockWrongPin => 'Wrong PIN';

  @override
  String get faVisitLogAddIssue => 'Add another issue';

  @override
  String get faVisitLogAdviceHo => 'HO will follow up';

  @override
  String get faVisitLogAlreadyLogged => 'This visit is already logged';

  @override
  String get faVisitLogBackToCalendar => 'Back to calendar';

  @override
  String get faVisitLogCameraFailed => 'The camera didn\'t open. Try again.';

  @override
  String get faVisitLogCheckDetails =>
      'Some details are missing. Check the red notes.';

  @override
  String faVisitLogDayAfterSowing({required int count}) {
    return 'day $count';
  }

  @override
  String get faVisitLogDiscard => 'Leave';

  @override
  String get faVisitLogDiscardBody =>
      'What you entered for this visit will be lost.';

  @override
  String get faVisitLogDiscardTitle => 'Leave without saving?';

  @override
  String get faVisitLogEditVisit => 'Edit this visit';

  @override
  String get faVisitLogFarmerPresent => 'Farmer was there';

  @override
  String get faVisitLogFarmerPresentNote =>
      'Turn off if you saw the field alone';

  @override
  String get faVisitLogGpsFinding => 'Finding GPS…';

  @override
  String faVisitLogGpsFix({required String lat, required String lng}) {
    return '$lat°N $lng°E';
  }

  @override
  String get faVisitLogGpsNone => 'No GPS fix';

  @override
  String get faVisitLogGpsRetry => 'Try GPS again';

  @override
  String get faVisitLogIssue => 'Issue';

  @override
  String faVisitLogIssueFrom({required String crop}) {
    return 'from the $crop list';
  }

  @override
  String faVisitLogIssueLabel({required String issue}) {
    return 'Issue: $issue. Change';
  }

  @override
  String faVisitLogIssueRow({required String issue, required int number}) {
    return 'Issue $number · $issue';
  }

  @override
  String faVisitLogIssueSeverity({
    required String issue,
    required String severity,
  }) {
    return '$issue ($severity)';
  }

  @override
  String get faVisitLogIssueType => 'Issue type';

  @override
  String get faVisitLogLangEn => 'English';

  @override
  String get faVisitLogLangTe => 'Telugu';

  @override
  String faVisitLogMoreCount({required int count}) {
    return '+ $count more';
  }

  @override
  String faVisitLogMorePhotos({required int count}) {
    return '$count more photos, show all';
  }

  @override
  String get faVisitLogNextNone => 'Not now';

  @override
  String get faVisitLogNextOther => 'Other date';

  @override
  String get faVisitLogNextVisit => 'Next visit';

  @override
  String get faVisitLogNextWeek => '+1 week';

  @override
  String faVisitLogNoCropBody({required String name}) {
    return 'Add $name\'s crop first, then log the visit.';
  }

  @override
  String get faVisitLogNoCropTitle => 'No crop to log a visit on';

  @override
  String get faVisitLogNoIssue => 'No issue found';

  @override
  String get faVisitLogNoIssueMatch => 'No issue matches';

  @override
  String get faVisitLogNoIssuesListed =>
      'No issues are listed for this crop yet.';

  @override
  String get faVisitLogNoPhotoBody =>
      'A photo helps HO check the advice. Save without one?';

  @override
  String get faVisitLogNoPhotoTitle => 'No photos yet';

  @override
  String get faVisitLogNoProduct => 'No Shanmukha product';

  @override
  String get faVisitLogNoProductNote =>
      'Farmer sees the salt name only, no brand';

  @override
  String get faVisitLogNoRule => 'No advice rule for this issue';

  @override
  String get faVisitLogNoRuleNote => 'HO will follow up with the farmer.';

  @override
  String get faVisitLogNone => 'None';

  @override
  String get faVisitLogNotPlanned => 'Not planned';

  @override
  String faVisitLogOpenFarmer({required String name}) {
    return 'Open $name';
  }

  @override
  String faVisitLogPhoto({required int number}) {
    return 'Photo $number';
  }

  @override
  String faVisitLogPhotoCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
      zero: 'take 1 to 3',
    );
    return '$_temp0';
  }

  @override
  String faVisitLogPhotoMax({required int max}) {
    return '$max photos at most';
  }

  @override
  String get faVisitLogPhotos => 'Photos';

  @override
  String get faVisitLogPickIssue => 'Pick the issue';

  @override
  String get faVisitLogPickIssueHint => 'Leave it if the crop looks fine';

  @override
  String get faVisitLogPickSalt => 'Pick the salt';

  @override
  String get faVisitLogPlot => 'Plot';

  @override
  String get faVisitLogPresentNo => 'farmer not there';

  @override
  String get faVisitLogPresentYes => 'farmer present ✓';

  @override
  String faVisitLogProduct({required String name}) {
    return 'Shanmukha product: $name';
  }

  @override
  String get faVisitLogProductNote => 'Farmer sees it with nearest dealers';

  @override
  String faVisitLogRemoveIssue({required String issue}) {
    return 'Remove issue $issue';
  }

  @override
  String faVisitLogRemovePhoto({required int number}) {
    return 'Remove photo $number';
  }

  @override
  String get faVisitLogRowAdvice => 'Advice';

  @override
  String get faVisitLogRowIssues => 'Issues';

  @override
  String get faVisitLogRowNext => 'Next visit';

  @override
  String get faVisitLogRowPhotos => 'Photos';

  @override
  String get faVisitLogRowStage => 'Stage';

  @override
  String get faVisitLogSalt => 'Recommend salt';

  @override
  String get faVisitLogSaltAfterIssue => 'Pick the issue first';

  @override
  String faVisitLogSaltLabel({required String salt}) {
    return 'Salt: $salt. Change';
  }

  @override
  String faVisitLogSaltOnly({required String salt}) {
    return '$salt · salt only';
  }

  @override
  String get faVisitLogSave => 'Save & tell farmer';

  @override
  String get faVisitLogSaveChanges => 'Save changes';

  @override
  String get faVisitLogSaveWithoutPhotos => 'Save without photos';

  @override
  String get faVisitLogSavedPending =>
      'Saved on this phone · goes to HO at next sync';

  @override
  String get faVisitLogSavedSynced => 'Synced · HO has it';

  @override
  String get faVisitLogSavedTitle => 'Visit saved';

  @override
  String get faVisitLogSearchIssues => 'Search issues';

  @override
  String get faVisitLogSeverity => 'How bad is it?';

  @override
  String get faVisitLogSeverityRequired => 'Pick how bad it is';

  @override
  String get faVisitLogSmsNone =>
      'No advice to send yet. HO will follow up on the issues.';

  @override
  String faVisitLogSmsPending({
    required String language,
    required String name,
  }) {
    return '$name will get the advice in $language by SMS and in the Orbit app when this syncs.';
  }

  @override
  String faVisitLogSmsSent({required String language, required String name}) {
    return '$name got the advice in $language by SMS and in the Orbit app.';
  }

  @override
  String get faVisitLogStage => 'Crop stage';

  @override
  String get faVisitLogStageRequired => 'Pick the crop stage';

  @override
  String get faVisitLogStay => 'Stay';

  @override
  String faVisitLogStep({required int number, required String title}) {
    return '$number · $title';
  }

  @override
  String get faVisitLogSuggested => 'suggested by master';

  @override
  String get faVisitLogSummary => 'What was saved';

  @override
  String get faVisitLogTakePhoto => 'Take photo';

  @override
  String get faVisitLogTypeDeficiency => 'Deficiency';

  @override
  String get faVisitLogTypeDisease => 'Disease';

  @override
  String get faVisitLogTypePest => 'Pest';

  @override
  String get faVisitLogWorksOffline => 'works offline';

  @override
  String get faVisitsErrorInvalidDate => 'Pick today or a later day.';

  @override
  String get faVisitsErrorNoData =>
      'Your farmers aren\'t on this phone yet. Sync first.';

  @override
  String get faVisitsErrorNoSeason =>
      'This plot has no crop yet. Add the crop first.';

  @override
  String get faVisitsErrorNotEditable =>
      'This visit was already sent to HO, so it can no longer be changed.';

  @override
  String get faVisitsErrorNotFound =>
      'This farmer, plot or visit isn\'t on this phone any more. Open it again.';

  @override
  String get faVisitsErrorNotPlanned =>
      'This visit is already done or cancelled.';

  @override
  String get faVisitsErrorRequired => 'Some details are missing.';

  @override
  String get faVisitsErrorTooMany =>
      'Too many photos or issues. Keep 20 at most.';

  @override
  String farmerAdviceAdvisedBy({required DateTime date, required String name}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Advised by $name · $dateString';
  }

  @override
  String get farmerAdviceAskAtShopBody =>
      'Ask for this name at the shop. If unsure, call your FA.';

  @override
  String get farmerAdviceAskAtShopLabel => 'Ask for this at the shop';

  @override
  String farmerAdviceDealerDistance({required String km}) {
    return '$km km';
  }

  @override
  String get farmerAdviceLocationNeeded =>
      'Allow location to see nearby dealers';

  @override
  String get farmerAdviceNearbyDealers => 'Nearby dealers';

  @override
  String get farmerAdviceNoDealers => 'No dealers found nearby';

  @override
  String get farmerAdviceNoProduct => 'No Shanmukha product for this';

  @override
  String get farmerAdviceProductTitle => 'Buy this product';

  @override
  String get farmerAdviceSaltTitle => 'FA advice';

  @override
  String get farmerAdviceShowAtShop => 'Show this card at the shop';

  @override
  String get farmerAdviceShowShopkeeper => 'Show this to the shopkeeper';

  @override
  String get farmerAdviceTitle => 'Advice';

  @override
  String get farmerAdviceVoiceHelpPending =>
      'Advice for this is not ready yet. Your FA will follow up. To ask now, call your FA.';

  @override
  String get farmerAdviceVoiceHelpProduct =>
      'This is the Shanmukha product your FA advised, with the dose per acre. Show this card at the shop.';

  @override
  String get farmerAdviceVoiceHelpSalt =>
      'There is no Shanmukha product for this problem. Ask for this name at the shop. If unsure, call your FA.';

  @override
  String farmerCalendarDay({required int day}) {
    return 'Day $day';
  }

  @override
  String farmerCalendarDayOf({required int day, required int total}) {
    return 'Day $day of about $total';
  }

  @override
  String get farmerCalendarNoSeason => 'Start a season to see the calendar.';

  @override
  String get farmerCalendarNoSowingDate =>
      'Tell your FA the sowing date. Then the calendar will show.';

  @override
  String get farmerCalendarNow => 'Now';

  @override
  String get farmerCalendarTasks => 'Upcoming tasks';

  @override
  String get farmerCalendarTasksLater =>
      'Task list and SMS reminders are coming soon.';

  @override
  String get farmerCalendarTitle => 'Crop calendar';

  @override
  String get farmerCalendarVoiceHelp =>
      'This shows which stage your crop is at, and how many days since sowing.';

  @override
  String get farmerConsentAgree => 'OK, I agree';

  @override
  String get farmerConsentDeclined =>
      'We can\'t send you advice without your permission. You can agree any time.';

  @override
  String get farmerConsentNotNow => 'Not now';

  @override
  String get farmerConsentPointChange =>
      'You can change this any time in My farm';

  @override
  String get farmerConsentPointPartners =>
      'Shared with partners only if you agree';

  @override
  String get farmerConsentPointSafe => 'Your details stay safe with Shanmukha';

  @override
  String get farmerConsentPurpose =>
      'We use your details to send you crop advice and to bring your FA to your field.';

  @override
  String get farmerConsentSaved => 'Your permission is saved';

  @override
  String get farmerConsentTitle => 'Your permission';

  @override
  String get farmerConsentVoiceHelp =>
      'We use your details to send you crop advice and to bring your FA to your field. Your details stay safe with Shanmukha. We share them with partners only if you agree. You can change this any time in My farm. Tap OK if you agree.';

  @override
  String get farmerConsentVoiceHelpDeclined =>
      'We can\'t send you advice without your permission. You can agree any time. To talk it over, call the helpline.';

  @override
  String get farmerConsentsAgree => 'Agree';

  @override
  String farmerConsentsChangedOn({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Changed on $dateString';
  }

  @override
  String get farmerConsentsDescLoyalty => 'Shanmukha rewards and cashback';

  @override
  String get farmerConsentsDescProgramme => 'Crop advice and FA visits';

  @override
  String get farmerConsentsDescSchemesFinance =>
      'Your details for schemes, insurance and loans';

  @override
  String get farmerConsentsDescSoilPartner =>
      'Your field location for the soil-test company';

  @override
  String get farmerConsentsEmpty => 'Couldn\'t load your permissions';

  @override
  String get farmerConsentsSubtitle => 'Who can see what';

  @override
  String get farmerConsentsTitle => 'Consents';

  @override
  String get farmerConsentsVoiceHelp =>
      'This shows who can see your details. You can agree to any of these, and withdraw any time.';

  @override
  String get farmerConsentsWithdraw => 'Withdraw';

  @override
  String get farmerConsentsWithdrawBody =>
      'You can agree again any time on this screen.';

  @override
  String get farmerConsentsWithdrawProgrammeVoice =>
      'Withdraw this permission? If you withdraw this, advice and FA visits may stop. You can agree again any time on this screen.';

  @override
  String get farmerConsentsWithdrawProgrammeWarning =>
      'If you withdraw this, advice and FA visits may stop.';

  @override
  String get farmerConsentsWithdrawTitle => 'Withdraw this permission?';

  @override
  String get farmerConsentsWithdrawVoice =>
      'Withdraw this permission? You can agree again any time on this screen.';

  @override
  String get farmerFarmAddPlot => 'Add plot';

  @override
  String get farmerFarmChangeName => 'Change name';

  @override
  String get farmerFarmChangeNameVoice => 'Type your name and tap Save.';

  @override
  String get farmerFarmChangePhoto => 'Change photo';

  @override
  String get farmerFarmCloseSeason => 'Close season';

  @override
  String get farmerFarmConsents => 'Consents';

  @override
  String get farmerFarmConsentsHint => 'Who can see what';

  @override
  String get farmerFarmFromGallery => 'Gallery';

  @override
  String get farmerFarmHelp => 'Help';

  @override
  String get farmerFarmLanguage => 'Language';

  @override
  String get farmerFarmLanguageChanged => 'Language changed';

  @override
  String get farmerFarmNoCrop => 'No crop yet';

  @override
  String get farmerFarmPhotoUpdated => 'Photo updated';

  @override
  String farmerFarmPlot({required int number}) {
    return 'Plot $number';
  }

  @override
  String get farmerFarmPlots => 'My plots';

  @override
  String get farmerFarmSignOutBody => 'You will need an OTP to sign in again.';

  @override
  String get farmerFarmSignOutTitle => 'Sign out from this phone?';

  @override
  String get farmerFarmSignOutVoice =>
      'Sign out from this phone? You will need an OTP to sign in again.';

  @override
  String farmerFarmSownOn({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'sown $dateString';
  }

  @override
  String farmerFarmSowsOn({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Sowing $dateString';
  }

  @override
  String get farmerFarmStartSeason => 'Start a season';

  @override
  String get farmerFarmTakePhoto => 'Take photo';

  @override
  String get farmerFarmTitle => 'My farm and profile';

  @override
  String get farmerFarmVillageChangeNote =>
      'To change your village, ask your FA';

  @override
  String get farmerFarmVoiceHelp =>
      'Your name, photo, plots, language and permissions are here. You can add a plot or start a season.';

  @override
  String get farmerFarmYourFa => 'Your FA';

  @override
  String farmerFasCallFailed({required String phone}) {
    return 'Couldn\'t open the phone app. Please call $phone.';
  }

  @override
  String get farmerFasCallHint => 'Tap Call to reach your FA directly';

  @override
  String get farmerFasCallback => 'Ask your FA to call you back';

  @override
  String get farmerFasCallbackCancelled => 'Request cancelled';

  @override
  String get farmerFasCallbackSent => 'Request sent';

  @override
  String farmerFasCallbackSentBody({required String name}) {
    return '$name will call you today';
  }

  @override
  String farmerFasCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count FAs',
      one: '1 FA',
      zero: 'No FAs here yet',
    );
    return '$_temp0';
  }

  @override
  String farmerFasLanguages({required String languages}) {
    return 'Speaks $languages';
  }

  @override
  String get farmerFasLead => 'Lead FA';

  @override
  String get farmerFasTitle => 'Field Assistants for your area';

  @override
  String get farmerFasVoiceHelp =>
      'These are the FAs for your area. Tap Call to talk to them. Tap Ask your FA to call you back and your FA will call you.';

  @override
  String get farmerFasWhatsappFailed =>
      'Couldn\'t open WhatsApp on this phone.';

  @override
  String farmerFasWhatsappMessage({
    required String name,
    required String village,
  }) {
    return 'Hello, I am $name, a farmer from $village.';
  }

  @override
  String farmerFasWorkingHours({required String hours}) {
    return 'Hours: $hours';
  }

  @override
  String get farmerFasYourFa => 'Your FA';

  @override
  String farmerHomeArea({required int acres, required int guntas}) {
    String _temp0 = intl.Intl.pluralLogic(
      guntas,
      locale: localeName,
      other: '$acres acres $guntas guntas',
      one: '$acres acres 1 gunta',
      zero: '$acres acres',
    );
    String _temp1 = intl.Intl.pluralLogic(
      guntas,
      locale: localeName,
      other: '1 acre $guntas guntas',
      one: '1 acre 1 gunta',
      zero: '1 acre',
    );
    String _temp2 = intl.Intl.pluralLogic(
      guntas,
      locale: localeName,
      other: '$guntas guntas',
      one: '1 gunta',
    );
    String _temp3 = intl.Intl.pluralLogic(
      acres,
      locale: localeName,
      other: '$_temp0',
      one: '$_temp1',
      zero: '$_temp2',
    );
    return '$_temp3';
  }

  @override
  String get farmerHomeFaVerified => 'Shanmukha FA';

  @override
  String farmerHomeGreeting({required String name}) {
    return 'Hello, $name';
  }

  @override
  String get farmerHomeLockedBody => 'We will tell you by SMS when it starts.';

  @override
  String get farmerHomeLockedTitle => 'This service is coming soon';

  @override
  String get farmerHomeLockedVoice =>
      'This service is coming soon. We will tell you by SMS when it starts.';

  @override
  String get farmerHomeLookForFas => 'Look for FAs';

  @override
  String get farmerHomeNextVisit => 'Next FA visit';

  @override
  String get farmerHomeNoNextVisit => 'Not planned yet';

  @override
  String get farmerHomeNoPlotBody =>
      'Add your field in My farm. Then your FA can advise you on your crop.';

  @override
  String get farmerHomeNoPlotTitle => 'Add your field';

  @override
  String get farmerHomeTileAdvisory => 'Advisory';

  @override
  String get farmerHomeTileAsk => 'Ask by voice';

  @override
  String get farmerHomeTileCalendar => 'Crop calendar';

  @override
  String get farmerHomeTilePests => 'Pests & disease';

  @override
  String get farmerHomeTilePremium => 'Premium';

  @override
  String get farmerHomeTileSchemes => 'Schemes';

  @override
  String get farmerHomeTileServices => 'Services';

  @override
  String get farmerHomeTileSoilTest => 'Soil test';

  @override
  String get farmerHomeTileWallet => 'Wallet';

  @override
  String get farmerHomeTileWeather => 'Weather';

  @override
  String farmerHomeUnread({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new advice',
      one: '1 new advice',
      zero: 'No new advice',
    );
    return '$_temp0';
  }

  @override
  String get farmerHomeVoiceHelp =>
      'This is your home. Tap the green button to call your FA. Visits, advice and your farm are at the bottom.';

  @override
  String get farmerHomeWeatherSoon => 'Weather is coming soon';

  @override
  String farmerHomeYourFa({required String name}) {
    return 'Your FA: $name';
  }

  @override
  String get farmerInboxEmptyBody => 'New advice will show here.';

  @override
  String get farmerInboxEmptyTitle => 'No advice yet';

  @override
  String get farmerInboxForYourField => 'For your field';

  @override
  String get farmerInboxListened => 'Listened';

  @override
  String farmerInboxNewCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '1 new',
      zero: 'Nothing new',
    );
    return '$_temp0';
  }

  @override
  String get farmerInboxNoAudio => 'No audio for this advice';

  @override
  String get farmerInboxNoAudioVoice =>
      'There is no recording for this advice yet. Read it on the screen, or ask your FA.';

  @override
  String get farmerInboxPinned => 'Pinned';

  @override
  String get farmerInboxTitle => 'Crop advisory';

  @override
  String get farmerInboxUnread => 'New';

  @override
  String get farmerInboxVoiceHelp =>
      'Crop advice from Shanmukha and CIV is here. Tap Listen to hear it.';

  @override
  String get farmerLoginAccountPaused =>
      'Your account is paused. Please call the helpline.';

  @override
  String get farmerLoginCallHelpline => 'Call helpline';

  @override
  String get farmerLoginChangeNumber => 'Change number';

  @override
  String get farmerLoginChooseLanguage => 'Choose language';

  @override
  String get farmerLoginNoOtp => 'OTP not received?';

  @override
  String get farmerLoginNoOtpHelp =>
      'Call the helpline and they will help you sign in.';

  @override
  String get farmerLoginOtpAutofill =>
      'The OTP fills in by itself when the SMS arrives';

  @override
  String get farmerLoginOtpHint => 'Type the 6-digit OTP from the SMS';

  @override
  String get farmerLoginOtpSent => 'OTP sent';

  @override
  String farmerLoginOtpSentTo({required String phone}) {
    return 'We sent a 6-digit OTP to $phone';
  }

  @override
  String get farmerLoginOtpTitle => 'Enter the OTP';

  @override
  String get farmerLoginOtpWaiting => 'Waiting for the OTP…';

  @override
  String get farmerLoginPausedTitle => 'Account paused';

  @override
  String get farmerLoginPhoneHint => '10-digit number';

  @override
  String get farmerLoginPhoneInvalid => 'Enter a 10-digit mobile number';

  @override
  String get farmerLoginPhoneSubtitle =>
      'We will send an OTP to this number by SMS';

  @override
  String get farmerLoginPhoneTitle => 'Your phone number';

  @override
  String get farmerLoginResend => 'Resend OTP';

  @override
  String farmerLoginResendIn({required String time}) {
    return 'Resend OTP in $time';
  }

  @override
  String get farmerLoginSendOtp => 'Send OTP';

  @override
  String get farmerLoginTagline => 'Crop advice, and your FA one call away';

  @override
  String get farmerLoginUseSimNumber => 'Use number from SIM';

  @override
  String get farmerLoginVerify => 'Verify and continue';

  @override
  String get farmerLoginVoiceHelpNoOtp =>
      'OTP not received? Call the helpline and they will help you sign in.';

  @override
  String get farmerLoginVoiceHelpOtp =>
      'Enter the 6-digit OTP from the SMS. If it does not come, call the helpline.';

  @override
  String get farmerLoginVoiceHelpPaused =>
      'Your account is paused. Please call the helpline.';

  @override
  String get farmerLoginVoiceHelpPhone =>
      'Type your phone number and tap Send OTP.';

  @override
  String get farmerNameDone =>
      'You\'re registered. Your FA will call you soon.';

  @override
  String get farmerNameFinish => 'Finish';

  @override
  String get farmerNameHint => 'Type your name';

  @override
  String get farmerNameRequired => 'Please type your name';

  @override
  String get farmerNameSubtitle => 'Your FA will know you by this name';

  @override
  String get farmerNameTitle => 'Your name';

  @override
  String get farmerNameVoiceHelp => 'Type your name and tap Finish.';

  @override
  String get farmerNavAdvisory => 'Advisory';

  @override
  String get farmerNavFarm => 'My farm';

  @override
  String get farmerNavHome => 'Home';

  @override
  String get farmerNavVisits => 'Visits';

  @override
  String get farmerNavWallet => 'Wallet';

  @override
  String farmerPlotAddAccuracy({required int meters}) {
    return 'Accurate to $meters m';
  }

  @override
  String get farmerPlotAddAcres => 'Acres';

  @override
  String get farmerPlotAddAreaInvalid => 'Enter the acres or guntas';

  @override
  String get farmerPlotAddAreaTitle => 'How big is the field?';

  @override
  String farmerPlotAddAreaTooBig({required int max}) {
    return 'Area must be $max acres or less';
  }

  @override
  String get farmerPlotAddGuntas => 'Guntas';

  @override
  String get farmerPlotAddGuntasHint => '40 guntas = 1 acre';

  @override
  String get farmerPlotAddGuntasInvalid => 'Guntas must be 0 to 39';

  @override
  String get farmerPlotAddLabelHint => 'e.g. Field near the well';

  @override
  String get farmerPlotAddLabelTitle => 'Field name (optional)';

  @override
  String get farmerPlotAddLocating => 'Finding your location…';

  @override
  String get farmerPlotAddLocationDenied =>
      'We need your location to mark the field';

  @override
  String get farmerPlotAddMarkSpot => 'Mark this spot';

  @override
  String get farmerPlotAddNoLocation =>
      'We couldn\'t find your village location. Ask your FA to add this field.';

  @override
  String get farmerPlotAddPinBody =>
      'Stand in your field and tap Mark this spot.';

  @override
  String get farmerPlotAddPinTitle => 'Stand in your field';

  @override
  String get farmerPlotAddSave => 'Save plot';

  @override
  String get farmerPlotAddSaved => 'Plot added';

  @override
  String get farmerPlotAddTitle => 'New plot';

  @override
  String get farmerPlotAddVillagePinBody =>
      'For now we use your village location. Your FA can mark the exact field when they visit.';

  @override
  String get farmerPlotAddVillagePinTitle => 'We\'ll mark it at your village';

  @override
  String get farmerPlotAddVoiceHelpArea =>
      'Enter how many acres and guntas your field is.';

  @override
  String get farmerPlotAddVoiceHelpLabel =>
      'Give your field a name if you like, then tap Continue.';

  @override
  String get farmerPlotAddVoiceHelpPin =>
      'Stand in the middle of your field and tap Mark this spot.';

  @override
  String get farmerPlotAddVoiceHelpVillagePin =>
      'For now we use your village location for this field. Your FA can mark the exact spot when they visit. Tap Continue.';

  @override
  String get farmerPlotAddWeakGps =>
      'GPS is weak. Stand in the open and try again.';

  @override
  String get farmerSeasonCloseClosed => 'Season closed';

  @override
  String get farmerSeasonCloseNoUndo => 'You can\'t undo this.';

  @override
  String get farmerSeasonCloseQuestion => 'What happened to this crop?';

  @override
  String get farmerSeasonCloseTitle => 'Close season';

  @override
  String get farmerSeasonCloseVoiceHelp =>
      'Was the crop harvested, or given up? Choose one.';

  @override
  String get farmerSeasonStartCurrent => 'This season';

  @override
  String get farmerSeasonStartNotSown => 'Not sown yet';

  @override
  String get farmerSeasonStartPreviousCrop => 'Which crop was here before?';

  @override
  String farmerSeasonStartSeasonLabel({
    required String season,
    required String year,
  }) {
    return '$season $year';
  }

  @override
  String get farmerSeasonStartSkip => 'Don\'t know, skip';

  @override
  String get farmerSeasonStartSowingDate => 'When did you sow?';

  @override
  String get farmerSeasonStartStarted => 'Season started';

  @override
  String get farmerSeasonStartTitle => 'Start a season';

  @override
  String get farmerSeasonStartVoiceHelp =>
      'Choose the season and the crop. If you know the sowing date, add it too.';

  @override
  String get farmerSeasonStartWhichCrop => 'Which crop?';

  @override
  String get farmerSeasonStartWhichSeason => 'Which season?';

  @override
  String get farmerStateCallFa => 'Call FA';

  @override
  String get farmerStateErrorTitle => 'Something went wrong';

  @override
  String get farmerStateErrorVoice => 'Something went wrong. Tap Try again.';

  @override
  String get farmerStateNoAdviceVoice =>
      'No advice yet. New advice will show here.';

  @override
  String get farmerStateNoFaAction => 'Call helpline';

  @override
  String get farmerStateNoFaTitle => 'Your FA will call you soon';

  @override
  String get farmerStateNoFaVoice =>
      'Your FA will call you soon. If you need help, call the helpline.';

  @override
  String get farmerStateNoVisitsBody => 'Your FA will plan the first one.';

  @override
  String get farmerStateNoVisitsTitle => 'No visits yet';

  @override
  String get farmerStateNoVisitsVoice =>
      'No visits yet. Your FA will plan the first one.';

  @override
  String farmerStateOfflineBody({required DateTime time}) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Showing saved details from $timeString';
  }

  @override
  String get farmerStateOfflineNothingSaved =>
      'Nothing saved yet. Try again when you are online.';

  @override
  String get farmerStateOfflineNothingVoice =>
      'No internet. Nothing saved yet. Try again when you are online.';

  @override
  String get farmerStateOfflineTitle => 'No internet';

  @override
  String get farmerStateOfflineVoice =>
      'No internet. Showing the details saved earlier.';

  @override
  String get farmerVillageBrowse => 'Browse by district and mandal';

  @override
  String get farmerVillageChooseDistrict => 'Choose district';

  @override
  String get farmerVillageChooseMandal => 'Choose mandal';

  @override
  String get farmerVillageChooseVillage => 'Choose village';

  @override
  String get farmerVillageConfirm => 'Yes, this is my village';

  @override
  String farmerVillageNoResults({required String query}) {
    return 'No village found for $query';
  }

  @override
  String farmerVillageResultArea({
    required String district,
    required String mandal,
  }) {
    return '$mandal mandal, $district district';
  }

  @override
  String get farmerVillageSearchHint => 'Type your village name';

  @override
  String get farmerVillageSubtitle => 'Choose the village where your field is';

  @override
  String get farmerVillageTitle => 'Your village';

  @override
  String get farmerVillageVoiceHelp =>
      'Type the name of the village where your field is. If you cannot find it, browse by district and mandal.';

  @override
  String get farmerVisitsAdvicePending =>
      'Advice pending. Your FA will follow up.';

  @override
  String farmerVisitsByFa({required DateTime date, required String name}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString · $name';
  }

  @override
  String farmerVisitsCallBefore({required String name}) {
    return '$name will call before coming';
  }

  @override
  String farmerVisitsMedicine({required String name}) {
    return 'Product: $name';
  }

  @override
  String get farmerVisitsNextVisit => 'Next visit';

  @override
  String get farmerVisitsNoIssues => 'No problems found';

  @override
  String farmerVisitsPhotos({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get farmerVisitsSaltOnly => 'No Shanmukha product, ask the shop';

  @override
  String get farmerVisitsSeeAdvice => 'See advice';

  @override
  String get farmerVisitsShanmukhaProduct => 'Shanmukha product';

  @override
  String farmerVisitsStage({required String stage}) {
    return '$stage stage';
  }

  @override
  String get farmerVisitsTitle => 'My visits';

  @override
  String get farmerVisitsVoiceHelp =>
      'Here are the days your FA visited, the problems they saw and the advice they gave. The next visit is at the top.';
}
