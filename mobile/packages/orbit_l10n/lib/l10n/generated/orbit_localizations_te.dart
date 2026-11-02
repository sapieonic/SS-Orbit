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
  String get faActionErrorAlreadyEnrolled =>
      'ఈ రైతు ఇప్పటికే మీ దగ్గర ఉన్నారు.';

  @override
  String get faActionErrorAreaTooSmall =>
      'ఈ విస్తీర్ణం చాలా చిన్నది. గట్టు మళ్ళీ నడవండి లేదా విస్తీర్ణం టైప్ చేయండి.';

  @override
  String get faActionErrorBoundaryCrossesItself =>
      'గట్టు తనను తానే దాటుతోంది. మళ్ళీ నడవండి.';

  @override
  String get faActionErrorCannotClear =>
      'దీన్ని ఇక్కడ ఖాళీగా వదలలేరు. తీసేయాలంటే HO కి చెప్పండి.';

  @override
  String get faActionErrorInvalidDate => 'ఈ రోజు లేదా తర్వాతి రోజు ఎంచుకోండి.';

  @override
  String get faActionErrorInvalidPhone => 'ఇది సరైన మొబైల్ నంబర్ కాదు.';

  @override
  String get faActionErrorInvalidSeasonCode =>
      'ఈ సీజన్ ముగిసింది. వేరేది ఎంచుకోండి.';

  @override
  String get faActionErrorLocationRequired =>
      'ముందు పొలం గట్టు నడవండి లేదా పిన్ పెట్టండి.';

  @override
  String get faActionErrorNoData =>
      'మీ రైతుల వివరాలు ఇంకా ఈ ఫోన్‌లో లేవు. ముందు ఒకసారి ఇంటర్నెట్‌తో సింక్ చేయండి.';

  @override
  String get faActionErrorNoSeason =>
      'ఈ పొలంలో ఇంకా పంట లేదు. ముందు పంట నమోదు చేయండి.';

  @override
  String get faActionErrorNotEditable =>
      'ఈ సందర్శన ఇప్పటికే HO కి వెళ్ళింది, ఇక మార్చలేరు.';

  @override
  String get faActionErrorNotFound =>
      'ఇది ఇప్పుడు ఈ ఫోన్‌లో లేదు. వెనక్కి వెళ్ళి మళ్ళీ తెరవండి.';

  @override
  String get faActionErrorNotPlanned =>
      'ఈ సందర్శన ఇప్పటికే పూర్తయింది లేదా రద్దయింది.';

  @override
  String get faActionErrorNothingToChange =>
      'ఏమీ మారలేదు, సేవ్ చేయడానికి ఏమీ లేదు.';

  @override
  String get faActionErrorOutOfRange => 'ఈ సంఖ్య సరిగ్గా లేదు. సరిచూడండి.';

  @override
  String get faActionErrorProofInvalid =>
      'అనుమతి OTP గడువు ముగిసింది. కొత్త OTP పంపండి.';

  @override
  String get faActionErrorRequired => 'అన్ని వివరాలు నింపండి.';

  @override
  String get faActionErrorTooLong => 'ఇది చాలా పొడవుగా ఉంది.';

  @override
  String get faActionErrorTooMany =>
      'ఫోటోలు లేదా సమస్యలు చాలా ఎక్కువ. 20 వరకే ఉంచండి.';

  @override
  String get faActionErrorWrongState =>
      'ఇది ఇప్పటికే మారింది. మళ్ళీ చూసి ఇంకోసారి ప్రయత్నించండి.';

  @override
  String get faAlertsAcknowledged =>
      'చూశారు · మీరు చదివినట్లు HO కి తెలుస్తుంది';

  @override
  String get faAlertsCallFarmer => 'రైతుకు కాల్ చేయండి';

  @override
  String get faAlertsCallPlanVisit => 'కాల్ · సందర్శన ప్లాన్';

  @override
  String get faAlertsCallbackClosed => 'కాల్ బ్యాక్ మూసివేయబడింది';

  @override
  String get faAlertsCallbackHint => 'కాల్ లాగ్ చేసినప్పుడు మూసివేయబడుతుంది';

  @override
  String get faAlertsCloseCallback => 'కాల్ బ్యాక్ మూసివేయండి';

  @override
  String get faAlertsCloseCallbackHint => 'మాట్లాడారా? అభ్యర్థనను మూసివేయండి.';

  @override
  String faAlertsEarlier({required int count}) {
    return 'ఇంతకు ముందువి · $count';
  }

  @override
  String get faAlertsEmptyBody =>
      'కొత్త రైతులు, కాల్ బ్యాక్ అభ్యర్థనలు, HO సందేశాలు ఇక్కడ కనిపిస్తాయి.';

  @override
  String get faAlertsEmptyTabBody => 'ఈ రకం హెచ్చరికలు ఇప్పుడు లేవు.';

  @override
  String get faAlertsEmptyTabTitle => 'ఇక్కడ ఏమీ లేదు';

  @override
  String get faAlertsEmptyTitle => 'హెచ్చరికలు లేవు';

  @override
  String get faAlertsFinishEnrolment => 'నమోదు పూర్తి చేయండి';

  @override
  String get faAlertsGotIt => 'సరే, చూశాను';

  @override
  String get faAlertsKindCallback => 'కాల్ చేయమన్నారు';

  @override
  String get faAlertsKindHoNote => 'HO సందేశం';

  @override
  String get faAlertsKindNewFarmer => 'కొత్త రైతు';

  @override
  String get faAlertsKindOther => 'హెచ్చరిక';

  @override
  String get faAlertsOfflineBody =>
      'ఈ ఫోన్‌లో ఉన్న హెచ్చరికలు చూపిస్తున్నాం. నెట్‌వర్క్ వచ్చాక కిందకి లాగి రిఫ్రెష్ చేయండి.';

  @override
  String get faAlertsOpenFarmer => 'రైతును చూడండి';

  @override
  String get faAlertsStatusClosed => 'మూసివేయబడింది';

  @override
  String faAlertsSubtitle({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count పనులు చేయాలి',
      one: '1 పని చేయాలి',
      zero: 'ఏ పనీ లేదు',
    );
    return '$_temp0';
  }

  @override
  String get faAlertsTabAll => 'అన్నీ';

  @override
  String get faAlertsTabCallbacks => 'కాల్ బ్యాక్‌లు';

  @override
  String get faAlertsTabHo => 'HO నుండి';

  @override
  String get faAlertsTabNewFarmers => 'కొత్త రైతులు';

  @override
  String get faAlertsTabsLabel => 'హెచ్చరిక రకం';

  @override
  String faAuthCallFailed({required String phone}) {
    return 'డయలర్ తెరవలేకపోయాం. HO కి $phone నంబర్‌కు కాల్ చేయండి.';
  }

  @override
  String faAuthCallHo({required String phone}) {
    return 'HO కి కాల్ చేయండి · $phone';
  }

  @override
  String faAuthFarmersCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count మంది రైతులు',
      one: '1 రైతు',
    );
    return '$_temp0';
  }

  @override
  String get faAuthHide => 'దాచు';

  @override
  String get faAuthHidePassword => 'పాస్‌వర్డ్ దాచు';

  @override
  String get faAuthOfflineSaved =>
      'ఆఫ్‌లైన్ · మీ రైతుల వివరాలు ఈ ఫోన్‌లో ఉన్నాయి';

  @override
  String get faAuthOnline => 'ఆన్‌లైన్';

  @override
  String get faAuthPinDelete => 'అంకె తొలగించండి';

  @override
  String faAuthPinEntered({required int filled, required int length}) {
    return '$length అంకెల్లో $filled నమోదు చేశారు';
  }

  @override
  String faAuthPlotsCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count పొలాలు',
      one: '1 పొలం',
    );
    return '$_temp0';
  }

  @override
  String get faAuthRole => 'ఫీల్డ్ అసిస్టెంట్';

  @override
  String get faAuthShow => 'చూపించు';

  @override
  String get faAuthShowPassword => 'పాస్‌వర్డ్ చూపించు';

  @override
  String get faBlockedBefore => 'అప్‌డేట్ చేసే ముందు';

  @override
  String get faBlockedNewLogin => 'కొత్త పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి';

  @override
  String get faBlockedNothingLost =>
      'ఏదీ పోదు: మీరు యాప్ వదిలే ముందు సేవ్ అయిన రికార్డులు పంపుతాం.';

  @override
  String get faBlockedOpenStore => 'Play Store తెరవండి';

  @override
  String get faBlockedRemovedBody =>
      'HO ఈ ఫోన్ నుంచి మీ లాగిన్‌ను తొలగించింది. రైతుల వివరాలు ఈ ఫోన్ నుంచి తొలగించబడ్డాయి.';

  @override
  String get faBlockedRemovedNote =>
      'ఫోన్ పోయినప్పుడు లేదా వేరేవారి చేతికి వెళ్ళినప్పుడు ఇలా జరుగుతుంది. పొరపాటు అనిపిస్తే HO కి కాల్ చేయండి; వారు కొత్త లాగిన్ ఇస్తారు.';

  @override
  String get faBlockedSendFailed =>
      'రికార్డులు పంపలేకపోయాం. ఇంటర్నెట్‌కు కనెక్ట్ అయి మళ్ళీ ప్రయత్నించండి. ఇప్పుడే అప్‌డేట్ చేస్తే అవి ఈ ఫోన్‌లోనే ఉండి అప్‌డేట్ తర్వాత పంపబడతాయి.';

  @override
  String get faBlockedSendThenUpdate => 'రికార్డులు పంపి, అప్‌డేట్ చేయండి';

  @override
  String get faBlockedSending => 'పంపుతోంది…';

  @override
  String get faBlockedStepNothing => 'మీ రికార్డులన్నీ పంపబడ్డాయి';

  @override
  String faBlockedStepSend({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'సేవ్ అయిన $count రికార్డులు HO కి పంపండి',
      one: 'సేవ్ అయిన 1 రికార్డు HO కి పంపండి',
    );
    return '$_temp0';
  }

  @override
  String faBlockedStepSending({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రికార్డులు పంపుతోంది…',
      one: '1 రికార్డు పంపుతోంది…',
    );
    return '$_temp0';
  }

  @override
  String faBlockedStepSent({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రికార్డులు HO కి పంపబడ్డాయి',
      one: '1 రికార్డు HO కి పంపబడింది',
    );
    return '$_temp0';
  }

  @override
  String get faBlockedStepStore => 'Play Store తెరిచి అప్‌డేట్ చేయండి';

  @override
  String get faBlockedStepUnlock => 'ఎప్పటిలాగే PIN తో తెరవండి';

  @override
  String get faBlockedStoreFailed =>
      'Play Store తెరవలేకపోయాం. మీరే తెరిచి Orbit Shifting అప్‌డేట్ చేయండి, లేదా HO కి కాల్ చేయండి.';

  @override
  String get faBlockedUpdateAnyway => 'పంపకుండా అప్‌డేట్ చేయండి';

  @override
  String faBlockedUpdateBody({required String min, required String version}) {
    return 'ఈ వెర్షన్ ($version) పాతది. రికార్డులు సరిగ్గా సింక్ అవ్వడానికి అందరూ $min లేదా కొత్తది వాడాలని HO కోరుతోంది.';
  }

  @override
  String faBlockedUpdateBodyPlain({required String version}) {
    return 'ఈ వెర్షన్ ($version) పాతది. రికార్డులు సరిగ్గా సింక్ అవ్వడానికి అప్‌డేట్ చేయండి.';
  }

  @override
  String get faCalendarAdd => 'జోడించు';

  @override
  String faCalendarCancelBody({required String date}) {
    return 'ఇది $date కి ప్లాన్ చేశారు. తర్వాతి సింక్ తర్వాత రైతుకు ఇది కనిపించదు.';
  }

  @override
  String faCalendarCancelTitle({required String name}) {
    return '$name సందర్శన రద్దు చేయాలా?';
  }

  @override
  String get faCalendarCancelVisit => 'సందర్శన రద్దు చేయండి';

  @override
  String faCalendarCancelled({required String name}) {
    return '$name సందర్శన రద్దు చేశారు';
  }

  @override
  String faCalendarDayLabel({required int count, required String date}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count సందర్శనలు',
      one: '1 సందర్శన',
      zero: 'సందర్శనలు లేవు',
    );
    return '$date, $_temp0';
  }

  @override
  String faCalendarDoneCount({required int count}) {
    return '$count పూర్తి';
  }

  @override
  String get faCalendarEmptyBody =>
      'సందర్శన రావాల్సిన రైతులను ఎంచుకుని, కాల్ చేసి రోజు ఖరారు చేయండి.';

  @override
  String get faCalendarEmptyTitle => 'సందర్శనలు ఏవీ ప్లాన్ చేయలేదు';

  @override
  String get faCalendarFindDue => 'సందర్శన రావాల్సిన రైతులు';

  @override
  String get faCalendarFooterNote =>
      'సందర్శన లాగ్ సేవ్ చేయగానే అది పూర్తయినట్టు మారుతుంది.';

  @override
  String get faCalendarKeepVisit => 'ఉంచండి';

  @override
  String faCalendarMoved({required String date, required String name}) {
    return 'సందర్శన మార్చారు · $name · $date';
  }

  @override
  String get faCalendarNextWeek => 'తర్వాత వారం';

  @override
  String get faCalendarOffline =>
      'ఇంటర్నెట్ లేదు · సందర్శనలు ఈ ఫోన్‌లో సేవ్ అయి, తర్వాత సింక్ అవుతాయి';

  @override
  String faCalendarPlanned({required String date, required String name}) {
    return 'సందర్శన ప్లాన్ అయింది · $name · $date';
  }

  @override
  String get faCalendarPreviousWeek => 'ముందు వారం';

  @override
  String get faCalendarReschedule => 'వేరే రోజుకు మార్చండి';

  @override
  String faCalendarSavedNoAdvice({required String name}) {
    return 'సందర్శన సేవ్ అయింది · $name పూర్తయింది';
  }

  @override
  String faCalendarSavedPending({required String name}) {
    return 'సందర్శన సేవ్ అయింది · $name పూర్తయింది · సింక్ అయ్యాక సలహా SMS లో వెళ్తుంది';
  }

  @override
  String faCalendarSavedSent({required String name}) {
    return 'సందర్శన సేవ్ అయింది · $name పూర్తయింది · సలహా పంపాం';
  }

  @override
  String get faCalendarStartVisit => 'సందర్శన మొదలు';

  @override
  String get faCalendarStatusDone => 'పూర్తయింది';

  @override
  String get faCalendarStatusFirstVisit => 'కొత్త · మొదటి సందర్శన';

  @override
  String get faCalendarStatusOverdue => 'ఆలస్యం';

  @override
  String get faCalendarStatusPlanned => 'ప్లాన్ చేశారు';

  @override
  String get faCalendarThisWeek => 'ఈ వారం';

  @override
  String get faCalendarTitle => 'సందర్శనల క్యాలెండర్';

  @override
  String faCalendarVisitCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count సందర్శనలు',
      one: '1 సందర్శన',
      zero: 'సందర్శనలు లేవు',
    );
    return '$_temp0';
  }

  @override
  String faCalendarVisitOptions({required String name}) {
    return '$name · మరిన్ని';
  }

  @override
  String faCalendarWeekOf({required String date}) {
    return '$date వారం';
  }

  @override
  String get faChangePinAgain => 'కొత్త PIN మళ్ళీ టైప్ చేయండి';

  @override
  String get faChangePinChanged => 'PIN మారింది';

  @override
  String get faChangePinNew => 'కొత్త PIN ఎంచుకోండి';

  @override
  String get faChangePinOld => 'మీ ప్రస్తుత PIN ఎంటర్ చేయండి';

  @override
  String get faChangePinWrongOld => 'ప్రస్తుత PIN తప్పు';

  @override
  String faCommonArea({required int acres, required int guntas}) {
    return '$acres ఎ. $guntas గుం.';
  }

  @override
  String faCommonCallFailed({required String phone}) {
    return 'డయలర్ తెరవలేకపోయాం. $phone కి కాల్ చేయండి.';
  }

  @override
  String get faCommonDirectionsFailed => 'మ్యాప్స్ తెరవలేకపోయాం.';

  @override
  String faCommonDistanceKm({required String distance}) {
    return '$distance కి.మీ.';
  }

  @override
  String faCommonDistanceM({required int distance}) {
    return '$distance మీ.';
  }

  @override
  String get faCommonErrorTitle => 'ఏదో తప్పు జరిగింది';

  @override
  String get faCommonLogOut => 'లాగ్ అవుట్';

  @override
  String get faCommonNotSynced => 'ఇంకా సింక్ కాలేదు';

  @override
  String get faCommonOfflineBody =>
      'నెట్‌వర్క్ వచ్చాక మళ్ళీ ప్రయత్నించండి. మీ రైతుల వివరాలు ఈ ఫోన్‌లో ఉన్నాయి.';

  @override
  String get faCommonOfflineTitle => 'ఇంటర్నెట్ లేదు';

  @override
  String faCommonTime({required DateTime time}) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$timeString';
  }

  @override
  String get faCommonWhatsappFailed => 'వాట్సాప్ తెరవలేకపోయాం. ఫోన్‌లో ఉందా?';

  @override
  String get faConsentAgreed =>
      'రైతు ఒప్పుకున్నారు. రైతు తర్వాత ఒప్పుకుంటేనే ఇతర కంపెనీలకు వివరాలు వెళ్తాయి.';

  @override
  String get faConsentConfirm => 'నిర్ధారించండి';

  @override
  String get faConsentHow =>
      'రైతు ఫోన్‌కి OTP వస్తుంది. రైతు తమ భాషలో అనుమతి విని, OTP మీకు చదివి చెబుతారు.';

  @override
  String get faConsentNeedsPhone => 'ముందు రైతు మొబైల్ నంబర్ ఇవ్వండి.';

  @override
  String get faConsentNotice =>
      'మీ పంటకు సలహాలు ఇవ్వడానికి, మీ FA మీ పొలానికి రావడానికి మీ వివరాలు వాడుతాం. మీ వివరాలు షణ్ముఖ వద్ద భద్రంగా ఉంటాయి. మీరు ఒప్పుకుంటేనే ఇతర కంపెనీలకు పంపుతాం. ఒప్పుకుంటే, మీకు వచ్చిన OTP ని మీ FA కి చెప్పండి.';

  @override
  String get faConsentOfflineBody =>
      'అది లేకుంటే అనుమతి పెండింగ్‌లో ఉంటుంది. నెట్‌వర్క్ వచ్చాక రైతు పేజీ నుండి నమోదు చేయండి.';

  @override
  String get faConsentOfflineTitle => 'అనుమతికి ఇంటర్నెట్ కావాలి';

  @override
  String get faConsentOtpLabel => 'రైతు చెప్పే OTP';

  @override
  String get faConsentPlay => 'అనుమతి వినిపించండి';

  @override
  String get faConsentPlayed => 'వినిపించాం';

  @override
  String faConsentRecorded({required String time}) {
    return 'అనుమతి నమోదైంది · $time';
  }

  @override
  String faConsentRecordedPlayed({
    required String language,
    required String time,
  }) {
    return 'అనుమతి నమోదైంది · $time · $language ఆడియో వినిపించాం';
  }

  @override
  String get faConsentResend => 'OTP మళ్ళీ పంపండి';

  @override
  String faConsentResendIn({required int seconds}) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds సెకన్లలో మళ్ళీ పంపవచ్చు',
      one: '1 సెకనులో మళ్ళీ పంపవచ్చు',
    );
    return '$_temp0';
  }

  @override
  String get faConsentSave => 'అనుమతి సేవ్ చేయండి';

  @override
  String get faConsentSaved =>
      'అనుమతి ఈ ఫోన్‌లో సేవ్ అయింది · ఆన్‌లైన్ అయ్యాక సింక్ అవుతుంది';

  @override
  String get faConsentSendOtp => 'అనుమతి OTP పంపండి';

  @override
  String faConsentSent({required String phone}) {
    return '$phone కి రైతు భాషలో అనుమతి సందేశంతో OTP పంపాం.';
  }

  @override
  String faConsentSheetTitle({required String name}) {
    return 'అనుమతి నమోదు · $name';
  }

  @override
  String get faConsentTitle => 'రైతు అనుమతి';

  @override
  String get faEnrolBackToFarmers => 'రైతుల జాబితాకు వెనక్కి';

  @override
  String get faEnrolCallHo => 'HO కి కాల్ చేయండి';

  @override
  String get faEnrolCheckedAtSync =>
      'కొనసాగించవచ్చు: సింక్ అప్పుడు నంబర్ మళ్ళీ చూస్తాం.';

  @override
  String get faEnrolChecking => 'నంబర్ చూస్తున్నాం…';

  @override
  String get faEnrolContinueClaim => 'కొనసాగించండి · నాకు కేటాయించండి';

  @override
  String get faEnrolDeactivatedBody =>
      'HO ఈ రైతును నిలిపివేసింది, కాబట్టి మళ్ళీ నమోదు చేయలేరు.';

  @override
  String get faEnrolDeactivatedTitle => 'రైతు ఖాతా నిలిపివేయబడింది';

  @override
  String get faEnrolErrorAlreadyEnrolled => 'ఈ రైతు ఇప్పటికే మీ దగ్గర ఉన్నారు.';

  @override
  String get faEnrolErrorInvalidPhone => 'ఇది సరైన మొబైల్ నంబర్ కాదు.';

  @override
  String get faEnrolErrorInvalidSeasonCode =>
      'ఈ సీజన్ ముగిసింది. వేరేది ఎంచుకోండి.';

  @override
  String get faEnrolErrorLocationRequired =>
      'ముందు పొలం గట్టు నడవండి లేదా పిన్ పెట్టండి.';

  @override
  String get faEnrolErrorNoData =>
      'మీ రైతుల వివరాలు ఇంకా ఈ ఫోన్‌లో లేవు. ఒకసారి ఇంటర్నెట్‌తో సింక్ చేసి, తర్వాత నమోదు చేయండి.';

  @override
  String get faEnrolErrorOutOfRange => 'ఈ సంఖ్య సరిగ్గా లేదు. సరిచూడండి.';

  @override
  String get faEnrolErrorProofInvalid =>
      'అనుమతి OTP గడువు ముగిసింది. కొత్త OTP పంపండి.';

  @override
  String get faEnrolErrorRequired => 'అన్ని వివరాలు నింపండి.';

  @override
  String get faEnrolErrorTooLong => 'ఇది చాలా పొడవుగా ఉంది.';

  @override
  String get faEnrolFinishEnrolment => 'నమోదు పూర్తి చేయండి';

  @override
  String get faEnrolLanguageLabel => 'రైతు భాష';

  @override
  String get faEnrolLeaveBody => 'ఇక్కడ నింపినవి సేవ్ కావు.';

  @override
  String get faEnrolLeaveConfirm => 'వదిలేయండి';

  @override
  String get faEnrolLeaveStay => 'ఉండండి';

  @override
  String get faEnrolLeaveTitle => 'నమోదు వదిలేయాలా?';

  @override
  String get faEnrolLookupFailedTitle => 'నంబర్ చూడలేకపోయాం';

  @override
  String faEnrolMineBody({required String name}) {
    return '$name ఇప్పటికే మీ రైతుల్లో ఉన్నారు.';
  }

  @override
  String get faEnrolMineBodyUnknown => 'ఈ నంబర్ ఇప్పటికే మీ రైతుల్లో ఉంది.';

  @override
  String get faEnrolMineTitle => 'ఇప్పటికే మీ రైతు';

  @override
  String get faEnrolNameLabel => 'రైతు పేరు';

  @override
  String get faEnrolNameRequired => 'రైతు పేరు ఇవ్వండి.';

  @override
  String get faEnrolNameTeLabel => 'తెలుగులో పేరు (ఐచ్ఛికం)';

  @override
  String get faEnrolNoConsentBody =>
      'రైతు పేజీ నుండి నమోదు చేసే వరకు అనుమతి పెండింగ్‌లో ఉంటుంది.';

  @override
  String get faEnrolNoConsentConfirm => 'అనుమతి లేకుండా నమోదు';

  @override
  String get faEnrolNoConsentTitle => 'అనుమతి లేకుండా నమోదు చేయాలా?';

  @override
  String get faEnrolOfflineBody =>
      'ఇప్పుడే నమోదు చేయండి: సింక్ అప్పుడు నంబర్ మళ్ళీ చూస్తాం. అనుమతి, ఫోటో తర్వాత రైతు పేజీ నుండి చేర్చవచ్చు.';

  @override
  String get faEnrolOfflineHint =>
      'ఆఫ్‌లైన్‌లో ఉన్నారా? సింక్ అప్పుడు నంబర్ మళ్ళీ చూస్తాం.';

  @override
  String get faEnrolOfflineTitle => 'ఇంటర్నెట్ లేదు';

  @override
  String get faEnrolOpenFarmer => 'రైతును తెరవండి';

  @override
  String get faEnrolOtherFaBody =>
      'ఈ రైతు వేరే FA దగ్గర ఉన్నారు. రైతును HO మాత్రమే మార్చగలదు. HO కి కాల్ చేయండి.';

  @override
  String get faEnrolOtherFaTitle => 'వేరే FA రైతు';

  @override
  String get faEnrolOtherNumber =>
      'వేరే రైతును నమోదు చేయాలంటే, వేరే నంబర్ ఇవ్వండి.';

  @override
  String get faEnrolOutsideBody =>
      'ఈ రైతు మీ ప్రాంతం బయటి గ్రామంలో నమోదై ఉన్నారు. మార్చడానికి HO కి కాల్ చేయండి.';

  @override
  String get faEnrolOutsideTitle => 'గ్రామం మీ ప్రాంతంలో లేదు';

  @override
  String get faEnrolPendingBody =>
      'ఈ రైతు స్వయంగా చేరారు. వివరాలు, అనుమతి ఇక్కడ పూర్తి చేయండి.';

  @override
  String get faEnrolPendingTitle => 'రైతు యాప్‌లో చేరారు';

  @override
  String get faEnrolPhoneInvalid => 'రైతు 10 అంకెల మొబైల్ నంబర్ ఇవ్వండి.';

  @override
  String get faEnrolPhoneLabel => 'రైతు మొబైల్ నంబర్';

  @override
  String get faEnrolPhoto => 'రైతు ఫోటో';

  @override
  String get faEnrolPhotoAdded => 'ఫోటో చేరింది';

  @override
  String get faEnrolPhotoFailed =>
      'ఫోటో వెళ్ళలేదు. మళ్ళీ ప్రయత్నించండి, లేదా ఫోటో లేకుండా కొనసాగండి.';

  @override
  String get faEnrolPhotoNoCamera =>
      'కెమెరా తెరవలేకపోయాం. కెమెరా అనుమతి చూడండి.';

  @override
  String get faEnrolPhotoOffline =>
      'ఫోటోకి ఇంటర్నెట్ కావాలి. తర్వాత రైతు పేజీ నుండి చేర్చండి.';

  @override
  String get faEnrolPhotoRetake => 'మళ్ళీ తీయండి';

  @override
  String get faEnrolPhotoUploading => 'ఫోటో పంపుతున్నాం…';

  @override
  String get faEnrolRecordConsent => 'అనుమతి నమోదు చేయండి';

  @override
  String get faEnrolRegisteredBody =>
      'ఈ రైతు స్వయంగా చేరారు, ఇంకా FA లేరు. కొత్తది చేయకుండా, వారి రికార్డులోనే చేరుస్తాం.';

  @override
  String get faEnrolRegisteredTitle => 'ఇప్పటికే నమోదై ఉన్నారు';

  @override
  String get faEnrolStepCrop => 'పంట';

  @override
  String get faEnrolStepCurrent => 'ప్రస్తుత దశ';

  @override
  String get faEnrolStepDone => 'పూర్తైంది';

  @override
  String get faEnrolStepFarm => 'పొలం';

  @override
  String get faEnrolStepFarmer => 'రైతు';

  @override
  String get faEnrolStepsLabel => 'దశలు';

  @override
  String get faEnrolTitle => 'రైతు నమోదు';

  @override
  String faEnrolTitleName({required String name}) {
    return 'నమోదు · $name';
  }

  @override
  String get faEnrolUnknownBody => 'ఈ నంబర్ గురించి HO కి కాల్ చేసి అడగండి.';

  @override
  String get faEnrolUnknownTitle => 'ఈ నంబర్‌ను నమోదు చేయలేము';

  @override
  String get faEnrolCropBackToFarmers => 'రైతుల జాబితాకు';

  @override
  String get faEnrolCropConsentDone => 'ఇచ్చారు ✓';

  @override
  String get faEnrolCropConsentPending =>
      'పెండింగ్ · రైతు పేజీ నుండి నమోదు చేయండి';

  @override
  String faEnrolCropCropHeading({required String season}) {
    return 'ఈ సీజన్ పంట · $season';
  }

  @override
  String faEnrolCropEnrolled({required String name}) {
    return '$name నమోదు అయ్యారు';
  }

  @override
  String get faEnrolCropErrorCrop => 'పంట ఎంచుకోండి.';

  @override
  String get faEnrolCropErrorSowing => 'విత్తిన తేదీ ఎంచుకోండి.';

  @override
  String get faEnrolCropFallow => 'ఖాళీ / తెలియదు';

  @override
  String get faEnrolCropFinish => 'నమోదు పూర్తి చేయండి';

  @override
  String get faEnrolCropNotSown => 'ఇంకా విత్తలేదు';

  @override
  String get faEnrolCropNotSownNote => 'విత్తిన తేదీ లేకుంటే పంట దశ తెలియదు.';

  @override
  String get faEnrolCropPlanVisit => 'మొదటి సందర్శన ప్లాన్ చేయండి';

  @override
  String get faEnrolCropPreviousLabel => 'ఈ పొలంలో ముందు పంట';

  @override
  String get faEnrolCropSavedOnPhone =>
      'ఈ ఫోన్‌లో సేవ్ అయింది. ఆన్‌లైన్ అయ్యాక HO కి వెళ్తుంది.';

  @override
  String get faEnrolCropSeasonHeading => 'సీజన్';

  @override
  String faEnrolCropSeasonLabel({
    required String season,
    required String year,
  }) {
    return '$season $year';
  }

  @override
  String faEnrolCropSmsNote({required String language, required String name}) {
    return 'సింక్ అయ్యాక $name కి $language లో స్వాగత SMS వెళ్తుంది.';
  }

  @override
  String faEnrolCropSowDay({required int day}) {
    return 'విత్తిన $dayవ రోజు';
  }

  @override
  String faEnrolCropSowDayStage({required int day, required String stage}) {
    return '$dayవ రోజు · $stage దశ';
  }

  @override
  String get faEnrolCropSowPick => 'తేదీ ఎంచుకోండి';

  @override
  String faEnrolCropSowToday({required String date}) {
    return 'ఈరోజు · $date';
  }

  @override
  String faEnrolCropSowYesterday({required String date}) {
    return 'నిన్న · $date';
  }

  @override
  String get faEnrolCropSowingLabel => 'విత్తిన తేదీ';

  @override
  String get faEnrolCropSummary => 'సారాంశం';

  @override
  String faEnrolCropSummaryAfter({required String crop}) {
    return '$crop తర్వాత';
  }

  @override
  String get faEnrolCropSummaryConsent => 'అనుమతి';

  @override
  String get faEnrolCropSummaryCrop => 'పంట';

  @override
  String get faEnrolCropSummaryFarmer => 'రైతు';

  @override
  String get faEnrolCropSummaryNoCrop => 'ఇంకా ఎంచుకోలేదు';

  @override
  String faEnrolCropSummarySown({required String date}) {
    return '$date న విత్తారు';
  }

  @override
  String get faEnrolCropThisSeason => 'ఈ సీజన్';

  @override
  String faEnrolPlotAcresDecimal({required String acres}) {
    return '($acres ఎ.)';
  }

  @override
  String get faEnrolPlotArea => 'విస్తీర్ణం';

  @override
  String get faEnrolPlotAreaNotYet => 'ఇంకా లేదు';

  @override
  String get faEnrolPlotChangeVillage => 'గ్రామం మార్చండి';

  @override
  String get faEnrolPlotClose => 'గట్టు పూర్తి చేయండి';

  @override
  String get faEnrolPlotClosed => 'గట్టు పూర్తైంది';

  @override
  String get faEnrolPlotErrorTyped => 'విస్తీర్ణం ఎకరాలు, గుంటల్లో ఇవ్వండి.';

  @override
  String get faEnrolPlotErrorWalk =>
      'గట్టు నడిచి పూర్తి చేయండి, లేదా విస్తీర్ణం టైప్ చేయండి.';

  @override
  String get faEnrolPlotGpsChecking => 'GPS చూస్తున్నాం…';

  @override
  String get faEnrolPlotGpsCheckingBody =>
      'ఫోన్‌ను పైకి పట్టుకుని కొన్ని సెకన్లు కదలకుండా ఉండండి.';

  @override
  String get faEnrolPlotGpsDenied => 'లొకేషన్ అనుమతి లేదు';

  @override
  String faEnrolPlotGpsGood({required int metres}) {
    return 'GPS ±$metres మీ. · బాగుంది';
  }

  @override
  String get faEnrolPlotGpsLowBody =>
      'గట్టు నడవడానికి ఇది సరిపోదు. చెట్లు, షెడ్లకు దూరంగా ఖాళీ చోటుకి వెళ్ళండి, లేదా విస్తీర్ణం టైప్ చేయండి.';

  @override
  String faEnrolPlotGpsLowTitle({required int metres}) {
    return 'GPS ±$metres మీ.';
  }

  @override
  String get faEnrolPlotGpsNoFix => 'ఇంకా GPS సిగ్నల్ రాలేదు';

  @override
  String get faEnrolPlotGpsOff => 'లొకేషన్ ఆఫ్‌లో ఉంది';

  @override
  String get faEnrolPlotGpsProblemBody =>
      'ఈ యాప్‌కి లొకేషన్ ఆన్ చేయండి, ఖాళీ చోటుకి వెళ్ళండి, లేదా విస్తీర్ణం టైప్ చేయండి.';

  @override
  String faEnrolPlotGpsRough({required int metres}) {
    return 'GPS ±$metres మీ. · సరిపోదు';
  }

  @override
  String get faEnrolPlotGuntasPerAcre => '40 గుంటలు = 1 ఎకరం';

  @override
  String get faEnrolPlotGuntasTooMany => 'గుంటలు 40 కంటే తక్కువ ఉండాలి.';

  @override
  String faEnrolPlotLabel({required int number}) {
    return 'పొలం $number';
  }

  @override
  String get faEnrolPlotMandal => 'మండలం';

  @override
  String faEnrolPlotMetresSoFar({required int metres}) {
    return 'ఇప్పటి వరకు $metres మీ.';
  }

  @override
  String get faEnrolPlotModeType => 'విస్తీర్ణం టైప్ చేయండి';

  @override
  String get faEnrolPlotModeWalk => 'గట్టు నడవండి';

  @override
  String get faEnrolPlotNeedCorners =>
      'గట్టు పూర్తి చేయడానికి కనీసం 3 మూలలు నడవండి.';

  @override
  String get faEnrolPlotPause => 'ఆపండి';

  @override
  String faEnrolPlotPaused({required int metres}) {
    return 'ఆపాం · $metres మీ.';
  }

  @override
  String get faEnrolPlotPickVillage => 'ఈ పొలం ఏ గ్రామంలో ఉంది?';

  @override
  String faEnrolPlotPinHere({required int metres}) {
    return 'మీరు ఉన్న చోట పిన్ · GPS ±$metres మీ.';
  }

  @override
  String get faEnrolPlotPinVillage => 'GPS లేదు: పిన్ గ్రామం మధ్యలో పెడతాం.';

  @override
  String get faEnrolPlotReady => 'ఒక మూలలో నిలబడి, \'మొదలు ఇక్కడ\' నొక్కండి';

  @override
  String faEnrolPlotRecording({required int metres}) {
    return 'రికార్డ్ అవుతోంది · $metres మీ.';
  }

  @override
  String get faEnrolPlotResume => 'కొనసాగించండి';

  @override
  String get faEnrolPlotRoughWhileWalking =>
      'ఇక్కడ GPS సరిగ్గా లేదు: మెరుగయ్యే వరకు మూలలు నమోదు కావు.';

  @override
  String get faEnrolPlotSaveNext => 'సేవ్ చేసి ముందుకు';

  @override
  String get faEnrolPlotSavedNote =>
      'ఈ ఫోన్‌లో సేవ్ అవుతుంది · ఆన్‌లైన్ అయ్యాక సింక్ అవుతుంది';

  @override
  String faEnrolPlotSketchClosed({required String area}) {
    return 'గట్టు పూర్తైంది, $area';
  }

  @override
  String get faEnrolPlotSketchPin => 'మీరు ఉన్న చోట పిన్';

  @override
  String faEnrolPlotSketchWalking({required int corners}) {
    String _temp0 = intl.Intl.pluralLogic(
      corners,
      locale: localeName,
      other: 'పొలం చిత్రం, $corners మూలలు నడిచారు',
      one: 'పొలం చిత్రం, 1 మూల నడిచారు',
      zero: 'పొలం చిత్రం, ఇంకా నడవలేదు',
    );
    return '$_temp0';
  }

  @override
  String get faEnrolPlotStart => 'మొదలు ఇక్కడ';

  @override
  String get faEnrolPlotTypedNote =>
      'GPS సరిగ్గా లేనప్పుడు ఇది వాడండి. గట్టు నడిచే వరకు పొలం పిన్‌గా మాత్రమే కనిపిస్తుంది.';

  @override
  String get faEnrolPlotUndo => 'చివరి మూల తీసేయండి';

  @override
  String get faEnrolPlotVillage => 'గ్రామం';

  @override
  String get faEnrolPlotVillageFromGps => 'గ్రామం · GPS నుండి';

  @override
  String get faEnrolPlotWalkAgain => 'మళ్ళీ నడవండి';

  @override
  String get faEnrolPlotWalking => 'నడుస్తున్నారు…';

  @override
  String get faFarmer360ActionFailed =>
      'ఈ ఫోన్‌లో సేవ్ కాలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String faFarmer360Advised({required String advice}) {
    return '$advice సూచించారు';
  }

  @override
  String faFarmer360CallbackAsked({required String when}) {
    return '$when అడిగారు';
  }

  @override
  String get faFarmer360CallbackClose => 'తిరిగి కాల్ పూర్తయింది';

  @override
  String get faFarmer360CallbackClosed => 'తిరిగి కాల్ మూసివేశాం.';

  @override
  String get faFarmer360ConflictKeepMine => 'నాది ఉంచండి';

  @override
  String get faFarmer360ConflictKeepTheirs => 'HOది ఉంచండి';

  @override
  String get faFarmer360ConflictMeta =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నప్పుడు HO ఈ ప్రొఫైల్ మార్చారు';

  @override
  String get faFarmer360ConflictMine => 'మీది';

  @override
  String get faFarmer360ConflictStatus => 'తేడా ఉంది';

  @override
  String get faFarmer360ConflictTheirs => 'HOది';

  @override
  String faFarmer360ConflictTitle({required String name}) {
    return 'ప్రొఫైల్ · $name';
  }

  @override
  String faFarmer360ConsentCount({required int count, required int total}) {
    return '$totalలో $countకి అంగీకారం';
  }

  @override
  String get faFarmer360ConsentPending => 'నమోదు కాలేదు';

  @override
  String get faFarmer360EditLanguage => 'రైతు భాష';

  @override
  String get faFarmer360EditName => 'పేరు (ఇంగ్లీష్)';

  @override
  String get faFarmer360EditNameTe => 'తెలుగులో పేరు';

  @override
  String get faFarmer360EditNothingChanged => 'ఏమీ మారలేదు.';

  @override
  String get faFarmer360EditProfile => 'ప్రొఫైల్ మార్చండి';

  @override
  String get faFarmer360EditRequired => 'పేరు రాయండి';

  @override
  String get faFarmer360EditSaved =>
      'సేవ్ అయింది. తదుపరి సింక్‌లో HOకి వెళ్తుంది.';

  @override
  String get faFarmer360EditTooLong => '100 అక్షరాల లోపు రాయండి';

  @override
  String get faFarmer360NextVisitNone => 'ఏదీ ప్లాన్ చేయలేదు';

  @override
  String get faFarmer360NoIssues => 'సమస్యలు కనిపించలేదు';

  @override
  String get faFarmer360NoPlot => 'ఇంకా పొలం లేదు';

  @override
  String get faFarmer360NoVisit => 'ఇంకా సందర్శన లేదు';

  @override
  String get faFarmer360PlanVisit => 'సందర్శన ప్లాన్ చేయండి';

  @override
  String faFarmer360PlotDay({required int day}) {
    return '$dayవ రోజు';
  }

  @override
  String get faFarmer360PlotNoCrop => 'పంట ఇంకా మొదలుపెట్టలేదు';

  @override
  String faFarmer360PlotStageDay({required int day, required String stage}) {
    return '$stage · $dayవ రోజు';
  }

  @override
  String get faFarmer360RecordConsent => 'అంగీకారం నమోదు చేయండి';

  @override
  String get faFarmer360RowCallback => 'తిరిగి కాల్';

  @override
  String get faFarmer360RowConsent => 'అంగీకారం';

  @override
  String get faFarmer360RowLastVisit => 'చివరి సందర్శన';

  @override
  String get faFarmer360RowNextVisit => 'తదుపరి సందర్శన';

  @override
  String get faFarmer360RowPlan => 'ప్లాన్';

  @override
  String get faFarmer360RowPlot => 'పొలం';

  @override
  String get faFarmer360StartVisit => 'సందర్శన మొదలు';

  @override
  String get faFarmer360SummaryLabel => 'రైతు సారాంశం';

  @override
  String get faFarmersActionDirections => 'దారి';

  @override
  String get faFarmersActionFinishEnrolment => 'నమోదు పూర్తి చేయండి';

  @override
  String get faFarmersActionOpenFarmer => 'రైతును తెరవండి';

  @override
  String faFarmersCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రైతులు',
      one: '1 రైతు',
    );
    return '$_temp0';
  }

  @override
  String get faFarmersEmptyAction => 'రైతును నమోదు చేయండి';

  @override
  String get faFarmersEmptyBody =>
      'మీరు నమోదు చేసిన రైతులు ఇక్కడ కనిపిస్తారు, దగ్గర వారు ముందు.';

  @override
  String get faFarmersEmptyTitle => 'ఇంకా రైతులు లేరు';

  @override
  String get faFarmersFilter30Days => '30+ రోజులు';

  @override
  String get faFarmersFilterAll => 'అందరూ';

  @override
  String get faFarmersFilterFinishEnrolment => 'నమోదు పూర్తి కావాలి';

  @override
  String get faFarmersFilterLabel => 'రైతులను వడపోయండి';

  @override
  String get faFarmersFilterNew => 'కొత్త';

  @override
  String get faFarmersFilterVisitDue => 'సందర్శన బాకీ';

  @override
  String get faFarmersMapAttribution => '© OpenStreetMap contributors';

  @override
  String get faFarmersMapLegendOthers => 'ఇతరులు';

  @override
  String get faFarmersMapOffline => 'ప్రస్తుతానికి మ్యాప్‌కు ఇంటర్నెట్ కావాలి';

  @override
  String get faFarmersMapSelected => 'ఎంచుకున్న రైతు';

  @override
  String get faFarmersMapYou => 'మీ స్థానం';

  @override
  String faFarmersMetaDaysSinceVisit({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'సందర్శన జరిగి $count రోజులు',
      one: 'సందర్శన జరిగి 1 రోజు',
    );
    return '$_temp0';
  }

  @override
  String faFarmersMetaJoinedOn({required String date}) {
    return '$dateన చేరారు';
  }

  @override
  String get faFarmersMetaJoinedToday => 'ఈరోజు చేరారు';

  @override
  String get faFarmersMetaJoinedYesterday => 'నిన్న చేరారు';

  @override
  String faFarmersMetaLastVisitDays({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'చివరి సందర్శన $count రోజుల క్రితం',
      one: 'చివరి సందర్శన 1 రోజు క్రితం',
    );
    return '$_temp0';
  }

  @override
  String faFarmersMetaNeverVisited({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రోజులుగా సందర్శన లేదు',
      one: '1 రోజులో సందర్శన లేదు',
    );
    return '$_temp0';
  }

  @override
  String get faFarmersMetaNoCrop => 'ఇంకా పంట లేదు';

  @override
  String faFarmersMetaVisitDueOn({required String day}) {
    return '$day సందర్శన';
  }

  @override
  String get faFarmersMetaVisitDueToday => 'ఈరోజు సందర్శన';

  @override
  String get faFarmersMetaVisitOverdue => 'సందర్శన ఆలస్యం';

  @override
  String get faFarmersMetaVisitedToday => 'ఈరోజు సందర్శించారు';

  @override
  String get faFarmersMetaVisitedYesterday => 'చివరి సందర్శన నిన్న';

  @override
  String get faFarmersNearestFirst => 'దగ్గర వారు ముందు';

  @override
  String get faFarmersNoDataAction => 'సింక్ తెరవండి';

  @override
  String get faFarmersNoDataBody =>
      'మొదటి సింక్‌లో అవి వస్తాయి. ఇంటర్నెట్ కలిపి సింక్ చేయండి.';

  @override
  String get faFarmersNoDataTitle => 'రైతుల వివరాలు ఇంకా ఈ ఫోన్‌లో లేవు';

  @override
  String get faFarmersNoMatchFilter => 'ఈ వడపోతలో ఇప్పుడు రైతులు లేరు.';

  @override
  String faFarmersNoMatchSearch({required String query}) {
    return '\"$query\"కి రైతు లేరు. పేరు లేదా నంబర్ చూడండి.';
  }

  @override
  String get faFarmersNoMatchTitle => 'సరిపోయే రైతులు లేరు';

  @override
  String get faFarmersSearchClear => 'వెతికినది తుడిచివేయండి';

  @override
  String get faFarmersSearchClose => 'వెతకడం ఆపండి';

  @override
  String get faFarmersSearchHint => 'పేరు లేదా ఫోన్ నంబర్';

  @override
  String get faFarmersSearchOpen => 'పేరు లేదా ఫోన్‌తో వెతకండి';

  @override
  String get faFarmersShowAll => 'అందరు రైతులను చూపండి';

  @override
  String faFarmersShown({required int count}) {
    return '$count చూపిస్తున్నాం';
  }

  @override
  String get faFarmersTagNew => 'కొత్త';

  @override
  String get faFarmersTagNewToday => 'ఈరోజు కొత్త';

  @override
  String get faFarmersTitle => 'నా దగ్గర రైతులు';

  @override
  String get faFarmersViewList => 'జాబితా';

  @override
  String get faFarmersViewMap => 'మ్యాప్';

  @override
  String get faLoginEndedBody =>
      'మీ రికార్డులు ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి. పాస్‌వర్డ్‌తో లాగిన్ అయ్యాక అవి పంపబడతాయి.';

  @override
  String get faLoginEndedTitle => 'సింక్ కోసం మళ్ళీ లాగిన్ అవ్వండి';

  @override
  String get faLoginErrorOfflineAgain =>
      'ఇంటర్నెట్ లేదు. నెట్‌వర్క్ వచ్చాక మీ పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి. మీ రికార్డులు ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి.';

  @override
  String get faLoginErrorOfflineFirst =>
      'లాగిన్ అవ్వడానికి నెట్‌వర్క్ కావాలి. మొబైల్ డేటా లేదా Wi-Fi ఆన్ చేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get faLoginErrorWrong =>
      'లాగిన్ ID లేదా పాస్‌వర్డ్ తప్పు. సరిచూసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String faLoginExpiredBody({required int days}) {
    return 'మీ PIN ఆఫ్‌లైన్‌లో $days రోజులు పనిచేస్తుంది. నెట్‌వర్క్ వచ్చాక మీ పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి.';
  }

  @override
  String get faLoginExpiredTitle => 'సెషన్ ముగిసింది';

  @override
  String faLoginFooterHo({required String phone}) {
    return 'HO $phone';
  }

  @override
  String faLoginFooterSynced({required String day, required String time}) {
    return 'చివరి సింక్ $day $time';
  }

  @override
  String faLoginFooterVersion({required String version}) {
    return 'వెర్షన్ $version';
  }

  @override
  String get faLoginForgot => 'పాస్‌వర్డ్ మర్చిపోయారా? HO కి కాల్ చేయండి';

  @override
  String get faLoginHoNote =>
      'మీ లాగిన్‌ను హెడ్ ఆఫీస్ ఇస్తుంది, అది మీకు మాత్రమే. మీరు బదిలీ అయినా వెళ్ళిపోయినా, HO మీ రైతులను కొత్త FA కి అప్పగిస్తుంది; లాగిన్‌లు ఎప్పుడూ పంచుకోరు.';

  @override
  String get faLoginLockedBody =>
      'మీ పాస్‌వర్డ్‌తో లాగిన్ అయ్యి కొత్త PIN పెట్టుకోండి. మీ రికార్డులు ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి.';

  @override
  String get faLoginLockedTitle => 'చాలా సార్లు తప్పు PIN';

  @override
  String get faLoginLogIn => 'లాగిన్ అవ్వండి';

  @override
  String get faLoginLoginId => 'లాగిన్ ID';

  @override
  String faLoginOtherFaBody({required String code, required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఈ ఫోన్‌లో $code యొక్క $count రికార్డులు ఇంకా సింక్ కాలేదు.',
      one: 'ఈ ఫోన్‌లో $code యొక్క 1 రికార్డు ఇంకా సింక్ కాలేదు.',
    );
    return '$_temp0 వేరే FA గా లాగిన్ అయితే అవి తొలగిపోతాయి.';
  }

  @override
  String get faLoginOtherFaConfirm => 'తొలగించి లాగిన్ అవ్వండి';

  @override
  String get faLoginOtherFaTitle => 'వేరే FA గా లాగిన్ అవ్వాలా?';

  @override
  String get faLoginPassword => 'పాస్‌వర్డ్';

  @override
  String faLoginPinNote({required int length}) {
    return 'తర్వాతి సారి ఆఫ్‌లైన్‌లో కూడా $length అంకెల PIN తో తెరవండి';
  }

  @override
  String get faLoginTempExpiredTitle => 'తాత్కాలిక పాస్‌వర్డ్ గడువు ముగిసింది';

  @override
  String get faLoginUsePin => 'బదులుగా PIN తో తెరవండి';

  @override
  String get faLoginWorksOffline => 'ఆఫ్‌లైన్‌లో పనిచేస్తుంది';

  @override
  String faMeArea({required String area}) {
    return 'ప్రాంతం: $area';
  }

  @override
  String get faMeCallHo => 'HO కి కాల్ చేయండి';

  @override
  String faMeCallHoSub({required String phone}) {
    return '$phone · ఉదయం 9 నుంచి సాయంత్రం 6';
  }

  @override
  String get faMeChangePassword => 'పాస్‌వర్డ్ మార్చండి';

  @override
  String get faMeChangePin => 'PIN మార్చండి';

  @override
  String faMeChangePinSub({required int days, required int left}) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'ఇంకా $left రోజులు',
      one: 'ఇంకా 1 రోజు',
    );
    return '$days రోజులు ఆఫ్‌లైన్‌లో పనిచేస్తుంది · $_temp0';
  }

  @override
  String faMeFooter({required String id, required String version}) {
    return 'వెర్షన్ $version · ఫోన్ ID $id';
  }

  @override
  String get faMeLanguage => 'యాప్ భాష';

  @override
  String get faMeLanguageSub => 'రైతుల పేర్లు, పంటలు కూడా ఇదే భాషలో';

  @override
  String get faMeLogInNow => 'ఇప్పుడే లాగిన్ అవ్వండి';

  @override
  String get faMeLogoutAnyway => 'అయినా లాగ్ అవుట్';

  @override
  String get faMeLogoutBody =>
      'మళ్ళీ లాగిన్ అవ్వడానికి మీ లాగిన్ ID, పాస్‌వర్డ్, నెట్‌వర్క్ కావాలి.';

  @override
  String get faMeLogoutTitle => 'లాగ్ అవుట్ అవ్వాలా?';

  @override
  String faMeLogoutUnsynced({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రికార్డులు ఇంకా సింక్ కాలేదు.',
      one: '1 రికార్డు ఇంకా సింక్ కాలేదు.',
    );
    return '$_temp0';
  }

  @override
  String get faMeLogoutUnsyncedBody =>
      'ముందు సింక్ చేయండి. ఇప్పుడు లాగ్ అవుట్ అయితే అవి ఈ ఫోన్‌లోనే ఉండి, మళ్ళీ లాగిన్ అయినప్పుడు పంపబడతాయి.';

  @override
  String get faMeNeedsPasswordBody =>
      'మీరు ఆఫ్‌లైన్‌లో పని కొనసాగించవచ్చు. లాగిన్ అయ్యాక రికార్డులు పంపబడతాయి.';

  @override
  String get faMeNeedsPasswordTitle =>
      'సింక్ కోసం పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి';

  @override
  String get faMePasswordSaved => 'పాస్‌వర్డ్ మారింది';

  @override
  String get faMeProfile => 'మీ ప్రొఫైల్';

  @override
  String faMeStatEnrolled({required String month}) {
    return '$month లో నమోదు';
  }

  @override
  String faMeStatFarmers({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'రైతులు',
      one: 'రైతు',
    );
    return '$_temp0';
  }

  @override
  String faMeStatVisits({required String month}) {
    return '$month లో సందర్శనలు';
  }

  @override
  String get faMeSubtitle => 'ప్రొఫైల్, సెట్టింగ్‌లు';

  @override
  String faMeSyncLast({required String day, required String time}) {
    return 'చివరి సింక్ $day $time';
  }

  @override
  String get faMeSyncNever => 'ఇంకా సింక్ కాలేదు';

  @override
  String get faMeSyncNow => 'ఇప్పుడే సింక్ చేయండి';

  @override
  String faMeSyncWaiting({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count వేచి ఉన్నాయి',
      one: '1 వేచి ఉంది',
    );
    return '$_temp0';
  }

  @override
  String get faMeThisMonth => 'ఈ నెల';

  @override
  String get faMeWifi => 'ఫోటోలు Wi-Fi లో మాత్రమే అప్‌లోడ్';

  @override
  String get faMeWifiOff => 'ఆఫ్ · ఫోటోలు మొబైల్ డేటాలో కూడా అప్‌లోడ్ అవుతాయి';

  @override
  String get faMeWifiOn => 'ఆన్ · రికార్డులు మొబైల్ డేటాలో కూడా సింక్ అవుతాయి';

  @override
  String get faNavAlerts => 'హెచ్చరికలు';

  @override
  String get faNavCalendar => 'క్యాలెండర్';

  @override
  String get faNavEnrol => 'నమోదు';

  @override
  String get faNavFarmers => 'రైతులు';

  @override
  String get faNewPasswordAgain => 'మళ్ళీ టైప్ చేయండి';

  @override
  String get faNewPasswordBackLabel => 'లాగిన్‌కు వెనక్కి';

  @override
  String get faNewPasswordCurrent => 'ప్రస్తుత పాస్‌వర్డ్';

  @override
  String get faNewPasswordCurrentTemp => 'తాత్కాలిక పాస్‌వర్డ్';

  @override
  String get faNewPasswordLeaveBody =>
      'మీరు లాగ్ అవుట్ అవుతారు. పూర్తి చేయడానికి తాత్కాలిక పాస్‌వర్డ్‌తో మళ్ళీ లాగిన్ అవ్వండి.';

  @override
  String get faNewPasswordLeaveTitle => 'కొత్త పాస్‌వర్డ్ లేకుండా వెళ్ళాలా?';

  @override
  String get faNewPasswordNeedsNetwork => 'నెట్‌వర్క్ కావాలి';

  @override
  String get faNewPasswordNeedsNetworkFirst =>
      'నెట్‌వర్క్ కావాలి · ఇది పూర్తయ్యే వరకు యాప్ వాడలేరు';

  @override
  String get faNewPasswordNew => 'కొత్త పాస్‌వర్డ్';

  @override
  String get faNewPasswordNote =>
      'HO మీకు తాత్కాలిక పాస్‌వర్డ్ ఇచ్చింది. అది 72 గంటలు మాత్రమే పనిచేస్తుంది; మీకు మాత్రమే తెలిసేలా ఇప్పుడే మీ సొంతది పెట్టుకోండి.';

  @override
  String get faNewPasswordOffline =>
      'పాస్‌వర్డ్ సేవ్ చేయడానికి నెట్‌వర్క్ కావాలి. కనెక్ట్ అయి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get faNewPasswordRuleCurrent => 'పాత పాస్‌వర్డ్ కాకూడదు';

  @override
  String get faNewPasswordRuleDone => 'పూర్తయింది';

  @override
  String get faNewPasswordRuleLength => 'కనీసం 8 అక్షరాలు';

  @override
  String get faNewPasswordRuleLetterDigit => 'ఒక అక్షరం, ఒక అంకె ఉండాలి';

  @override
  String get faNewPasswordRuleLoginId => 'మీ లాగిన్ ID కాకూడదు';

  @override
  String get faNewPasswordRuleMatch => 'రెండు బాక్సుల్లో ఒకటే ఉండాలి';

  @override
  String get faNewPasswordRuleNotYet => 'ఇంకా లేదు';

  @override
  String get faNewPasswordRules => 'పాస్‌వర్డ్ నియమాలు';

  @override
  String get faNewPasswordSave => 'పాస్‌వర్డ్ సేవ్ చేయండి';

  @override
  String faNewPasswordSavedBody({required String code}) {
    return 'నెట్‌వర్క్‌లో లాగిన్ అయ్యేటప్పుడు $code తో దీన్ని వాడండి. రోజూ మీ PIN తో యాప్ తెరవండి.';
  }

  @override
  String get faNewPasswordSavedTitle => 'పాస్‌వర్డ్ సేవ్ అయింది';

  @override
  String get faNewPasswordStep => 'దశ 1/2 · మొదటి లాగిన్';

  @override
  String get faNewPasswordTitle => 'మీ సొంత పాస్‌వర్డ్ పెట్టుకోండి';

  @override
  String get faNewPasswordWrongCurrent => 'ప్రస్తుత పాస్‌వర్డ్ తప్పు.';

  @override
  String get faNewPasswordWrongTemp =>
      'తాత్కాలిక పాస్‌వర్డ్ తప్పు. HO ఇచ్చిన పాస్‌వర్డ్ టైప్ చేయండి.';

  @override
  String get faPlanVisitChangeFarmer => 'రైతును మార్చండి';

  @override
  String get faPlanVisitDay => 'రోజు';

  @override
  String get faPlanVisitMove => 'సందర్శన మార్చండి';

  @override
  String faPlanVisitMovingFrom({required String date}) {
    return 'ఇప్పుడు $date కి ప్లాన్ అయింది';
  }

  @override
  String get faPlanVisitNearestFirst => 'దగ్గర వారు ముందు';

  @override
  String get faPlanVisitNoCrop => 'ఇంకా పంట నమోదు కాలేదు';

  @override
  String faPlanVisitNoCropBody({required String name}) {
    return 'ముందు $name పంట నమోదు చేసి, తర్వాత సందర్శన ప్లాన్ చేయండి.';
  }

  @override
  String get faPlanVisitNoCropTitle => 'సందర్శనకు ఇంకా పంట లేదు';

  @override
  String get faPlanVisitNoMatch => 'ఈ వెతుకులాటకు రైతు దొరకలేదు';

  @override
  String get faPlanVisitOtherDate => 'వేరే తేదీ';

  @override
  String get faPlanVisitPickFarmer => 'ఏ రైతు దగ్గరకు వెళ్తున్నారు?';

  @override
  String get faPlanVisitPlot => 'పొలం';

  @override
  String get faPlanVisitPurpose => 'ఎందుకు వెళ్తున్నారు';

  @override
  String get faPlanVisitPurposeAdviceFollowUp => 'సలహా తర్వాత పరిశీలన';

  @override
  String get faPlanVisitPurposeFirstVisit => 'మొదటి సందర్శన';

  @override
  String get faPlanVisitPurposeHint => 'ఎందుకో కొన్ని మాటల్లో';

  @override
  String get faPlanVisitPurposeOther => 'ఇతర';

  @override
  String get faPlanVisitPurposePestFollowUp => 'పురుగు పరిశీలన';

  @override
  String get faPlanVisitPurposeRequired => 'ఎందుకు వెళ్తున్నారో రాయండి';

  @override
  String get faPlanVisitPurposeSoilSample => 'మట్టి నమూనా';

  @override
  String get faPlanVisitPurposeStageCheck => 'పంట దశ చూడటం';

  @override
  String get faPlanVisitRescheduleTitle => 'సందర్శన రోజు మార్చండి';

  @override
  String get faPlanVisitSave => 'సందర్శన సేవ్ చేయండి';

  @override
  String get faPlanVisitSavedOffline =>
      'ఈ ఫోన్‌లో సేవ్ అయింది · తర్వాతి సింక్‌లో HO కి వెళ్తుంది';

  @override
  String get faPlanVisitSearchHint => 'పేరు లేదా ఫోన్ నంబర్‌తో వెతకండి';

  @override
  String get faPlanVisitSlot => 'సమయం';

  @override
  String faSetupDoneTitle({required String name}) {
    return '$name, మీరు సిద్ధం';
  }

  @override
  String get faSetupDownloadFailed =>
      'మీ రైతుల వివరాలు ఇంకా డౌన్‌లోడ్ కాలేదు. నెట్‌వర్క్ రాగానే డౌన్‌లోడ్ అవుతాయి.';

  @override
  String get faSetupDownloadLists =>
      'పంట, సలహా జాబితాలు · ఇకపై ఆఫ్‌లైన్‌లో పనిచేస్తుంది';

  @override
  String get faSetupDownloadProgress => 'డౌన్‌లోడ్ పురోగతి';

  @override
  String get faSetupDownloadTitle => 'మీ ప్రాంతం ఈ ఫోన్‌లో సేవ్ అవుతోంది';

  @override
  String get faSetupDownloading => 'డౌన్‌లోడ్ అవుతోంది…';

  @override
  String get faSetupLanguageNote =>
      'రైతుల పేర్లు, పంటలు, సలహాలు మీరు ఎంచుకున్న భాషలో కనిపిస్తాయి. దీన్ని తర్వాత \"నేను\" లో మార్చుకోవచ్చు.';

  @override
  String get faSetupOpenFarmers => 'నా రైతులను తెరవండి';

  @override
  String faSetupPasswordSaved({required String code}) {
    return 'పాస్‌వర్డ్ సేవ్ అయింది. నెట్‌వర్క్‌లో లాగిన్ అయ్యేటప్పుడు $code తో దీన్ని వాడండి.';
  }

  @override
  String get faSetupPinAgain => 'అదే PIN మళ్ళీ టైప్ చేయండి';

  @override
  String get faSetupPinBackLabel => 'భాషకు వెనక్కి';

  @override
  String get faSetupPinHintAgain => 'నిర్ధారణ కోసం ఇంకోసారి';

  @override
  String faSetupPinHintFirst({required int days}) {
    return 'ఒకసారికి $days రోజులు ఆఫ్‌లైన్‌లో పనిచేస్తుంది';
  }

  @override
  String get faSetupPinMismatch => 'PIN లు సరిపోలలేదు. మళ్ళీ మొదలుపెట్టండి.';

  @override
  String faSetupPinNote({required int tries}) {
    return 'మీ PIN ఈ ఫోన్‌లోనే ఉంటుంది. 1234, 0000 లేదా మీ పుట్టిన సంవత్సరం వద్దు. $tries సార్లు తప్పు అయితే పాస్‌వర్డ్ కావాలి.';
  }

  @override
  String get faSetupPinPick => 'యాప్ తెరవడానికి PIN ఎంచుకోండి';

  @override
  String get faSetupPinWeak => 'సులభంగా ఊహించవచ్చు. వేరేది ఎంచుకోండి.';

  @override
  String get faSetupPinYear => 'ఇది సంవత్సరంలా ఉంది. వేరేది ఎంచుకోండి.';

  @override
  String get faSetupQuestion => 'యాప్ ఏ భాషలో ఉండాలి?';

  @override
  String get faSetupStepAgain => 'ఈ ఫోన్‌ను సిద్ధం చేయండి';

  @override
  String get faSetupStepFirst => 'దశ 2/2 · మొదటి లాగిన్';

  @override
  String get faSetupTeSub => 'తెలుగు · సిఫార్సు';

  @override
  String get faSetupTitleDone => 'అంతా సిద్ధం';

  @override
  String get faSetupTitleLanguage => 'యాప్ భాష';

  @override
  String faSetupTitlePin({required int length}) {
    return '$length అంకెల PIN పెట్టుకోండి';
  }

  @override
  String get faSetupToPin => 'ముందుకు · PIN పెట్టండి';

  @override
  String get faShellMe => 'నేను · ప్రొఫైల్, సెట్టింగ్‌లు';

  @override
  String get faShellSyncAllSynced => 'అన్ని రికార్డులు సింక్ అయ్యాయి';

  @override
  String faShellSyncNeedsYou({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రికార్డులకు మీ నిర్ణయం కావాలి',
      one: '1 రికార్డుకు మీ నిర్ణయం కావాలి',
    );
    return '$_temp0';
  }

  @override
  String get faShellSyncRunning => 'సింక్ అవుతోంది';

  @override
  String faShellSyncWaiting({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రికార్డులు సింక్ కోసం వేచి ఉన్నాయి',
      one: '1 రికార్డు సింక్ కోసం వేచి ఉంది',
    );
    return '$_temp0';
  }

  @override
  String get faShellTitleDev => 'డెవ్ మెనూ';

  @override
  String get faShellTitleFarmer => 'రైతు';

  @override
  String get faShellTitleMe => 'నేను';

  @override
  String get faShellTitlePlanVisit => 'సందర్శన ప్లాన్';

  @override
  String get faShellTitleRemoved => 'ఈ ఫోన్ తొలగించబడింది';

  @override
  String get faShellTitleSync => 'సింక్';

  @override
  String get faShellTitleVisitLog => 'సందర్శన లాగ్';

  @override
  String faSyncAllSyncedBody({required String time}) {
    return '$time వరకు అన్నీ HO దగ్గర ఉన్నాయి';
  }

  @override
  String get faSyncAllSyncedTitle => 'అన్నీ సింక్ అయ్యాయి';

  @override
  String get faSyncBusy =>
      'ఇంకో సింక్ జరుగుతోంది. కాసేపట్లో మళ్లీ ప్రయత్నించండి.';

  @override
  String get faSyncCallHo => 'HO కి కాల్';

  @override
  String get faSyncConflictMetaFarmer =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నప్పుడు HO ఈ రైతు వివరాలు మార్చింది';

  @override
  String get faSyncConflictMetaOther =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నప్పుడు HO దీన్ని మార్చింది';

  @override
  String faSyncConflictMetaPlot({required String plot}) {
    return 'మీరు ఆఫ్‌లైన్‌లో ఉన్నప్పుడు HO $plot ని మార్చింది';
  }

  @override
  String get faSyncConflictOnlyTheirs => 'దీనికి HO వెర్షన్ మాత్రమే ఉంచవచ్చు.';

  @override
  String get faSyncConflictWaiting =>
      'మీ తర్వాతి మార్పు ఈ ఎంపిక కోసం ఆగి ఉంది.';

  @override
  String get faSyncDismiss => 'తీసివేయి';

  @override
  String get faSyncDroppedHeading => 'దీని వల్ల ఇవి కూడా సేవ్ కాలేదు:';

  @override
  String get faSyncErrorTitle => 'సింక్ కాలేదు';

  @override
  String get faSyncFirstSyncBody =>
      'మీ రైతుల వివరాల కోసం ఇప్పుడే సింక్ నొక్కండి.';

  @override
  String get faSyncKeepMine => 'నాది ఉంచు';

  @override
  String get faSyncKeepTheirs => 'HO ది ఉంచు';

  @override
  String get faSyncLastSyncedJustNow => 'ఇప్పుడే సింక్ అయింది';

  @override
  String faSyncLastSyncedOn({required String date, required String time}) {
    return 'చివరి సింక్ $date, $time';
  }

  @override
  String faSyncLastSyncedToday({required String time}) {
    return 'చివరి సింక్ ఈరోజు $time';
  }

  @override
  String get faSyncMobileDataTitle => 'మొబైల్ డేటాలో ఉన్నారు';

  @override
  String get faSyncNeedsYouBody =>
      'వెర్షన్ ఎంచుకోండి లేదా ఎరుపు వరుసలను తీసివేయండి.';

  @override
  String faSyncNeedsYouTitle({required int count, required int synced}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$synced సింక్ అయ్యాయి · $count మీ కోసం',
      one: '$synced సింక్ అయ్యాయి · 1 మీ కోసం',
    );
    return '$_temp0';
  }

  @override
  String get faSyncNeverSynced => 'ఇంకా సింక్ కాలేదు';

  @override
  String faSyncOfflineBody({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count రికార్డ్‌లు ఈ ఫోన్‌లో ఉన్నాయి. నెట్‌వర్క్ వచ్చినప్పుడు వెళ్తాయి.',
      one: '1 రికార్డ్ ఈ ఫోన్‌లో ఉంది. నెట్‌వర్క్ వచ్చినప్పుడు వెళ్తుంది.',
      zero: 'మీ పని ఈ ఫోన్‌లో భద్రంగా ఉంది.',
    );
    return '$_temp0';
  }

  @override
  String get faSyncOfflineTitle => 'ఇంటర్నెట్ లేదు';

  @override
  String faSyncPhotosCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ఫోటోలు',
      one: '1 ఫోటో',
    );
    return '$_temp0';
  }

  @override
  String faSyncPhotosHeld({required String size}) {
    return '$size ఫోటోలు Wi-Fi కోసం వేచి ఉన్నాయి. రికార్డ్‌లు సింక్ అవుతాయి.';
  }

  @override
  String get faSyncPillConflict => 'తేడా ఉంది';

  @override
  String get faSyncPillNotSaved => 'సేవ్ కాలేదు';

  @override
  String get faSyncPillSynced => 'సింక్ అయింది';

  @override
  String get faSyncPillUploading => 'పంపుతోంది';

  @override
  String get faSyncPillWaiting => 'వేచి ఉంది';

  @override
  String get faSyncProgressLabel => 'అప్‌లోడ్ పురోగతి';

  @override
  String get faSyncReasonClient => 'యాప్ దీన్ని పంపలేకపోయింది. HO కి చెప్పండి.';

  @override
  String get faSyncReasonConsentExpired =>
      'అనుమతి కోడ్ గడువు ముగిసింది. రైతు పేజీలో మళ్లీ అనుమతి తీసుకోండి.';

  @override
  String get faSyncReasonNotInArea => 'గ్రామం మీ ప్రాంతంలో లేదు';

  @override
  String get faSyncReasonOther => 'HO దీన్ని తీసుకోలేదు';

  @override
  String get faSyncReasonOtherFa =>
      'ఈ రైతు వేరే FA దగ్గర ఉన్నారు. HO కి కాల్ చేయండి.';

  @override
  String get faSyncReasonParent =>
      'పంపలేదు: దీనికి కావాల్సిన రికార్డ్ సేవ్ కాలేదు';

  @override
  String get faSyncReasonServer => 'సేవ్ కాలేదు. HO కి తెలియజేశాం.';

  @override
  String faSyncResolvedMine({required String value}) {
    return 'మీది ఉంచారు · $value';
  }

  @override
  String get faSyncResolvedReady => 'సింక్‌కు సిద్ధం';

  @override
  String faSyncResolvedTheirs({required String value}) {
    return 'HO ది ఉంచారు · $value';
  }

  @override
  String faSyncRetryBody({required String time}) {
    return 'మళ్లీ $time కి ప్రయత్నిస్తాం. లేదా ఇప్పుడే సింక్ నొక్కండి.';
  }

  @override
  String get faSyncRetryTitle => 'సర్వర్ అందలేదు';

  @override
  String faSyncSizeKb({required String size}) {
    return '$size KB';
  }

  @override
  String faSyncSizeMb({required String size}) {
    return '$size MB';
  }

  @override
  String get faSyncSyncNow => 'ఇప్పుడే సింక్ చేయి';

  @override
  String faSyncSyncedToday({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఈరోజు $count రికార్డ్‌లు సింక్ అయ్యాయి',
      one: 'ఈరోజు 1 రికార్డ్ సింక్ అయింది',
      zero: 'ఈరోజు ఏ రికార్డ్ సింక్ కాలేదు',
    );
    return '$_temp0';
  }

  @override
  String get faSyncSyncingBody => 'రికార్డ్‌లు పంపుతోంది';

  @override
  String faSyncSyncingBodyPhotos({required String size}) {
    return 'రికార్డ్‌లు, $size ఫోటోలు పంపుతోంది';
  }

  @override
  String get faSyncSyncingTitle => 'సింక్ అవుతోంది…';

  @override
  String get faSyncTheirs => 'HO ది';

  @override
  String get faSyncTypeAlert => 'హెచ్చరిక చదివారు';

  @override
  String get faSyncTypeCallback => 'కాల్ బ్యాక్';

  @override
  String get faSyncTypeCancel => 'సందర్శన రద్దు';

  @override
  String get faSyncTypeConsent => 'అనుమతి';

  @override
  String get faSyncTypeEnrol => 'నమోదు';

  @override
  String get faSyncTypeFarmer => 'రైతు వివరాలు';

  @override
  String get faSyncTypePlan => 'సందర్శన ప్లాన్';

  @override
  String get faSyncTypePlot => 'పొలం';

  @override
  String get faSyncTypeSeason => 'పంట';

  @override
  String get faSyncTypeVisit => 'సందర్శన లాగ్';

  @override
  String get faSyncUnknownFarmer => 'రైతు';

  @override
  String get faSyncValueBoundaryWalked => 'సరిహద్దు నడిచారు';

  @override
  String get faSyncValueEmpty => 'ఖాళీ';

  @override
  String get faSyncValueNoBoundary => 'సరిహద్దు లేదు';

  @override
  String get faSyncValueNoPhoto => 'ఫోటో లేదు';

  @override
  String get faSyncValuePhoto => 'కొత్త ఫోటో';

  @override
  String faSyncValueVersion({required int version}) {
    return 'వెర్షన్ $version';
  }

  @override
  String faSyncWaitingRecords({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రికార్డ్‌లు వేచి ఉన్నాయి',
      one: '1 రికార్డ్ వేచి ఉంది',
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
      other: '$count రికార్డ్‌లు, $size ఫోటోలు వేచి ఉన్నాయి',
      one: '1 రికార్డ్, $size ఫోటోలు వేచి ఉన్నాయి',
      zero: '$size ఫోటోలు వేచి ఉన్నాయి',
    );
    return '$_temp0';
  }

  @override
  String get faSyncWaitingTitle => 'సింక్ కోసం వేచి ఉన్నాయి';

  @override
  String get faSyncWifiOff => 'ఆఫ్ · ఫోటోలు మొబైల్ డేటాలో కూడా వెళ్తాయి';

  @override
  String get faSyncWifiOn =>
      'ఆన్ · రికార్డ్‌లు మొబైల్ డేటాలో కూడా సింక్ అవుతాయి';

  @override
  String get faSyncWifiTitle => 'ఫోటోలు Wi-Fi లో మాత్రమే పంపు';

  @override
  String get faSyncYours => 'మీది';

  @override
  String faUnlockEnterPin({required int length}) {
    return 'మీ $length అంకెల PIN ఎంటర్ చేయండి';
  }

  @override
  String faUnlockGraceNote({required int days}) {
    return 'PIN ఆఫ్‌లైన్‌లో $days రోజులు పనిచేస్తుంది. ఆ తర్వాత నెట్‌వర్క్ వచ్చాక పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి.';
  }

  @override
  String faUnlockTriesLeft({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఇంకా $count ప్రయత్నాలు ఉన్నాయి',
      one: 'ఇంకా 1 ప్రయత్నం ఉంది',
    );
    return '$_temp0';
  }

  @override
  String get faUnlockUsePassword => 'బదులుగా పాస్‌వర్డ్ వాడండి';

  @override
  String faUnlockWelcome({required String name}) {
    return 'మళ్ళీ స్వాగతం, $name';
  }

  @override
  String get faUnlockWrongPin => 'తప్పు PIN';

  @override
  String get faVisitLogAddIssue => 'ఇంకో సమస్య జోడించండి';

  @override
  String get faVisitLogAdviceHo => 'HO చూసుకుంటుంది';

  @override
  String get faVisitLogAlreadyLogged => 'ఈ సందర్శన ఇప్పటికే లాగ్ చేశారు';

  @override
  String get faVisitLogBackToCalendar => 'క్యాలెండర్‌కి వెళ్ళండి';

  @override
  String get faVisitLogCameraFailed =>
      'కెమెరా తెరుచుకోలేదు. మళ్ళీ ప్రయత్నించండి.';

  @override
  String get faVisitLogCheckDetails =>
      'కొన్ని వివరాలు లేవు. ఎరుపు గుర్తులు చూడండి.';

  @override
  String faVisitLogDayAfterSowing({required int count}) {
    return '$countవ రోజు';
  }

  @override
  String get faVisitLogDiscard => 'వెళ్ళిపోండి';

  @override
  String get faVisitLogDiscardBody => 'ఈ సందర్శనకు మీరు ఇచ్చిన వివరాలు పోతాయి.';

  @override
  String get faVisitLogDiscardTitle => 'సేవ్ చేయకుండా వెళ్ళాలా?';

  @override
  String get faVisitLogEditVisit => 'ఈ సందర్శన మార్చండి';

  @override
  String get faVisitLogFarmerPresent => 'రైతు ఉన్నారు';

  @override
  String get faVisitLogFarmerPresentNote => 'మీరు ఒక్కరే పొలం చూస్తే ఆపేయండి';

  @override
  String get faVisitLogGpsFinding => 'GPS వెతుకుతోంది…';

  @override
  String faVisitLogGpsFix({required String lat, required String lng}) {
    return '$lat°N $lng°E';
  }

  @override
  String get faVisitLogGpsNone => 'GPS దొరకలేదు';

  @override
  String get faVisitLogGpsRetry => 'GPS మళ్ళీ ప్రయత్నించండి';

  @override
  String get faVisitLogIssue => 'సమస్య';

  @override
  String faVisitLogIssueFrom({required String crop}) {
    return '$crop జాబితా నుంచి';
  }

  @override
  String faVisitLogIssueLabel({required String issue}) {
    return 'సమస్య: $issue. మార్చండి';
  }

  @override
  String faVisitLogIssueRow({required String issue, required int number}) {
    return 'సమస్య $number · $issue';
  }

  @override
  String faVisitLogIssueSeverity({
    required String issue,
    required String severity,
  }) {
    return '$issue ($severity)';
  }

  @override
  String get faVisitLogIssueType => 'సమస్య రకం';

  @override
  String get faVisitLogLangEn => 'ఇంగ్లీష్';

  @override
  String get faVisitLogLangTe => 'తెలుగు';

  @override
  String faVisitLogMoreCount({required int count}) {
    return '+ ఇంకా $count';
  }

  @override
  String faVisitLogMorePhotos({required int count}) {
    return 'ఇంకా $count ఫోటోలు, అన్నీ చూడండి';
  }

  @override
  String get faVisitLogNextNone => 'ఇప్పుడు వద్దు';

  @override
  String get faVisitLogNextOther => 'వేరే తేదీ';

  @override
  String get faVisitLogNextVisit => 'తదుపరి సందర్శన';

  @override
  String get faVisitLogNextWeek => '+1 వారం';

  @override
  String faVisitLogNoCropBody({required String name}) {
    return 'ముందు $name పంట నమోదు చేసి, తర్వాత సందర్శన లాగ్ చేయండి.';
  }

  @override
  String get faVisitLogNoCropTitle => 'సందర్శన లాగ్ చేయడానికి పంట లేదు';

  @override
  String get faVisitLogNoIssue => 'సమస్య ఏమీ లేదు';

  @override
  String get faVisitLogNoIssueMatch => 'ఈ పేరుతో సమస్య లేదు';

  @override
  String get faVisitLogNoIssuesListed => 'ఈ పంటకు ఇంకా సమస్యల జాబితా లేదు.';

  @override
  String get faVisitLogNoPhotoBody =>
      'ఫోటో ఉంటే HO సలహాను సరిచూడగలరు. ఫోటో లేకుండా సేవ్ చేయాలా?';

  @override
  String get faVisitLogNoPhotoTitle => 'ఇంకా ఫోటోలు లేవు';

  @override
  String get faVisitLogNoProduct => 'షణ్ముఖ ఉత్పత్తి లేదు';

  @override
  String get faVisitLogNoProductNote =>
      'రైతుకు మందు పేరు మాత్రమే కనిపిస్తుంది, బ్రాండ్ కాదు';

  @override
  String get faVisitLogNoRule => 'ఈ సమస్యకు సలహా నియమం లేదు';

  @override
  String get faVisitLogNoRuleNote => 'HO రైతుతో మాట్లాడుతుంది.';

  @override
  String get faVisitLogNone => 'ఏమీ లేవు';

  @override
  String get faVisitLogNotPlanned => 'ప్లాన్ చేయలేదు';

  @override
  String faVisitLogOpenFarmer({required String name}) {
    return '$name వివరాలు చూడండి';
  }

  @override
  String faVisitLogPhoto({required int number}) {
    return 'ఫోటో $number';
  }

  @override
  String faVisitLogPhotoCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ఫోటోలు',
      one: '1 ఫోటో',
      zero: '1 నుంచి 3 తీయండి',
    );
    return '$_temp0';
  }

  @override
  String faVisitLogPhotoMax({required int max}) {
    return 'గరిష్టంగా $max ఫోటోలు';
  }

  @override
  String get faVisitLogPhotos => 'ఫోటోలు';

  @override
  String get faVisitLogPickIssue => 'సమస్య ఎంచుకోండి';

  @override
  String get faVisitLogPickIssueHint => 'పంట బాగుంటే వదిలేయండి';

  @override
  String get faVisitLogPickSalt => 'మందు ఎంచుకోండి';

  @override
  String get faVisitLogPlot => 'పొలం';

  @override
  String get faVisitLogPresentNo => 'రైతు లేరు';

  @override
  String get faVisitLogPresentYes => 'రైతు ఉన్నారు ✓';

  @override
  String faVisitLogProduct({required String name}) {
    return 'షణ్ముఖ ఉత్పత్తి: $name';
  }

  @override
  String get faVisitLogProductNote =>
      'దగ్గరి డీలర్లతో పాటు రైతుకు కనిపిస్తుంది';

  @override
  String faVisitLogRemoveIssue({required String issue}) {
    return '$issue సమస్య తీసేయండి';
  }

  @override
  String faVisitLogRemovePhoto({required int number}) {
    return 'ఫోటో $number తీసేయండి';
  }

  @override
  String get faVisitLogRowAdvice => 'సలహా';

  @override
  String get faVisitLogRowIssues => 'సమస్యలు';

  @override
  String get faVisitLogRowNext => 'తదుపరి సందర్శన';

  @override
  String get faVisitLogRowPhotos => 'ఫోటోలు';

  @override
  String get faVisitLogRowStage => 'దశ';

  @override
  String get faVisitLogSalt => 'మందు సూచన';

  @override
  String get faVisitLogSaltAfterIssue => 'ముందు సమస్య ఎంచుకోండి';

  @override
  String faVisitLogSaltLabel({required String salt}) {
    return 'మందు: $salt. మార్చండి';
  }

  @override
  String faVisitLogSaltOnly({required String salt}) {
    return '$salt · మందు పేరు మాత్రమే';
  }

  @override
  String get faVisitLogSave => 'సేవ్ చేసి రైతుకు చెప్పండి';

  @override
  String get faVisitLogSaveChanges => 'మార్పులు సేవ్ చేయండి';

  @override
  String get faVisitLogSaveWithoutPhotos => 'ఫోటో లేకుండా సేవ్';

  @override
  String get faVisitLogSavedPending =>
      'ఈ ఫోన్‌లో సేవ్ అయింది · తర్వాతి సింక్‌లో HO కి వెళ్తుంది';

  @override
  String get faVisitLogSavedSynced => 'సింక్ అయింది · HO కి చేరింది';

  @override
  String get faVisitLogSavedTitle => 'సందర్శన సేవ్ అయింది';

  @override
  String get faVisitLogSearchIssues => 'సమస్య వెతకండి';

  @override
  String get faVisitLogSeverity => 'ఎంత తీవ్రంగా ఉంది?';

  @override
  String get faVisitLogSeverityRequired => 'తీవ్రత ఎంచుకోండి';

  @override
  String get faVisitLogSmsNone =>
      'పంపడానికి ఇంకా సలహా లేదు. సమస్యల గురించి HO చూసుకుంటుంది.';

  @override
  String faVisitLogSmsPending({
    required String language,
    required String name,
  }) {
    return 'ఇది సింక్ అయ్యాక $name గారికి సలహా $languageలో SMS ద్వారా, ఆర్బిట్ యాప్‌లో వెళ్తుంది.';
  }

  @override
  String faVisitLogSmsSent({required String language, required String name}) {
    return '$name గారికి సలహా $languageలో SMS ద్వారా, ఆర్బిట్ యాప్‌లో వెళ్ళింది.';
  }

  @override
  String get faVisitLogStage => 'పంట దశ';

  @override
  String get faVisitLogStageRequired => 'పంట దశ ఎంచుకోండి';

  @override
  String get faVisitLogStay => 'ఇక్కడే ఉండండి';

  @override
  String faVisitLogStep({required int number, required String title}) {
    return '$number · $title';
  }

  @override
  String get faVisitLogSuggested => 'మాస్టర్ సూచించింది';

  @override
  String get faVisitLogSummary => 'సేవ్ చేసిన వివరాలు';

  @override
  String get faVisitLogTakePhoto => 'ఫోటో తీయండి';

  @override
  String get faVisitLogTypeDeficiency => 'పోషక లోపం';

  @override
  String get faVisitLogTypeDisease => 'తెగులు';

  @override
  String get faVisitLogTypePest => 'పురుగు';

  @override
  String get faVisitLogWorksOffline => 'నెట్ లేకున్నా పనిచేస్తుంది';

  @override
  String get faVisitsErrorInvalidDate => 'ఈ రోజు లేదా తర్వాతి రోజు ఎంచుకోండి.';

  @override
  String get faVisitsErrorNoData =>
      'మీ రైతుల వివరాలు ఇంకా ఈ ఫోన్‌లో లేవు. ముందు సింక్ చేయండి.';

  @override
  String get faVisitsErrorNoSeason =>
      'ఈ పొలంలో ఇంకా పంట లేదు. ముందు పంట నమోదు చేయండి.';

  @override
  String get faVisitsErrorNotEditable =>
      'ఈ సందర్శన ఇప్పటికే HO కి వెళ్ళింది, ఇక మార్చలేరు.';

  @override
  String get faVisitsErrorNotFound =>
      'ఈ రైతు, పొలం లేదా సందర్శన ఇప్పుడు ఈ ఫోన్‌లో లేదు. మళ్ళీ తెరవండి.';

  @override
  String get faVisitsErrorNotPlanned =>
      'ఈ సందర్శన ఇప్పటికే పూర్తయింది లేదా రద్దయింది.';

  @override
  String get faVisitsErrorRequired => 'కొన్ని వివరాలు లేవు.';

  @override
  String get faVisitsErrorTooMany =>
      'ఫోటోలు లేదా సమస్యలు చాలా ఎక్కువ. 20 వరకే ఉంచండి.';

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
