// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'orbit_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class OrbitLocalizationsTe extends OrbitLocalizations {
  OrbitLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get commonAllow => 'అనుమతి ఇవ్వండి';

  @override
  String get commonAppName => 'Orbit Shifting';

  @override
  String get commonAudioError => 'ఆడియో ప్లే కాలేదు';

  @override
  String get commonAudioLoading => 'ఆడియో వస్తోంది…';

  @override
  String get commonAudioUnavailable => 'ఈ ఆడియో ఇంకా లేదు';

  @override
  String get commonBack => 'వెనక్కి';

  @override
  String get commonCall => 'కాల్';

  @override
  String commonCallName({required String name}) {
    return '$name గారికి కాల్ చేయండి';
  }

  @override
  String get commonCancel => 'రద్దు';

  @override
  String get commonChoose => 'ఎంచుకోండి';

  @override
  String get commonClose => 'మూసివేయండి';

  @override
  String get commonComingSoon => 'త్వరలో';

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
      other: '$count రోజుల క్రితం',
      one: '1 రోజు క్రితం',
    );
    return '$_temp0';
  }

  @override
  String get commonDone => 'పూర్తయింది';

  @override
  String commonDotJoin({required String first, required String second}) {
    return '$first · $second';
  }

  @override
  String get commonEdit => 'మార్చండి';

  @override
  String get commonHelp => 'సహాయం';

  @override
  String get commonHelpline => 'సహాయ కేంద్రం';

  @override
  String commonHoursAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count గంటల క్రితం',
      one: '1 గంట క్రితం',
    );
    return '$_temp0';
  }

  @override
  String get commonLater => 'తర్వాత';

  @override
  String get commonListen => 'వినండి';

  @override
  String get commonLoading => 'లోడ్ అవుతోంది…';

  @override
  String commonMinutesAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count నిమిషాల క్రితం',
      one: '1 నిమిషం క్రితం',
    );
    return '$_temp0';
  }

  @override
  String get commonNext => 'ముందుకు';

  @override
  String get commonNo => 'వద్దు';

  @override
  String get commonOffline => 'ఇంటర్నెట్ లేదు';

  @override
  String get commonOk => 'సరే';

  @override
  String get commonOpenSettings => 'సెట్టింగ్స్ తెరవండి';

  @override
  String get commonRead => 'చదవండి';

  @override
  String get commonRetry => 'మళ్ళీ ప్రయత్నించండి';

  @override
  String get commonSave => 'సేవ్ చేయండి';

  @override
  String commonSavedAt({required DateTime time}) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$timeString కి సేవ్ చేసింది';
  }

  @override
  String get commonSearch => 'వెతకండి';

  @override
  String get commonSignOut => 'లాగౌట్';

  @override
  String commonStepOf({required int step, required int total}) {
    return '$step/$total';
  }

  @override
  String get commonStop => 'ఆపండి';

  @override
  String get commonToday => 'ఈ రోజు';

  @override
  String get commonTomorrow => 'రేపు';

  @override
  String get commonUndo => 'రద్దు చేయండి';

  @override
  String get commonUnknown => 'తెలియదు';

  @override
  String get commonUpdateAvailable => 'కొత్త వెర్షన్ వచ్చింది';

  @override
  String get commonUpdateButton => 'అప్‌డేట్ చేయండి';

  @override
  String get commonUpdateRequiredBody =>
      'కొనసాగడానికి కొత్త వెర్షన్ ఇన్‌స్టాల్ చేయండి.';

  @override
  String get commonUpdateRequiredTitle => 'యాప్ అప్‌డేట్ చేయండి';

  @override
  String get commonWhatsapp => 'WhatsApp';

  @override
  String get commonYes => 'అవును';

  @override
  String get commonYesterday => 'నిన్న';

  @override
  String get enumAdviceStatusGiven => 'సలహా ఇచ్చారు';

  @override
  String get enumAdviceStatusUnresolved => 'సలహా రావాలి';

  @override
  String get enumAreaSourceBoundary => 'పొలం చుట్టూ నడిచి కొలిచారు';

  @override
  String get enumAreaSourceTyped => 'రైతు చెప్పిన విస్తీర్ణం';

  @override
  String get enumAreaUnitAcre => 'ఎకరాలు';

  @override
  String get enumAreaUnitGunta => 'గుంటలు';

  @override
  String get enumCallbackStatusCancelled => 'రద్దు చేశారు';

  @override
  String get enumCallbackStatusClosed => 'FA కాల్ చేశారు';

  @override
  String get enumCallbackStatusOpen => 'అభ్యర్థన పంపాం';

  @override
  String get enumConsentMethodApp => 'యాప్‌లో';

  @override
  String get enumConsentMethodFaOtp => 'FA ద్వారా, OTP తో';

  @override
  String get enumConsentMethodHo => 'షణ్ముఖ ఆఫీసు ద్వారా';

  @override
  String get enumConsentPurposeLoyalty => 'క్యాష్‌బ్యాక్, బహుమతులు';

  @override
  String get enumConsentPurposeProgramme => 'ఆర్బిట్ కార్యక్రమం';

  @override
  String get enumConsentPurposeSchemesFinance => 'పథకాలు, రుణాలు, బీమా';

  @override
  String get enumConsentPurposeSoilPartner => 'మట్టి పరీక్ష కంపెనీ';

  @override
  String get enumConsentStateGranted => 'ఒప్పుకున్నారు';

  @override
  String get enumConsentStateNeverAsked => 'ఇంకా అడగలేదు';

  @override
  String get enumConsentStateWithdrawn => 'వద్దన్నారు';

  @override
  String get enumCoverageLevelDistrict => 'జిల్లా';

  @override
  String get enumCoverageLevelMandal => 'మండలం';

  @override
  String get enumCoverageLevelVillage => 'గ్రామం';

  @override
  String get enumFarmerPlanFree => 'ఉచితం';

  @override
  String get enumFarmerPlanPremium => 'ప్రీమియం';

  @override
  String get enumFarmerStatusActive => 'యాక్టివ్';

  @override
  String get enumFarmerStatusInactive => 'ఆపివేశారు';

  @override
  String get enumFarmerStatusPendingProfile => 'నమోదు పూర్తి కాలేదు';

  @override
  String get enumLanguageEn => 'English';

  @override
  String get enumLanguageTe => 'తెలుగు';

  @override
  String get enumNoticeSenderCiv => 'CIV';

  @override
  String get enumNoticeSenderFa => 'మీ FA';

  @override
  String get enumNoticeSenderHo => 'షణ్ముఖ';

  @override
  String get enumNoticeSenderSystem => 'ఆర్బిట్';

  @override
  String get enumPlannedSlotAfternoon => 'మధ్యాహ్నం';

  @override
  String get enumPlannedSlotAny => 'రోజులో ఎప్పుడైనా';

  @override
  String get enumPlannedSlotMorning => 'ఉదయం';

  @override
  String get enumSeasonKindKharif => 'ఖరీఫ్';

  @override
  String get enumSeasonKindRabi => 'రబీ';

  @override
  String get enumSeasonKindSummer => 'వేసవి';

  @override
  String get enumSeasonStatusAbandoned => 'పంట వదిలేశారు';

  @override
  String get enumSeasonStatusActive => 'పంట పొలంలో ఉంది';

  @override
  String get enumSeasonStatusHarvested => 'కోత పూర్తయింది';

  @override
  String get enumSeverityHigh => 'ఎక్కువ';

  @override
  String get enumSeverityLow => 'తక్కువ';

  @override
  String get enumSeverityModerate => 'మధ్యస్థం';

  @override
  String get enumVisitStatusCancelled => 'రద్దయింది';

  @override
  String get enumVisitStatusDone => 'వచ్చి వెళ్ళారు';

  @override
  String get enumVisitStatusMissed => 'రాలేదు';

  @override
  String get enumVisitStatusPlanned => 'రావాల్సి ఉంది';

  @override
  String get errorActiveSeasonExists =>
      'ఈ పొలంలో ఇప్పటికే ఒక పంట ఉంది. ముందు దాన్ని ముగించండి.';

  @override
  String get errorCallbackClosed => 'మీ FA ఈ అభ్యర్థన ఇప్పటికే ముగించారు.';

  @override
  String errorDetailAttemptsLeft({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఇంకా $count సార్లు ప్రయత్నించవచ్చు.',
      one: 'ఇంకా 1 సారి ప్రయత్నించవచ్చు.',
      zero: 'ఇక ప్రయత్నాలు లేవు. కొత్త OTP అడగండి.',
    );
    return '$_temp0';
  }

  @override
  String errorDetailRetryAfterSeconds({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count సెకన్ల తర్వాత మళ్ళీ ప్రయత్నించండి.',
      one: '1 సెకను తర్వాత మళ్ళీ ప్రయత్నించండి.',
    );
    return '$_temp0';
  }

  @override
  String get errorDeviceRevoked =>
      'ఈ ఫోన్ నుంచి లాగౌట్ చేశాం. మళ్ళీ లాగిన్ అవ్వండి.';

  @override
  String get errorForbidden => 'ఇది చేయడానికి అనుమతి లేదు.';

  @override
  String get errorInternal =>
      'మా వైపు ఏదో తప్పు జరిగింది. మళ్ళీ ప్రయత్నించండి.';

  @override
  String get errorInvalidCursor => 'జాబితా పాతబడింది. మళ్ళీ తెరవండి.';

  @override
  String get errorInvalidRequest => 'ఏదో సరిగా లేదు. మళ్ళీ ప్రయత్నించండి.';

  @override
  String get errorNetwork =>
      'ఇంటర్నెట్ లేదు. కనెక్షన్ చూసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get errorNoFaAssigned =>
      'మీకు ఇంకా FA ని ఇవ్వలేదు. సహాయ కేంద్రానికి కాల్ చేయండి.';

  @override
  String get errorNotFound => 'ఇది దొరకలేదు. మళ్ళీ తెరిచి చూడండి.';

  @override
  String get errorNotInYourArea => 'ఈ రైతు గ్రామం మీ ప్రాంతంలో లేదు.';

  @override
  String get errorOtpExpired => 'ఈ OTP గడువు ముగిసింది. కొత్త OTP అడగండి.';

  @override
  String get errorOtpInvalid => 'OTP తప్పు. SMS చూసి మళ్ళీ వేయండి.';

  @override
  String get errorPasswordChangeRequired =>
      'కొనసాగడానికి మీ పాస్‌వర్డ్ మార్చండి.';

  @override
  String get errorPayloadTooLarge => 'ఇది పంపడానికి చాలా పెద్దది.';

  @override
  String get errorPhoneTaken => 'ఈ ఫోన్ నంబర్ మరో రైతు పేరు మీద ఉంది.';

  @override
  String get errorPhotoAlreadyUploaded => 'ఈ ఫోటో ఇప్పటికే పంపారు.';

  @override
  String get errorProfileAlreadyComplete => 'మీ నమోదు ఇప్పటికే పూర్తయింది.';

  @override
  String get errorProfileIncomplete => 'ముందు మీ నమోదు పూర్తి చేయండి.';

  @override
  String get errorRateLimited =>
      'చాలా సార్లు ప్రయత్నించారు. కాసేపు ఆగి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get errorRefreshReused =>
      'ఈ లాగిన్ వేరే చోట వాడారు. మళ్ళీ లాగిన్ అవ్వండి.';

  @override
  String get errorRegisteredWithAnotherFa =>
      'ఈ రైతు ఇప్పటికే వేరే FA దగ్గర నమోదయ్యారు.';

  @override
  String get errorSeasonExists => 'ఈ సీజన్‌కు ఈ పొలంలో పంట ఇప్పటికే ఉంది.';

  @override
  String get errorSeasonNotActive => 'ఈ పంట ఇప్పటికే ముగిసింది.';

  @override
  String get errorSessionRevoked =>
      'మీరు లాగౌట్ అయ్యారు. మళ్ళీ లాగిన్ అవ్వండి.';

  @override
  String get errorTempPasswordExpired =>
      'మీ తాత్కాలిక పాస్‌వర్డ్ గడువు ముగిసింది. కొత్తది కోసం HO కి కాల్ చేయండి.';

  @override
  String get errorTimeout => 'ఇంటర్నెట్ నెమ్మదిగా ఉంది. మళ్ళీ ప్రయత్నించండి.';

  @override
  String get errorUnauthorized => 'మళ్ళీ లాగిన్ అవ్వండి.';

  @override
  String get errorUnavailable =>
      'సర్వీస్ ఇప్పుడు పని చేయడం లేదు. కాసేపటి తర్వాత ప్రయత్నించండి.';

  @override
  String get errorUnknown => 'ఏదో తప్పు జరిగింది. మళ్ళీ ప్రయత్నించండి.';

  @override
  String get errorUploadMissing => 'ఫోటో అప్‌లోడ్ కాలేదు. మళ్ళీ పంపండి.';

  @override
  String get errorValidationFailed => 'వివరాలు సరిగా లేవు. చూసి మళ్ళీ ఇవ్వండి.';

  @override
  String get errorVersionMismatch =>
      'ఈ వివరాలు HO మార్చింది. మళ్ళీ తెరిచి చూడండి.';

  @override
  String farmerAdviceAdvisedBy({required DateTime date, required String name}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$name గారి సలహా · $dateString';
  }

  @override
  String get farmerAdviceAskAtShopBody =>
      'దుకాణంలో ఈ పేరు అడగండి. సందేహం ఉంటే FA కి కాల్ చేయండి.';

  @override
  String get farmerAdviceAskAtShopLabel => 'దుకాణంలో ఇది అడగండి';

  @override
  String farmerAdviceDealerDistance({required String km}) {
    return '$km కి.మీ';
  }

  @override
  String get farmerAdviceLocationNeeded =>
      'దగ్గర దుకాణాలు చూడడానికి లొకేషన్ అనుమతి ఇవ్వండి';

  @override
  String get farmerAdviceNearbyDealers => 'దగ్గర దుకాణాలు';

  @override
  String get farmerAdviceNoDealers => 'దగ్గరలో దుకాణాలు దొరకలేదు';

  @override
  String get farmerAdviceNoProduct => 'షణ్ముఖ మందు లేదు';

  @override
  String get farmerAdviceProductTitle => 'ఈ మందు కొనండి';

  @override
  String get farmerAdviceSaltTitle => 'FA సలహా';

  @override
  String get farmerAdviceShowAtShop => 'ఈ కార్డు దుకాణంలో చూపించండి';

  @override
  String get farmerAdviceShowShopkeeper => 'దుకాణదారుకు చూపించండి';

  @override
  String get farmerAdviceTitle => 'సలహా';

  @override
  String get farmerAdviceVoiceHelpPending =>
      'దీనికి సలహా ఇంకా రాలేదు. మీ FA తర్వాత చెబుతారు. ఇప్పుడే అడగాలంటే మీ FA కి కాల్ చేయండి.';

  @override
  String get farmerAdviceVoiceHelpProduct =>
      'ఇది మీ FA చెప్పిన షణ్ముఖ మందు, ఎకరానికి ఎంత వేయాలో కింద ఉంది. ఈ కార్డు దుకాణంలో చూపించండి.';

  @override
  String get farmerAdviceVoiceHelpSalt =>
      'ఈ సమస్యకు షణ్ముఖ మందు లేదు. దుకాణంలో ఈ పేరు అడగండి. సందేహం ఉంటే FA కి కాల్ చేయండి.';

  @override
  String farmerCalendarDay({required int day}) {
    return '$dayవ రోజు';
  }

  @override
  String farmerCalendarDayOf({required int day, required int total}) {
    return '$dayవ రోజు (మొత్తం సుమారు $total రోజులు)';
  }

  @override
  String get farmerCalendarNoSeason =>
      'పంట మొదలుపెడితే క్యాలెండర్ కనిపిస్తుంది.';

  @override
  String get farmerCalendarNoSowingDate =>
      'విత్తిన రోజు మీ FA కి చెప్పండి. అప్పుడు క్యాలెండర్ కనిపిస్తుంది.';

  @override
  String get farmerCalendarNow => 'ఇప్పుడు';

  @override
  String get farmerCalendarTasks => 'రాబోయే పనులు';

  @override
  String get farmerCalendarTasksLater =>
      'చేయాల్సిన పనులు, SMS రిమైండర్లు త్వరలో వస్తాయి.';

  @override
  String get farmerCalendarTitle => 'పంట క్యాలెండర్';

  @override
  String get farmerCalendarVoiceHelp =>
      'మీ పంట ఏ దశలో ఉందో ఇక్కడ చూడవచ్చు. విత్తిన రోజు నుంచి ఎన్ని రోజులైందో పైన ఉంది.';

  @override
  String get farmerConsentAgree => 'సరే, ఒప్పుకుంటున్నాను';

  @override
  String get farmerConsentDeclined =>
      'మీ అనుమతి లేకుండా సలహాలు పంపలేము. ఎప్పుడైనా ఒప్పుకోవచ్చు.';

  @override
  String get farmerConsentNotNow => 'ఇప్పుడు కాదు';

  @override
  String get farmerConsentPointChange =>
      '\'నా పొలం\' లో ఎప్పుడైనా మార్చుకోవచ్చు';

  @override
  String get farmerConsentPointPartners =>
      'ఇతర కంపెనీలకు మీరు ఒప్పుకుంటేనే పంపుతాం';

  @override
  String get farmerConsentPointSafe =>
      'మీ పేరు, ఫోన్, పొలం వివరాలు షణ్ముఖ వద్ద భద్రంగా ఉంటాయి';

  @override
  String get farmerConsentPurpose =>
      'మీ పంటకు సలహాలు ఇవ్వడానికి, మీ FA మీ పొలానికి రావడానికి మీ వివరాలు వాడుతాం.';

  @override
  String get farmerConsentSaved => 'మీ అనుమతి సేవ్ అయింది';

  @override
  String get farmerConsentTitle => 'మీ అనుమతి';

  @override
  String get farmerConsentVoiceHelp =>
      'మీ పంటకు సలహాలు ఇవ్వడానికి, మీ FA మీ పొలానికి రావడానికి మీ వివరాలు వాడుతాం. మీ పేరు, ఫోన్, పొలం వివరాలు షణ్ముఖ వద్ద భద్రంగా ఉంటాయి. ఇతర కంపెనీలకు మీరు ఒప్పుకుంటేనే పంపుతాం. \'నా పొలం\' లో ఎప్పుడైనా మార్చుకోవచ్చు. ఒప్పుకుంటే, సరే నొక్కండి.';

  @override
  String get farmerConsentVoiceHelpDeclined =>
      'మీ అనుమతి లేకుండా సలహాలు పంపలేము. ఎప్పుడైనా ఒప్పుకోవచ్చు. మాట్లాడాలంటే సహాయ కేంద్రానికి కాల్ చేయండి.';

  @override
  String get farmerConsentsAgree => 'ఒప్పుకోండి';

  @override
  String farmerConsentsChangedOn({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString న మార్చారు';
  }

  @override
  String get farmerConsentsDescLoyalty => 'షణ్ముఖ బహుమతులు, క్యాష్‌బ్యాక్';

  @override
  String get farmerConsentsDescProgramme => 'మీ పంటకు సలహాలు, FA సందర్శనలు';

  @override
  String get farmerConsentsDescSchemesFinance =>
      'పథకాలు, బీమా, రుణాల కోసం మీ వివరాలు';

  @override
  String get farmerConsentsDescSoilPartner =>
      'మట్టి పరీక్ష కంపెనీకి మీ పొలం లొకేషన్';

  @override
  String get farmerConsentsEmpty => 'మీ అనుమతులు చూపించలేకపోయాం';

  @override
  String get farmerConsentsSubtitle => 'ఎవరు ఏమి చూడవచ్చు';

  @override
  String get farmerConsentsTitle => 'అనుమతులు';

  @override
  String get farmerConsentsVoiceHelp =>
      'మీ వివరాలు ఎవరు చూడవచ్చో ఇక్కడ ఉంది. ఏది కావాలంటే అది ఒప్పుకోవచ్చు, ఎప్పుడైనా వెనక్కి తీసుకోవచ్చు.';

  @override
  String get farmerConsentsWithdraw => 'వెనక్కి తీసుకోండి';

  @override
  String get farmerConsentsWithdrawBody =>
      'ఇక్కడే ఎప్పుడైనా మళ్ళీ ఒప్పుకోవచ్చు.';

  @override
  String get farmerConsentsWithdrawProgrammeVoice =>
      'ఈ అనుమతి వెనక్కి తీసుకోవాలా? ఇది తీసేస్తే సలహాలు, FA సందర్శనలు ఆగిపోవచ్చు. ఇక్కడే ఎప్పుడైనా మళ్ళీ ఒప్పుకోవచ్చు.';

  @override
  String get farmerConsentsWithdrawProgrammeWarning =>
      'ఇది తీసేస్తే సలహాలు, FA సందర్శనలు ఆగిపోవచ్చు.';

  @override
  String get farmerConsentsWithdrawTitle => 'అనుమతి వెనక్కి తీసుకోవాలా?';

  @override
  String get farmerConsentsWithdrawVoice =>
      'ఈ అనుమతి వెనక్కి తీసుకోవాలా? ఇక్కడే ఎప్పుడైనా మళ్ళీ ఒప్పుకోవచ్చు.';

  @override
  String get farmerFarmAddPlot => 'పొలం జోడించండి';

  @override
  String get farmerFarmChangeName => 'పేరు మార్చండి';

  @override
  String get farmerFarmChangeNameVoice =>
      'మీ పేరు టైప్ చేసి, \'సేవ్\' బటన్ నొక్కండి.';

  @override
  String get farmerFarmChangePhoto => 'ఫోటో మార్చండి';

  @override
  String get farmerFarmCloseSeason => 'పంట ముగించండి';

  @override
  String get farmerFarmConsents => 'అనుమతులు';

  @override
  String get farmerFarmConsentsHint => 'ఎవరు ఏమి చూడవచ్చు';

  @override
  String get farmerFarmFromGallery => 'గ్యాలరీ';

  @override
  String get farmerFarmHelp => 'సహాయం';

  @override
  String get farmerFarmLanguage => 'భాష';

  @override
  String get farmerFarmLanguageChanged => 'భాష మారింది';

  @override
  String get farmerFarmNoCrop => 'ఇంకా పంట వేయలేదు';

  @override
  String get farmerFarmPhotoUpdated => 'ఫోటో మారింది';

  @override
  String farmerFarmPlot({required int number}) {
    return 'పొలం $number';
  }

  @override
  String get farmerFarmPlots => 'నా పొలాలు';

  @override
  String get farmerFarmSignOutBody => 'మళ్ళీ లాగిన్ అవ్వడానికి OTP కావాలి.';

  @override
  String get farmerFarmSignOutTitle => 'ఈ ఫోన్ నుంచి లాగౌట్ అవ్వాలా?';

  @override
  String get farmerFarmSignOutVoice =>
      'ఈ ఫోన్ నుంచి లాగౌట్ అవ్వాలా? మళ్ళీ లాగిన్ అవ్వడానికి OTP కావాలి.';

  @override
  String farmerFarmSownOn({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString న విత్తారు';
  }

  @override
  String farmerFarmSowsOn({required DateTime date}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString న విత్తుతారు';
  }

  @override
  String get farmerFarmStartSeason => 'పంట మొదలుపెట్టండి';

  @override
  String get farmerFarmTakePhoto => 'ఫోటో తీయండి';

  @override
  String get farmerFarmTitle => 'నా పొలం';

  @override
  String get farmerFarmVillageChangeNote =>
      'గ్రామం మార్చాలంటే మీ FA కి చెప్పండి';

  @override
  String get farmerFarmVoiceHelp =>
      'ఇక్కడ మీ పేరు, ఫోటో, పొలాలు, భాష, అనుమతులు ఉన్నాయి. కొత్త పొలం జోడించవచ్చు, పంట మొదలుపెట్టవచ్చు.';

  @override
  String get farmerFarmYourFa => 'మీ FA';

  @override
  String farmerFasCallFailed({required String phone}) {
    return 'ఫోన్ యాప్ తెరుచుకోలేదు. $phone కు కాల్ చేయండి.';
  }

  @override
  String get farmerFasCallHint =>
      'మీ FA కి నేరుగా కాల్ చేయడానికి కాల్ నొక్కండి';

  @override
  String get farmerFasCallback => 'నాకు కాల్ చేయండి';

  @override
  String get farmerFasCallbackCancelled => 'అభ్యర్థన రద్దు చేశాం';

  @override
  String get farmerFasCallbackSent => 'అభ్యర్థన పంపాం';

  @override
  String farmerFasCallbackSentBody({required String name}) {
    return '$name గారు ఈ రోజు మీకు కాల్ చేస్తారు';
  }

  @override
  String farmerFasCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count FA లు',
      one: '1 FA',
      zero: 'ఇక్కడ ఇంకా FA లు లేరు',
    );
    return '$_temp0';
  }

  @override
  String farmerFasLanguages({required String languages}) {
    return 'భాషలు: $languages';
  }

  @override
  String get farmerFasLead => 'ముఖ్య FA';

  @override
  String get farmerFasTitle => 'FA లు';

  @override
  String get farmerFasVoiceHelp =>
      'మీ ప్రాంతంలోని FA లు ఇక్కడ ఉన్నారు. కాల్ నొక్కితే నేరుగా మాట్లాడవచ్చు. నాకు కాల్ చేయండి నొక్కితే మీ FA మీకు కాల్ చేస్తారు.';

  @override
  String get farmerFasWhatsappFailed => 'ఈ ఫోన్‌లో WhatsApp తెరుచుకోలేదు.';

  @override
  String farmerFasWhatsappMessage({
    required String name,
    required String village,
  }) {
    return 'నమస్కారం, నేను $name, $village రైతును.';
  }

  @override
  String farmerFasWorkingHours({required String hours}) {
    return 'పని వేళలు: $hours';
  }

  @override
  String get farmerFasYourFa => 'మీ FA';

  @override
  String farmerHomeArea({required int acres, required int guntas}) {
    String _temp0 = intl.Intl.pluralLogic(
      guntas,
      locale: localeName,
      other: '$acres ఎకరాలు $guntas గుంటలు',
      one: '$acres ఎకరాలు 1 గుంట',
      zero: '$acres ఎకరాలు',
    );
    String _temp1 = intl.Intl.pluralLogic(
      guntas,
      locale: localeName,
      other: '1 ఎకరం $guntas గుంటలు',
      one: '1 ఎకరం 1 గుంట',
      zero: '1 ఎకరం',
    );
    String _temp2 = intl.Intl.pluralLogic(
      guntas,
      locale: localeName,
      other: '$guntas గుంటలు',
      one: '1 గుంట',
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
  String get farmerHomeFaVerified => 'షణ్ముఖ FA';

  @override
  String farmerHomeGreeting({required String name}) {
    return 'నమస్కారం, $name';
  }

  @override
  String get farmerHomeLockedBody => 'ఇది మొదలవగానే SMS ద్వారా మీకు చెబుతాం.';

  @override
  String get farmerHomeLockedTitle => 'ఈ సేవ త్వరలో వస్తుంది';

  @override
  String get farmerHomeLockedVoice =>
      'ఈ సేవ త్వరలో వస్తుంది. మొదలవగానే SMS ద్వారా మీకు చెబుతాం.';

  @override
  String get farmerHomeLookForFas => 'FA లను చూడండి';

  @override
  String get farmerHomeNextVisit => 'FA వచ్చే రోజు';

  @override
  String get farmerHomeNoNextVisit => 'ఇంకా రోజు నిర్ణయించలేదు';

  @override
  String get farmerHomeNoPlotBody =>
      '\'నా పొలం\' పేజీలో మీ పొలం జోడించండి. అప్పుడు FA మీ పంటకు సలహా ఇస్తారు.';

  @override
  String get farmerHomeNoPlotTitle => 'మీ పొలం జోడించండి';

  @override
  String get farmerHomeTileAdvisory => 'సలహాలు';

  @override
  String get farmerHomeTileAsk => 'అడగండి';

  @override
  String get farmerHomeTileCalendar => 'క్యాలెండర్';

  @override
  String get farmerHomeTilePests => 'చీడపీడలు';

  @override
  String get farmerHomeTilePremium => 'ప్రీమియం';

  @override
  String get farmerHomeTileSchemes => 'పథకాలు';

  @override
  String get farmerHomeTileServices => 'సేవలు';

  @override
  String get farmerHomeTileSoilTest => 'మట్టి పరీక్ష';

  @override
  String get farmerHomeTileWallet => 'వాలెట్';

  @override
  String get farmerHomeTileWeather => 'వాతావరణం';

  @override
  String farmerHomeUnread({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count కొత్త సలహాలు',
      one: '1 కొత్త సలహా',
      zero: 'కొత్త సలహాలు లేవు',
    );
    return '$_temp0';
  }

  @override
  String get farmerHomeVoiceHelp =>
      'ఇది మీ హోమ్. మీ FA కి కాల్ చేయడానికి పచ్చ బటన్ నొక్కండి. కింద సందర్శనలు, సలహాలు, మీ పొలం ఉన్నాయి.';

  @override
  String get farmerHomeWeatherSoon => 'వాతావరణం త్వరలో వస్తుంది';

  @override
  String farmerHomeYourFa({required String name}) {
    return 'మీ FA: $name';
  }

  @override
  String get farmerInboxEmptyBody => 'కొత్త సలహాలు వస్తే ఇక్కడ కనిపిస్తాయి.';

  @override
  String get farmerInboxEmptyTitle => 'ఇంకా సలహాలు లేవు';

  @override
  String get farmerInboxForYourField => 'మీ పొలానికి';

  @override
  String get farmerInboxListened => 'విన్నారు';

  @override
  String farmerInboxNewCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count కొత్తవి',
      one: '1 కొత్తది',
      zero: 'కొత్తవి లేవు',
    );
    return '$_temp0';
  }

  @override
  String get farmerInboxNoAudio => 'ఈ సలహాకు ఆడియో లేదు';

  @override
  String get farmerInboxNoAudioVoice =>
      'ఈ సలహాకు ఇంకా ఆడియో రికార్డ్ చేయలేదు. స్క్రీన్ మీద చదవండి, లేదా మీ FA ని అడగండి.';

  @override
  String get farmerInboxPinned => 'ముఖ్యమైనది';

  @override
  String get farmerInboxTitle => 'సలహాలు';

  @override
  String get farmerInboxUnread => 'కొత్తది';

  @override
  String get farmerInboxVoiceHelp =>
      'షణ్ముఖ, CIV పంపిన పంట సలహాలు ఇక్కడ ఉన్నాయి. వినాలంటే \'వినండి\' బటన్ నొక్కండి.';

  @override
  String get farmerLoginAccountPaused =>
      'మీ ఖాతా ఇప్పుడు ఆగి ఉంది. సహాయ కేంద్రానికి కాల్ చేయండి.';

  @override
  String get farmerLoginCallHelpline => 'సహాయ కేంద్రానికి కాల్';

  @override
  String get farmerLoginChangeNumber => 'నంబర్ మార్చండి';

  @override
  String get farmerLoginChooseLanguage => 'భాష ఎంచుకోండి';

  @override
  String get farmerLoginNoOtp => 'OTP రాలేదా?';

  @override
  String get farmerLoginNoOtpHelp =>
      'సహాయ కేంద్రానికి కాల్ చేయండి. వారు సహాయం చేస్తారు.';

  @override
  String get farmerLoginOtpAutofill => 'SMS రాగానే OTP దానంతట అదే నిండుతుంది';

  @override
  String get farmerLoginOtpHint => 'SMS లో వచ్చిన 6 అంకెల OTP వేయండి';

  @override
  String get farmerLoginOtpSent => 'OTP పంపాం';

  @override
  String farmerLoginOtpSentTo({required String phone}) {
    return '$phone కు 6 అంకెల OTP పంపాం';
  }

  @override
  String get farmerLoginOtpTitle => 'OTP వేయండి';

  @override
  String get farmerLoginOtpWaiting => 'OTP కోసం చూస్తున్నాం…';

  @override
  String get farmerLoginPausedTitle => 'మీ ఖాతా ఆగి ఉంది';

  @override
  String get farmerLoginPhoneHint => '10 అంకెల నంబర్';

  @override
  String get farmerLoginPhoneInvalid => '10 అంకెల మొబైల్ నంబర్ ఇవ్వండి';

  @override
  String get farmerLoginPhoneSubtitle => 'ఈ నంబర్‌కు SMS లో OTP పంపుతాం';

  @override
  String get farmerLoginPhoneTitle => 'మీ ఫోన్ నంబర్';

  @override
  String get farmerLoginResend => 'OTP మళ్ళీ పంపండి';

  @override
  String farmerLoginResendIn({required String time}) {
    return '$time తర్వాత మళ్ళీ పంపవచ్చు';
  }

  @override
  String get farmerLoginSendOtp => 'OTP పంపండి';

  @override
  String get farmerLoginTagline => 'పంటకు సలహా, మీ FA ఒక్క కాల్ దూరంలో';

  @override
  String get farmerLoginUseSimNumber => 'SIM నంబర్ వాడండి';

  @override
  String get farmerLoginVerify => 'సరిచూసి ముందుకు';

  @override
  String get farmerLoginVoiceHelpNoOtp =>
      'OTP రాలేదా? సహాయ కేంద్రానికి కాల్ చేయండి. వారు సహాయం చేస్తారు.';

  @override
  String get farmerLoginVoiceHelpOtp =>
      'SMS లో వచ్చిన 6 అంకెల OTP ఇక్కడ వేయండి. OTP రాకపోతే సహాయ కేంద్రానికి కాల్ చేయండి.';

  @override
  String get farmerLoginVoiceHelpPaused =>
      'మీ ఖాతా ఇప్పుడు ఆగి ఉంది. సహాయ కేంద్రానికి కాల్ చేయండి.';

  @override
  String get farmerLoginVoiceHelpPhone =>
      'మీ ఫోన్ నంబర్ టైప్ చేసి, OTP పంపండి నొక్కండి.';

  @override
  String get farmerNameDone => 'నమోదు పూర్తయింది. మీ FA త్వరలో కాల్ చేస్తారు.';

  @override
  String get farmerNameFinish => 'నమోదు పూర్తి చేయండి';

  @override
  String get farmerNameHint => 'మీ పేరు టైప్ చేయండి';

  @override
  String get farmerNameRequired => 'దయచేసి మీ పేరు రాయండి';

  @override
  String get farmerNameSubtitle => 'మీ FA మిమ్మల్ని ఈ పేరుతో గుర్తిస్తారు';

  @override
  String get farmerNameTitle => 'మీ పేరు';

  @override
  String get farmerNameVoiceHelp =>
      'మీ పేరు టైప్ చేసి, నమోదు పూర్తి చేయండి నొక్కండి.';

  @override
  String get farmerNavAdvisory => 'సలహాలు';

  @override
  String get farmerNavFarm => 'నా పొలం';

  @override
  String get farmerNavHome => 'హోమ్';

  @override
  String get farmerNavVisits => 'సందర్శనలు';

  @override
  String get farmerNavWallet => 'వాలెట్';

  @override
  String farmerPlotAddAccuracy({required int meters}) {
    return '$meters మీటర్ల లోపు సరిగ్గా ఉంది';
  }

  @override
  String get farmerPlotAddAcres => 'ఎకరాలు';

  @override
  String get farmerPlotAddAreaInvalid => 'ఎకరాలు లేదా గుంటలు వేయండి';

  @override
  String get farmerPlotAddAreaTitle => 'పొలం ఎంత ఉంది?';

  @override
  String farmerPlotAddAreaTooBig({required int max}) {
    return 'పొలం $max ఎకరాల లోపు ఉండాలి';
  }

  @override
  String get farmerPlotAddGuntas => 'గుంటలు';

  @override
  String get farmerPlotAddGuntasHint => '40 గుంటలు = 1 ఎకరం';

  @override
  String get farmerPlotAddGuntasInvalid => 'గుంటలు 0 నుంచి 39 వరకు ఉండాలి';

  @override
  String get farmerPlotAddLabelHint => 'ఉదా: బావి దగ్గర పొలం';

  @override
  String get farmerPlotAddLabelTitle => 'పొలానికి పేరు (అవసరమైతే)';

  @override
  String get farmerPlotAddLocating => 'మీ చోటు చూస్తున్నాం…';

  @override
  String get farmerPlotAddLocationDenied => 'లొకేషన్ లేకుండా పొలం గుర్తించలేము';

  @override
  String get farmerPlotAddMarkSpot => 'ఈ చోటు గుర్తించండి';

  @override
  String get farmerPlotAddNoLocation =>
      'మీ గ్రామం లొకేషన్ దొరకలేదు. ఈ పొలం జోడించమని మీ FA కి చెప్పండి.';

  @override
  String get farmerPlotAddPinBody =>
      'పొలంలో నిలబడి, ఈ చోటు గుర్తించండి నొక్కండి.';

  @override
  String get farmerPlotAddPinTitle => 'మీ పొలంలో నిలబడండి';

  @override
  String get farmerPlotAddSave => 'పొలం సేవ్ చేయండి';

  @override
  String get farmerPlotAddSaved => 'పొలం జోడించాం';

  @override
  String get farmerPlotAddTitle => 'కొత్త పొలం';

  @override
  String get farmerPlotAddVillagePinBody =>
      'ఇప్పటికి మీ గ్రామం లొకేషన్ వాడుతాం. మీ FA వచ్చినప్పుడు పొలం సరైన చోటు గుర్తిస్తారు.';

  @override
  String get farmerPlotAddVillagePinTitle => 'మీ గ్రామం దగ్గర గుర్తిస్తాం';

  @override
  String get farmerPlotAddVoiceHelpArea =>
      'మీ పొలం ఎన్ని ఎకరాలు, ఎన్ని గుంటలు ఉందో వేయండి.';

  @override
  String get farmerPlotAddVoiceHelpLabel =>
      'కావాలంటే మీ పొలానికి ఒక పేరు పెట్టండి. తర్వాత ముందుకు నొక్కండి.';

  @override
  String get farmerPlotAddVoiceHelpPin =>
      'మీ పొలం మధ్యలో నిలబడి, ఈ చోటు గుర్తించండి నొక్కండి.';

  @override
  String get farmerPlotAddVoiceHelpVillagePin =>
      'ఇప్పటికి ఈ పొలానికి మీ గ్రామం లొకేషన్ వాడుతాం. మీ FA వచ్చినప్పుడు సరైన చోటు గుర్తిస్తారు. ముందుకు నొక్కండి.';

  @override
  String get farmerPlotAddWeakGps =>
      'GPS సరిగా లేదు. ఆకాశం కనిపించే చోట నిలబడి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get farmerSeasonCloseClosed => 'పంట ముగిసింది';

  @override
  String get farmerSeasonCloseNoUndo => 'ఇది మళ్ళీ మార్చలేరు.';

  @override
  String get farmerSeasonCloseQuestion => 'ఈ పంట ఏమైంది?';

  @override
  String get farmerSeasonCloseTitle => 'పంట ముగించండి';

  @override
  String get farmerSeasonCloseVoiceHelp =>
      'కోత పూర్తయిందా, లేక పంట వదిలేశారా? ఒకటి ఎంచుకోండి.';

  @override
  String get farmerSeasonStartCurrent => 'ఇప్పటి సీజన్';

  @override
  String get farmerSeasonStartNotSown => 'ఇంకా విత్తలేదు';

  @override
  String get farmerSeasonStartPreviousCrop => 'ఇంతకు ముందు ఇక్కడ ఏ పంట వేశారు?';

  @override
  String farmerSeasonStartSeasonLabel({
    required String season,
    required String year,
  }) {
    return '$season $year';
  }

  @override
  String get farmerSeasonStartSkip => 'తెలియదు, వదిలేయండి';

  @override
  String get farmerSeasonStartSowingDate => 'ఎప్పుడు విత్తారు?';

  @override
  String get farmerSeasonStartStarted => 'పంట మొదలైంది';

  @override
  String get farmerSeasonStartTitle => 'పంట మొదలుపెట్టండి';

  @override
  String get farmerSeasonStartVoiceHelp =>
      'సీజన్, పంట ఎంచుకోండి. విత్తిన రోజు తెలిస్తే అది కూడా ఇవ్వండి.';

  @override
  String get farmerSeasonStartWhichCrop => 'ఏ పంట?';

  @override
  String get farmerSeasonStartWhichSeason => 'ఏ సీజన్?';

  @override
  String get farmerStateCallFa => 'FA కి కాల్';

  @override
  String get farmerStateErrorTitle => 'ఏదో తప్పు జరిగింది';

  @override
  String get farmerStateErrorVoice =>
      'ఏదో తప్పు జరిగింది. మళ్ళీ ప్రయత్నించండి నొక్కండి.';

  @override
  String get farmerStateNoAdviceVoice =>
      'ఇంకా సలహాలు లేవు. కొత్త సలహాలు వస్తే ఇక్కడ కనిపిస్తాయి.';

  @override
  String get farmerStateNoFaAction => 'సహాయ కేంద్రానికి కాల్';

  @override
  String get farmerStateNoFaTitle => 'మీ FA త్వరలో కాల్ చేస్తారు';

  @override
  String get farmerStateNoFaVoice =>
      'మీ FA త్వరలో కాల్ చేస్తారు. అవసరమైతే సహాయ కేంద్రానికి కాల్ చేయండి.';

  @override
  String get farmerStateNoVisitsBody => 'మీ FA మొదటి సందర్శన ప్లాన్ చేస్తారు.';

  @override
  String get farmerStateNoVisitsTitle => 'ఇంకా సందర్శనలు లేవు';

  @override
  String get farmerStateNoVisitsVoice =>
      'ఇంకా సందర్శనలు లేవు. మీ FA మొదటి సందర్శన ప్లాన్ చేస్తారు.';

  @override
  String farmerStateOfflineBody({required DateTime time}) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$timeString కి సేవ్ చేసిన వివరాలు చూపిస్తున్నాం';
  }

  @override
  String get farmerStateOfflineNothingSaved =>
      'ఇంకా ఏమీ సేవ్ కాలేదు. ఇంటర్నెట్ వచ్చాక మళ్ళీ ప్రయత్నించండి.';

  @override
  String get farmerStateOfflineNothingVoice =>
      'ఇంటర్నెట్ లేదు. ఇంకా ఏమీ సేవ్ కాలేదు. ఇంటర్నెట్ వచ్చాక మళ్ళీ ప్రయత్నించండి.';

  @override
  String get farmerStateOfflineTitle => 'ఇంటర్నెట్ లేదు';

  @override
  String get farmerStateOfflineVoice =>
      'ఇంటర్నెట్ లేదు. ఇంతకు ముందు సేవ్ చేసిన వివరాలు చూపిస్తున్నాం.';

  @override
  String get farmerVillageBrowse => 'జిల్లా, మండలం నుంచి వెతకండి';

  @override
  String get farmerVillageChooseDistrict => 'జిల్లా ఎంచుకోండి';

  @override
  String get farmerVillageChooseMandal => 'మండలం ఎంచుకోండి';

  @override
  String get farmerVillageChooseVillage => 'గ్రామం ఎంచుకోండి';

  @override
  String get farmerVillageConfirm => 'అవును, ఇదే నా గ్రామం';

  @override
  String farmerVillageNoResults({required String query}) {
    return '$query పేరుతో గ్రామం దొరకలేదు';
  }

  @override
  String farmerVillageResultArea({
    required String district,
    required String mandal,
  }) {
    return '$mandal మండలం, $district జిల్లా';
  }

  @override
  String get farmerVillageSearchHint => 'గ్రామం పేరు టైప్ చేయండి';

  @override
  String get farmerVillageSubtitle => 'మీ పొలం ఉన్న గ్రామం ఎంచుకోండి';

  @override
  String get farmerVillageTitle => 'మీ గ్రామం';

  @override
  String get farmerVillageVoiceHelp =>
      'మీ పొలం ఉన్న గ్రామం పేరు టైప్ చేయండి. దొరకకపోతే జిల్లా, మండలం నుంచి వెతకండి.';

  @override
  String get farmerVisitsAdvicePending =>
      'సలహా ఇంకా రాలేదు. మీ FA తర్వాత చెబుతారు.';

  @override
  String farmerVisitsByFa({required DateTime date, required String name}) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString · $name';
  }

  @override
  String farmerVisitsCallBefore({required String name}) {
    return '$name గారు వచ్చే ముందు కాల్ చేస్తారు';
  }

  @override
  String farmerVisitsMedicine({required String name}) {
    return 'మందు: $name';
  }

  @override
  String get farmerVisitsNextVisit => 'FA వచ్చే రోజు';

  @override
  String get farmerVisitsNoIssues => 'సమస్యలు ఏమీ కనిపించలేదు';

  @override
  String farmerVisitsPhotos({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ఫోటోలు',
      one: '1 ఫోటో',
    );
    return '$_temp0';
  }

  @override
  String get farmerVisitsSaltOnly => 'షణ్ముఖ మందు లేదు, దుకాణంలో అడగండి';

  @override
  String get farmerVisitsSeeAdvice => 'సలహా చూడండి';

  @override
  String get farmerVisitsShanmukhaProduct => 'షణ్ముఖ మందు';

  @override
  String farmerVisitsStage({required String stage}) {
    return '$stage';
  }

  @override
  String get farmerVisitsTitle => 'సందర్శనలు';

  @override
  String get farmerVisitsVoiceHelp =>
      'మీ FA మీ పొలానికి వచ్చిన రోజులు, చూసిన సమస్యలు, ఇచ్చిన సలహాలు ఇక్కడ ఉన్నాయి. పైన FA వచ్చే రోజు ఉంది.';
}
