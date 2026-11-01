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
