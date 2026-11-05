import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'orbit_localizations_en.dart';
import 'orbit_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of OrbitLocalizations
/// returned by `OrbitLocalizations.of(context)`.
///
/// Applications need to include `OrbitLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/orbit_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: OrbitLocalizations.localizationsDelegates,
///   supportedLocales: OrbitLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the OrbitLocalizations.supportedLocales
/// property.
abstract class OrbitLocalizations {
  OrbitLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static OrbitLocalizations of(BuildContext context) {
    return Localizations.of<OrbitLocalizations>(context, OrbitLocalizations)!;
  }

  static const LocalizationsDelegate<OrbitLocalizations> delegate =
      _OrbitLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('te'),
    Locale('en'),
  ];

  /// Button that asks for a phone permission (location, camera).
  ///
  /// In te, this message translates to:
  /// **'అనుమతి ఇవ్వండి'**
  String get commonAllow;

  /// App and programme name; brand, never translated.
  ///
  /// In te, this message translates to:
  /// **'Orbit Shifting'**
  String get commonAppName;

  /// Listen button after playback failed.
  ///
  /// In te, this message translates to:
  /// **'ఆడియో ప్లే కాలేదు'**
  String get commonAudioError;

  /// Listen button while the audio loads.
  ///
  /// In te, this message translates to:
  /// **'ఆడియో వస్తోంది…'**
  String get commonAudioLoading;

  /// Listen button when no recording exists for this screen or notice.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఆడియో ఇంకా లేదు'**
  String get commonAudioUnavailable;

  /// Back button (wireframe F9b).
  ///
  /// In te, this message translates to:
  /// **'వెనక్కి'**
  String get commonBack;

  /// Call button (opens the dialler).
  ///
  /// In te, this message translates to:
  /// **'కాల్'**
  String get commonCall;

  /// Call button naming the person. Wireframe has "సురేష్‌కు కాల్ చేయండి"; "గారికి" is used so the suffix fits any name, including names in Latin script.
  ///
  /// In te, this message translates to:
  /// **'{name} గారికి కాల్ చేయండి'**
  String commonCallName({required String name});

  /// Cancel button in dialogs.
  ///
  /// In te, this message translates to:
  /// **'రద్దు'**
  String get commonCancel;

  /// Generic choose / select label.
  ///
  /// In te, this message translates to:
  /// **'ఎంచుకోండి'**
  String get commonChoose;

  /// Close button for sheets and dialogs.
  ///
  /// In te, this message translates to:
  /// **'మూసివేయండి'**
  String get commonClose;

  /// Label on locked tiles and features not built yet.
  ///
  /// In te, this message translates to:
  /// **'త్వరలో'**
  String get commonComingSoon;

  /// A full date with year, e.g. "12 అక్టో, 2026". Use on consents and seasons.
  ///
  /// In te, this message translates to:
  /// **'{date}'**
  String commonDateFull({required DateTime date});

  /// A day and short month, e.g. "12 అక్టో". Use on list rows.
  ///
  /// In te, this message translates to:
  /// **'{date}'**
  String commonDateShort({required DateTime date});

  /// A date with short weekday and month, e.g. "గురు, 29 అక్టో". Use for visit dates.
  ///
  /// In te, this message translates to:
  /// **'{date}'**
  String commonDateWeekday({required DateTime date});

  /// Relative time on cards.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రోజు క్రితం} other{{count} రోజుల క్రితం}}'**
  String commonDaysAgo({required int count});

  /// Done button at the end of a flow.
  ///
  /// In te, this message translates to:
  /// **'పూర్తయింది'**
  String get commonDone;

  /// Joins two short facts on one line (wireframe style "Kondapur · Cotton").
  ///
  /// In te, this message translates to:
  /// **'{first} · {second}'**
  String commonDotJoin({required String first, required String second});

  /// Edit / change button.
  ///
  /// In te, this message translates to:
  /// **'మార్చండి'**
  String get commonEdit;

  /// Help label (wireframe F10).
  ///
  /// In te, this message translates to:
  /// **'సహాయం'**
  String get commonHelp;

  /// Helpline label; the number comes from app config.
  ///
  /// In te, this message translates to:
  /// **'సహాయ కేంద్రం'**
  String get commonHelpline;

  /// Relative time on cards (wireframe F5 "2 h ago").
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 గంట క్రితం} other{{count} గంటల క్రితం}}'**
  String commonHoursAgo({required int count});

  /// Dismiss button for optional prompts.
  ///
  /// In te, this message translates to:
  /// **'తర్వాత'**
  String get commonLater;

  /// Listen button: plays the voice prompt or voice note.
  ///
  /// In te, this message translates to:
  /// **'వినండి'**
  String get commonListen;

  /// Shown while a screen loads.
  ///
  /// In te, this message translates to:
  /// **'లోడ్ అవుతోంది…'**
  String get commonLoading;

  /// Relative time on cards.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 నిమిషం క్రితం} other{{count} నిమిషాల క్రితం}}'**
  String commonMinutesAgo({required int count});

  /// Continue / next step button (wireframe F9a).
  ///
  /// In te, this message translates to:
  /// **'ముందుకు'**
  String get commonNext;

  /// No answer (wireframe F1a).
  ///
  /// In te, this message translates to:
  /// **'వద్దు'**
  String get commonNo;

  /// Offline banner title (wireframe states).
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు'**
  String get commonOffline;

  /// Generic OK / acknowledge button.
  ///
  /// In te, this message translates to:
  /// **'సరే'**
  String get commonOk;

  /// Button that opens the phone settings after a permission was denied.
  ///
  /// In te, this message translates to:
  /// **'సెట్టింగ్స్ తెరవండి'**
  String get commonOpenSettings;

  /// Read button (opens the full text).
  ///
  /// In te, this message translates to:
  /// **'చదవండి'**
  String get commonRead;

  /// Retry button on error cards (wireframe F7b, F9c).
  ///
  /// In te, this message translates to:
  /// **'మళ్ళీ ప్రయత్నించండి'**
  String get commonRetry;

  /// Save button.
  ///
  /// In te, this message translates to:
  /// **'సేవ్ చేయండి'**
  String get commonSave;

  /// Banner under cached data: when it was saved. Wireframe F2 "Saved at 7:00 am".
  ///
  /// In te, this message translates to:
  /// **'{time} కి సేవ్ చేసింది'**
  String commonSavedAt({required DateTime time});

  /// Search field label.
  ///
  /// In te, this message translates to:
  /// **'వెతకండి'**
  String get commonSearch;

  /// Sign-out button.
  ///
  /// In te, this message translates to:
  /// **'లాగౌట్'**
  String get commonSignOut;

  /// Step header in multi-step flows (one input per screen).
  ///
  /// In te, this message translates to:
  /// **'{step}/{total}'**
  String commonStepOf({required int step, required int total});

  /// Stop button while audio plays.
  ///
  /// In te, this message translates to:
  /// **'ఆపండి'**
  String get commonStop;

  /// Relative day label (wireframe F2).
  ///
  /// In te, this message translates to:
  /// **'ఈ రోజు'**
  String get commonToday;

  /// Relative day label (wireframe F2).
  ///
  /// In te, this message translates to:
  /// **'రేపు'**
  String get commonTomorrow;

  /// Undo action on a snackbar.
  ///
  /// In te, this message translates to:
  /// **'రద్దు చేయండి'**
  String get commonUndo;

  /// Shown when a value is missing or an enum value is new to this app version.
  ///
  /// In te, this message translates to:
  /// **'తెలియదు'**
  String get commonUnknown;

  /// Dismissable "new version" card.
  ///
  /// In te, this message translates to:
  /// **'కొత్త వెర్షన్ వచ్చింది'**
  String get commonUpdateAvailable;

  /// Opens the store page.
  ///
  /// In te, this message translates to:
  /// **'అప్‌డేట్ చేయండి'**
  String get commonUpdateButton;

  /// Blocking forced-update screen body.
  ///
  /// In te, this message translates to:
  /// **'కొనసాగడానికి కొత్త వెర్షన్ ఇన్‌స్టాల్ చేయండి.'**
  String get commonUpdateRequiredBody;

  /// Blocking forced-update screen title.
  ///
  /// In te, this message translates to:
  /// **'యాప్ అప్‌డేట్ చేయండి'**
  String get commonUpdateRequiredTitle;

  /// WhatsApp chat button; brand, never translated.
  ///
  /// In te, this message translates to:
  /// **'WhatsApp'**
  String get commonWhatsapp;

  /// Yes answer.
  ///
  /// In te, this message translates to:
  /// **'అవును'**
  String get commonYes;

  /// Relative day label.
  ///
  /// In te, this message translates to:
  /// **'నిన్న'**
  String get commonYesterday;

  /// Visit issue advice status.
  ///
  /// In te, this message translates to:
  /// **'సలహా ఇచ్చారు'**
  String get enumAdviceStatusGiven;

  /// Visit issue advice status: the FA will follow up.
  ///
  /// In te, this message translates to:
  /// **'సలహా రావాలి'**
  String get enumAdviceStatusUnresolved;

  /// How a plot area was found.
  ///
  /// In te, this message translates to:
  /// **'పొలం చుట్టూ నడిచి కొలిచారు'**
  String get enumAreaSourceBoundary;

  /// How a plot area was found.
  ///
  /// In te, this message translates to:
  /// **'రైతు చెప్పిన విస్తీర్ణం'**
  String get enumAreaSourceTyped;

  /// Area unit (app-side; 40 guntas = 1 acre).
  ///
  /// In te, this message translates to:
  /// **'ఎకరాలు'**
  String get enumAreaUnitAcre;

  /// Area unit (app-side; 40 guntas = 1 acre).
  ///
  /// In te, this message translates to:
  /// **'గుంటలు'**
  String get enumAreaUnitGunta;

  /// Call-back request status.
  ///
  /// In te, this message translates to:
  /// **'రద్దు చేశారు'**
  String get enumCallbackStatusCancelled;

  /// Call-back request status.
  ///
  /// In te, this message translates to:
  /// **'FA కాల్ చేశారు'**
  String get enumCallbackStatusClosed;

  /// Call-back request status (wireframe F3).
  ///
  /// In te, this message translates to:
  /// **'అభ్యర్థన పంపాం'**
  String get enumCallbackStatusOpen;

  /// How the consent was given.
  ///
  /// In te, this message translates to:
  /// **'యాప్‌లో'**
  String get enumConsentMethodApp;

  /// How the consent was given.
  ///
  /// In te, this message translates to:
  /// **'FA ద్వారా, OTP తో'**
  String get enumConsentMethodFaOtp;

  /// How the consent was given.
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ ఆఫీసు ద్వారా'**
  String get enumConsentMethodHo;

  /// Consent purpose.
  ///
  /// In te, this message translates to:
  /// **'క్యాష్‌బ్యాక్, బహుమతులు'**
  String get enumConsentPurposeLoyalty;

  /// Consent purpose.
  ///
  /// In te, this message translates to:
  /// **'ఆర్బిట్ కార్యక్రమం'**
  String get enumConsentPurposeProgramme;

  /// Consent purpose.
  ///
  /// In te, this message translates to:
  /// **'పథకాలు, రుణాలు, బీమా'**
  String get enumConsentPurposeSchemesFinance;

  /// Consent purpose.
  ///
  /// In te, this message translates to:
  /// **'మట్టి పరీక్ష కంపెనీ'**
  String get enumConsentPurposeSoilPartner;

  /// App-side consent state: granted = true.
  ///
  /// In te, this message translates to:
  /// **'ఒప్పుకున్నారు'**
  String get enumConsentStateGranted;

  /// App-side consent state: granted = null.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా అడగలేదు'**
  String get enumConsentStateNeverAsked;

  /// App-side consent state: granted = false.
  ///
  /// In te, this message translates to:
  /// **'వద్దన్నారు'**
  String get enumConsentStateWithdrawn;

  /// FA coverage level; F3 tab (wireframe).
  ///
  /// In te, this message translates to:
  /// **'జిల్లా'**
  String get enumCoverageLevelDistrict;

  /// FA coverage level; F3 tab (wireframe).
  ///
  /// In te, this message translates to:
  /// **'మండలం'**
  String get enumCoverageLevelMandal;

  /// FA coverage level; F3 tab (wireframe).
  ///
  /// In te, this message translates to:
  /// **'గ్రామం'**
  String get enumCoverageLevelVillage;

  /// Plan badge (wireframe F7).
  ///
  /// In te, this message translates to:
  /// **'ఉచితం'**
  String get enumFarmerPlanFree;

  /// Plan badge (wireframe F7).
  ///
  /// In te, this message translates to:
  /// **'ప్రీమియం'**
  String get enumFarmerPlanPremium;

  /// Farmer status.
  ///
  /// In te, this message translates to:
  /// **'యాక్టివ్'**
  String get enumFarmerStatusActive;

  /// Farmer status.
  ///
  /// In te, this message translates to:
  /// **'ఆపివేశారు'**
  String get enumFarmerStatusInactive;

  /// Farmer status.
  ///
  /// In te, this message translates to:
  /// **'నమోదు పూర్తి కాలేదు'**
  String get enumFarmerStatusPendingProfile;

  /// Language chip; always shown in its own script (wireframe F1).
  ///
  /// In te, this message translates to:
  /// **'English'**
  String get enumLanguageEn;

  /// Language chip; always shown in its own script (wireframe F1).
  ///
  /// In te, this message translates to:
  /// **'తెలుగు'**
  String get enumLanguageTe;

  /// Notice source tag (wireframe F5); CIV full name is an open decision.
  ///
  /// In te, this message translates to:
  /// **'CIV'**
  String get enumNoticeSenderCiv;

  /// Notice source tag.
  ///
  /// In te, this message translates to:
  /// **'మీ FA'**
  String get enumNoticeSenderFa;

  /// Notice source tag (wireframe F5).
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ'**
  String get enumNoticeSenderHo;

  /// Notice source tag for system notices.
  ///
  /// In te, this message translates to:
  /// **'ఆర్బిట్'**
  String get enumNoticeSenderSystem;

  /// Planned visit slot.
  ///
  /// In te, this message translates to:
  /// **'మధ్యాహ్నం'**
  String get enumPlannedSlotAfternoon;

  /// Planned visit slot.
  ///
  /// In te, this message translates to:
  /// **'రోజులో ఎప్పుడైనా'**
  String get enumPlannedSlotAny;

  /// Planned visit slot.
  ///
  /// In te, this message translates to:
  /// **'ఉదయం'**
  String get enumPlannedSlotMorning;

  /// First part of a season code (kharif-2026).
  ///
  /// In te, this message translates to:
  /// **'ఖరీఫ్'**
  String get enumSeasonKindKharif;

  /// First part of a season code (rabi-2026-27).
  ///
  /// In te, this message translates to:
  /// **'రబీ'**
  String get enumSeasonKindRabi;

  /// First part of a season code (summer-2026).
  ///
  /// In te, this message translates to:
  /// **'వేసవి'**
  String get enumSeasonKindSummer;

  /// Season status and close-season outcome (crop lost or given up).
  ///
  /// In te, this message translates to:
  /// **'పంట వదిలేశారు'**
  String get enumSeasonStatusAbandoned;

  /// Season status.
  ///
  /// In te, this message translates to:
  /// **'పంట పొలంలో ఉంది'**
  String get enumSeasonStatusActive;

  /// Season status and close-season outcome.
  ///
  /// In te, this message translates to:
  /// **'కోత పూర్తయింది'**
  String get enumSeasonStatusHarvested;

  /// Issue severity.
  ///
  /// In te, this message translates to:
  /// **'ఎక్కువ'**
  String get enumSeverityHigh;

  /// Issue severity (wireframe F4).
  ///
  /// In te, this message translates to:
  /// **'తక్కువ'**
  String get enumSeverityLow;

  /// Issue severity (wireframe F4).
  ///
  /// In te, this message translates to:
  /// **'మధ్యస్థం'**
  String get enumSeverityModerate;

  /// Visit status.
  ///
  /// In te, this message translates to:
  /// **'రద్దయింది'**
  String get enumVisitStatusCancelled;

  /// Visit status.
  ///
  /// In te, this message translates to:
  /// **'వచ్చి వెళ్ళారు'**
  String get enumVisitStatusDone;

  /// Visit status.
  ///
  /// In te, this message translates to:
  /// **'రాలేదు'**
  String get enumVisitStatusMissed;

  /// Visit status.
  ///
  /// In te, this message translates to:
  /// **'రావాల్సి ఉంది'**
  String get enumVisitStatusPlanned;

  /// 409 on start season.
  ///
  /// In te, this message translates to:
  /// **'ఈ పొలంలో ఇప్పటికే ఒక పంట ఉంది. ముందు దాన్ని ముగించండి.'**
  String get errorActiveSeasonExists;

  /// 409 callback_closed on undo.
  ///
  /// In te, this message translates to:
  /// **'మీ FA ఈ అభ్యర్థన ఇప్పటికే ముగించారు.'**
  String get errorCallbackClosed;

  /// Added after an error message when details.attempts_left is present (otp_invalid).
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{ఇక ప్రయత్నాలు లేవు. కొత్త OTP అడగండి.} one{ఇంకా 1 సారి ప్రయత్నించవచ్చు.} other{ఇంకా {count} సార్లు ప్రయత్నించవచ్చు.}}'**
  String errorDetailAttemptsLeft({required int count});

  /// Added after an error message when the app puts the Retry-After seconds in details.retry_after_seconds.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 సెకను తర్వాత మళ్ళీ ప్రయత్నించండి.} other{{count} సెకన్ల తర్వాత మళ్ళీ ప్రయత్నించండి.}}'**
  String errorDetailRetryAfterSeconds({required int count});

  /// 401 device_revoked: the app wipes local data and goes to sign-in.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్ నుంచి లాగౌట్ చేశాం. మళ్ళీ లాగిన్ అవ్వండి.'**
  String get errorDeviceRevoked;

  /// 403 forbidden (e.g. deactivated farmer).
  ///
  /// In te, this message translates to:
  /// **'ఇది చేయడానికి అనుమతి లేదు.'**
  String get errorForbidden;

  /// 500 internal.
  ///
  /// In te, this message translates to:
  /// **'మా వైపు ఏదో తప్పు జరిగింది. మళ్ళీ ప్రయత్నించండి.'**
  String get errorInternal;

  /// 400 invalid_cursor on a paged list.
  ///
  /// In te, this message translates to:
  /// **'జాబితా పాతబడింది. మళ్ళీ తెరవండి.'**
  String get errorInvalidCursor;

  /// 400 invalid_request (malformed body or query).
  ///
  /// In te, this message translates to:
  /// **'ఏదో సరిగా లేదు. మళ్ళీ ప్రయత్నించండి.'**
  String get errorInvalidRequest;

  /// App-side code: no connection.
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు. కనెక్షన్ చూసి మళ్ళీ ప్రయత్నించండి.'**
  String get errorNetwork;

  /// 409 no_fa_assigned on call-back request.
  ///
  /// In te, this message translates to:
  /// **'మీకు ఇంకా FA ని ఇవ్వలేదు. సహాయ కేంద్రానికి కాల్ చేయండి.'**
  String get errorNoFaAssigned;

  /// 404 not_found.
  ///
  /// In te, this message translates to:
  /// **'ఇది దొరకలేదు. మళ్ళీ తెరిచి చూడండి.'**
  String get errorNotFound;

  /// Sync reject reason on EnrolFarmer (FA app).
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు గ్రామం మీ ప్రాంతంలో లేదు.'**
  String get errorNotInYourArea;

  /// 400 otp_expired on OTP verify.
  ///
  /// In te, this message translates to:
  /// **'ఈ OTP గడువు ముగిసింది. కొత్త OTP అడగండి.'**
  String get errorOtpExpired;

  /// 400 otp_invalid on OTP verify. Pair with error.detail.attempts_left.
  ///
  /// In te, this message translates to:
  /// **'OTP తప్పు. SMS చూసి మళ్ళీ వేయండి.'**
  String get errorOtpInvalid;

  /// 403 password_change_required (FA app).
  ///
  /// In te, this message translates to:
  /// **'కొనసాగడానికి మీ పాస్‌వర్డ్ మార్చండి.'**
  String get errorPasswordChangeRequired;

  /// 413 payload_too_large.
  ///
  /// In te, this message translates to:
  /// **'ఇది పంపడానికి చాలా పెద్దది.'**
  String get errorPayloadTooLarge;

  /// 409 phone_taken.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్ నంబర్ మరో రైతు పేరు మీద ఉంది.'**
  String get errorPhoneTaken;

  /// 409 photo_already_uploaded (FA app).
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోటో ఇప్పటికే పంపారు.'**
  String get errorPhotoAlreadyUploaded;

  /// 409 on complete-profile; the app carries on to Home.
  ///
  /// In te, this message translates to:
  /// **'మీ నమోదు ఇప్పటికే పూర్తయింది.'**
  String get errorProfileAlreadyComplete;

  /// 409 profile_incomplete.
  ///
  /// In te, this message translates to:
  /// **'ముందు మీ నమోదు పూర్తి చేయండి.'**
  String get errorProfileIncomplete;

  /// 429 rate_limited. Pair with error.detail.retry_after_seconds (from the Retry-After header).
  ///
  /// In te, this message translates to:
  /// **'చాలా సార్లు ప్రయత్నించారు. కాసేపు ఆగి మళ్ళీ ప్రయత్నించండి.'**
  String get errorRateLimited;

  /// 401 refresh_reused on /v1/auth/refresh.
  ///
  /// In te, this message translates to:
  /// **'ఈ లాగిన్ వేరే చోట వాడారు. మళ్ళీ లాగిన్ అవ్వండి.'**
  String get errorRefreshReused;

  /// Sync reject reason on EnrolFarmer (FA app).
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు ఇప్పటికే వేరే FA దగ్గర నమోదయ్యారు.'**
  String get errorRegisteredWithAnotherFa;

  /// 409 season_exists on start season.
  ///
  /// In te, this message translates to:
  /// **'ఈ సీజన్‌కు ఈ పొలంలో పంట ఇప్పటికే ఉంది.'**
  String get errorSeasonExists;

  /// 409 season_not_active on close season.
  ///
  /// In te, this message translates to:
  /// **'ఈ పంట ఇప్పటికే ముగిసింది.'**
  String get errorSeasonNotActive;

  /// 401 session_revoked.
  ///
  /// In te, this message translates to:
  /// **'మీరు లాగౌట్ అయ్యారు. మళ్ళీ లాగిన్ అవ్వండి.'**
  String get errorSessionRevoked;

  /// 401 temp_password_expired (FA app).
  ///
  /// In te, this message translates to:
  /// **'మీ తాత్కాలిక పాస్‌వర్డ్ గడువు ముగిసింది. కొత్తది కోసం HO కి కాల్ చేయండి.'**
  String get errorTempPasswordExpired;

  /// App-side code: the request timed out.
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ నెమ్మదిగా ఉంది. మళ్ళీ ప్రయత్నించండి.'**
  String get errorTimeout;

  /// 401 unauthorized after a failed refresh.
  ///
  /// In te, this message translates to:
  /// **'మళ్ళీ లాగిన్ అవ్వండి.'**
  String get errorUnauthorized;

  /// 503 unavailable.
  ///
  /// In te, this message translates to:
  /// **'సర్వీస్ ఇప్పుడు పని చేయడం లేదు. కాసేపటి తర్వాత ప్రయత్నించండి.'**
  String get errorUnavailable;

  /// Fallback for any code this app version does not know.
  ///
  /// In te, this message translates to:
  /// **'ఏదో తప్పు జరిగింది. మళ్ళీ ప్రయత్నించండి.'**
  String get errorUnknown;

  /// 409 upload_missing on photo confirm (FA app).
  ///
  /// In te, this message translates to:
  /// **'ఫోటో అప్‌లోడ్ కాలేదు. మళ్ళీ పంపండి.'**
  String get errorUploadMissing;

  /// 400 validation_failed (details.fields names the fields).
  ///
  /// In te, this message translates to:
  /// **'వివరాలు సరిగా లేవు. చూసి మళ్ళీ ఇవ్వండి.'**
  String get errorValidationFailed;

  /// 409 version_mismatch (FA app).
  ///
  /// In te, this message translates to:
  /// **'ఈ వివరాలు HO మార్చింది. మళ్ళీ తెరిచి చూడండి.'**
  String get errorVersionMismatch;

  /// FaActionError already_enrolled: the phone is already one of the FA's farmers.
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు ఇప్పటికే మీ దగ్గర ఉన్నారు.'**
  String get faActionErrorAlreadyEnrolled;

  /// FaActionError area_too_small: the plot area rounds to nothing.
  ///
  /// In te, this message translates to:
  /// **'ఈ విస్తీర్ణం చాలా చిన్నది. గట్టు మళ్ళీ నడవండి లేదా విస్తీర్ణం టైప్ చేయండి.'**
  String get faActionErrorAreaTooSmall;

  /// FaActionError boundary_crosses_itself: the walked boundary crosses itself.
  ///
  /// In te, this message translates to:
  /// **'గట్టు తనను తానే దాటుతోంది. మళ్ళీ నడవండి.'**
  String get faActionErrorBoundaryCrossesItself;

  /// FaActionError cannot_clear: a field (the Telugu name) cannot be emptied from the FA app.
  ///
  /// In te, this message translates to:
  /// **'దీన్ని ఇక్కడ ఖాళీగా వదలలేరు. తీసేయాలంటే HO కి చెప్పండి.'**
  String get faActionErrorCannotClear;

  /// FaActionError invalid_date: a day in the past (or a visit time in the future).
  ///
  /// In te, this message translates to:
  /// **'ఈ రోజు లేదా తర్వాతి రోజు ఎంచుకోండి.'**
  String get faActionErrorInvalidDate;

  /// FaActionError invalid_phone: not a 10-digit Indian mobile number.
  ///
  /// In te, this message translates to:
  /// **'ఇది సరైన మొబైల్ నంబర్ కాదు.'**
  String get faActionErrorInvalidPhone;

  /// FaActionError invalid_season_code: the season is not open.
  ///
  /// In te, this message translates to:
  /// **'ఈ సీజన్ ముగిసింది. వేరేది ఎంచుకోండి.'**
  String get faActionErrorInvalidSeasonCode;

  /// FaActionError location_required: a plot needs a boundary or a pin.
  ///
  /// In te, this message translates to:
  /// **'ముందు పొలం గట్టు నడవండి లేదా పిన్ పెట్టండి.'**
  String get faActionErrorLocationRequired;

  /// FaActionError no_data: no snapshot on the phone yet (first sign-in before the first pull).
  ///
  /// In te, this message translates to:
  /// **'మీ రైతుల వివరాలు ఇంకా ఈ ఫోన్‌లో లేవు. ముందు ఒకసారి ఇంటర్నెట్‌తో సింక్ చేయండి.'**
  String get faActionErrorNoData;

  /// FaActionError no_season: no active plot or season to plan or log a visit on.
  ///
  /// In te, this message translates to:
  /// **'ఈ పొలంలో ఇంకా పంట లేదు. ముందు పంట నమోదు చేయండి.'**
  String get faActionErrorNoSeason;

  /// FaActionError not_editable: the queued visit log was already sent.
  ///
  /// In te, this message translates to:
  /// **'ఈ సందర్శన ఇప్పటికే HO కి వెళ్ళింది, ఇక మార్చలేరు.'**
  String get faActionErrorNotEditable;

  /// FaActionError not_found: the farmer, plot, visit, village, crop or alert referred to is gone from the phone.
  ///
  /// In te, this message translates to:
  /// **'ఇది ఇప్పుడు ఈ ఫోన్‌లో లేదు. వెనక్కి వెళ్ళి మళ్ళీ తెరవండి.'**
  String get faActionErrorNotFound;

  /// FaActionError not_planned: the visit is not planned any more.
  ///
  /// In te, this message translates to:
  /// **'ఈ సందర్శన ఇప్పటికే పూర్తయింది లేదా రద్దయింది.'**
  String get faActionErrorNotPlanned;

  /// FaActionError nothing_to_change: the edit would change nothing.
  ///
  /// In te, this message translates to:
  /// **'ఏమీ మారలేదు, సేవ్ చేయడానికి ఏమీ లేదు.'**
  String get faActionErrorNothingToChange;

  /// FaActionError out_of_range: a number such as plot area or GPS accuracy is out of range.
  ///
  /// In te, this message translates to:
  /// **'ఈ సంఖ్య సరిగ్గా లేదు. సరిచూడండి.'**
  String get faActionErrorOutOfRange;

  /// FaActionError proof_invalid: the consent proof expired or is for another phone.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి OTP గడువు ముగిసింది. కొత్త OTP పంపండి.'**
  String get faActionErrorProofInvalid;

  /// FaActionError required: a required value is empty.
  ///
  /// In te, this message translates to:
  /// **'అన్ని వివరాలు నింపండి.'**
  String get faActionErrorRequired;

  /// FaActionError too_long: a text is too long (e.g. a name over 100 characters). Also the inline error under the name field.
  ///
  /// In te, this message translates to:
  /// **'ఇది చాలా పొడవుగా ఉంది.'**
  String get faActionErrorTooLong;

  /// FaActionError too_many: more than 20 photos or issues.
  ///
  /// In te, this message translates to:
  /// **'ఫోటోలు లేదా సమస్యలు చాలా ఎక్కువ. 20 వరకే ఉంచండి.'**
  String get faActionErrorTooMany;

  /// FaActionError wrong_state: the sync row is no longer in a state that allows this (Keep mine, Keep HO's, dismiss).
  ///
  /// In te, this message translates to:
  /// **'ఇది ఇప్పటికే మారింది. మళ్ళీ చూసి ఇంకోసారి ప్రయత్నించండి.'**
  String get faActionErrorWrongState;

  /// Status line after Got it.
  ///
  /// In te, this message translates to:
  /// **'చూశారు · మీరు చదివినట్లు HO కి తెలుస్తుంది'**
  String get faAlertsAcknowledged;

  /// Call button when the farmer name is not known.
  ///
  /// In te, this message translates to:
  /// **'రైతుకు కాల్ చేయండి'**
  String get faAlertsCallFarmer;

  /// Button on a new farmer alert: calls the farmer, then opens plan a visit.
  ///
  /// In te, this message translates to:
  /// **'కాల్ · సందర్శన ప్లాన్'**
  String get faAlertsCallPlanVisit;

  /// Status line once the call-back is closed.
  ///
  /// In te, this message translates to:
  /// **'కాల్ బ్యాక్ మూసివేయబడింది'**
  String get faAlertsCallbackClosed;

  /// Line on a call-back alert.
  ///
  /// In te, this message translates to:
  /// **'కాల్ లాగ్ చేసినప్పుడు మూసివేయబడుతుంది'**
  String get faAlertsCallbackHint;

  /// Button shown after the FA called back.
  ///
  /// In te, this message translates to:
  /// **'కాల్ బ్యాక్ మూసివేయండి'**
  String get faAlertsCloseCallback;

  /// Line above Close call-back after the call.
  ///
  /// In te, this message translates to:
  /// **'మాట్లాడారా? అభ్యర్థనను మూసివేయండి.'**
  String get faAlertsCloseCallbackHint;

  /// Collapsed section of acknowledged and closed alerts, with how many.
  ///
  /// In te, this message translates to:
  /// **'ఇంతకు ముందువి · {count}'**
  String faAlertsEarlier({required int count});

  /// Empty state text.
  ///
  /// In te, this message translates to:
  /// **'కొత్త రైతులు, కాల్ బ్యాక్ అభ్యర్థనలు, HO సందేశాలు ఇక్కడ కనిపిస్తాయి.'**
  String get faAlertsEmptyBody;

  /// Empty state text of one filter chip.
  ///
  /// In te, this message translates to:
  /// **'ఈ రకం హెచ్చరికలు ఇప్పుడు లేవు.'**
  String get faAlertsEmptyTabBody;

  /// Empty state of one filter chip.
  ///
  /// In te, this message translates to:
  /// **'ఇక్కడ ఏమీ లేదు'**
  String get faAlertsEmptyTabTitle;

  /// Empty state title.
  ///
  /// In te, this message translates to:
  /// **'హెచ్చరికలు లేవు'**
  String get faAlertsEmptyTitle;

  /// Button on a new farmer alert: opens enrolment with the phone filled in.
  ///
  /// In te, this message translates to:
  /// **'నమోదు పూర్తి చేయండి'**
  String get faAlertsFinishEnrolment;

  /// Button on an HO note: tells HO the FA read it.
  ///
  /// In te, this message translates to:
  /// **'సరే, చూశాను'**
  String get faAlertsGotIt;

  /// Pill on a call-back alert.
  ///
  /// In te, this message translates to:
  /// **'కాల్ చేయమన్నారు'**
  String get faAlertsKindCallback;

  /// Pill on a note from head office.
  ///
  /// In te, this message translates to:
  /// **'HO సందేశం'**
  String get faAlertsKindHoNote;

  /// Pill on a new farmer alert.
  ///
  /// In te, this message translates to:
  /// **'కొత్త రైతు'**
  String get faAlertsKindNewFarmer;

  /// Pill on an alert of a kind this app does not know.
  ///
  /// In te, this message translates to:
  /// **'హెచ్చరిక'**
  String get faAlertsKindOther;

  /// Offline banner on Alerts.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్‌లో ఉన్న హెచ్చరికలు చూపిస్తున్నాం. నెట్‌వర్క్ వచ్చాక కిందకి లాగి రిఫ్రెష్ చేయండి.'**
  String get faAlertsOfflineBody;

  /// Button on a new farmer alert once the farmer is fully enrolled.
  ///
  /// In te, this message translates to:
  /// **'రైతును చూడండి'**
  String get faAlertsOpenFarmer;

  /// Status line on an older closed alert.
  ///
  /// In te, this message translates to:
  /// **'మూసివేయబడింది'**
  String get faAlertsStatusClosed;

  /// Header sub-line: open alerts that need the FA.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{ఏ పనీ లేదు} one{1 పని చేయాలి} other{{count} పనులు చేయాలి}}'**
  String faAlertsSubtitle({required int count});

  /// Filter chip: every alert.
  ///
  /// In te, this message translates to:
  /// **'అన్నీ'**
  String get faAlertsTabAll;

  /// Filter chip: farmers asking to be called.
  ///
  /// In te, this message translates to:
  /// **'కాల్ బ్యాక్‌లు'**
  String get faAlertsTabCallbacks;

  /// Filter chip: notes from head office.
  ///
  /// In te, this message translates to:
  /// **'HO నుండి'**
  String get faAlertsTabHo;

  /// Filter chip: new farmer alerts.
  ///
  /// In te, this message translates to:
  /// **'కొత్త రైతులు'**
  String get faAlertsTabNewFarmers;

  /// Screen reader label of the filter chips row.
  ///
  /// In te, this message translates to:
  /// **'హెచ్చరిక రకం'**
  String get faAlertsTabsLabel;

  /// Snack bar when the dialer did not open.
  ///
  /// In te, this message translates to:
  /// **'డయలర్ తెరవలేకపోయాం. HO కి {phone} నంబర్‌కు కాల్ చేయండి.'**
  String faAuthCallFailed({required String phone});

  /// Button that opens the dialer with the HO helpline.
  ///
  /// In te, this message translates to:
  /// **'HO కి కాల్ చేయండి · {phone}'**
  String faAuthCallHo({required String phone});

  /// How many farmers are saved on the phone.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రైతు} other{{count} మంది రైతులు}}'**
  String faAuthFarmersCount({required int count});

  /// Button in a password field that hides the text again.
  ///
  /// In te, this message translates to:
  /// **'దాచు'**
  String get faAuthHide;

  /// Screen reader label of the Hide button.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ దాచు'**
  String get faAuthHidePassword;

  /// Pill on the PIN screen without network.
  ///
  /// In te, this message translates to:
  /// **'ఆఫ్‌లైన్ · మీ రైతుల వివరాలు ఈ ఫోన్‌లో ఉన్నాయి'**
  String get faAuthOfflineSaved;

  /// Pill on the PIN screen when the phone has network.
  ///
  /// In te, this message translates to:
  /// **'ఆన్‌లైన్'**
  String get faAuthOnline;

  /// Screen reader label of the PIN pad delete key.
  ///
  /// In te, this message translates to:
  /// **'అంకె తొలగించండి'**
  String get faAuthPinDelete;

  /// Screen reader label of the PIN dots.
  ///
  /// In te, this message translates to:
  /// **'{length} అంకెల్లో {filled} నమోదు చేశారు'**
  String faAuthPinEntered({required int filled, required int length});

  /// How many plots are saved on the phone.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 పొలం} other{{count} పొలాలు}}'**
  String faAuthPlotsCount({required int count});

  /// Under the app name on the splash and login.
  ///
  /// In te, this message translates to:
  /// **'ఫీల్డ్ అసిస్టెంట్'**
  String get faAuthRole;

  /// Button in a password field that shows the text.
  ///
  /// In te, this message translates to:
  /// **'చూపించు'**
  String get faAuthShow;

  /// Screen reader label of the Show button.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ చూపించు'**
  String get faAuthShowPassword;

  /// Screen reader label of the steps card.
  ///
  /// In te, this message translates to:
  /// **'అప్‌డేట్ చేసే ముందు'**
  String get faBlockedBefore;

  /// Removed screen secondary button.
  ///
  /// In te, this message translates to:
  /// **'కొత్త పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి'**
  String get faBlockedNewLogin;

  /// Note under the steps.
  ///
  /// In te, this message translates to:
  /// **'ఏదీ పోదు: మీరు యాప్ వదిలే ముందు సేవ్ అయిన రికార్డులు పంపుతాం.'**
  String get faBlockedNothingLost;

  /// Main button once nothing waits.
  ///
  /// In te, this message translates to:
  /// **'Play Store తెరవండి'**
  String get faBlockedOpenStore;

  /// Removed screen body.
  ///
  /// In te, this message translates to:
  /// **'HO ఈ ఫోన్ నుంచి మీ లాగిన్‌ను తొలగించింది. రైతుల వివరాలు ఈ ఫోన్ నుంచి తొలగించబడ్డాయి.'**
  String get faBlockedRemovedBody;

  /// Removed screen info card.
  ///
  /// In te, this message translates to:
  /// **'ఫోన్ పోయినప్పుడు లేదా వేరేవారి చేతికి వెళ్ళినప్పుడు ఇలా జరుగుతుంది. పొరపాటు అనిపిస్తే HO కి కాల్ చేయండి; వారు కొత్త లాగిన్ ఇస్తారు.'**
  String get faBlockedRemovedNote;

  /// Error after a failed push.
  ///
  /// In te, this message translates to:
  /// **'రికార్డులు పంపలేకపోయాం. ఇంటర్నెట్‌కు కనెక్ట్ అయి మళ్ళీ ప్రయత్నించండి. ఇప్పుడే అప్‌డేట్ చేస్తే అవి ఈ ఫోన్‌లోనే ఉండి అప్‌డేట్ తర్వాత పంపబడతాయి.'**
  String get faBlockedSendFailed;

  /// Main button before sending.
  ///
  /// In te, this message translates to:
  /// **'రికార్డులు పంపి, అప్‌డేట్ చేయండి'**
  String get faBlockedSendThenUpdate;

  /// Main button while sending.
  ///
  /// In te, this message translates to:
  /// **'పంపుతోంది…'**
  String get faBlockedSending;

  /// Step 1 when nothing waits.
  ///
  /// In te, this message translates to:
  /// **'మీ రికార్డులన్నీ పంపబడ్డాయి'**
  String get faBlockedStepNothing;

  /// Step 1 before sending.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{సేవ్ అయిన 1 రికార్డు HO కి పంపండి} other{సేవ్ అయిన {count} రికార్డులు HO కి పంపండి}}'**
  String faBlockedStepSend({required int count});

  /// Step 1 while sending.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రికార్డు పంపుతోంది…} other{{count} రికార్డులు పంపుతోంది…}}'**
  String faBlockedStepSending({required int count});

  /// Step 1 after sending.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రికార్డు HO కి పంపబడింది} other{{count} రికార్డులు HO కి పంపబడ్డాయి}}'**
  String faBlockedStepSent({required int count});

  /// Step 2.
  ///
  /// In te, this message translates to:
  /// **'Play Store తెరిచి అప్‌డేట్ చేయండి'**
  String get faBlockedStepStore;

  /// Step 3.
  ///
  /// In te, this message translates to:
  /// **'ఎప్పటిలాగే PIN తో తెరవండి'**
  String get faBlockedStepUnlock;

  /// Snack bar when the store did not open.
  ///
  /// In te, this message translates to:
  /// **'Play Store తెరవలేకపోయాం. మీరే తెరిచి Orbit Shifting అప్‌డేట్ చేయండి, లేదా HO కి కాల్ చేయండి.'**
  String get faBlockedStoreFailed;

  /// Secondary button after a failed push.
  ///
  /// In te, this message translates to:
  /// **'పంపకుండా అప్‌డేట్ చేయండి'**
  String get faBlockedUpdateAnyway;

  /// Update screen body with the minimum version.
  ///
  /// In te, this message translates to:
  /// **'ఈ వెర్షన్ ({version}) పాతది. రికార్డులు సరిగ్గా సింక్ అవ్వడానికి అందరూ {min} లేదా కొత్తది వాడాలని HO కోరుతోంది.'**
  String faBlockedUpdateBody({required String min, required String version});

  /// Update screen body when the minimum version is not known.
  ///
  /// In te, this message translates to:
  /// **'ఈ వెర్షన్ ({version}) పాతది. రికార్డులు సరిగ్గా సింక్ అవ్వడానికి అప్‌డేట్ చేయండి.'**
  String faBlockedUpdateBodyPlain({required String version});

  /// Header pill button that opens Plan a visit. Keep very short.
  ///
  /// In te, this message translates to:
  /// **'జోడించు'**
  String get faCalendarAdd;

  /// Confirm dialog body. date is like "Tue, 3 Nov".
  ///
  /// In te, this message translates to:
  /// **'ఇది {date} కి ప్లాన్ చేశారు. తర్వాతి సింక్ తర్వాత రైతుకు ఇది కనిపించదు.'**
  String faCalendarCancelBody({required String date});

  /// Confirm dialog title before cancelling a planned visit.
  ///
  /// In te, this message translates to:
  /// **'{name} సందర్శన రద్దు చేయాలా?'**
  String faCalendarCancelTitle({required String name});

  /// Menu item and confirm button: cancels a planned visit.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన రద్దు చేయండి'**
  String get faCalendarCancelVisit;

  /// Notice after cancelling a planned visit.
  ///
  /// In te, this message translates to:
  /// **'{name} సందర్శన రద్దు చేశారు'**
  String faCalendarCancelled({required String name});

  /// Screen reader label of one day in the week strip. date is like "Tue, 27 Oct".
  ///
  /// In te, this message translates to:
  /// **'{date}, {count, plural, =0{సందర్శనలు లేవు} one{1 సందర్శన} other{{count} సందర్శనలు}}'**
  String faCalendarDayLabel({required int count, required String date});

  /// Header sub-line part: how many of the day's visits are done.
  ///
  /// In te, this message translates to:
  /// **'{count} పూర్తి'**
  String faCalendarDoneCount({required int count});

  /// Empty day text.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన రావాల్సిన రైతులను ఎంచుకుని, కాల్ చేసి రోజు ఖరారు చేయండి.'**
  String get faCalendarEmptyBody;

  /// Empty day title.
  ///
  /// In te, this message translates to:
  /// **'సందర్శనలు ఏవీ ప్లాన్ చేయలేదు'**
  String get faCalendarEmptyTitle;

  /// Empty day button: opens Farmers on the Visit due filter.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన రావాల్సిన రైతులు'**
  String get faCalendarFindDue;

  /// Note at the bottom of the calendar.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన లాగ్ సేవ్ చేయగానే అది పూర్తయినట్టు మారుతుంది.'**
  String get faCalendarFooterNote;

  /// Confirm dialog button that does not cancel.
  ///
  /// In te, this message translates to:
  /// **'ఉంచండి'**
  String get faCalendarKeepVisit;

  /// Notice after moving a visit to another day.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన మార్చారు · {name} · {date}'**
  String faCalendarMoved({required String date, required String name});

  /// Screen reader label of the arrow that shows the week after.
  ///
  /// In te, this message translates to:
  /// **'తర్వాత వారం'**
  String get faCalendarNextWeek;

  /// Banner on the calendar while offline.
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు · సందర్శనలు ఈ ఫోన్‌లో సేవ్ అయి, తర్వాత సింక్ అవుతాయి'**
  String get faCalendarOffline;

  /// Notice after planning a visit. date is like "Wed, 4 Nov".
  ///
  /// In te, this message translates to:
  /// **'సందర్శన ప్లాన్ అయింది · {name} · {date}'**
  String faCalendarPlanned({required String date, required String name});

  /// Screen reader label of the arrow that shows the week before.
  ///
  /// In te, this message translates to:
  /// **'ముందు వారం'**
  String get faCalendarPreviousWeek;

  /// Menu item on a planned visit: opens Plan a visit filled in, and cancels this one when saved.
  ///
  /// In te, this message translates to:
  /// **'వేరే రోజుకు మార్చండి'**
  String get faCalendarReschedule;

  /// Notice on the calendar after a visit log without advice was saved (no SMS goes to the farmer).
  ///
  /// In te, this message translates to:
  /// **'సందర్శన సేవ్ అయింది · {name} పూర్తయింది'**
  String faCalendarSavedNoAdvice({required String name});

  /// Notice on the calendar after a visit log was saved and is not synced yet.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన సేవ్ అయింది · {name} పూర్తయింది · సింక్ అయ్యాక సలహా SMS లో వెళ్తుంది'**
  String faCalendarSavedPending({required String name});

  /// Notice on the calendar after a visit log was saved and synced.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన సేవ్ అయింది · {name} పూర్తయింది · సలహా పంపాం'**
  String faCalendarSavedSent({required String name});

  /// Button on today's planned visit card: opens the visit log.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన మొదలు'**
  String get faCalendarStartVisit;

  /// Status pill of a visit whose log is saved.
  ///
  /// In te, this message translates to:
  /// **'పూర్తయింది'**
  String get faCalendarStatusDone;

  /// Status pill of a planned visit to a farmer the FA has never visited.
  ///
  /// In te, this message translates to:
  /// **'కొత్త · మొదటి సందర్శన'**
  String get faCalendarStatusFirstVisit;

  /// Status pill of a planned visit whose day has passed, or a missed visit.
  ///
  /// In te, this message translates to:
  /// **'ఆలస్యం'**
  String get faCalendarStatusOverdue;

  /// Status pill of a visit still to do.
  ///
  /// In te, this message translates to:
  /// **'ప్లాన్ చేశారు'**
  String get faCalendarStatusPlanned;

  /// Button that jumps back to today's week.
  ///
  /// In te, this message translates to:
  /// **'ఈ వారం'**
  String get faCalendarThisWeek;

  /// Calendar screen title.
  ///
  /// In te, this message translates to:
  /// **'సందర్శనల క్యాలెండర్'**
  String get faCalendarTitle;

  /// Header sub-line part: visits on the picked day.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{సందర్శనలు లేవు} one{1 సందర్శన} other{{count} సందర్శనలు}}'**
  String faCalendarVisitCount({required int count});

  /// Screen reader label of the menu button on a visit card (Reschedule, Cancel visit).
  ///
  /// In te, this message translates to:
  /// **'{name} · మరిన్ని'**
  String faCalendarVisitOptions({required String name});

  /// Screen reader label of the week strip and the label between the week arrows. date is like "2 Nov".
  ///
  /// In te, this message translates to:
  /// **'{date} వారం'**
  String faCalendarWeekOf({required String date});

  /// Step 3.
  ///
  /// In te, this message translates to:
  /// **'కొత్త PIN మళ్ళీ టైప్ చేయండి'**
  String get faChangePinAgain;

  /// Snack bar after the change.
  ///
  /// In te, this message translates to:
  /// **'PIN మారింది'**
  String get faChangePinChanged;

  /// Step 2.
  ///
  /// In te, this message translates to:
  /// **'కొత్త PIN ఎంచుకోండి'**
  String get faChangePinNew;

  /// Step 1.
  ///
  /// In te, this message translates to:
  /// **'మీ ప్రస్తుత PIN ఎంటర్ చేయండి'**
  String get faChangePinOld;

  /// After a wrong current PIN.
  ///
  /// In te, this message translates to:
  /// **'ప్రస్తుత PIN తప్పు'**
  String get faChangePinWrongOld;

  /// Plot area as acres and guntas (40 guntas = 1 acre), both parts always shown, e.g. "2 ac 4 gunta".
  ///
  /// In te, this message translates to:
  /// **'{acres} ఎ. {guntas} గుం.'**
  String faCommonArea({required int acres, required int guntas});

  /// Snack bar when the dialer did not open for a farmer's number (Farmers, map, Farmer 360, calendar, alerts).
  ///
  /// In te, this message translates to:
  /// **'డయలర్ తెరవలేకపోయాం. {phone} కి కాల్ చేయండి.'**
  String faCommonCallFailed({required String phone});

  /// Snack bar when no maps app opened for directions.
  ///
  /// In te, this message translates to:
  /// **'మ్యాప్స్ తెరవలేకపోయాం.'**
  String get faCommonDirectionsFailed;

  /// Distance from the FA, e.g. "1.2 km". The number is formatted by the app (one decimal).
  ///
  /// In te, this message translates to:
  /// **'{distance} కి.మీ.'**
  String faCommonDistanceKm({required String distance});

  /// Distance under 1 km, e.g. "350 m".
  ///
  /// In te, this message translates to:
  /// **'{distance} మీ.'**
  String faCommonDistanceM({required int distance});

  /// Error card title for any other error; the error text comes under it.
  ///
  /// In te, this message translates to:
  /// **'ఏదో తప్పు జరిగింది'**
  String get faCommonErrorTitle;

  /// Log out action (error card for a session error, Me).
  ///
  /// In te, this message translates to:
  /// **'లాగ్ అవుట్'**
  String get faCommonLogOut;

  /// Tag on a farmer, plot or visit saved on this phone and not yet sent to HO.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా సింక్ కాలేదు'**
  String get faCommonNotSynced;

  /// Error card text when a screen needs the network and there is none.
  ///
  /// In te, this message translates to:
  /// **'నెట్‌వర్క్ వచ్చాక మళ్ళీ ప్రయత్నించండి. మీ రైతుల వివరాలు ఈ ఫోన్‌లో ఉన్నాయి.'**
  String get faCommonOfflineBody;

  /// Error card title when a screen needs the network and there is none.
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు'**
  String get faCommonOfflineTitle;

  /// A time of day, e.g. "11:05 am".
  ///
  /// In te, this message translates to:
  /// **'{time}'**
  String faCommonTime({required DateTime time});

  /// Snack bar when WhatsApp did not open.
  ///
  /// In te, this message translates to:
  /// **'వాట్సాప్ తెరవలేకపోయాం. ఫోన్‌లో ఉందా?'**
  String get faCommonWhatsappFailed;

  /// Consent box after the OTP is confirmed.
  ///
  /// In te, this message translates to:
  /// **'రైతు ఒప్పుకున్నారు. రైతు తర్వాత ఒప్పుకుంటేనే ఇతర కంపెనీలకు వివరాలు వెళ్తాయి.'**
  String get faConsentAgreed;

  /// Button: verify the consent OTP.
  ///
  /// In te, this message translates to:
  /// **'నిర్ధారించండి'**
  String get faConsentConfirm;

  /// Consent box before the OTP is sent.
  ///
  /// In te, this message translates to:
  /// **'రైతు ఫోన్‌కి OTP వస్తుంది. రైతు తమ భాషలో అనుమతి విని, OTP మీకు చదివి చెబుతారు.'**
  String get faConsentHow;

  /// Under the disabled Send button.
  ///
  /// In te, this message translates to:
  /// **'ముందు రైతు మొబైల్ నంబర్ ఇవ్వండి.'**
  String get faConsentNeedsPhone;

  /// The consent notice the FA reads or plays to the farmer, shown in the farmer's language (notice_version fa-v1). Changing it means a new notice version.
  ///
  /// In te, this message translates to:
  /// **'మీ పంటకు సలహాలు ఇవ్వడానికి, మీ FA మీ పొలానికి రావడానికి మీ వివరాలు వాడుతాం. మీ వివరాలు షణ్ముఖ వద్ద భద్రంగా ఉంటాయి. మీరు ఒప్పుకుంటేనే ఇతర కంపెనీలకు పంపుతాం. ఒప్పుకుంటే, మీకు వచ్చిన OTP ని మీ FA కి చెప్పండి.'**
  String get faConsentNotice;

  /// Offline consent box body.
  ///
  /// In te, this message translates to:
  /// **'అది లేకుంటే అనుమతి పెండింగ్‌లో ఉంటుంది. నెట్‌వర్క్ వచ్చాక రైతు పేజీ నుండి నమోదు చేయండి.'**
  String get faConsentOfflineBody;

  /// Offline: no consent OTP.
  ///
  /// In te, this message translates to:
  /// **'అనుమతికి ఇంటర్నెట్ కావాలి'**
  String get faConsentOfflineTitle;

  /// Label of the OTP boxes.
  ///
  /// In te, this message translates to:
  /// **'రైతు చెప్పే OTP'**
  String get faConsentOtpLabel;

  /// Listen button that plays the consent notice to the farmer.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి వినిపించండి'**
  String get faConsentPlay;

  /// Listen button label after the notice was played.
  ///
  /// In te, this message translates to:
  /// **'వినిపించాం'**
  String get faConsentPlayed;

  /// The consent OTP was confirmed at time.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి నమోదైంది · {time}'**
  String faConsentRecorded({required String time});

  /// The consent OTP was confirmed and the notice played, in language.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి నమోదైంది · {time} · {language} ఆడియో వినిపించాం'**
  String faConsentRecordedPlayed({
    required String language,
    required String time,
  });

  /// Button: send a new consent OTP.
  ///
  /// In te, this message translates to:
  /// **'OTP మళ్ళీ పంపండి'**
  String get faConsentResend;

  /// Countdown before the OTP can be sent again.
  ///
  /// In te, this message translates to:
  /// **'{seconds, plural, one{1 సెకనులో మళ్ళీ పంపవచ్చు} other{{seconds} సెకన్లలో మళ్ళీ పంపవచ్చు}}'**
  String faConsentResendIn({required int seconds});

  /// Button: queue RecordConsent.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి సేవ్ చేయండి'**
  String get faConsentSave;

  /// Snack bar after RecordConsent is queued.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి ఈ ఫోన్‌లో సేవ్ అయింది · ఆన్‌లైన్ అయ్యాక సింక్ అవుతుంది'**
  String get faConsentSaved;

  /// Button: send the consent OTP SMS.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి OTP పంపండి'**
  String get faConsentSendOtp;

  /// Consent box after the OTP is sent.
  ///
  /// In te, this message translates to:
  /// **'{phone} కి రైతు భాషలో అనుమతి సందేశంతో OTP పంపాం.'**
  String faConsentSent({required String phone});

  /// Title of the record-consent sheet (Farmer 360).
  ///
  /// In te, this message translates to:
  /// **'అనుమతి నమోదు · {name}'**
  String faConsentSheetTitle({required String name});

  /// Title of the consent box.
  ///
  /// In te, this message translates to:
  /// **'రైతు అనుమతి'**
  String get faConsentTitle;

  /// Screen reader label of the back arrow on enrol step 1.
  ///
  /// In te, this message translates to:
  /// **'రైతుల జాబితాకు వెనక్కి'**
  String get faEnrolBackToFarmers;

  /// Button: dial the HO helpline.
  ///
  /// In te, this message translates to:
  /// **'HO కి కాల్ చేయండి'**
  String get faEnrolCallHo;

  /// After the lookup error text.
  ///
  /// In te, this message translates to:
  /// **'కొనసాగించవచ్చు: సింక్ అప్పుడు నంబర్ మళ్ళీ చూస్తాం.'**
  String get faEnrolCheckedAtSync;

  /// While the phone lookup runs.
  ///
  /// In te, this message translates to:
  /// **'నంబర్ చూస్తున్నాం…'**
  String get faEnrolChecking;

  /// Continue button when the farmer is an unassigned self sign-up.
  ///
  /// In te, this message translates to:
  /// **'కొనసాగించండి · నాకు కేటాయించండి'**
  String get faEnrolContinueClaim;

  /// Body of the deactivated card.
  ///
  /// In te, this message translates to:
  /// **'HO ఈ రైతును నిలిపివేసింది, కాబట్టి మళ్ళీ నమోదు చేయలేరు.'**
  String get faEnrolDeactivatedBody;

  /// Lookup result deactivated.
  ///
  /// In te, this message translates to:
  /// **'రైతు ఖాతా నిలిపివేయబడింది'**
  String get faEnrolDeactivatedTitle;

  /// FaActionError already_enrolled.
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు ఇప్పటికే మీ దగ్గర ఉన్నారు.'**
  String get faEnrolErrorAlreadyEnrolled;

  /// FaActionError invalid_phone.
  ///
  /// In te, this message translates to:
  /// **'ఇది సరైన మొబైల్ నంబర్ కాదు.'**
  String get faEnrolErrorInvalidPhone;

  /// FaActionError invalid_season_code.
  ///
  /// In te, this message translates to:
  /// **'ఈ సీజన్ ముగిసింది. వేరేది ఎంచుకోండి.'**
  String get faEnrolErrorInvalidSeasonCode;

  /// FaActionError location_required.
  ///
  /// In te, this message translates to:
  /// **'ముందు పొలం గట్టు నడవండి లేదా పిన్ పెట్టండి.'**
  String get faEnrolErrorLocationRequired;

  /// FaActionError no_data.
  ///
  /// In te, this message translates to:
  /// **'మీ రైతుల వివరాలు ఇంకా ఈ ఫోన్‌లో లేవు. ఒకసారి ఇంటర్నెట్‌తో సింక్ చేసి, తర్వాత నమోదు చేయండి.'**
  String get faEnrolErrorNoData;

  /// FaActionError out_of_range (area, GPS accuracy).
  ///
  /// In te, this message translates to:
  /// **'ఈ సంఖ్య సరిగ్గా లేదు. సరిచూడండి.'**
  String get faEnrolErrorOutOfRange;

  /// FaActionError proof_invalid.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి OTP గడువు ముగిసింది. కొత్త OTP పంపండి.'**
  String get faEnrolErrorProofInvalid;

  /// FaActionError required.
  ///
  /// In te, this message translates to:
  /// **'అన్ని వివరాలు నింపండి.'**
  String get faEnrolErrorRequired;

  /// FaActionError too_long; name over 100 characters.
  ///
  /// In te, this message translates to:
  /// **'ఇది చాలా పొడవుగా ఉంది.'**
  String get faEnrolErrorTooLong;

  /// Button: go to the missing enrolment step (plot or crop).
  ///
  /// In te, this message translates to:
  /// **'నమోదు పూర్తి చేయండి'**
  String get faEnrolFinishEnrolment;

  /// Label of the language chips.
  ///
  /// In te, this message translates to:
  /// **'రైతు భాష'**
  String get faEnrolLanguageLabel;

  /// Dialog body: leaving loses the form.
  ///
  /// In te, this message translates to:
  /// **'ఇక్కడ నింపినవి సేవ్ కావు.'**
  String get faEnrolLeaveBody;

  /// Dialog button: leave and lose the form.
  ///
  /// In te, this message translates to:
  /// **'వదిలేయండి'**
  String get faEnrolLeaveConfirm;

  /// Dialog button: stay on the form.
  ///
  /// In te, this message translates to:
  /// **'ఉండండి'**
  String get faEnrolLeaveStay;

  /// Dialog title: back with details filled in.
  ///
  /// In te, this message translates to:
  /// **'నమోదు వదిలేయాలా?'**
  String get faEnrolLeaveTitle;

  /// The phone lookup failed (not offline): enrolment can go on.
  ///
  /// In te, this message translates to:
  /// **'నంబర్ చూడలేకపోయాం'**
  String get faEnrolLookupFailedTitle;

  /// Body of the already-your-farmer card.
  ///
  /// In te, this message translates to:
  /// **'{name} ఇప్పటికే మీ రైతుల్లో ఉన్నారు.'**
  String faEnrolMineBody({required String name});

  /// Body of the already-your-farmer card when the farmer is not on the phone yet.
  ///
  /// In te, this message translates to:
  /// **'ఈ నంబర్ ఇప్పటికే మీ రైతుల్లో ఉంది.'**
  String get faEnrolMineBodyUnknown;

  /// Lookup result: the number is already this FA's farmer.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పటికే మీ రైతు'**
  String get faEnrolMineTitle;

  /// Label of the name field.
  ///
  /// In te, this message translates to:
  /// **'రైతు పేరు'**
  String get faEnrolNameLabel;

  /// Validation error under the name field.
  ///
  /// In te, this message translates to:
  /// **'రైతు పేరు ఇవ్వండి.'**
  String get faEnrolNameRequired;

  /// Label of the Telugu name field.
  ///
  /// In te, this message translates to:
  /// **'తెలుగులో పేరు (ఐచ్ఛికం)'**
  String get faEnrolNameTeLabel;

  /// Dialog body: enrol without consent.
  ///
  /// In te, this message translates to:
  /// **'రైతు పేజీ నుండి నమోదు చేసే వరకు అనుమతి పెండింగ్‌లో ఉంటుంది.'**
  String get faEnrolNoConsentBody;

  /// Dialog button: enrol without consent.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి లేకుండా నమోదు'**
  String get faEnrolNoConsentConfirm;

  /// Dialog title: online but no consent OTP confirmed.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి లేకుండా నమోదు చేయాలా?'**
  String get faEnrolNoConsentTitle;

  /// Offline banner body on enrol step 1.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పుడే నమోదు చేయండి: సింక్ అప్పుడు నంబర్ మళ్ళీ చూస్తాం. అనుమతి, ఫోటో తర్వాత రైతు పేజీ నుండి చేర్చవచ్చు.'**
  String get faEnrolOfflineBody;

  /// Hint under Continue (online).
  ///
  /// In te, this message translates to:
  /// **'ఆఫ్‌లైన్‌లో ఉన్నారా? సింక్ అప్పుడు నంబర్ మళ్ళీ చూస్తాం.'**
  String get faEnrolOfflineHint;

  /// Offline banner title on enrol step 1.
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు'**
  String get faEnrolOfflineTitle;

  /// Button: open Farmer 360.
  ///
  /// In te, this message translates to:
  /// **'రైతును తెరవండి'**
  String get faEnrolOpenFarmer;

  /// Body of the other-FA card.
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు వేరే FA దగ్గర ఉన్నారు. రైతును HO మాత్రమే మార్చగలదు. HO కి కాల్ చేయండి.'**
  String get faEnrolOtherFaBody;

  /// Lookup result other_fa.
  ///
  /// In te, this message translates to:
  /// **'వేరే FA రైతు'**
  String get faEnrolOtherFaTitle;

  /// Under a card that stops enrolment of this number.
  ///
  /// In te, this message translates to:
  /// **'వేరే రైతును నమోదు చేయాలంటే, వేరే నంబర్ ఇవ్వండి.'**
  String get faEnrolOtherNumber;

  /// Body of the outside-your-area card.
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు మీ ప్రాంతం బయటి గ్రామంలో నమోదై ఉన్నారు. మార్చడానికి HO కి కాల్ చేయండి.'**
  String get faEnrolOutsideBody;

  /// Lookup result outside_my_area.
  ///
  /// In te, this message translates to:
  /// **'గ్రామం మీ ప్రాంతంలో లేదు'**
  String get faEnrolOutsideTitle;

  /// Body of the self sign-up card.
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు స్వయంగా చేరారు. వివరాలు, అనుమతి ఇక్కడ పూర్తి చేయండి.'**
  String get faEnrolPendingBody;

  /// The number is a self sign-up of this FA that still needs its profile.
  ///
  /// In te, this message translates to:
  /// **'రైతు యాప్‌లో చేరారు'**
  String get faEnrolPendingTitle;

  /// Validation error under the phone field.
  ///
  /// In te, this message translates to:
  /// **'రైతు 10 అంకెల మొబైల్ నంబర్ ఇవ్వండి.'**
  String get faEnrolPhoneInvalid;

  /// Label of the phone field.
  ///
  /// In te, this message translates to:
  /// **'రైతు మొబైల్ నంబర్'**
  String get faEnrolPhoneLabel;

  /// Button that opens the camera for the farmer photo; also the photo label.
  ///
  /// In te, this message translates to:
  /// **'రైతు ఫోటో'**
  String get faEnrolPhoto;

  /// The farmer photo uploaded.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో చేరింది'**
  String get faEnrolPhotoAdded;

  /// The farmer photo upload failed.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో వెళ్ళలేదు. మళ్ళీ ప్రయత్నించండి, లేదా ఫోటో లేకుండా కొనసాగండి.'**
  String get faEnrolPhotoFailed;

  /// Snack bar: the camera could not be used.
  ///
  /// In te, this message translates to:
  /// **'కెమెరా తెరవలేకపోయాం. కెమెరా అనుమతి చూడండి.'**
  String get faEnrolPhotoNoCamera;

  /// Offline: no farmer photo now.
  ///
  /// In te, this message translates to:
  /// **'ఫోటోకి ఇంటర్నెట్ కావాలి. తర్వాత రైతు పేజీ నుండి చేర్చండి.'**
  String get faEnrolPhotoOffline;

  /// Button: take the farmer photo again.
  ///
  /// In te, this message translates to:
  /// **'మళ్ళీ తీయండి'**
  String get faEnrolPhotoRetake;

  /// While the farmer photo uploads.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో పంపుతున్నాం…'**
  String get faEnrolPhotoUploading;

  /// Button: record consent for a farmer enrolled without it.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి నమోదు చేయండి'**
  String get faEnrolRecordConsent;

  /// Body of the already-registered card; enrolment continues and the server merges.
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు స్వయంగా చేరారు, ఇంకా FA లేరు. కొత్తది చేయకుండా, వారి రికార్డులోనే చేరుస్తాం.'**
  String get faEnrolRegisteredBody;

  /// Lookup result unassigned_in_my_area: a self sign-up with no FA.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పటికే నమోదై ఉన్నారు'**
  String get faEnrolRegisteredTitle;

  /// Step 3 name in the enrolment step row.
  ///
  /// In te, this message translates to:
  /// **'పంట'**
  String get faEnrolStepCrop;

  /// Screen reader suffix of the current step.
  ///
  /// In te, this message translates to:
  /// **'ప్రస్తుత దశ'**
  String get faEnrolStepCurrent;

  /// Screen reader suffix of a finished step.
  ///
  /// In te, this message translates to:
  /// **'పూర్తైంది'**
  String get faEnrolStepDone;

  /// Step 2 name in the enrolment step row.
  ///
  /// In te, this message translates to:
  /// **'పొలం'**
  String get faEnrolStepFarm;

  /// Step 1 name in the enrolment step row.
  ///
  /// In te, this message translates to:
  /// **'రైతు'**
  String get faEnrolStepFarmer;

  /// Screen reader label of the enrolment step row.
  ///
  /// In te, this message translates to:
  /// **'దశలు'**
  String get faEnrolStepsLabel;

  /// Header title of enrol step 1.
  ///
  /// In te, this message translates to:
  /// **'రైతు నమోదు'**
  String get faEnrolTitle;

  /// Header title of enrol steps 2 and 3 with the farmer name.
  ///
  /// In te, this message translates to:
  /// **'నమోదు · {name}'**
  String faEnrolTitleName({required String name});

  /// Body of the unknown-status card.
  ///
  /// In te, this message translates to:
  /// **'ఈ నంబర్ గురించి HO కి కాల్ చేసి అడగండి.'**
  String get faEnrolUnknownBody;

  /// Lookup returned a status this app version does not know.
  ///
  /// In te, this message translates to:
  /// **'ఈ నంబర్‌ను నమోదు చేయలేము'**
  String get faEnrolUnknownTitle;

  /// Success button: open Farmers.
  ///
  /// In te, this message translates to:
  /// **'రైతుల జాబితాకు'**
  String get faEnrolCropBackToFarmers;

  /// Summary consent row: consent given.
  ///
  /// In te, this message translates to:
  /// **'ఇచ్చారు ✓'**
  String get faEnrolCropConsentDone;

  /// Summary consent row: consent pending.
  ///
  /// In te, this message translates to:
  /// **'పెండింగ్ · రైతు పేజీ నుండి నమోదు చేయండి'**
  String get faEnrolCropConsentPending;

  /// Heading of the crop chips.
  ///
  /// In te, this message translates to:
  /// **'ఈ సీజన్ పంట · {season}'**
  String faEnrolCropCropHeading({required String season});

  /// Success title after Finish enrolment.
  ///
  /// In te, this message translates to:
  /// **'{name} నమోదు అయ్యారు'**
  String faEnrolCropEnrolled({required String name});

  /// Finish without a crop.
  ///
  /// In te, this message translates to:
  /// **'పంట ఎంచుకోండి.'**
  String get faEnrolCropErrorCrop;

  /// Finish without a sowing choice.
  ///
  /// In te, this message translates to:
  /// **'విత్తిన తేదీ ఎంచుకోండి.'**
  String get faEnrolCropErrorSowing;

  /// Previous crop chip: none or unknown.
  ///
  /// In te, this message translates to:
  /// **'ఖాళీ / తెలియదు'**
  String get faEnrolCropFallow;

  /// Button: queue StartSeason.
  ///
  /// In te, this message translates to:
  /// **'నమోదు పూర్తి చేయండి'**
  String get faEnrolCropFinish;

  /// Sowing date chip: no date.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా విత్తలేదు'**
  String get faEnrolCropNotSown;

  /// Note under the chips for not sown yet.
  ///
  /// In te, this message translates to:
  /// **'విత్తిన తేదీ లేకుంటే పంట దశ తెలియదు.'**
  String get faEnrolCropNotSownNote;

  /// Success button: plan the first visit.
  ///
  /// In te, this message translates to:
  /// **'మొదటి సందర్శన ప్లాన్ చేయండి'**
  String get faEnrolCropPlanVisit;

  /// Heading of the previous crop chips.
  ///
  /// In te, this message translates to:
  /// **'ఈ పొలంలో ముందు పంట'**
  String get faEnrolCropPreviousLabel;

  /// Success note while not synced.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్‌లో సేవ్ అయింది. ఆన్‌లైన్ అయ్యాక HO కి వెళ్తుంది.'**
  String get faEnrolCropSavedOnPhone;

  /// Heading of the season chips.
  ///
  /// In te, this message translates to:
  /// **'సీజన్'**
  String get faEnrolCropSeasonHeading;

  /// A season, e.g. Rabi 2026-27.
  ///
  /// In te, this message translates to:
  /// **'{season} {year}'**
  String faEnrolCropSeasonLabel({required String season, required String year});

  /// Under Finish enrolment while the enrolment is on the phone.
  ///
  /// In te, this message translates to:
  /// **'సింక్ అయ్యాక {name} కి {language} లో స్వాగత SMS వెళ్తుంది.'**
  String faEnrolCropSmsNote({required String language, required String name});

  /// Note under the sowing date chips.
  ///
  /// In te, this message translates to:
  /// **'విత్తిన {day}వ రోజు'**
  String faEnrolCropSowDay({required int day});

  /// Note under the sowing date chips with the crop stage.
  ///
  /// In te, this message translates to:
  /// **'{day}వ రోజు · {stage} దశ'**
  String faEnrolCropSowDayStage({required int day, required String stage});

  /// Sowing date chip: open the date picker.
  ///
  /// In te, this message translates to:
  /// **'తేదీ ఎంచుకోండి'**
  String get faEnrolCropSowPick;

  /// Sowing date chip: today.
  ///
  /// In te, this message translates to:
  /// **'ఈరోజు · {date}'**
  String faEnrolCropSowToday({required String date});

  /// Sowing date chip: yesterday.
  ///
  /// In te, this message translates to:
  /// **'నిన్న · {date}'**
  String faEnrolCropSowYesterday({required String date});

  /// Heading of the sowing date chips; date picker title.
  ///
  /// In te, this message translates to:
  /// **'విత్తిన తేదీ'**
  String get faEnrolCropSowingLabel;

  /// Screen reader label of the summary card.
  ///
  /// In te, this message translates to:
  /// **'సారాంశం'**
  String get faEnrolCropSummary;

  /// Summary crop row part: the previous crop.
  ///
  /// In te, this message translates to:
  /// **'{crop} తర్వాత'**
  String faEnrolCropSummaryAfter({required String crop});

  /// Summary row label.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి'**
  String get faEnrolCropSummaryConsent;

  /// Summary row label.
  ///
  /// In te, this message translates to:
  /// **'పంట'**
  String get faEnrolCropSummaryCrop;

  /// Summary row label.
  ///
  /// In te, this message translates to:
  /// **'రైతు'**
  String get faEnrolCropSummaryFarmer;

  /// Summary crop row without a crop.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా ఎంచుకోలేదు'**
  String get faEnrolCropSummaryNoCrop;

  /// Summary crop row part.
  ///
  /// In te, this message translates to:
  /// **'{date} న విత్తారు'**
  String faEnrolCropSummarySown({required String date});

  /// Under the current season chip.
  ///
  /// In te, this message translates to:
  /// **'ఈ సీజన్'**
  String get faEnrolCropThisSeason;

  /// The area in decimal acres, after acres and guntas.
  ///
  /// In te, this message translates to:
  /// **'({acres} ఎ.)'**
  String faEnrolPlotAcresDecimal({required String acres});

  /// Label of the area row.
  ///
  /// In te, this message translates to:
  /// **'విస్తీర్ణం'**
  String get faEnrolPlotArea;

  /// Area row before there is an area.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా లేదు'**
  String get faEnrolPlotAreaNotYet;

  /// Button: pick another village.
  ///
  /// In te, this message translates to:
  /// **'గ్రామం మార్చండి'**
  String get faEnrolPlotChangeVillage;

  /// Button: join the last corner to the first.
  ///
  /// In te, this message translates to:
  /// **'గట్టు పూర్తి చేయండి'**
  String get faEnrolPlotClose;

  /// Walk status once closed.
  ///
  /// In te, this message translates to:
  /// **'గట్టు పూర్తైంది'**
  String get faEnrolPlotClosed;

  /// Save without a typed area.
  ///
  /// In te, this message translates to:
  /// **'విస్తీర్ణం ఎకరాలు, గుంటల్లో ఇవ్వండి.'**
  String get faEnrolPlotErrorTyped;

  /// Save without a closed boundary.
  ///
  /// In te, this message translates to:
  /// **'గట్టు నడిచి పూర్తి చేయండి, లేదా విస్తీర్ణం టైప్ చేయండి.'**
  String get faEnrolPlotErrorWalk;

  /// Waiting for a GPS fix.
  ///
  /// In te, this message translates to:
  /// **'GPS చూస్తున్నాం…'**
  String get faEnrolPlotGpsChecking;

  /// Body of the checking GPS card.
  ///
  /// In te, this message translates to:
  /// **'ఫోన్‌ను పైకి పట్టుకుని కొన్ని సెకన్లు కదలకుండా ఉండండి.'**
  String get faEnrolPlotGpsCheckingBody;

  /// GPS card: permission denied.
  ///
  /// In te, this message translates to:
  /// **'లొకేషన్ అనుమతి లేదు'**
  String get faEnrolPlotGpsDenied;

  /// GPS pill while good enough.
  ///
  /// In te, this message translates to:
  /// **'GPS ±{metres} మీ. · బాగుంది'**
  String faEnrolPlotGpsGood({required int metres});

  /// Body of the GPS too rough card.
  ///
  /// In te, this message translates to:
  /// **'గట్టు నడవడానికి ఇది సరిపోదు. చెట్లు, షెడ్లకు దూరంగా ఖాళీ చోటుకి వెళ్ళండి, లేదా విస్తీర్ణం టైప్ చేయండి.'**
  String get faEnrolPlotGpsLowBody;

  /// GPS too rough to walk the boundary.
  ///
  /// In te, this message translates to:
  /// **'GPS ±{metres} మీ.'**
  String faEnrolPlotGpsLowTitle({required int metres});

  /// GPS card: no fix in time.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా GPS సిగ్నల్ రాలేదు'**
  String get faEnrolPlotGpsNoFix;

  /// GPS card: location service off.
  ///
  /// In te, this message translates to:
  /// **'లొకేషన్ ఆఫ్‌లో ఉంది'**
  String get faEnrolPlotGpsOff;

  /// Body of the GPS problem card.
  ///
  /// In te, this message translates to:
  /// **'ఈ యాప్‌కి లొకేషన్ ఆన్ చేయండి, ఖాళీ చోటుకి వెళ్ళండి, లేదా విస్తీర్ణం టైప్ చేయండి.'**
  String get faEnrolPlotGpsProblemBody;

  /// GPS pill while too rough.
  ///
  /// In te, this message translates to:
  /// **'GPS ±{metres} మీ. · సరిపోదు'**
  String faEnrolPlotGpsRough({required int metres});

  /// Hint under the area fields.
  ///
  /// In te, this message translates to:
  /// **'40 గుంటలు = 1 ఎకరం'**
  String get faEnrolPlotGuntasPerAcre;

  /// Validation error of the guntas field.
  ///
  /// In te, this message translates to:
  /// **'గుంటలు 40 కంటే తక్కువ ఉండాలి.'**
  String get faEnrolPlotGuntasTooMany;

  /// The new plot label (stored in English as data).
  ///
  /// In te, this message translates to:
  /// **'పొలం {number}'**
  String faEnrolPlotLabel({required int number});

  /// Mandal row label.
  ///
  /// In te, this message translates to:
  /// **'మండలం'**
  String get faEnrolPlotMandal;

  /// Distance walked so far.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పటి వరకు {metres} మీ.'**
  String faEnrolPlotMetresSoFar({required int metres});

  /// Tab and button: type the area instead.
  ///
  /// In te, this message translates to:
  /// **'విస్తీర్ణం టైప్ చేయండి'**
  String get faEnrolPlotModeType;

  /// Tab: mark the plot by walking its edge.
  ///
  /// In te, this message translates to:
  /// **'గట్టు నడవండి'**
  String get faEnrolPlotModeWalk;

  /// Under the disabled Close boundary button.
  ///
  /// In te, this message translates to:
  /// **'గట్టు పూర్తి చేయడానికి కనీసం 3 మూలలు నడవండి.'**
  String get faEnrolPlotNeedCorners;

  /// Button: pause recording the walk.
  ///
  /// In te, this message translates to:
  /// **'ఆపండి'**
  String get faEnrolPlotPause;

  /// Walk status while paused.
  ///
  /// In te, this message translates to:
  /// **'ఆపాం · {metres} మీ.'**
  String faEnrolPlotPaused({required int metres});

  /// Title of the village picker.
  ///
  /// In te, this message translates to:
  /// **'ఈ పొలం ఏ గ్రామంలో ఉంది?'**
  String get faEnrolPlotPickVillage;

  /// Where the typed plot pin goes.
  ///
  /// In te, this message translates to:
  /// **'మీరు ఉన్న చోట పిన్ · GPS ±{metres} మీ.'**
  String faEnrolPlotPinHere({required int metres});

  /// Typed plot pin without GPS.
  ///
  /// In te, this message translates to:
  /// **'GPS లేదు: పిన్ గ్రామం మధ్యలో పెడతాం.'**
  String get faEnrolPlotPinVillage;

  /// Walk status before starting.
  ///
  /// In te, this message translates to:
  /// **'ఒక మూలలో నిలబడి, \'మొదలు ఇక్కడ\' నొక్కండి'**
  String get faEnrolPlotReady;

  /// Walk status while recording.
  ///
  /// In te, this message translates to:
  /// **'రికార్డ్ అవుతోంది · {metres} మీ.'**
  String faEnrolPlotRecording({required int metres});

  /// Button: resume recording the walk.
  ///
  /// In te, this message translates to:
  /// **'కొనసాగించండి'**
  String get faEnrolPlotResume;

  /// Warning while walking with a rough fix.
  ///
  /// In te, this message translates to:
  /// **'ఇక్కడ GPS సరిగ్గా లేదు: మెరుగయ్యే వరకు మూలలు నమోదు కావు.'**
  String get faEnrolPlotRoughWhileWalking;

  /// Button: queue SavePlot and open step 3.
  ///
  /// In te, this message translates to:
  /// **'సేవ్ చేసి ముందుకు'**
  String get faEnrolPlotSaveNext;

  /// Under Save & next.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్‌లో సేవ్ అవుతుంది · ఆన్‌లైన్ అయ్యాక సింక్ అవుతుంది'**
  String get faEnrolPlotSavedNote;

  /// Screen reader label of the closed boundary sketch.
  ///
  /// In te, this message translates to:
  /// **'గట్టు పూర్తైంది, {area}'**
  String faEnrolPlotSketchClosed({required String area});

  /// Screen reader label of the pin sketch.
  ///
  /// In te, this message translates to:
  /// **'మీరు ఉన్న చోట పిన్'**
  String get faEnrolPlotSketchPin;

  /// Screen reader label of the boundary sketch.
  ///
  /// In te, this message translates to:
  /// **'{corners, plural, =0{పొలం చిత్రం, ఇంకా నడవలేదు} one{పొలం చిత్రం, 1 మూల నడిచారు} other{పొలం చిత్రం, {corners} మూలలు నడిచారు}}'**
  String faEnrolPlotSketchWalking({required int corners});

  /// Button: the first corner is where the FA stands.
  ///
  /// In te, this message translates to:
  /// **'మొదలు ఇక్కడ'**
  String get faEnrolPlotStart;

  /// Note above the typed area fields.
  ///
  /// In te, this message translates to:
  /// **'GPS సరిగ్గా లేనప్పుడు ఇది వాడండి. గట్టు నడిచే వరకు పొలం పిన్‌గా మాత్రమే కనిపిస్తుంది.'**
  String get faEnrolPlotTypedNote;

  /// Button: drop the last recorded corner.
  ///
  /// In te, this message translates to:
  /// **'చివరి మూల తీసేయండి'**
  String get faEnrolPlotUndo;

  /// Village row label (picked by hand).
  ///
  /// In te, this message translates to:
  /// **'గ్రామం'**
  String get faEnrolPlotVillage;

  /// Village row label (nearest to the GPS).
  ///
  /// In te, this message translates to:
  /// **'గ్రామం · GPS నుండి'**
  String get faEnrolPlotVillageFromGps;

  /// Button: drop the boundary and walk again.
  ///
  /// In te, this message translates to:
  /// **'మళ్ళీ నడవండి'**
  String get faEnrolPlotWalkAgain;

  /// Area row while walking.
  ///
  /// In te, this message translates to:
  /// **'నడుస్తున్నారు…'**
  String get faEnrolPlotWalking;

  /// Snack bar when a local action failed.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్‌లో సేవ్ కాలేదు. మళ్లీ ప్రయత్నించండి.'**
  String get faFarmer360ActionFailed;

  /// Advice given on the last visit: a product name, else a salt name.
  ///
  /// In te, this message translates to:
  /// **'{advice} సూచించారు'**
  String faFarmer360Advised({required String advice});

  /// When the call-back was asked, e.g. "25 min ago".
  ///
  /// In te, this message translates to:
  /// **'{when} అడిగారు'**
  String faFarmer360CallbackAsked({required String when});

  /// Button after calling the farmer back.
  ///
  /// In te, this message translates to:
  /// **'తిరిగి కాల్ పూర్తయింది'**
  String get faFarmer360CallbackClose;

  /// Snack bar after closing the call-back.
  ///
  /// In te, this message translates to:
  /// **'తిరిగి కాల్ మూసివేశాం.'**
  String get faFarmer360CallbackClosed;

  /// Conflict card button.
  ///
  /// In te, this message translates to:
  /// **'నాది ఉంచండి'**
  String get faFarmer360ConflictKeepMine;

  /// Conflict card button.
  ///
  /// In te, this message translates to:
  /// **'HOది ఉంచండి'**
  String get faFarmer360ConflictKeepTheirs;

  /// Conflict card line.
  ///
  /// In te, this message translates to:
  /// **'మీరు ఆఫ్‌లైన్‌లో ఉన్నప్పుడు HO ఈ ప్రొఫైల్ మార్చారు'**
  String get faFarmer360ConflictMeta;

  /// Conflict card: your value heading.
  ///
  /// In te, this message translates to:
  /// **'మీది'**
  String get faFarmer360ConflictMine;

  /// Conflict card pill.
  ///
  /// In te, this message translates to:
  /// **'తేడా ఉంది'**
  String get faFarmer360ConflictStatus;

  /// Conflict card: HO's value heading.
  ///
  /// In te, this message translates to:
  /// **'HOది'**
  String get faFarmer360ConflictTheirs;

  /// Conflict card title.
  ///
  /// In te, this message translates to:
  /// **'ప్రొఫైల్ · {name}'**
  String faFarmer360ConflictTitle({required String name});

  /// Consents granted, e.g. "2 of 4 agreed".
  ///
  /// In te, this message translates to:
  /// **'{total}లో {count}కి అంగీకారం'**
  String faFarmer360ConsentCount({required int count, required int total});

  /// Pill: programme consent not recorded yet.
  ///
  /// In te, this message translates to:
  /// **'నమోదు కాలేదు'**
  String get faFarmer360ConsentPending;

  /// Edit profile field: language of SMS and app.
  ///
  /// In te, this message translates to:
  /// **'రైతు భాష'**
  String get faFarmer360EditLanguage;

  /// Edit profile field.
  ///
  /// In te, this message translates to:
  /// **'పేరు (ఇంగ్లీష్)'**
  String get faFarmer360EditName;

  /// Edit profile field.
  ///
  /// In te, this message translates to:
  /// **'తెలుగులో పేరు'**
  String get faFarmer360EditNameTe;

  /// Save tapped without a change.
  ///
  /// In te, this message translates to:
  /// **'ఏమీ మారలేదు.'**
  String get faFarmer360EditNothingChanged;

  /// Button and sheet title.
  ///
  /// In te, this message translates to:
  /// **'ప్రొఫైల్ మార్చండి'**
  String get faFarmer360EditProfile;

  /// Validation: empty name.
  ///
  /// In te, this message translates to:
  /// **'పేరు రాయండి'**
  String get faFarmer360EditRequired;

  /// Snack bar after saving the profile.
  ///
  /// In te, this message translates to:
  /// **'సేవ్ అయింది. తదుపరి సింక్‌లో HOకి వెళ్తుంది.'**
  String get faFarmer360EditSaved;

  /// Validation: name too long.
  ///
  /// In te, this message translates to:
  /// **'100 అక్షరాల లోపు రాయండి'**
  String get faFarmer360EditTooLong;

  /// No planned visit.
  ///
  /// In te, this message translates to:
  /// **'ఏదీ ప్లాన్ చేయలేదు'**
  String get faFarmer360NextVisitNone;

  /// Last visit without issues.
  ///
  /// In te, this message translates to:
  /// **'సమస్యలు కనిపించలేదు'**
  String get faFarmer360NoIssues;

  /// Farmer with no plot.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా పొలం లేదు'**
  String get faFarmer360NoPlot;

  /// No done visit.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా సందర్శన లేదు'**
  String get faFarmer360NoVisit;

  /// Button: opens Plan a visit.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన ప్లాన్ చేయండి'**
  String get faFarmer360PlanVisit;

  /// Days after sowing when the stage is unknown.
  ///
  /// In te, this message translates to:
  /// **'{day}వ రోజు'**
  String faFarmer360PlotDay({required int day});

  /// Plot without an active season.
  ///
  /// In te, this message translates to:
  /// **'పంట ఇంకా మొదలుపెట్టలేదు'**
  String get faFarmer360PlotNoCrop;

  /// Crop stage and days after sowing, e.g. "Flowering · day 137".
  ///
  /// In te, this message translates to:
  /// **'{stage} · {day}వ రోజు'**
  String faFarmer360PlotStageDay({required int day, required String stage});

  /// Button for a farmer enrolled without consent.
  ///
  /// In te, this message translates to:
  /// **'అంగీకారం నమోదు చేయండి'**
  String get faFarmer360RecordConsent;

  /// Summary row label: the farmer asked for a call.
  ///
  /// In te, this message translates to:
  /// **'తిరిగి కాల్'**
  String get faFarmer360RowCallback;

  /// Summary row label.
  ///
  /// In te, this message translates to:
  /// **'అంగీకారం'**
  String get faFarmer360RowConsent;

  /// Summary row label.
  ///
  /// In te, this message translates to:
  /// **'చివరి సందర్శన'**
  String get faFarmer360RowLastVisit;

  /// Summary row label.
  ///
  /// In te, this message translates to:
  /// **'తదుపరి సందర్శన'**
  String get faFarmer360RowNextVisit;

  /// Summary row label.
  ///
  /// In te, this message translates to:
  /// **'ప్లాన్'**
  String get faFarmer360RowPlan;

  /// Summary row label.
  ///
  /// In te, this message translates to:
  /// **'పొలం'**
  String get faFarmer360RowPlot;

  /// Quick action: opens the visit log.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన మొదలు'**
  String get faFarmer360StartVisit;

  /// Screen reader label of the summary card.
  ///
  /// In te, this message translates to:
  /// **'రైతు సారాంశం'**
  String get faFarmer360SummaryLabel;

  /// Button / label: opens maps at the farm.
  ///
  /// In te, this message translates to:
  /// **'దారి'**
  String get faFarmersActionDirections;

  /// Card and map button: continue enrolment where it stopped.
  ///
  /// In te, this message translates to:
  /// **'నమోదు పూర్తి చేయండి'**
  String get faFarmersActionFinishEnrolment;

  /// Map card main button: opens Farmer 360.
  ///
  /// In te, this message translates to:
  /// **'రైతును తెరవండి'**
  String get faFarmersActionOpenFarmer;

  /// Header sub-line part: farmers in the territory.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రైతు} other{{count} రైతులు}}'**
  String faFarmersCount({required int count});

  /// Empty list button: opens Enrol.
  ///
  /// In te, this message translates to:
  /// **'రైతును నమోదు చేయండి'**
  String get faFarmersEmptyAction;

  /// Empty list text.
  ///
  /// In te, this message translates to:
  /// **'మీరు నమోదు చేసిన రైతులు ఇక్కడ కనిపిస్తారు, దగ్గర వారు ముందు.'**
  String get faFarmersEmptyBody;

  /// Empty list title.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా రైతులు లేరు'**
  String get faFarmersEmptyTitle;

  /// Filter chip and map legend: no visit for 30 days or more.
  ///
  /// In te, this message translates to:
  /// **'30+ రోజులు'**
  String get faFarmersFilter30Days;

  /// Filter chip.
  ///
  /// In te, this message translates to:
  /// **'అందరూ'**
  String get faFarmersFilterAll;

  /// Filter chip: consent, plot or crop missing.
  ///
  /// In te, this message translates to:
  /// **'నమోదు పూర్తి కావాలి'**
  String get faFarmersFilterFinishEnrolment;

  /// Screen reader label of the filter chips.
  ///
  /// In te, this message translates to:
  /// **'రైతులను వడపోయండి'**
  String get faFarmersFilterLabel;

  /// Filter chip and map legend: joined today or yesterday.
  ///
  /// In te, this message translates to:
  /// **'కొత్త'**
  String get faFarmersFilterNew;

  /// Filter chip.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన బాకీ'**
  String get faFarmersFilterVisitDue;

  /// Map tile attribution required by OpenStreetMap. Keep as is.
  ///
  /// In te, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get faFarmersMapAttribution;

  /// Map legend: other farmers.
  ///
  /// In te, this message translates to:
  /// **'ఇతరులు'**
  String get faFarmersMapLegendOthers;

  /// Pill on the map when offline (pins still work).
  ///
  /// In te, this message translates to:
  /// **'ప్రస్తుతానికి మ్యాప్‌కు ఇంటర్నెట్ కావాలి'**
  String get faFarmersMapOffline;

  /// Screen reader label of the card under the map.
  ///
  /// In te, this message translates to:
  /// **'ఎంచుకున్న రైతు'**
  String get faFarmersMapSelected;

  /// Screen reader label of the FA marker.
  ///
  /// In te, this message translates to:
  /// **'మీ స్థానం'**
  String get faFarmersMapYou;

  /// Card meta part, shown in red at 30 days or more.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{సందర్శన జరిగి 1 రోజు} other{సందర్శన జరిగి {count} రోజులు}}'**
  String faFarmersMetaDaysSinceVisit({required int count});

  /// Card meta part, date like "12 Oct".
  ///
  /// In te, this message translates to:
  /// **'{date}న చేరారు'**
  String faFarmersMetaJoinedOn({required String date});

  /// Card meta part.
  ///
  /// In te, this message translates to:
  /// **'ఈరోజు చేరారు'**
  String get faFarmersMetaJoinedToday;

  /// Card meta part.
  ///
  /// In te, this message translates to:
  /// **'నిన్న చేరారు'**
  String get faFarmersMetaJoinedYesterday;

  /// Card meta part.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{చివరి సందర్శన 1 రోజు క్రితం} other{చివరి సందర్శన {count} రోజుల క్రితం}}'**
  String faFarmersMetaLastVisitDays({required int count});

  /// Card meta part: never visited, days since joining (red at 30+).
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రోజులో సందర్శన లేదు} other{{count} రోజులుగా సందర్శన లేదు}}'**
  String faFarmersMetaNeverVisited({required int count});

  /// Card meta part: no crop on any plot.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా పంట లేదు'**
  String get faFarmersMetaNoCrop;

  /// Card meta part: a visit planned this week; day is a short weekday like "Thu".
  ///
  /// In te, this message translates to:
  /// **'{day} సందర్శన'**
  String faFarmersMetaVisitDueOn({required String day});

  /// Card meta part: a visit is planned today.
  ///
  /// In te, this message translates to:
  /// **'ఈరోజు సందర్శన'**
  String get faFarmersMetaVisitDueToday;

  /// Card meta part: a planned visit date has passed.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన ఆలస్యం'**
  String get faFarmersMetaVisitOverdue;

  /// Card meta part.
  ///
  /// In te, this message translates to:
  /// **'ఈరోజు సందర్శించారు'**
  String get faFarmersMetaVisitedToday;

  /// Card meta part.
  ///
  /// In te, this message translates to:
  /// **'చివరి సందర్శన నిన్న'**
  String get faFarmersMetaVisitedYesterday;

  /// Header sub-line part: list order.
  ///
  /// In te, this message translates to:
  /// **'దగ్గర వారు ముందు'**
  String get faFarmersNearestFirst;

  /// Button before the first sync: opens Sync.
  ///
  /// In te, this message translates to:
  /// **'సింక్ తెరవండి'**
  String get faFarmersNoDataAction;

  /// Before the first sync.
  ///
  /// In te, this message translates to:
  /// **'మొదటి సింక్‌లో అవి వస్తాయి. ఇంటర్నెట్ కలిపి సింక్ చేయండి.'**
  String get faFarmersNoDataBody;

  /// Before the first sync.
  ///
  /// In te, this message translates to:
  /// **'రైతుల వివరాలు ఇంకా ఈ ఫోన్‌లో లేవు'**
  String get faFarmersNoDataTitle;

  /// No farmer under the chip.
  ///
  /// In te, this message translates to:
  /// **'ఈ వడపోతలో ఇప్పుడు రైతులు లేరు.'**
  String get faFarmersNoMatchFilter;

  /// No search result.
  ///
  /// In te, this message translates to:
  /// **'\"{query}\"కి రైతు లేరు. పేరు లేదా నంబర్ చూడండి.'**
  String faFarmersNoMatchSearch({required String query});

  /// Nothing matches the filter or search.
  ///
  /// In te, this message translates to:
  /// **'సరిపోయే రైతులు లేరు'**
  String get faFarmersNoMatchTitle;

  /// Tooltip of the clear button in the search field.
  ///
  /// In te, this message translates to:
  /// **'వెతికినది తుడిచివేయండి'**
  String get faFarmersSearchClear;

  /// Tooltip of the header icon while search is open.
  ///
  /// In te, this message translates to:
  /// **'వెతకడం ఆపండి'**
  String get faFarmersSearchClose;

  /// Hint in the search field.
  ///
  /// In te, this message translates to:
  /// **'పేరు లేదా ఫోన్ నంబర్'**
  String get faFarmersSearchHint;

  /// Tooltip of the header search icon.
  ///
  /// In te, this message translates to:
  /// **'పేరు లేదా ఫోన్‌తో వెతకండి'**
  String get faFarmersSearchOpen;

  /// Button that clears filter and search.
  ///
  /// In te, this message translates to:
  /// **'అందరు రైతులను చూపండి'**
  String get faFarmersShowAll;

  /// Header sub-line part when a filter or search is on.
  ///
  /// In te, this message translates to:
  /// **'{count} చూపిస్తున్నాం'**
  String faFarmersShown({required int count});

  /// Tag on a farmer who joined yesterday or still needs enrolment.
  ///
  /// In te, this message translates to:
  /// **'కొత్త'**
  String get faFarmersTagNew;

  /// Tag on a farmer who joined today.
  ///
  /// In te, this message translates to:
  /// **'ఈరోజు కొత్త'**
  String get faFarmersTagNewToday;

  /// Farmers tab header title.
  ///
  /// In te, this message translates to:
  /// **'నా దగ్గర రైతులు'**
  String get faFarmersTitle;

  /// List / Map switch: list.
  ///
  /// In te, this message translates to:
  /// **'జాబితా'**
  String get faFarmersViewList;

  /// List / Map switch: map.
  ///
  /// In te, this message translates to:
  /// **'మ్యాప్'**
  String get faFarmersViewMap;

  /// Banner body: the server session ended.
  ///
  /// In te, this message translates to:
  /// **'మీ రికార్డులు ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి. పాస్‌వర్డ్‌తో లాగిన్ అయ్యాక అవి పంపబడతాయి.'**
  String get faLoginEndedBody;

  /// Banner title: the server session ended.
  ///
  /// In te, this message translates to:
  /// **'సింక్ కోసం మళ్ళీ లాగిన్ అవ్వండి'**
  String get faLoginEndedTitle;

  /// Login failed offline while a session (and unsynced records) is on the phone.
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు. నెట్‌వర్క్ వచ్చాక మీ పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి. మీ రికార్డులు ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి.'**
  String get faLoginErrorOfflineAgain;

  /// Login failed offline and there is no session on the phone yet.
  ///
  /// In te, this message translates to:
  /// **'లాగిన్ అవ్వడానికి నెట్‌వర్క్ కావాలి. మొబైల్ డేటా లేదా Wi-Fi ఆన్ చేసి మళ్ళీ ప్రయత్నించండి.'**
  String get faLoginErrorOfflineFirst;

  /// 401 unauthorized: one message for a wrong ID or password.
  ///
  /// In te, this message translates to:
  /// **'లాగిన్ ID లేదా పాస్‌వర్డ్ తప్పు. సరిచూసి మళ్ళీ ప్రయత్నించండి.'**
  String get faLoginErrorWrong;

  /// Banner body: the PIN offline grace is over.
  ///
  /// In te, this message translates to:
  /// **'మీ PIN ఆఫ్‌లైన్‌లో {days} రోజులు పనిచేస్తుంది. నెట్‌వర్క్ వచ్చాక మీ పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి.'**
  String faLoginExpiredBody({required int days});

  /// Banner title: the PIN offline grace is over.
  ///
  /// In te, this message translates to:
  /// **'సెషన్ ముగిసింది'**
  String get faLoginExpiredTitle;

  /// Footer part: the HO helpline.
  ///
  /// In te, this message translates to:
  /// **'HO {phone}'**
  String faLoginFooterHo({required String phone});

  /// Footer part: last sync, e.g. "last synced Today 10:42 AM".
  ///
  /// In te, this message translates to:
  /// **'చివరి సింక్ {day} {time}'**
  String faLoginFooterSynced({required String day, required String time});

  /// Footer part: app version.
  ///
  /// In te, this message translates to:
  /// **'వెర్షన్ {version}'**
  String faLoginFooterVersion({required String version});

  /// Link that opens the dialer with the HO helpline.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ మర్చిపోయారా? HO కి కాల్ చేయండి'**
  String get faLoginForgot;

  /// Info card at the bottom of the login.
  ///
  /// In te, this message translates to:
  /// **'మీ లాగిన్‌ను హెడ్ ఆఫీస్ ఇస్తుంది, అది మీకు మాత్రమే. మీరు బదిలీ అయినా వెళ్ళిపోయినా, HO మీ రైతులను కొత్త FA కి అప్పగిస్తుంది; లాగిన్‌లు ఎప్పుడూ పంచుకోరు.'**
  String get faLoginHoNote;

  /// Banner body: the PIN is locked out.
  ///
  /// In te, this message translates to:
  /// **'మీ పాస్‌వర్డ్‌తో లాగిన్ అయ్యి కొత్త PIN పెట్టుకోండి. మీ రికార్డులు ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి.'**
  String get faLoginLockedBody;

  /// Banner title: the PIN is locked out.
  ///
  /// In te, this message translates to:
  /// **'చాలా సార్లు తప్పు PIN'**
  String get faLoginLockedTitle;

  /// Main button.
  ///
  /// In te, this message translates to:
  /// **'లాగిన్ అవ్వండి'**
  String get faLoginLogIn;

  /// Label of the login ID field.
  ///
  /// In te, this message translates to:
  /// **'లాగిన్ ID'**
  String get faLoginLoginId;

  /// Dialog body: another FA's unsynced records are on this phone.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{ఈ ఫోన్‌లో {code} యొక్క 1 రికార్డు ఇంకా సింక్ కాలేదు.} other{ఈ ఫోన్‌లో {code} యొక్క {count} రికార్డులు ఇంకా సింక్ కాలేదు.}} వేరే FA గా లాగిన్ అయితే అవి తొలగిపోతాయి.'**
  String faLoginOtherFaBody({required String code, required int count});

  /// Dialog button: delete the other FA's records and log in.
  ///
  /// In te, this message translates to:
  /// **'తొలగించి లాగిన్ అవ్వండి'**
  String get faLoginOtherFaConfirm;

  /// Dialog title: another FA's unsynced records are on this phone.
  ///
  /// In te, this message translates to:
  /// **'వేరే FA గా లాగిన్ అవ్వాలా?'**
  String get faLoginOtherFaTitle;

  /// Label of the password field.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్'**
  String get faLoginPassword;

  /// Info line under the password: the PIN is set after login (replaces the design's Remember this device checkbox).
  ///
  /// In te, this message translates to:
  /// **'తర్వాతి సారి ఆఫ్‌లైన్‌లో కూడా {length} అంకెల PIN తో తెరవండి'**
  String faLoginPinNote({required int length});

  /// Banner title: the temporary password is older than 72 hours.
  ///
  /// In te, this message translates to:
  /// **'తాత్కాలిక పాస్‌వర్డ్ గడువు ముగిసింది'**
  String get faLoginTempExpiredTitle;

  /// Button back to the PIN screen while the PIN still works.
  ///
  /// In te, this message translates to:
  /// **'బదులుగా PIN తో తెరవండి'**
  String get faLoginUsePin;

  /// Pill beside the forgot link.
  ///
  /// In te, this message translates to:
  /// **'ఆఫ్‌లైన్‌లో పనిచేస్తుంది'**
  String get faLoginWorksOffline;

  /// Profile card: the FA's villages.
  ///
  /// In te, this message translates to:
  /// **'ప్రాంతం: {area}'**
  String faMeArea({required String area});

  /// Row title.
  ///
  /// In te, this message translates to:
  /// **'HO కి కాల్ చేయండి'**
  String get faMeCallHo;

  /// Row sub-line: the helpline and its hours.
  ///
  /// In te, this message translates to:
  /// **'{phone} · ఉదయం 9 నుంచి సాయంత్రం 6'**
  String faMeCallHoSub({required String phone});

  /// Row title and page title.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ మార్చండి'**
  String get faMeChangePassword;

  /// Row title.
  ///
  /// In te, this message translates to:
  /// **'PIN మార్చండి'**
  String get faMeChangePin;

  /// Change PIN sub-line: the offline grace and what is left of it.
  ///
  /// In te, this message translates to:
  /// **'{days} రోజులు ఆఫ్‌లైన్‌లో పనిచేస్తుంది · {left, plural, one{ఇంకా 1 రోజు} other{ఇంకా {left} రోజులు}}'**
  String faMeChangePinSub({required int days, required int left});

  /// Footer.
  ///
  /// In te, this message translates to:
  /// **'వెర్షన్ {version} · ఫోన్ ID {id}'**
  String faMeFooter({required String id, required String version});

  /// Language row title.
  ///
  /// In te, this message translates to:
  /// **'యాప్ భాష'**
  String get faMeLanguage;

  /// Language row sub-line.
  ///
  /// In te, this message translates to:
  /// **'రైతుల పేర్లు, పంటలు కూడా ఇదే భాషలో'**
  String get faMeLanguageSub;

  /// Banner action.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పుడే లాగిన్ అవ్వండి'**
  String get faMeLogInNow;

  /// Log out warning button.
  ///
  /// In te, this message translates to:
  /// **'అయినా లాగ్ అవుట్'**
  String get faMeLogoutAnyway;

  /// Log out confirm body.
  ///
  /// In te, this message translates to:
  /// **'మళ్ళీ లాగిన్ అవ్వడానికి మీ లాగిన్ ID, పాస్‌వర్డ్, నెట్‌వర్క్ కావాలి.'**
  String get faMeLogoutBody;

  /// Log out confirm title.
  ///
  /// In te, this message translates to:
  /// **'లాగ్ అవుట్ అవ్వాలా?'**
  String get faMeLogoutTitle;

  /// Log out warning, bold part.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రికార్డు ఇంకా సింక్ కాలేదు.} other{{count} రికార్డులు ఇంకా సింక్ కాలేదు.}}'**
  String faMeLogoutUnsynced({required int count});

  /// Log out warning, rest.
  ///
  /// In te, this message translates to:
  /// **'ముందు సింక్ చేయండి. ఇప్పుడు లాగ్ అవుట్ అయితే అవి ఈ ఫోన్‌లోనే ఉండి, మళ్ళీ లాగిన్ అయినప్పుడు పంపబడతాయి.'**
  String get faMeLogoutUnsyncedBody;

  /// Banner body: the server session ended.
  ///
  /// In te, this message translates to:
  /// **'మీరు ఆఫ్‌లైన్‌లో పని కొనసాగించవచ్చు. లాగిన్ అయ్యాక రికార్డులు పంపబడతాయి.'**
  String get faMeNeedsPasswordBody;

  /// Banner: the server session ended.
  ///
  /// In te, this message translates to:
  /// **'సింక్ కోసం పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి'**
  String get faMeNeedsPasswordTitle;

  /// Snack bar after Change password.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ మారింది'**
  String get faMePasswordSaved;

  /// Screen reader label of the profile card.
  ///
  /// In te, this message translates to:
  /// **'మీ ప్రొఫైల్'**
  String get faMeProfile;

  /// Under the count of farmers enrolled this month.
  ///
  /// In te, this message translates to:
  /// **'{month} లో నమోదు'**
  String faMeStatEnrolled({required String month});

  /// Under the farmer count.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{రైతు} other{రైతులు}}'**
  String faMeStatFarmers({required int count});

  /// Under the count of visits done this month.
  ///
  /// In te, this message translates to:
  /// **'{month} లో సందర్శనలు'**
  String faMeStatVisits({required String month});

  /// Header sub-line.
  ///
  /// In te, this message translates to:
  /// **'ప్రొఫైల్, సెట్టింగ్‌లు'**
  String get faMeSubtitle;

  /// Sync row sub-line part.
  ///
  /// In te, this message translates to:
  /// **'చివరి సింక్ {day} {time}'**
  String faMeSyncLast({required String day, required String time});

  /// Sync row sub-line before the first sync.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా సింక్ కాలేదు'**
  String get faMeSyncNever;

  /// Log out warning button.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పుడే సింక్ చేయండి'**
  String get faMeSyncNow;

  /// Sync row sub-line part: queued records.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 వేచి ఉంది} other{{count} వేచి ఉన్నాయి}}'**
  String faMeSyncWaiting({required int count});

  /// Screen reader label of the counts row.
  ///
  /// In te, this message translates to:
  /// **'ఈ నెల'**
  String get faMeThisMonth;

  /// Switch row title.
  ///
  /// In te, this message translates to:
  /// **'ఫోటోలు Wi-Fi లో మాత్రమే అప్‌లోడ్'**
  String get faMeWifi;

  /// Switch sub-line when off.
  ///
  /// In te, this message translates to:
  /// **'ఆఫ్ · ఫోటోలు మొబైల్ డేటాలో కూడా అప్‌లోడ్ అవుతాయి'**
  String get faMeWifiOff;

  /// Switch sub-line when on.
  ///
  /// In te, this message translates to:
  /// **'ఆన్ · రికార్డులు మొబైల్ డేటాలో కూడా సింక్ అవుతాయి'**
  String get faMeWifiOn;

  /// Bottom bar tab: alerts from HO and farmers (badge shows open alerts).
  ///
  /// In te, this message translates to:
  /// **'హెచ్చరికలు'**
  String get faNavAlerts;

  /// Bottom bar tab: the visit calendar.
  ///
  /// In te, this message translates to:
  /// **'క్యాలెండర్'**
  String get faNavCalendar;

  /// Bottom bar tab: enrol a farmer.
  ///
  /// In te, this message translates to:
  /// **'నమోదు'**
  String get faNavEnrol;

  /// Bottom bar tab: farmers near me (list and map).
  ///
  /// In te, this message translates to:
  /// **'రైతులు'**
  String get faNavFarmers;

  /// Label of the confirm field.
  ///
  /// In te, this message translates to:
  /// **'మళ్ళీ టైప్ చేయండి'**
  String get faNewPasswordAgain;

  /// Screen reader label of the back arrow.
  ///
  /// In te, this message translates to:
  /// **'లాగిన్‌కు వెనక్కి'**
  String get faNewPasswordBackLabel;

  /// Label of the current password field (Me, Change password).
  ///
  /// In te, this message translates to:
  /// **'ప్రస్తుత పాస్‌వర్డ్'**
  String get faNewPasswordCurrent;

  /// Label of the field for the password HO gave (shown when the app no longer has it).
  ///
  /// In te, this message translates to:
  /// **'తాత్కాలిక పాస్‌వర్డ్'**
  String get faNewPasswordCurrentTemp;

  /// Dialog body when going back on the first login.
  ///
  /// In te, this message translates to:
  /// **'మీరు లాగ్ అవుట్ అవుతారు. పూర్తి చేయడానికి తాత్కాలిక పాస్‌వర్డ్‌తో మళ్ళీ లాగిన్ అవ్వండి.'**
  String get faNewPasswordLeaveBody;

  /// Dialog title when going back on the first login.
  ///
  /// In te, this message translates to:
  /// **'కొత్త పాస్‌వర్డ్ లేకుండా వెళ్ళాలా?'**
  String get faNewPasswordLeaveTitle;

  /// Note under the button in Me, and the Me row sub-line.
  ///
  /// In te, this message translates to:
  /// **'నెట్‌వర్క్ కావాలి'**
  String get faNewPasswordNeedsNetwork;

  /// Note under the button on the first login.
  ///
  /// In te, this message translates to:
  /// **'నెట్‌వర్క్ కావాలి · ఇది పూర్తయ్యే వరకు యాప్ వాడలేరు'**
  String get faNewPasswordNeedsNetworkFirst;

  /// Label of the new password field.
  ///
  /// In te, this message translates to:
  /// **'కొత్త పాస్‌వర్డ్'**
  String get faNewPasswordNew;

  /// Warning note at the top.
  ///
  /// In te, this message translates to:
  /// **'HO మీకు తాత్కాలిక పాస్‌వర్డ్ ఇచ్చింది. అది 72 గంటలు మాత్రమే పనిచేస్తుంది; మీకు మాత్రమే తెలిసేలా ఇప్పుడే మీ సొంతది పెట్టుకోండి.'**
  String get faNewPasswordNote;

  /// Error: saving failed offline.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ సేవ్ చేయడానికి నెట్‌వర్క్ కావాలి. కనెక్ట్ అయి మళ్ళీ ప్రయత్నించండి.'**
  String get faNewPasswordOffline;

  /// Rule.
  ///
  /// In te, this message translates to:
  /// **'పాత పాస్‌వర్డ్ కాకూడదు'**
  String get faNewPasswordRuleCurrent;

  /// Screen reader suffix of a rule that holds.
  ///
  /// In te, this message translates to:
  /// **'పూర్తయింది'**
  String get faNewPasswordRuleDone;

  /// Rule.
  ///
  /// In te, this message translates to:
  /// **'కనీసం 8 అక్షరాలు'**
  String get faNewPasswordRuleLength;

  /// Rule.
  ///
  /// In te, this message translates to:
  /// **'ఒక అక్షరం, ఒక అంకె ఉండాలి'**
  String get faNewPasswordRuleLetterDigit;

  /// Rule.
  ///
  /// In te, this message translates to:
  /// **'మీ లాగిన్ ID కాకూడదు'**
  String get faNewPasswordRuleLoginId;

  /// Rule.
  ///
  /// In te, this message translates to:
  /// **'రెండు బాక్సుల్లో ఒకటే ఉండాలి'**
  String get faNewPasswordRuleMatch;

  /// Screen reader suffix of a rule that does not hold yet.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా లేదు'**
  String get faNewPasswordRuleNotYet;

  /// Screen reader label of the rule checklist.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ నియమాలు'**
  String get faNewPasswordRules;

  /// Main button.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ సేవ్ చేయండి'**
  String get faNewPasswordSave;

  /// Success body.
  ///
  /// In te, this message translates to:
  /// **'నెట్‌వర్క్‌లో లాగిన్ అయ్యేటప్పుడు {code} తో దీన్ని వాడండి. రోజూ మీ PIN తో యాప్ తెరవండి.'**
  String faNewPasswordSavedBody({required String code});

  /// Success title.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ సేవ్ అయింది'**
  String get faNewPasswordSavedTitle;

  /// Header sub-line.
  ///
  /// In te, this message translates to:
  /// **'దశ 1/2 · మొదటి లాగిన్'**
  String get faNewPasswordStep;

  /// Header title.
  ///
  /// In te, this message translates to:
  /// **'మీ సొంత పాస్‌వర్డ్ పెట్టుకోండి'**
  String get faNewPasswordTitle;

  /// Error: the current password did not match (Me).
  ///
  /// In te, this message translates to:
  /// **'ప్రస్తుత పాస్‌వర్డ్ తప్పు.'**
  String get faNewPasswordWrongCurrent;

  /// Error: the temporary password did not match.
  ///
  /// In te, this message translates to:
  /// **'తాత్కాలిక పాస్‌వర్డ్ తప్పు. HO ఇచ్చిన పాస్‌వర్డ్ టైప్ చేయండి.'**
  String get faNewPasswordWrongTemp;

  /// Button that goes back to the farmer picker.
  ///
  /// In te, this message translates to:
  /// **'రైతును మార్చండి'**
  String get faPlanVisitChangeFarmer;

  /// Section label: which day.
  ///
  /// In te, this message translates to:
  /// **'రోజు'**
  String get faPlanVisitDay;

  /// Save button when moving a visit.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన మార్చండి'**
  String get faPlanVisitMove;

  /// Note when moving a visit: the day it is on now.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పుడు {date} కి ప్లాన్ అయింది'**
  String faPlanVisitMovingFrom({required String date});

  /// Sub-line of the farmer picker list.
  ///
  /// In te, this message translates to:
  /// **'దగ్గర వారు ముందు'**
  String get faPlanVisitNearestFirst;

  /// Farmer picker row of a farmer with no crop to visit (disabled).
  ///
  /// In te, this message translates to:
  /// **'ఇంకా పంట నమోదు కాలేదు'**
  String get faPlanVisitNoCrop;

  /// State card text.
  ///
  /// In te, this message translates to:
  /// **'ముందు {name} పంట నమోదు చేసి, తర్వాత సందర్శన ప్లాన్ చేయండి.'**
  String faPlanVisitNoCropBody({required String name});

  /// State card: the farmer has no plot with a crop.
  ///
  /// In te, this message translates to:
  /// **'సందర్శనకు ఇంకా పంట లేదు'**
  String get faPlanVisitNoCropTitle;

  /// Farmer picker with no results.
  ///
  /// In te, this message translates to:
  /// **'ఈ వెతుకులాటకు రైతు దొరకలేదు'**
  String get faPlanVisitNoMatch;

  /// Date chip that opens a date picker.
  ///
  /// In te, this message translates to:
  /// **'వేరే తేదీ'**
  String get faPlanVisitOtherDate;

  /// Heading of the farmer picker.
  ///
  /// In te, this message translates to:
  /// **'ఏ రైతు దగ్గరకు వెళ్తున్నారు?'**
  String get faPlanVisitPickFarmer;

  /// Section label: which plot.
  ///
  /// In te, this message translates to:
  /// **'పొలం'**
  String get faPlanVisitPlot;

  /// Section label: why the visit is planned.
  ///
  /// In te, this message translates to:
  /// **'ఎందుకు వెళ్తున్నారు'**
  String get faPlanVisitPurpose;

  /// Visit purpose chip.
  ///
  /// In te, this message translates to:
  /// **'సలహా తర్వాత పరిశీలన'**
  String get faPlanVisitPurposeAdviceFollowUp;

  /// Visit purpose chip.
  ///
  /// In te, this message translates to:
  /// **'మొదటి సందర్శన'**
  String get faPlanVisitPurposeFirstVisit;

  /// Hint of the purpose text box.
  ///
  /// In te, this message translates to:
  /// **'ఎందుకో కొన్ని మాటల్లో'**
  String get faPlanVisitPurposeHint;

  /// Visit purpose chip that shows a text box.
  ///
  /// In te, this message translates to:
  /// **'ఇతర'**
  String get faPlanVisitPurposeOther;

  /// Visit purpose chip.
  ///
  /// In te, this message translates to:
  /// **'పురుగు పరిశీలన'**
  String get faPlanVisitPurposePestFollowUp;

  /// Error when Other is picked and the text box is empty.
  ///
  /// In te, this message translates to:
  /// **'ఎందుకు వెళ్తున్నారో రాయండి'**
  String get faPlanVisitPurposeRequired;

  /// Visit purpose chip.
  ///
  /// In te, this message translates to:
  /// **'మట్టి నమూనా'**
  String get faPlanVisitPurposeSoilSample;

  /// Visit purpose chip.
  ///
  /// In te, this message translates to:
  /// **'పంట దశ చూడటం'**
  String get faPlanVisitPurposeStageCheck;

  /// Plan screen title when moving a planned visit to another day.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన రోజు మార్చండి'**
  String get faPlanVisitRescheduleTitle;

  /// Save button.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన సేవ్ చేయండి'**
  String get faPlanVisitSave;

  /// Note under the save button.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్‌లో సేవ్ అయింది · తర్వాతి సింక్‌లో HO కి వెళ్తుంది'**
  String get faPlanVisitSavedOffline;

  /// Search field hint on the farmer picker.
  ///
  /// In te, this message translates to:
  /// **'పేరు లేదా ఫోన్ నంబర్‌తో వెతకండి'**
  String get faPlanVisitSearchHint;

  /// Section label: morning, afternoon or any time.
  ///
  /// In te, this message translates to:
  /// **'సమయం'**
  String get faPlanVisitSlot;

  /// Last step title.
  ///
  /// In te, this message translates to:
  /// **'{name}, మీరు సిద్ధం'**
  String faSetupDoneTitle({required String name});

  /// Download card when the download failed (offline).
  ///
  /// In te, this message translates to:
  /// **'మీ రైతుల వివరాలు ఇంకా డౌన్‌లోడ్ కాలేదు. నెట్‌వర్క్ రాగానే డౌన్‌లోడ్ అవుతాయి.'**
  String get faSetupDownloadFailed;

  /// Download card, after the farmer and plot counts.
  ///
  /// In te, this message translates to:
  /// **'పంట, సలహా జాబితాలు · ఇకపై ఆఫ్‌లైన్‌లో పనిచేస్తుంది'**
  String get faSetupDownloadLists;

  /// Screen reader label of the progress bar.
  ///
  /// In te, this message translates to:
  /// **'డౌన్‌లోడ్ పురోగతి'**
  String get faSetupDownloadProgress;

  /// Download card title.
  ///
  /// In te, this message translates to:
  /// **'మీ ప్రాంతం ఈ ఫోన్‌లో సేవ్ అవుతోంది'**
  String get faSetupDownloadTitle;

  /// Download card status while it runs.
  ///
  /// In te, this message translates to:
  /// **'డౌన్‌లోడ్ అవుతోంది…'**
  String get faSetupDownloading;

  /// Note under the language choice.
  ///
  /// In te, this message translates to:
  /// **'రైతుల పేర్లు, పంటలు, సలహాలు మీరు ఎంచుకున్న భాషలో కనిపిస్తాయి. దీన్ని తర్వాత \"నేను\" లో మార్చుకోవచ్చు.'**
  String get faSetupLanguageNote;

  /// Last step button.
  ///
  /// In te, this message translates to:
  /// **'నా రైతులను తెరవండి'**
  String get faSetupOpenFarmers;

  /// Banner on the language step right after the password change.
  ///
  /// In te, this message translates to:
  /// **'పాస్‌వర్డ్ సేవ్ అయింది. నెట్‌వర్క్‌లో లాగిన్ అయ్యేటప్పుడు {code} తో దీన్ని వాడండి.'**
  String faSetupPasswordSaved({required String code});

  /// PIN step, confirm entry.
  ///
  /// In te, this message translates to:
  /// **'అదే PIN మళ్ళీ టైప్ చేయండి'**
  String get faSetupPinAgain;

  /// Screen reader label of the Back key on the PIN pad.
  ///
  /// In te, this message translates to:
  /// **'భాషకు వెనక్కి'**
  String get faSetupPinBackLabel;

  /// Hint under the dots, confirm entry.
  ///
  /// In te, this message translates to:
  /// **'నిర్ధారణ కోసం ఇంకోసారి'**
  String get faSetupPinHintAgain;

  /// Hint under the dots, first entry.
  ///
  /// In te, this message translates to:
  /// **'ఒకసారికి {days} రోజులు ఆఫ్‌లైన్‌లో పనిచేస్తుంది'**
  String faSetupPinHintFirst({required int days});

  /// Error: the confirm PIN differs.
  ///
  /// In te, this message translates to:
  /// **'PIN లు సరిపోలలేదు. మళ్ళీ మొదలుపెట్టండి.'**
  String get faSetupPinMismatch;

  /// Note at the bottom of the PIN step.
  ///
  /// In te, this message translates to:
  /// **'మీ PIN ఈ ఫోన్‌లోనే ఉంటుంది. 1234, 0000 లేదా మీ పుట్టిన సంవత్సరం వద్దు. {tries} సార్లు తప్పు అయితే పాస్‌వర్డ్ కావాలి.'**
  String faSetupPinNote({required int tries});

  /// PIN step, first entry.
  ///
  /// In te, this message translates to:
  /// **'యాప్ తెరవడానికి PIN ఎంచుకోండి'**
  String get faSetupPinPick;

  /// Error: repeated or sequential PIN.
  ///
  /// In te, this message translates to:
  /// **'సులభంగా ఊహించవచ్చు. వేరేది ఎంచుకోండి.'**
  String get faSetupPinWeak;

  /// Error: the PIN looks like a birth year.
  ///
  /// In te, this message translates to:
  /// **'ఇది సంవత్సరంలా ఉంది. వేరేది ఎంచుకోండి.'**
  String get faSetupPinYear;

  /// Question above the language choice.
  ///
  /// In te, this message translates to:
  /// **'యాప్ ఏ భాషలో ఉండాలి?'**
  String get faSetupQuestion;

  /// Header sub-line on a later password login without a PIN.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్‌ను సిద్ధం చేయండి'**
  String get faSetupStepAgain;

  /// Header sub-line on the first login.
  ///
  /// In te, this message translates to:
  /// **'దశ 2/2 · మొదటి లాగిన్'**
  String get faSetupStepFirst;

  /// Second line of the Telugu choice.
  ///
  /// In te, this message translates to:
  /// **'తెలుగు · సిఫార్సు'**
  String get faSetupTeSub;

  /// Header title, last step.
  ///
  /// In te, this message translates to:
  /// **'అంతా సిద్ధం'**
  String get faSetupTitleDone;

  /// Header title, language step.
  ///
  /// In te, this message translates to:
  /// **'యాప్ భాష'**
  String get faSetupTitleLanguage;

  /// Header title, PIN step.
  ///
  /// In te, this message translates to:
  /// **'{length} అంకెల PIN పెట్టుకోండి'**
  String faSetupTitlePin({required int length});

  /// Button to the PIN step.
  ///
  /// In te, this message translates to:
  /// **'ముందుకు · PIN పెట్టండి'**
  String get faSetupToPin;

  /// Screen reader label of the FA's initials avatar in the header. Tap opens Me.
  ///
  /// In te, this message translates to:
  /// **'నేను · ప్రొఫైల్, సెట్టింగ్‌లు'**
  String get faShellMe;

  /// Screen reader label of the header's sync pill when nothing is waiting.
  ///
  /// In te, this message translates to:
  /// **'అన్ని రికార్డులు సింక్ అయ్యాయి'**
  String get faShellSyncAllSynced;

  /// Screen reader label of the header's sync pill when records are in conflict or were rejected.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రికార్డుకు మీ నిర్ణయం కావాలి} other{{count} రికార్డులకు మీ నిర్ణయం కావాలి}}'**
  String faShellSyncNeedsYou({required int count});

  /// Screen reader label of the header's sync pill while a sync runs.
  ///
  /// In te, this message translates to:
  /// **'సింక్ అవుతోంది'**
  String get faShellSyncRunning;

  /// Screen reader label of the header's sync pill when records are queued. Tap opens Sync.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రికార్డు సింక్ కోసం వేచి ఉంది} other{{count} రికార్డులు సింక్ కోసం వేచి ఉన్నాయి}}'**
  String faShellSyncWaiting({required int count});

  /// Placeholder title of the dev menu (dev builds only) until it is built.
  ///
  /// In te, this message translates to:
  /// **'డెవ్ మెనూ'**
  String get faShellTitleDev;

  /// Placeholder title of Farmer 360 until it is built.
  ///
  /// In te, this message translates to:
  /// **'రైతు'**
  String get faShellTitleFarmer;

  /// Placeholder title of the Me screen until it is built.
  ///
  /// In te, this message translates to:
  /// **'నేను'**
  String get faShellTitleMe;

  /// Placeholder title of Plan visit until it is built.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన ప్లాన్'**
  String get faShellTitlePlanVisit;

  /// Placeholder title of the device removed screen until it is built.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్ తొలగించబడింది'**
  String get faShellTitleRemoved;

  /// Placeholder title of the Sync screen until it is built.
  ///
  /// In te, this message translates to:
  /// **'సింక్'**
  String get faShellTitleSync;

  /// Placeholder title of the visit log until it is built.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన లాగ్'**
  String get faShellTitleVisitLog;

  /// Banner text when nothing waits.
  ///
  /// In te, this message translates to:
  /// **'{time} వరకు అన్నీ HO దగ్గర ఉన్నాయి'**
  String faSyncAllSyncedBody({required String time});

  /// Banner title when nothing waits.
  ///
  /// In te, this message translates to:
  /// **'అన్నీ సింక్ అయ్యాయి'**
  String get faSyncAllSyncedTitle;

  /// Snack bar when another runner holds the sync lease.
  ///
  /// In te, this message translates to:
  /// **'ఇంకో సింక్ జరుగుతోంది. కాసేపట్లో మళ్లీ ప్రయత్నించండి.'**
  String get faSyncBusy;

  /// Button: call the HO helpline.
  ///
  /// In te, this message translates to:
  /// **'HO కి కాల్'**
  String get faSyncCallHo;

  /// Conflict card line for a farmer.
  ///
  /// In te, this message translates to:
  /// **'మీరు ఆఫ్‌లైన్‌లో ఉన్నప్పుడు HO ఈ రైతు వివరాలు మార్చింది'**
  String get faSyncConflictMetaFarmer;

  /// Conflict card line for other records.
  ///
  /// In te, this message translates to:
  /// **'మీరు ఆఫ్‌లైన్‌లో ఉన్నప్పుడు HO దీన్ని మార్చింది'**
  String get faSyncConflictMetaOther;

  /// Conflict card line for a plot.
  ///
  /// In te, this message translates to:
  /// **'మీరు ఆఫ్‌లైన్‌లో ఉన్నప్పుడు HO {plot} ని మార్చింది'**
  String faSyncConflictMetaPlot({required String plot});

  /// Conflict card line when Keep mine is not possible.
  ///
  /// In te, this message translates to:
  /// **'దీనికి HO వెర్షన్ మాత్రమే ఉంచవచ్చు.'**
  String get faSyncConflictOnlyTheirs;

  /// On a conflict card: the FA edited the same plot or farmer again after the conflict; that edit is held in the card until Keep mine (sends it) or Keep HO's (drops it).
  ///
  /// In te, this message translates to:
  /// **'మీ తర్వాతి మార్పు ఈ ఎంపిక కోసం ఆగి ఉంది.'**
  String get faSyncConflictWaiting;

  /// Button that taps a finished or refused row away.
  ///
  /// In te, this message translates to:
  /// **'తీసివేయి'**
  String get faSyncDismiss;

  /// Heading of the records not saved because a refused one they need was refused (dropped before sending, or refused with it).
  ///
  /// In te, this message translates to:
  /// **'దీని వల్ల ఇవి కూడా సేవ్ కాలేదు:'**
  String get faSyncDroppedHeading;

  /// Banner title after a failed sync (the error text follows).
  ///
  /// In te, this message translates to:
  /// **'సింక్ కాలేదు'**
  String get faSyncErrorTitle;

  /// Banner text before the first sync.
  ///
  /// In te, this message translates to:
  /// **'మీ రైతుల వివరాల కోసం ఇప్పుడే సింక్ నొక్కండి.'**
  String get faSyncFirstSyncBody;

  /// Conflict card button.
  ///
  /// In te, this message translates to:
  /// **'నాది ఉంచు'**
  String get faSyncKeepMine;

  /// Conflict card button.
  ///
  /// In te, this message translates to:
  /// **'HO ది ఉంచు'**
  String get faSyncKeepTheirs;

  /// Header sub-line.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పుడే సింక్ అయింది'**
  String get faSyncLastSyncedJustNow;

  /// Header sub-line with the day and time of the last sync.
  ///
  /// In te, this message translates to:
  /// **'చివరి సింక్ {date}, {time}'**
  String faSyncLastSyncedOn({required String date, required String time});

  /// Header sub-line with the time of the last sync today.
  ///
  /// In te, this message translates to:
  /// **'చివరి సింక్ ఈరోజు {time}'**
  String faSyncLastSyncedToday({required String time});

  /// Banner title when records wait and the phone is on mobile data.
  ///
  /// In te, this message translates to:
  /// **'మొబైల్ డేటాలో ఉన్నారు'**
  String get faSyncMobileDataTitle;

  /// Banner text when records need the FA.
  ///
  /// In te, this message translates to:
  /// **'వెర్షన్ ఎంచుకోండి లేదా ఎరుపు వరుసలను తీసివేయండి.'**
  String get faSyncNeedsYouBody;

  /// Banner title: records synced today and records that need the FA.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{{synced} సింక్ అయ్యాయి · 1 మీ కోసం} other{{synced} సింక్ అయ్యాయి · {count} మీ కోసం}}'**
  String faSyncNeedsYouTitle({required int count, required int synced});

  /// Header sub-line and banner title before the first sync.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా సింక్ కాలేదు'**
  String get faSyncNeverSynced;

  /// Banner text when offline.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{మీ పని ఈ ఫోన్‌లో భద్రంగా ఉంది.} one{1 రికార్డ్ ఈ ఫోన్‌లో ఉంది. నెట్‌వర్క్ వచ్చినప్పుడు వెళ్తుంది.} other{{count} రికార్డ్‌లు ఈ ఫోన్‌లో ఉన్నాయి. నెట్‌వర్క్ వచ్చినప్పుడు వెళ్తాయి.}}'**
  String faSyncOfflineBody({required int count});

  /// Banner title when offline.
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు'**
  String get faSyncOfflineTitle;

  /// Row meta: photos of a visit log.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 ఫోటో} other{{count} ఫోటోలు}}'**
  String faSyncPhotosCount({required int count});

  /// Banner text when only photos wait for Wi-Fi.
  ///
  /// In te, this message translates to:
  /// **'{size} ఫోటోలు Wi-Fi కోసం వేచి ఉన్నాయి. రికార్డ్‌లు సింక్ అవుతాయి.'**
  String faSyncPhotosHeld({required String size});

  /// Pill on a conflict card.
  ///
  /// In te, this message translates to:
  /// **'తేడా ఉంది'**
  String get faSyncPillConflict;

  /// Pill on a refused record.
  ///
  /// In te, this message translates to:
  /// **'సేవ్ కాలేదు'**
  String get faSyncPillNotSaved;

  /// Row pill: HO has it.
  ///
  /// In te, this message translates to:
  /// **'సింక్ అయింది'**
  String get faSyncPillSynced;

  /// Row pill: being sent.
  ///
  /// In te, this message translates to:
  /// **'పంపుతోంది'**
  String get faSyncPillUploading;

  /// Row pill: not sent yet.
  ///
  /// In te, this message translates to:
  /// **'వేచి ఉంది'**
  String get faSyncPillWaiting;

  /// Screen reader label of the progress bar.
  ///
  /// In te, this message translates to:
  /// **'అప్‌లోడ్ పురోగతి'**
  String get faSyncProgressLabel;

  /// Refused: the app sent something the server could not read.
  ///
  /// In te, this message translates to:
  /// **'యాప్ దీన్ని పంపలేకపోయింది. HO కి చెప్పండి.'**
  String get faSyncReasonClient;

  /// Refused: the consent OTP proof expired before sending.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి కోడ్ గడువు ముగిసింది. రైతు పేజీలో మళ్లీ అనుమతి తీసుకోండి.'**
  String get faSyncReasonConsentExpired;

  /// Refused: village not in the FA area.
  ///
  /// In te, this message translates to:
  /// **'గ్రామం మీ ప్రాంతంలో లేదు'**
  String get faSyncReasonNotInArea;

  /// Heading above an English reason from the server.
  ///
  /// In te, this message translates to:
  /// **'HO దీన్ని తీసుకోలేదు'**
  String get faSyncReasonOther;

  /// Refused: the farmer is registered with another FA.
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు వేరే FA దగ్గర ఉన్నారు. HO కి కాల్ చేయండి.'**
  String get faSyncReasonOtherFa;

  /// Dropped because the record it depends on was refused.
  ///
  /// In te, this message translates to:
  /// **'పంపలేదు: దీనికి కావాల్సిన రికార్డ్ సేవ్ కాలేదు'**
  String get faSyncReasonParent;

  /// Refused: the server failed 5 times.
  ///
  /// In te, this message translates to:
  /// **'సేవ్ కాలేదు. HO కి తెలియజేశాం.'**
  String get faSyncReasonServer;

  /// Row line after Keep mine.
  ///
  /// In te, this message translates to:
  /// **'మీది ఉంచారు · {value}'**
  String faSyncResolvedMine({required String value});

  /// Added to the resolved line while the kept version waits to go up.
  ///
  /// In te, this message translates to:
  /// **'సింక్‌కు సిద్ధం'**
  String get faSyncResolvedReady;

  /// Row line after Keep HO's.
  ///
  /// In te, this message translates to:
  /// **'HO ది ఉంచారు · {value}'**
  String faSyncResolvedTheirs({required String value});

  /// Banner text with the next retry time.
  ///
  /// In te, this message translates to:
  /// **'మళ్లీ {time} కి ప్రయత్నిస్తాం. లేదా ఇప్పుడే సింక్ నొక్కండి.'**
  String faSyncRetryBody({required String time});

  /// Banner title while waiting for the next retry.
  ///
  /// In te, this message translates to:
  /// **'సర్వర్ అందలేదు'**
  String get faSyncRetryTitle;

  /// Size in kilobytes.
  ///
  /// In te, this message translates to:
  /// **'{size} KB'**
  String faSyncSizeKb({required String size});

  /// Size in megabytes.
  ///
  /// In te, this message translates to:
  /// **'{size} MB'**
  String faSyncSizeMb({required String size});

  /// Main button.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పుడే సింక్ చేయి'**
  String get faSyncSyncNow;

  /// Records synced today.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{ఈరోజు ఏ రికార్డ్ సింక్ కాలేదు} one{ఈరోజు 1 రికార్డ్ సింక్ అయింది} other{ఈరోజు {count} రికార్డ్‌లు సింక్ అయ్యాయి}}'**
  String faSyncSyncedToday({required int count});

  /// Banner text while a sync runs.
  ///
  /// In te, this message translates to:
  /// **'రికార్డ్‌లు పంపుతోంది'**
  String get faSyncSyncingBody;

  /// Banner text while a sync runs with photos.
  ///
  /// In te, this message translates to:
  /// **'రికార్డ్‌లు, {size} ఫోటోలు పంపుతోంది'**
  String faSyncSyncingBodyPhotos({required String size});

  /// Banner title and button label while a sync runs.
  ///
  /// In te, this message translates to:
  /// **'సింక్ అవుతోంది…'**
  String get faSyncSyncingTitle;

  /// Conflict card: the HO value heading.
  ///
  /// In te, this message translates to:
  /// **'HO ది'**
  String get faSyncTheirs;

  /// Record type: an alert acknowledged.
  ///
  /// In te, this message translates to:
  /// **'హెచ్చరిక చదివారు'**
  String get faSyncTypeAlert;

  /// Record type: a call-back closed.
  ///
  /// In te, this message translates to:
  /// **'కాల్ బ్యాక్'**
  String get faSyncTypeCallback;

  /// Record type: a planned visit cancelled.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన రద్దు'**
  String get faSyncTypeCancel;

  /// Record type: a consent record.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి'**
  String get faSyncTypeConsent;

  /// Record type: a farmer enrolment.
  ///
  /// In te, this message translates to:
  /// **'నమోదు'**
  String get faSyncTypeEnrol;

  /// Record type: farmer profile change.
  ///
  /// In te, this message translates to:
  /// **'రైతు వివరాలు'**
  String get faSyncTypeFarmer;

  /// Record type: a visit planned.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన ప్లాన్'**
  String get faSyncTypePlan;

  /// Record type: a plot saved.
  ///
  /// In te, this message translates to:
  /// **'పొలం'**
  String get faSyncTypePlot;

  /// Record type: a crop season started.
  ///
  /// In te, this message translates to:
  /// **'పంట'**
  String get faSyncTypeSeason;

  /// Record type: a visit logged.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన లాగ్'**
  String get faSyncTypeVisit;

  /// Row title when the farmer name is not known.
  ///
  /// In te, this message translates to:
  /// **'రైతు'**
  String get faSyncUnknownFarmer;

  /// Conflict value: the plot has a walked boundary.
  ///
  /// In te, this message translates to:
  /// **'సరిహద్దు నడిచారు'**
  String get faSyncValueBoundaryWalked;

  /// Conflict value: empty.
  ///
  /// In te, this message translates to:
  /// **'ఖాళీ'**
  String get faSyncValueEmpty;

  /// Conflict value: the plot has no boundary.
  ///
  /// In te, this message translates to:
  /// **'సరిహద్దు లేదు'**
  String get faSyncValueNoBoundary;

  /// Conflict value: no farmer photo.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో లేదు'**
  String get faSyncValueNoPhoto;

  /// Conflict value: a farmer photo.
  ///
  /// In te, this message translates to:
  /// **'కొత్త ఫోటో'**
  String get faSyncValuePhoto;

  /// Conflict value: a record version number.
  ///
  /// In te, this message translates to:
  /// **'వెర్షన్ {version}'**
  String faSyncValueVersion({required int version});

  /// Banner text: records waiting.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 రికార్డ్ వేచి ఉంది} other{{count} రికార్డ్‌లు వేచి ఉన్నాయి}}'**
  String faSyncWaitingRecords({required int count});

  /// Banner text: records and photos waiting.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{{size} ఫోటోలు వేచి ఉన్నాయి} one{1 రికార్డ్, {size} ఫోటోలు వేచి ఉన్నాయి} other{{count} రికార్డ్‌లు, {size} ఫోటోలు వేచి ఉన్నాయి}}'**
  String faSyncWaitingRecordsPhotos({required int count, required String size});

  /// Banner title when records wait.
  ///
  /// In te, this message translates to:
  /// **'సింక్ కోసం వేచి ఉన్నాయి'**
  String get faSyncWaitingTitle;

  /// Setting sub-line when off.
  ///
  /// In te, this message translates to:
  /// **'ఆఫ్ · ఫోటోలు మొబైల్ డేటాలో కూడా వెళ్తాయి'**
  String get faSyncWifiOff;

  /// Setting sub-line when on.
  ///
  /// In te, this message translates to:
  /// **'ఆన్ · రికార్డ్‌లు మొబైల్ డేటాలో కూడా సింక్ అవుతాయి'**
  String get faSyncWifiOn;

  /// Setting title.
  ///
  /// In te, this message translates to:
  /// **'ఫోటోలు Wi-Fi లో మాత్రమే పంపు'**
  String get faSyncWifiTitle;

  /// Conflict card: the FA value heading.
  ///
  /// In te, this message translates to:
  /// **'మీది'**
  String get faSyncYours;

  /// Label above the dots.
  ///
  /// In te, this message translates to:
  /// **'మీ {length} అంకెల PIN ఎంటర్ చేయండి'**
  String faUnlockEnterPin({required int length});

  /// Note at the bottom.
  ///
  /// In te, this message translates to:
  /// **'PIN ఆఫ్‌లైన్‌లో {days} రోజులు పనిచేస్తుంది. ఆ తర్వాత నెట్‌వర్క్ వచ్చాక పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి.'**
  String faUnlockGraceNote({required int days});

  /// Tries left before the password is needed.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{ఇంకా 1 ప్రయత్నం ఉంది} other{ఇంకా {count} ప్రయత్నాలు ఉన్నాయి}}'**
  String faUnlockTriesLeft({required int count});

  /// Link to the password login.
  ///
  /// In te, this message translates to:
  /// **'బదులుగా పాస్‌వర్డ్ వాడండి'**
  String get faUnlockUsePassword;

  /// Greeting.
  ///
  /// In te, this message translates to:
  /// **'మళ్ళీ స్వాగతం, {name}'**
  String faUnlockWelcome({required String name});

  /// After a wrong PIN.
  ///
  /// In te, this message translates to:
  /// **'తప్పు PIN'**
  String get faUnlockWrongPin;

  /// Button that adds another issue.
  ///
  /// In te, this message translates to:
  /// **'ఇంకో సమస్య జోడించండి'**
  String get faVisitLogAddIssue;

  /// Saved summary: issues without an advice rule.
  ///
  /// In te, this message translates to:
  /// **'HO చూసుకుంటుంది'**
  String get faVisitLogAdviceHo;

  /// State card: the planned visit was already logged or cancelled.
  ///
  /// In te, this message translates to:
  /// **'ఈ సందర్శన ఇప్పటికే లాగ్ చేశారు'**
  String get faVisitLogAlreadyLogged;

  /// Button on the saved summary and the back arrow label.
  ///
  /// In te, this message translates to:
  /// **'క్యాలెండర్‌కి వెళ్ళండి'**
  String get faVisitLogBackToCalendar;

  /// Snack bar when the camera fails.
  ///
  /// In te, this message translates to:
  /// **'కెమెరా తెరుచుకోలేదు. మళ్ళీ ప్రయత్నించండి.'**
  String get faVisitLogCameraFailed;

  /// Snack bar when Save finds a missing stage or severity.
  ///
  /// In te, this message translates to:
  /// **'కొన్ని వివరాలు లేవు. ఎరుపు గుర్తులు చూడండి.'**
  String get faVisitLogCheckDetails;

  /// Header sub-line part: days after sowing, as in "Ravi K · Plot 1 · Cotton · day 137".
  ///
  /// In te, this message translates to:
  /// **'{count}వ రోజు'**
  String faVisitLogDayAfterSowing({required int count});

  /// Dialog button that leaves without saving.
  ///
  /// In te, this message translates to:
  /// **'వెళ్ళిపోండి'**
  String get faVisitLogDiscard;

  /// Dialog text.
  ///
  /// In te, this message translates to:
  /// **'ఈ సందర్శనకు మీరు ఇచ్చిన వివరాలు పోతాయి.'**
  String get faVisitLogDiscardBody;

  /// Dialog when leaving the visit log with unsaved details.
  ///
  /// In te, this message translates to:
  /// **'సేవ్ చేయకుండా వెళ్ళాలా?'**
  String get faVisitLogDiscardTitle;

  /// Button on the saved summary while the visit is not sent yet.
  ///
  /// In te, this message translates to:
  /// **'ఈ సందర్శన మార్చండి'**
  String get faVisitLogEditVisit;

  /// Switch: was the farmer at the field.
  ///
  /// In te, this message translates to:
  /// **'రైతు ఉన్నారు'**
  String get faVisitLogFarmerPresent;

  /// Sub-line of the farmer present switch.
  ///
  /// In te, this message translates to:
  /// **'మీరు ఒక్కరే పొలం చూస్తే ఆపేయండి'**
  String get faVisitLogFarmerPresentNote;

  /// Footer while the GPS fix is coming.
  ///
  /// In te, this message translates to:
  /// **'GPS వెతుకుతోంది…'**
  String get faVisitLogGpsFinding;

  /// Footer: where the phone is. lat and lng have two decimals.
  ///
  /// In te, this message translates to:
  /// **'{lat}°N {lng}°E'**
  String faVisitLogGpsFix({required String lat, required String lng});

  /// Footer when the GPS fails (the visit saves without a location).
  ///
  /// In te, this message translates to:
  /// **'GPS దొరకలేదు'**
  String get faVisitLogGpsNone;

  /// Screen reader label of the footer button that asks the GPS again.
  ///
  /// In te, this message translates to:
  /// **'GPS మళ్ళీ ప్రయత్నించండి'**
  String get faVisitLogGpsRetry;

  /// Step heading.
  ///
  /// In te, this message translates to:
  /// **'సమస్య'**
  String get faVisitLogIssue;

  /// After the Issue heading.
  ///
  /// In te, this message translates to:
  /// **'{crop} జాబితా నుంచి'**
  String faVisitLogIssueFrom({required String crop});

  /// Screen reader label of the issue picker button.
  ///
  /// In te, this message translates to:
  /// **'సమస్య: {issue}. మార్చండి'**
  String faVisitLogIssueLabel({required String issue});

  /// An issue already added, above the one being edited.
  ///
  /// In te, this message translates to:
  /// **'సమస్య {number} · {issue}'**
  String faVisitLogIssueRow({required String issue, required int number});

  /// Saved summary: an issue and how bad.
  ///
  /// In te, this message translates to:
  /// **'{issue} ({severity})'**
  String faVisitLogIssueSeverity({
    required String issue,
    required String severity,
  });

  /// Screen reader label of the issue type segments.
  ///
  /// In te, this message translates to:
  /// **'సమస్య రకం'**
  String get faVisitLogIssueType;

  /// Language name inside the SMS note.
  ///
  /// In te, this message translates to:
  /// **'ఇంగ్లీష్'**
  String get faVisitLogLangEn;

  /// Language name inside the SMS note.
  ///
  /// In te, this message translates to:
  /// **'తెలుగు'**
  String get faVisitLogLangTe;

  /// Saved summary: more issues or advice.
  ///
  /// In te, this message translates to:
  /// **'+ ఇంకా {count}'**
  String faVisitLogMoreCount({required int count});

  /// Screen reader label of the "+N" thumbnail.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా {count} ఫోటోలు, అన్నీ చూడండి'**
  String faVisitLogMorePhotos({required int count});

  /// Next visit chip: no follow-up visit.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పుడు వద్దు'**
  String get faVisitLogNextNone;

  /// Next visit chip that opens a date picker.
  ///
  /// In te, this message translates to:
  /// **'వేరే తేదీ'**
  String get faVisitLogNextOther;

  /// Step heading.
  ///
  /// In te, this message translates to:
  /// **'తదుపరి సందర్శన'**
  String get faVisitLogNextVisit;

  /// Next visit chip: a week from today.
  ///
  /// In te, this message translates to:
  /// **'+1 వారం'**
  String get faVisitLogNextWeek;

  /// State card text.
  ///
  /// In te, this message translates to:
  /// **'ముందు {name} పంట నమోదు చేసి, తర్వాత సందర్శన లాగ్ చేయండి.'**
  String faVisitLogNoCropBody({required String name});

  /// State card: the farmer has no plot with a crop.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన లాగ్ చేయడానికి పంట లేదు'**
  String get faVisitLogNoCropTitle;

  /// First row of the issue picker: clears the issue.
  ///
  /// In te, this message translates to:
  /// **'సమస్య ఏమీ లేదు'**
  String get faVisitLogNoIssue;

  /// Issue picker with no results.
  ///
  /// In te, this message translates to:
  /// **'ఈ పేరుతో సమస్య లేదు'**
  String get faVisitLogNoIssueMatch;

  /// Shown when the crop has no issues in the masters.
  ///
  /// In te, this message translates to:
  /// **'ఈ పంటకు ఇంకా సమస్యల జాబితా లేదు.'**
  String get faVisitLogNoIssuesListed;

  /// Dialog text.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో ఉంటే HO సలహాను సరిచూడగలరు. ఫోటో లేకుండా సేవ్ చేయాలా?'**
  String get faVisitLogNoPhotoBody;

  /// Dialog title when saving without photos.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా ఫోటోలు లేవు'**
  String get faVisitLogNoPhotoTitle;

  /// Card when the advice is a salt only.
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ ఉత్పత్తి లేదు'**
  String get faVisitLogNoProduct;

  /// Second line of the salt-only card.
  ///
  /// In te, this message translates to:
  /// **'రైతుకు మందు పేరు మాత్రమే కనిపిస్తుంది, బ్రాండ్ కాదు'**
  String get faVisitLogNoProductNote;

  /// Card when the masters have no rule for the issue.
  ///
  /// In te, this message translates to:
  /// **'ఈ సమస్యకు సలహా నియమం లేదు'**
  String get faVisitLogNoRule;

  /// Second line of the no-rule card.
  ///
  /// In te, this message translates to:
  /// **'HO రైతుతో మాట్లాడుతుంది.'**
  String get faVisitLogNoRuleNote;

  /// Saved summary value when nothing was entered.
  ///
  /// In te, this message translates to:
  /// **'ఏమీ లేవు'**
  String get faVisitLogNone;

  /// Saved summary: no next visit.
  ///
  /// In te, this message translates to:
  /// **'ప్లాన్ చేయలేదు'**
  String get faVisitLogNotPlanned;

  /// Button on the saved summary: opens Farmer 360.
  ///
  /// In te, this message translates to:
  /// **'{name} వివరాలు చూడండి'**
  String faVisitLogOpenFarmer({required String name});

  /// Screen reader label of a photo thumbnail.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో {number}'**
  String faVisitLogPhoto({required int number});

  /// After the Photos heading: how many were taken (aim 1 to 3).
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{1 నుంచి 3 తీయండి} one{1 ఫోటో} other{{count} ఫోటోలు}}'**
  String faVisitLogPhotoCount({required int count});

  /// Note when the photo limit is reached.
  ///
  /// In te, this message translates to:
  /// **'గరిష్టంగా {max} ఫోటోలు'**
  String faVisitLogPhotoMax({required int max});

  /// Step heading.
  ///
  /// In te, this message translates to:
  /// **'ఫోటోలు'**
  String get faVisitLogPhotos;

  /// Issue picker button before an issue is picked, and the picker sheet title.
  ///
  /// In te, this message translates to:
  /// **'సమస్య ఎంచుకోండి'**
  String get faVisitLogPickIssue;

  /// Sub-line of the issue picker button before an issue is picked.
  ///
  /// In te, this message translates to:
  /// **'పంట బాగుంటే వదిలేయండి'**
  String get faVisitLogPickIssueHint;

  /// Salt picker sheet title.
  ///
  /// In te, this message translates to:
  /// **'మందు ఎంచుకోండి'**
  String get faVisitLogPickSalt;

  /// Plot chips when the farmer has more than one crop.
  ///
  /// In te, this message translates to:
  /// **'పొలం'**
  String get faVisitLogPlot;

  /// Footer part.
  ///
  /// In te, this message translates to:
  /// **'రైతు లేరు'**
  String get faVisitLogPresentNo;

  /// Footer part.
  ///
  /// In te, this message translates to:
  /// **'రైతు ఉన్నారు ✓'**
  String get faVisitLogPresentYes;

  /// Card when the advice has a Shanmukha product.
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ ఉత్పత్తి: {name}'**
  String faVisitLogProduct({required String name});

  /// Second line of the product card.
  ///
  /// In te, this message translates to:
  /// **'దగ్గరి డీలర్లతో పాటు రైతుకు కనిపిస్తుంది'**
  String get faVisitLogProductNote;

  /// Screen reader label of the remove button on an added issue.
  ///
  /// In te, this message translates to:
  /// **'{issue} సమస్య తీసేయండి'**
  String faVisitLogRemoveIssue({required String issue});

  /// Button on a photo in the photos sheet.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో {number} తీసేయండి'**
  String faVisitLogRemovePhoto({required int number});

  /// Saved summary row label.
  ///
  /// In te, this message translates to:
  /// **'సలహా'**
  String get faVisitLogRowAdvice;

  /// Saved summary row label.
  ///
  /// In te, this message translates to:
  /// **'సమస్యలు'**
  String get faVisitLogRowIssues;

  /// Saved summary row label.
  ///
  /// In te, this message translates to:
  /// **'తదుపరి సందర్శన'**
  String get faVisitLogRowNext;

  /// Saved summary row label.
  ///
  /// In te, this message translates to:
  /// **'ఫోటోలు'**
  String get faVisitLogRowPhotos;

  /// Saved summary row label.
  ///
  /// In te, this message translates to:
  /// **'దశ'**
  String get faVisitLogRowStage;

  /// Step heading.
  ///
  /// In te, this message translates to:
  /// **'మందు సూచన'**
  String get faVisitLogSalt;

  /// Recommend salt step before an issue is picked.
  ///
  /// In te, this message translates to:
  /// **'ముందు సమస్య ఎంచుకోండి'**
  String get faVisitLogSaltAfterIssue;

  /// Screen reader label of the salt picker button.
  ///
  /// In te, this message translates to:
  /// **'మందు: {salt}. మార్చండి'**
  String faVisitLogSaltLabel({required String salt});

  /// Saved summary: advice without a Shanmukha product.
  ///
  /// In te, this message translates to:
  /// **'{salt} · మందు పేరు మాత్రమే'**
  String faVisitLogSaltOnly({required String salt});

  /// Main save button.
  ///
  /// In te, this message translates to:
  /// **'సేవ్ చేసి రైతుకు చెప్పండి'**
  String get faVisitLogSave;

  /// Save button while editing a saved visit.
  ///
  /// In te, this message translates to:
  /// **'మార్పులు సేవ్ చేయండి'**
  String get faVisitLogSaveChanges;

  /// Dialog button.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో లేకుండా సేవ్'**
  String get faVisitLogSaveWithoutPhotos;

  /// Saved summary sub-line before sync.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్‌లో సేవ్ అయింది · తర్వాతి సింక్‌లో HO కి వెళ్తుంది'**
  String get faVisitLogSavedPending;

  /// Saved summary sub-line after sync.
  ///
  /// In te, this message translates to:
  /// **'సింక్ అయింది · HO కి చేరింది'**
  String get faVisitLogSavedSynced;

  /// Saved summary title.
  ///
  /// In te, this message translates to:
  /// **'సందర్శన సేవ్ అయింది'**
  String get faVisitLogSavedTitle;

  /// Search field in the issue picker.
  ///
  /// In te, this message translates to:
  /// **'సమస్య వెతకండి'**
  String get faVisitLogSearchIssues;

  /// Screen reader label of the severity buttons.
  ///
  /// In te, this message translates to:
  /// **'ఎంత తీవ్రంగా ఉంది?'**
  String get faVisitLogSeverity;

  /// Error when an issue has no severity.
  ///
  /// In te, this message translates to:
  /// **'తీవ్రత ఎంచుకోండి'**
  String get faVisitLogSeverityRequired;

  /// Saved summary note when no issue had an advice rule.
  ///
  /// In te, this message translates to:
  /// **'పంపడానికి ఇంకా సలహా లేదు. సమస్యల గురించి HO చూసుకుంటుంది.'**
  String get faVisitLogSmsNone;

  /// Saved summary note before sync.
  ///
  /// In te, this message translates to:
  /// **'ఇది సింక్ అయ్యాక {name} గారికి సలహా {language}లో SMS ద్వారా, ఆర్బిట్ యాప్‌లో వెళ్తుంది.'**
  String faVisitLogSmsPending({required String language, required String name});

  /// Saved summary note after sync.
  ///
  /// In te, this message translates to:
  /// **'{name} గారికి సలహా {language}లో SMS ద్వారా, ఆర్బిట్ యాప్‌లో వెళ్ళింది.'**
  String faVisitLogSmsSent({required String language, required String name});

  /// Step heading.
  ///
  /// In te, this message translates to:
  /// **'పంట దశ'**
  String get faVisitLogStage;

  /// Error when no stage is picked.
  ///
  /// In te, this message translates to:
  /// **'పంట దశ ఎంచుకోండి'**
  String get faVisitLogStageRequired;

  /// Dialog button that stays.
  ///
  /// In te, this message translates to:
  /// **'ఇక్కడే ఉండండి'**
  String get faVisitLogStay;

  /// Numbered step heading, e.g. "1 · Photos".
  ///
  /// In te, this message translates to:
  /// **'{number} · {title}'**
  String faVisitLogStep({required int number, required String title});

  /// After the Recommend salt heading when the masters suggest a salt.
  ///
  /// In te, this message translates to:
  /// **'మాస్టర్ సూచించింది'**
  String get faVisitLogSuggested;

  /// Screen reader label of the saved summary card.
  ///
  /// In te, this message translates to:
  /// **'సేవ్ చేసిన వివరాలు'**
  String get faVisitLogSummary;

  /// Camera button label (screen reader) and dialog button.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో తీయండి'**
  String get faVisitLogTakePhoto;

  /// Issue type segment.
  ///
  /// In te, this message translates to:
  /// **'పోషక లోపం'**
  String get faVisitLogTypeDeficiency;

  /// Issue type segment.
  ///
  /// In te, this message translates to:
  /// **'తెగులు'**
  String get faVisitLogTypeDisease;

  /// Issue type segment.
  ///
  /// In te, this message translates to:
  /// **'పురుగు'**
  String get faVisitLogTypePest;

  /// Footer part: saving does not need the internet.
  ///
  /// In te, this message translates to:
  /// **'నెట్ లేకున్నా పనిచేస్తుంది'**
  String get faVisitLogWorksOffline;

  /// Action error: a day in the past (or a visit time in the future).
  ///
  /// In te, this message translates to:
  /// **'ఈ రోజు లేదా తర్వాతి రోజు ఎంచుకోండి.'**
  String get faVisitsErrorInvalidDate;

  /// Action error: no snapshot yet.
  ///
  /// In te, this message translates to:
  /// **'మీ రైతుల వివరాలు ఇంకా ఈ ఫోన్‌లో లేవు. ముందు సింక్ చేయండి.'**
  String get faVisitsErrorNoData;

  /// Action error: no active season.
  ///
  /// In te, this message translates to:
  /// **'ఈ పొలంలో ఇంకా పంట లేదు. ముందు పంట నమోదు చేయండి.'**
  String get faVisitsErrorNoSeason;

  /// Action error: the queued visit log was sent.
  ///
  /// In te, this message translates to:
  /// **'ఈ సందర్శన ఇప్పటికే HO కి వెళ్ళింది, ఇక మార్చలేరు.'**
  String get faVisitsErrorNotEditable;

  /// Action error: something referred to is gone.
  ///
  /// In te, this message translates to:
  /// **'ఈ రైతు, పొలం లేదా సందర్శన ఇప్పుడు ఈ ఫోన్‌లో లేదు. మళ్ళీ తెరవండి.'**
  String get faVisitsErrorNotFound;

  /// Action error: the visit is not planned any more.
  ///
  /// In te, this message translates to:
  /// **'ఈ సందర్శన ఇప్పటికే పూర్తయింది లేదా రద్దయింది.'**
  String get faVisitsErrorNotPlanned;

  /// Action error: a required value is empty.
  ///
  /// In te, this message translates to:
  /// **'కొన్ని వివరాలు లేవు.'**
  String get faVisitsErrorRequired;

  /// Action error: more than 20 photos or issues.
  ///
  /// In te, this message translates to:
  /// **'ఫోటోలు లేదా సమస్యలు చాలా ఎక్కువ. 20 వరకే ఉంచండి.'**
  String get faVisitsErrorTooMany;

  /// Byline (wireframe "Advised by Suresh · 12 Oct").
  ///
  /// In te, this message translates to:
  /// **'{name} గారి సలహా · {date}'**
  String farmerAdviceAdvisedBy({required DateTime date, required String name});

  /// F8b instruction (wireframe; the cashback sentence is dropped until Phase 2).
  ///
  /// In te, this message translates to:
  /// **'దుకాణంలో ఈ పేరు అడగండి. సందేహం ఉంటే FA కి కాల్ చేయండి.'**
  String get farmerAdviceAskAtShopBody;

  /// F8b label above the salt name (wireframe "ASK FOR THIS AT THE SHOP").
  ///
  /// In te, this message translates to:
  /// **'దుకాణంలో ఇది అడగండి'**
  String get farmerAdviceAskAtShopLabel;

  /// Dealer distance; km is pre-formatted, e.g. 1.8.
  ///
  /// In te, this message translates to:
  /// **'{km} కి.మీ'**
  String farmerAdviceDealerDistance({required String km});

  /// Dealer list without location permission.
  ///
  /// In te, this message translates to:
  /// **'దగ్గర దుకాణాలు చూడడానికి లొకేషన్ అనుమతి ఇవ్వండి'**
  String get farmerAdviceLocationNeeded;

  /// Dealer list header (wireframe).
  ///
  /// In te, this message translates to:
  /// **'దగ్గర దుకాణాలు'**
  String get farmerAdviceNearbyDealers;

  /// Empty dealer list.
  ///
  /// In te, this message translates to:
  /// **'దగ్గరలో దుకాణాలు దొరకలేదు'**
  String get farmerAdviceNoDealers;

  /// F8b line (wireframe).
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ మందు లేదు'**
  String get farmerAdviceNoProduct;

  /// F8a title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'ఈ మందు కొనండి'**
  String get farmerAdviceProductTitle;

  /// F8b title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'FA సలహా'**
  String get farmerAdviceSaltTitle;

  /// F8a button that opens the full-screen card (wireframe).
  ///
  /// In te, this message translates to:
  /// **'ఈ కార్డు దుకాణంలో చూపించండి'**
  String get farmerAdviceShowAtShop;

  /// Full-screen card header (wireframe).
  ///
  /// In te, this message translates to:
  /// **'దుకాణదారుకు చూపించండి'**
  String get farmerAdviceShowShopkeeper;

  /// Neutral advice header while loading, pending or not found (promises neither a product nor a salt).
  ///
  /// In te, this message translates to:
  /// **'సలహా'**
  String get farmerAdviceTitle;

  /// Voice prompt for an advice item the FA has not filled in yet.
  ///
  /// In te, this message translates to:
  /// **'దీనికి సలహా ఇంకా రాలేదు. మీ FA తర్వాత చెబుతారు. ఇప్పుడే అడగాలంటే మీ FA కి కాల్ చేయండి.'**
  String get farmerAdviceVoiceHelpPending;

  /// Voice prompt for F8a.
  ///
  /// In te, this message translates to:
  /// **'ఇది మీ FA చెప్పిన షణ్ముఖ మందు, ఎకరానికి ఎంత వేయాలో కింద ఉంది. ఈ కార్డు దుకాణంలో చూపించండి.'**
  String get farmerAdviceVoiceHelpProduct;

  /// Voice prompt for F8b.
  ///
  /// In te, this message translates to:
  /// **'ఈ సమస్యకు షణ్ముఖ మందు లేదు. దుకాణంలో ఈ పేరు అడగండి. సందేహం ఉంటే FA కి కాల్ చేయండి.'**
  String get farmerAdviceVoiceHelpSalt;

  /// Progress line when the crop has no duration.
  ///
  /// In te, this message translates to:
  /// **'{day}వ రోజు'**
  String farmerCalendarDay({required int day});

  /// Progress line (wireframe "day 137 of about 170").
  ///
  /// In te, this message translates to:
  /// **'{day}వ రోజు (మొత్తం సుమారు {total} రోజులు)'**
  String farmerCalendarDayOf({required int day, required int total});

  /// No active season.
  ///
  /// In te, this message translates to:
  /// **'పంట మొదలుపెడితే క్యాలెండర్ కనిపిస్తుంది.'**
  String get farmerCalendarNoSeason;

  /// Season without a sowing date; only the FA can add it.
  ///
  /// In te, this message translates to:
  /// **'విత్తిన రోజు మీ FA కి చెప్పండి. అప్పుడు క్యాలెండర్ కనిపిస్తుంది.'**
  String get farmerCalendarNoSowingDate;

  /// Marker on the current stage (wireframe "(now)").
  ///
  /// In te, this message translates to:
  /// **'ఇప్పుడు'**
  String get farmerCalendarNow;

  /// Tasks section header (wireframe).
  ///
  /// In te, this message translates to:
  /// **'రాబోయే పనులు'**
  String get farmerCalendarTasks;

  /// Shown in place of the task list (calendar module not built).
  ///
  /// In te, this message translates to:
  /// **'చేయాల్సిన పనులు, SMS రిమైండర్లు త్వరలో వస్తాయి.'**
  String get farmerCalendarTasksLater;

  /// F11 title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'పంట క్యాలెండర్'**
  String get farmerCalendarTitle;

  /// Voice prompt for F11.
  ///
  /// In te, this message translates to:
  /// **'మీ పంట ఏ దశలో ఉందో ఇక్కడ చూడవచ్చు. విత్తిన రోజు నుంచి ఎన్ని రోజులైందో పైన ఉంది.'**
  String get farmerCalendarVoiceHelp;

  /// Primary button: grants the programme consent (wireframe).
  ///
  /// In te, this message translates to:
  /// **'సరే, ఒప్పుకుంటున్నాను'**
  String get farmerConsentAgree;

  /// Shown after "Not now".
  ///
  /// In te, this message translates to:
  /// **'మీ అనుమతి లేకుండా సలహాలు పంపలేము. ఎప్పుడైనా ఒప్పుకోవచ్చు.'**
  String get farmerConsentDeclined;

  /// Secondary button: does not grant.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పుడు కాదు'**
  String get farmerConsentNotNow;

  /// Consent point 3 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'\'నా పొలం\' లో ఎప్పుడైనా మార్చుకోవచ్చు'**
  String get farmerConsentPointChange;

  /// Consent point 2 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'ఇతర కంపెనీలకు మీరు ఒప్పుకుంటేనే పంపుతాం'**
  String get farmerConsentPointPartners;

  /// Consent point 1 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'మీ పేరు, ఫోన్, పొలం వివరాలు షణ్ముఖ వద్ద భద్రంగా ఉంటాయి'**
  String get farmerConsentPointSafe;

  /// Programme purpose, shown above the three points (notice_version is bundled with this text).
  ///
  /// In te, this message translates to:
  /// **'మీ పంటకు సలహాలు ఇవ్వడానికి, మీ FA మీ పొలానికి రావడానికి మీ వివరాలు వాడుతాం.'**
  String get farmerConsentPurpose;

  /// Snackbar after the consent is stored.
  ///
  /// In te, this message translates to:
  /// **'మీ అనుమతి సేవ్ అయింది'**
  String get farmerConsentSaved;

  /// Consent screen title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'మీ అనుమతి'**
  String get farmerConsentTitle;

  /// Voice prompt that reads the whole consent notice (purpose first); audio_played is sent when it plays to the end.
  ///
  /// In te, this message translates to:
  /// **'మీ పంటకు సలహాలు ఇవ్వడానికి, మీ FA మీ పొలానికి రావడానికి మీ వివరాలు వాడుతాం. మీ పేరు, ఫోన్, పొలం వివరాలు షణ్ముఖ వద్ద భద్రంగా ఉంటాయి. ఇతర కంపెనీలకు మీరు ఒప్పుకుంటేనే పంపుతాం. \'నా పొలం\' లో ఎప్పుడైనా మార్చుకోవచ్చు. ఒప్పుకుంటే, సరే నొక్కండి.'**
  String get farmerConsentVoiceHelp;

  /// Voice prompt for the "Not now" sheet of the consent screen.
  ///
  /// In te, this message translates to:
  /// **'మీ అనుమతి లేకుండా సలహాలు పంపలేము. ఎప్పుడైనా ఒప్పుకోవచ్చు. మాట్లాడాలంటే సహాయ కేంద్రానికి కాల్ చేయండి.'**
  String get farmerConsentVoiceHelpDeclined;

  /// Grants the consent.
  ///
  /// In te, this message translates to:
  /// **'ఒప్పుకోండి'**
  String get farmerConsentsAgree;

  /// When the consent was last set.
  ///
  /// In te, this message translates to:
  /// **'{date} న మార్చారు'**
  String farmerConsentsChangedOn({required DateTime date});

  /// What the loyalty consent covers.
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ బహుమతులు, క్యాష్‌బ్యాక్'**
  String get farmerConsentsDescLoyalty;

  /// What the programme consent covers.
  ///
  /// In te, this message translates to:
  /// **'మీ పంటకు సలహాలు, FA సందర్శనలు'**
  String get farmerConsentsDescProgramme;

  /// What the schemes_finance consent covers.
  ///
  /// In te, this message translates to:
  /// **'పథకాలు, బీమా, రుణాల కోసం మీ వివరాలు'**
  String get farmerConsentsDescSchemesFinance;

  /// What the soil_partner consent covers.
  ///
  /// In te, this message translates to:
  /// **'మట్టి పరీక్ష కంపెనీకి మీ పొలం లొకేషన్'**
  String get farmerConsentsDescSoilPartner;

  /// Consents screen when the list came back empty; Try again below.
  ///
  /// In te, this message translates to:
  /// **'మీ అనుమతులు చూపించలేకపోయాం'**
  String get farmerConsentsEmpty;

  /// Consents list subtitle (wireframe).
  ///
  /// In te, this message translates to:
  /// **'ఎవరు ఏమి చూడవచ్చు'**
  String get farmerConsentsSubtitle;

  /// Consents list title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'అనుమతులు'**
  String get farmerConsentsTitle;

  /// Voice prompt for the consents list.
  ///
  /// In te, this message translates to:
  /// **'మీ వివరాలు ఎవరు చూడవచ్చో ఇక్కడ ఉంది. ఏది కావాలంటే అది ఒప్పుకోవచ్చు, ఎప్పుడైనా వెనక్కి తీసుకోవచ్చు.'**
  String get farmerConsentsVoiceHelp;

  /// Withdraws the consent.
  ///
  /// In te, this message translates to:
  /// **'వెనక్కి తీసుకోండి'**
  String get farmerConsentsWithdraw;

  /// Withdraw dialog body, under the purpose name.
  ///
  /// In te, this message translates to:
  /// **'ఇక్కడే ఎప్పుడైనా మళ్ళీ ఒప్పుకోవచ్చు.'**
  String get farmerConsentsWithdrawBody;

  /// Voice prompt for the withdraw dialog of the programme consent (with the warning).
  ///
  /// In te, this message translates to:
  /// **'ఈ అనుమతి వెనక్కి తీసుకోవాలా? ఇది తీసేస్తే సలహాలు, FA సందర్శనలు ఆగిపోవచ్చు. ఇక్కడే ఎప్పుడైనా మళ్ళీ ఒప్పుకోవచ్చు.'**
  String get farmerConsentsWithdrawProgrammeVoice;

  /// Extra warning when withdrawing the programme consent.
  ///
  /// In te, this message translates to:
  /// **'ఇది తీసేస్తే సలహాలు, FA సందర్శనలు ఆగిపోవచ్చు.'**
  String get farmerConsentsWithdrawProgrammeWarning;

  /// Withdraw confirmation title.
  ///
  /// In te, this message translates to:
  /// **'అనుమతి వెనక్కి తీసుకోవాలా?'**
  String get farmerConsentsWithdrawTitle;

  /// Voice prompt for the withdraw-consent dialog (any purpose but programme).
  ///
  /// In te, this message translates to:
  /// **'ఈ అనుమతి వెనక్కి తీసుకోవాలా? ఇక్కడే ఎప్పుడైనా మళ్ళీ ఒప్పుకోవచ్చు.'**
  String get farmerConsentsWithdrawVoice;

  /// Button to add a plot (wireframe).
  ///
  /// In te, this message translates to:
  /// **'పొలం జోడించండి'**
  String get farmerFarmAddPlot;

  /// Profile name action.
  ///
  /// In te, this message translates to:
  /// **'పేరు మార్చండి'**
  String get farmerFarmChangeName;

  /// Voice prompt for the change-name dialog.
  ///
  /// In te, this message translates to:
  /// **'మీ పేరు టైప్ చేసి, \'సేవ్\' బటన్ నొక్కండి.'**
  String get farmerFarmChangeNameVoice;

  /// Profile photo action.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో మార్చండి'**
  String get farmerFarmChangePhoto;

  /// Plot action.
  ///
  /// In te, this message translates to:
  /// **'పంట ముగించండి'**
  String get farmerFarmCloseSeason;

  /// Row label (wireframe).
  ///
  /// In te, this message translates to:
  /// **'అనుమతులు'**
  String get farmerFarmConsents;

  /// Row subtitle (wireframe "who can see what").
  ///
  /// In te, this message translates to:
  /// **'ఎవరు ఏమి చూడవచ్చు'**
  String get farmerFarmConsentsHint;

  /// Photo source option (wireframe F9b).
  ///
  /// In te, this message translates to:
  /// **'గ్యాలరీ'**
  String get farmerFarmFromGallery;

  /// Row label; dials the helpline (wireframe).
  ///
  /// In te, this message translates to:
  /// **'సహాయం'**
  String get farmerFarmHelp;

  /// Row label (wireframe).
  ///
  /// In te, this message translates to:
  /// **'భాష'**
  String get farmerFarmLanguage;

  /// Snackbar after the language changes.
  ///
  /// In te, this message translates to:
  /// **'భాష మారింది'**
  String get farmerFarmLanguageChanged;

  /// Plot without an active season.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా పంట వేయలేదు'**
  String get farmerFarmNoCrop;

  /// Snackbar after the photo upload.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో మారింది'**
  String get farmerFarmPhotoUpdated;

  /// Default plot name when the plot has no label (wireframe "పొలం 1").
  ///
  /// In te, this message translates to:
  /// **'పొలం {number}'**
  String farmerFarmPlot({required int number});

  /// Section header above the plot cards.
  ///
  /// In te, this message translates to:
  /// **'నా పొలాలు'**
  String get farmerFarmPlots;

  /// Sign-out confirmation body.
  ///
  /// In te, this message translates to:
  /// **'మళ్ళీ లాగిన్ అవ్వడానికి OTP కావాలి.'**
  String get farmerFarmSignOutBody;

  /// Sign-out confirmation title.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్ నుంచి లాగౌట్ అవ్వాలా?'**
  String get farmerFarmSignOutTitle;

  /// Voice prompt for the sign-out confirmation.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్ నుంచి లాగౌట్ అవ్వాలా? మళ్ళీ లాగిన్ అవ్వడానికి OTP కావాలి.'**
  String get farmerFarmSignOutVoice;

  /// Plot row line (wireframe "sown 12 Jun").
  ///
  /// In te, this message translates to:
  /// **'{date} న విత్తారు'**
  String farmerFarmSownOn({required DateTime date});

  /// Plot row and crop calendar line when the sowing date is still ahead (counterpart of sown_on).
  ///
  /// In te, this message translates to:
  /// **'{date} న విత్తుతారు'**
  String farmerFarmSowsOn({required DateTime date});

  /// Plot action.
  ///
  /// In te, this message translates to:
  /// **'పంట మొదలుపెట్టండి'**
  String get farmerFarmStartSeason;

  /// Photo source option.
  ///
  /// In te, this message translates to:
  /// **'ఫోటో తీయండి'**
  String get farmerFarmTakePhoto;

  /// F10 title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'నా పొలం'**
  String get farmerFarmTitle;

  /// Note under the village (not editable here).
  ///
  /// In te, this message translates to:
  /// **'గ్రామం మార్చాలంటే మీ FA కి చెప్పండి'**
  String get farmerFarmVillageChangeNote;

  /// Voice prompt for F10.
  ///
  /// In te, this message translates to:
  /// **'ఇక్కడ మీ పేరు, ఫోటో, పొలాలు, భాష, అనుమతులు ఉన్నాయి. కొత్త పొలం జోడించవచ్చు, పంట మొదలుపెట్టవచ్చు.'**
  String get farmerFarmVoiceHelp;

  /// Row label; opens F3 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'మీ FA'**
  String get farmerFarmYourFa;

  /// Snack bar when the phone has no dialer (tablet); shows the number to call by hand. Also used on Home.
  ///
  /// In te, this message translates to:
  /// **'ఫోన్ యాప్ తెరుచుకోలేదు. {phone} కు కాల్ చేయండి.'**
  String farmerFasCallFailed({required String phone});

  /// Hint above the list.
  ///
  /// In te, this message translates to:
  /// **'మీ FA కి నేరుగా కాల్ చేయడానికి కాల్ నొక్కండి'**
  String get farmerFasCallHint;

  /// Call-back request button (wireframe).
  ///
  /// In te, this message translates to:
  /// **'నాకు కాల్ చేయండి'**
  String get farmerFasCallback;

  /// Snackbar after Undo.
  ///
  /// In te, this message translates to:
  /// **'అభ్యర్థన రద్దు చేశాం'**
  String get farmerFasCallbackCancelled;

  /// Call-back sent title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'అభ్యర్థన పంపాం'**
  String get farmerFasCallbackSent;

  /// Call-back sent line (wireframe "Suresh will call you today").
  ///
  /// In te, this message translates to:
  /// **'{name} గారు ఈ రోజు మీకు కాల్ చేస్తారు'**
  String farmerFasCallbackSentBody({required String name});

  /// Count under the tabs.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{ఇక్కడ ఇంకా FA లు లేరు} one{1 FA} other{{count} FA లు}}'**
  String farmerFasCount({required int count});

  /// FA card line.
  ///
  /// In te, this message translates to:
  /// **'భాషలు: {languages}'**
  String farmerFasLanguages({required String languages});

  /// Badge on the lead FA for the area.
  ///
  /// In te, this message translates to:
  /// **'ముఖ్య FA'**
  String get farmerFasLead;

  /// F3 title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'FA లు'**
  String get farmerFasTitle;

  /// Voice prompt for F3.
  ///
  /// In te, this message translates to:
  /// **'మీ ప్రాంతంలోని FA లు ఇక్కడ ఉన్నారు. కాల్ నొక్కితే నేరుగా మాట్లాడవచ్చు. నాకు కాల్ చేయండి నొక్కితే మీ FA మీకు కాల్ చేస్తారు.'**
  String get farmerFasVoiceHelp;

  /// Snack bar when WhatsApp could not be opened.
  ///
  /// In te, this message translates to:
  /// **'ఈ ఫోన్‌లో WhatsApp తెరుచుకోలేదు.'**
  String get farmerFasWhatsappFailed;

  /// Text pre-filled in the WhatsApp chat (wa.me ?text=).
  ///
  /// In te, this message translates to:
  /// **'నమస్కారం, నేను {name}, {village} రైతును.'**
  String farmerFasWhatsappMessage({
    required String name,
    required String village,
  });

  /// FA card line; hours text comes from the server.
  ///
  /// In te, this message translates to:
  /// **'పని వేళలు: {hours}'**
  String farmerFasWorkingHours({required String hours});

  /// Badge on the farmer's own FA (wireframe).
  ///
  /// In te, this message translates to:
  /// **'మీ FA'**
  String get farmerFasYourFa;

  /// Plot area as acres and guntas, spelled out; a zero part is left out ("2 ఎకరాలు", "20 గుంటలు", "2 ఎకరాలు 20 గుంటలు").
  ///
  /// In te, this message translates to:
  /// **'{acres, plural, =0{{guntas, plural, =1{1 గుంట} other{{guntas} గుంటలు}}} =1{{guntas, plural, =0{1 ఎకరం} =1{1 ఎకరం 1 గుంట} other{1 ఎకరం {guntas} గుంటలు}}} other{{guntas, plural, =0{{acres} ఎకరాలు} =1{{acres} ఎకరాలు 1 గుంట} other{{acres} ఎకరాలు {guntas} గుంటలు}}}}'**
  String farmerHomeArea({required int acres, required int guntas});

  /// FA card subtitle.
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ FA'**
  String get farmerHomeFaVerified;

  /// Home greeting (wireframe "నమస్కారం, రవి").
  ///
  /// In te, this message translates to:
  /// **'నమస్కారం, {name}'**
  String farmerHomeGreeting({required String name});

  /// Sheet body for a locked tile.
  ///
  /// In te, this message translates to:
  /// **'ఇది మొదలవగానే SMS ద్వారా మీకు చెబుతాం.'**
  String get farmerHomeLockedBody;

  /// Sheet shown when a locked tile is tapped.
  ///
  /// In te, this message translates to:
  /// **'ఈ సేవ త్వరలో వస్తుంది'**
  String get farmerHomeLockedTitle;

  /// Voice prompt for the coming-soon sheet of a locked Home tile.
  ///
  /// In te, this message translates to:
  /// **'ఈ సేవ త్వరలో వస్తుంది. మొదలవగానే SMS ద్వారా మీకు చెబుతాం.'**
  String get farmerHomeLockedVoice;

  /// Link from the FA card to F3.
  ///
  /// In te, this message translates to:
  /// **'FA లను చూడండి'**
  String get farmerHomeLookForFas;

  /// Label above the next visit date (wireframe F4).
  ///
  /// In te, this message translates to:
  /// **'FA వచ్చే రోజు'**
  String get farmerHomeNextVisit;

  /// Shown when there is no planned visit.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా రోజు నిర్ణయించలేదు'**
  String get farmerHomeNoNextVisit;

  /// Home card body when the farmer has no plot yet; the button opens My farm.
  ///
  /// In te, this message translates to:
  /// **'\'నా పొలం\' పేజీలో మీ పొలం జోడించండి. అప్పుడు FA మీ పంటకు సలహా ఇస్తారు.'**
  String get farmerHomeNoPlotBody;

  /// Home card when the farmer has no plot yet.
  ///
  /// In te, this message translates to:
  /// **'మీ పొలం జోడించండి'**
  String get farmerHomeNoPlotTitle;

  /// Home tile (wireframe nav label).
  ///
  /// In te, this message translates to:
  /// **'సలహాలు'**
  String get farmerHomeTileAdvisory;

  /// Home tile, locked until Phase 3 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'అడగండి'**
  String get farmerHomeTileAsk;

  /// Home tile (wireframe).
  ///
  /// In te, this message translates to:
  /// **'క్యాలెండర్'**
  String get farmerHomeTileCalendar;

  /// Home tile; opens visits/advice (wireframe).
  ///
  /// In te, this message translates to:
  /// **'చీడపీడలు'**
  String get farmerHomeTilePests;

  /// Home tile, locked until Phase 2 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'ప్రీమియం'**
  String get farmerHomeTilePremium;

  /// Home tile, locked until Phase 3 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'పథకాలు'**
  String get farmerHomeTileSchemes;

  /// Home tile, locked until Phase 2 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'సేవలు'**
  String get farmerHomeTileServices;

  /// Home tile, locked until Phase 2 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'మట్టి పరీక్ష'**
  String get farmerHomeTileSoilTest;

  /// Home tile, locked until Phase 2 (wireframe).
  ///
  /// In te, this message translates to:
  /// **'వాలెట్'**
  String get farmerHomeTileWallet;

  /// Home tile, locked until the feed exists (wireframe).
  ///
  /// In te, this message translates to:
  /// **'వాతావరణం'**
  String get farmerHomeTileWeather;

  /// Bell badge accessibility label.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{కొత్త సలహాలు లేవు} one{1 కొత్త సలహా} other{{count} కొత్త సలహాలు}}'**
  String farmerHomeUnread({required int count});

  /// Voice prompt for Home.
  ///
  /// In te, this message translates to:
  /// **'ఇది మీ హోమ్. మీ FA కి కాల్ చేయడానికి పచ్చ బటన్ నొక్కండి. కింద సందర్శనలు, సలహాలు, మీ పొలం ఉన్నాయి.'**
  String get farmerHomeVoiceHelp;

  /// Weather card placeholder (feed not built; hidden in prod).
  ///
  /// In te, this message translates to:
  /// **'వాతావరణం త్వరలో వస్తుంది'**
  String get farmerHomeWeatherSoon;

  /// FA card title (wireframe "మీ FA: సురేష్").
  ///
  /// In te, this message translates to:
  /// **'మీ FA: {name}'**
  String farmerHomeYourFa({required String name});

  /// Empty inbox body.
  ///
  /// In te, this message translates to:
  /// **'కొత్త సలహాలు వస్తే ఇక్కడ కనిపిస్తాయి.'**
  String get farmerInboxEmptyBody;

  /// Empty inbox title.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా సలహాలు లేవు'**
  String get farmerInboxEmptyTitle;

  /// Tag on personal notices (wireframe).
  ///
  /// In te, this message translates to:
  /// **'మీ పొలానికి'**
  String get farmerInboxForYourField;

  /// Tag after the voice note played to the end.
  ///
  /// In te, this message translates to:
  /// **'విన్నారు'**
  String get farmerInboxListened;

  /// Count next to the title (wireframe "3 new").
  ///
  /// In te, this message translates to:
  /// **'{count, plural, =0{కొత్తవి లేవు} one{1 కొత్తది} other{{count} కొత్తవి}}'**
  String farmerInboxNewCount({required int count});

  /// Shown instead of Listen when audio_url is null.
  ///
  /// In te, this message translates to:
  /// **'ఈ సలహాకు ఆడియో లేదు'**
  String get farmerInboxNoAudio;

  /// Voice prompt on a notice that has no voice note of its own (audio_url is null).
  ///
  /// In te, this message translates to:
  /// **'ఈ సలహాకు ఇంకా ఆడియో రికార్డ్ చేయలేదు. స్క్రీన్ మీద చదవండి, లేదా మీ FA ని అడగండి.'**
  String get farmerInboxNoAudioVoice;

  /// Tag on pinned notices (wireframe "PINNED").
  ///
  /// In te, this message translates to:
  /// **'ముఖ్యమైనది'**
  String get farmerInboxPinned;

  /// F5 title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'సలహాలు'**
  String get farmerInboxTitle;

  /// Tag on unread notices.
  ///
  /// In te, this message translates to:
  /// **'కొత్తది'**
  String get farmerInboxUnread;

  /// Voice prompt for F5.
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ, CIV పంపిన పంట సలహాలు ఇక్కడ ఉన్నాయి. వినాలంటే \'వినండి\' బటన్ నొక్కండి.'**
  String get farmerInboxVoiceHelp;

  /// Shown after sign-in when farmer_status is inactive.
  ///
  /// In te, this message translates to:
  /// **'మీ ఖాతా ఇప్పుడు ఆగి ఉంది. సహాయ కేంద్రానికి కాల్ చేయండి.'**
  String get farmerLoginAccountPaused;

  /// Button that dials the helpline (wireframe states).
  ///
  /// In te, this message translates to:
  /// **'సహాయ కేంద్రానికి కాల్'**
  String get farmerLoginCallHelpline;

  /// Link back to the phone step.
  ///
  /// In te, this message translates to:
  /// **'నంబర్ మార్చండి'**
  String get farmerLoginChangeNumber;

  /// Label above the language chips.
  ///
  /// In te, this message translates to:
  /// **'భాష ఎంచుకోండి'**
  String get farmerLoginChooseLanguage;

  /// Link under the OTP boxes (wireframe states).
  ///
  /// In te, this message translates to:
  /// **'OTP రాలేదా?'**
  String get farmerLoginNoOtp;

  /// Sheet shown for "OTP not received?". Voice OTP (call me) is not built, so the helpline is offered instead.
  ///
  /// In te, this message translates to:
  /// **'సహాయ కేంద్రానికి కాల్ చేయండి. వారు సహాయం చేస్తారు.'**
  String get farmerLoginNoOtpHelp;

  /// Reserved for SMS autofill (not wired yet): hint under the OTP boxes once the app reads the SMS by itself.
  ///
  /// In te, this message translates to:
  /// **'SMS రాగానే OTP దానంతట అదే నిండుతుంది'**
  String get farmerLoginOtpAutofill;

  /// Hint under the OTP boxes (no SMS autofill yet).
  ///
  /// In te, this message translates to:
  /// **'SMS లో వచ్చిన 6 అంకెల OTP వేయండి'**
  String get farmerLoginOtpHint;

  /// Snackbar after (re)sending the OTP.
  ///
  /// In te, this message translates to:
  /// **'OTP పంపాం'**
  String get farmerLoginOtpSent;

  /// OTP step subtitle; phone is phone_masked from the server.
  ///
  /// In te, this message translates to:
  /// **'{phone} కు 6 అంకెల OTP పంపాం'**
  String farmerLoginOtpSentTo({required String phone});

  /// OTP step title.
  ///
  /// In te, this message translates to:
  /// **'OTP వేయండి'**
  String get farmerLoginOtpTitle;

  /// Shown while SMS autofill waits for the OTP.
  ///
  /// In te, this message translates to:
  /// **'OTP కోసం చూస్తున్నాం…'**
  String get farmerLoginOtpWaiting;

  /// Title of the account paused card (farmer_status inactive).
  ///
  /// In te, this message translates to:
  /// **'మీ ఖాతా ఆగి ఉంది'**
  String get farmerLoginPausedTitle;

  /// Phone field hint (+91 prefix is shown by the field).
  ///
  /// In te, this message translates to:
  /// **'10 అంకెల నంబర్'**
  String get farmerLoginPhoneHint;

  /// Inline error on the phone field.
  ///
  /// In te, this message translates to:
  /// **'10 అంకెల మొబైల్ నంబర్ ఇవ్వండి'**
  String get farmerLoginPhoneInvalid;

  /// Phone step subtitle.
  ///
  /// In te, this message translates to:
  /// **'ఈ నంబర్‌కు SMS లో OTP పంపుతాం'**
  String get farmerLoginPhoneSubtitle;

  /// Phone step title.
  ///
  /// In te, this message translates to:
  /// **'మీ ఫోన్ నంబర్'**
  String get farmerLoginPhoneTitle;

  /// Resend button after the countdown.
  ///
  /// In te, this message translates to:
  /// **'OTP మళ్ళీ పంపండి'**
  String get farmerLoginResend;

  /// Resend countdown; time is m:ss, e.g. 0:24.
  ///
  /// In te, this message translates to:
  /// **'{time} తర్వాత మళ్ళీ పంపవచ్చు'**
  String farmerLoginResendIn({required String time});

  /// Primary button on the phone step.
  ///
  /// In te, this message translates to:
  /// **'OTP పంపండి'**
  String get farmerLoginSendOtp;

  /// Tag line under the app name on the phone step.
  ///
  /// In te, this message translates to:
  /// **'పంటకు సలహా, మీ FA ఒక్క కాల్ దూరంలో'**
  String get farmerLoginTagline;

  /// Phone number hint picker button (wireframe "From SIM").
  ///
  /// In te, this message translates to:
  /// **'SIM నంబర్ వాడండి'**
  String get farmerLoginUseSimNumber;

  /// Primary button on the OTP step.
  ///
  /// In te, this message translates to:
  /// **'సరిచూసి ముందుకు'**
  String get farmerLoginVerify;

  /// Voice prompt for the "OTP not received?" sheet.
  ///
  /// In te, this message translates to:
  /// **'OTP రాలేదా? సహాయ కేంద్రానికి కాల్ చేయండి. వారు సహాయం చేస్తారు.'**
  String get farmerLoginVoiceHelpNoOtp;

  /// Voice prompt for the OTP step (Listen button).
  ///
  /// In te, this message translates to:
  /// **'SMS లో వచ్చిన 6 అంకెల OTP ఇక్కడ వేయండి. OTP రాకపోతే సహాయ కేంద్రానికి కాల్ చేయండి.'**
  String get farmerLoginVoiceHelpOtp;

  /// Voice prompt for the account paused screen (Listen button).
  ///
  /// In te, this message translates to:
  /// **'మీ ఖాతా ఇప్పుడు ఆగి ఉంది. సహాయ కేంద్రానికి కాల్ చేయండి.'**
  String get farmerLoginVoiceHelpPaused;

  /// Voice prompt for the phone step (Listen button).
  ///
  /// In te, this message translates to:
  /// **'మీ ఫోన్ నంబర్ టైప్ చేసి, OTP పంపండి నొక్కండి.'**
  String get farmerLoginVoiceHelpPhone;

  /// Shown after complete-profile succeeds.
  ///
  /// In te, this message translates to:
  /// **'నమోదు పూర్తయింది. మీ FA త్వరలో కాల్ చేస్తారు.'**
  String get farmerNameDone;

  /// Primary button: calls complete-profile.
  ///
  /// In te, this message translates to:
  /// **'నమోదు పూర్తి చేయండి'**
  String get farmerNameFinish;

  /// Name field hint.
  ///
  /// In te, this message translates to:
  /// **'మీ పేరు టైప్ చేయండి'**
  String get farmerNameHint;

  /// Inline error when the name is blank.
  ///
  /// In te, this message translates to:
  /// **'దయచేసి మీ పేరు రాయండి'**
  String get farmerNameRequired;

  /// Name step subtitle.
  ///
  /// In te, this message translates to:
  /// **'మీ FA మిమ్మల్ని ఈ పేరుతో గుర్తిస్తారు'**
  String get farmerNameSubtitle;

  /// Name step title.
  ///
  /// In te, this message translates to:
  /// **'మీ పేరు'**
  String get farmerNameTitle;

  /// Voice prompt for the name step.
  ///
  /// In te, this message translates to:
  /// **'మీ పేరు టైప్ చేసి, నమోదు పూర్తి చేయండి నొక్కండి.'**
  String get farmerNameVoiceHelp;

  /// Bottom tab.
  ///
  /// In te, this message translates to:
  /// **'సలహాలు'**
  String get farmerNavAdvisory;

  /// Bottom tab (replaces Wallet until Phase 2).
  ///
  /// In te, this message translates to:
  /// **'నా పొలం'**
  String get farmerNavFarm;

  /// Bottom tab.
  ///
  /// In te, this message translates to:
  /// **'హోమ్'**
  String get farmerNavHome;

  /// Bottom tab.
  ///
  /// In te, this message translates to:
  /// **'సందర్శనలు'**
  String get farmerNavVisits;

  /// Bottom tab (Phase 2; hidden in 1b).
  ///
  /// In te, this message translates to:
  /// **'వాలెట్'**
  String get farmerNavWallet;

  /// GPS accuracy line.
  ///
  /// In te, this message translates to:
  /// **'{meters} మీటర్ల లోపు సరిగ్గా ఉంది'**
  String farmerPlotAddAccuracy({required int meters});

  /// Acres input label.
  ///
  /// In te, this message translates to:
  /// **'ఎకరాలు'**
  String get farmerPlotAddAcres;

  /// Inline error: no area typed (0 acres and 0 guntas).
  ///
  /// In te, this message translates to:
  /// **'ఎకరాలు లేదా గుంటలు వేయండి'**
  String get farmerPlotAddAreaInvalid;

  /// Area step title.
  ///
  /// In te, this message translates to:
  /// **'పొలం ఎంత ఉంది?'**
  String get farmerPlotAddAreaTitle;

  /// Inline error: area above the app's cap for one field (maxPlotAcres, below the API's 10000).
  ///
  /// In te, this message translates to:
  /// **'పొలం {max} ఎకరాల లోపు ఉండాలి'**
  String farmerPlotAddAreaTooBig({required int max});

  /// Guntas input label.
  ///
  /// In te, this message translates to:
  /// **'గుంటలు'**
  String get farmerPlotAddGuntas;

  /// Hint under the area inputs.
  ///
  /// In te, this message translates to:
  /// **'40 గుంటలు = 1 ఎకరం'**
  String get farmerPlotAddGuntasHint;

  /// Inline error.
  ///
  /// In te, this message translates to:
  /// **'గుంటలు 0 నుంచి 39 వరకు ఉండాలి'**
  String get farmerPlotAddGuntasInvalid;

  /// Label field hint.
  ///
  /// In te, this message translates to:
  /// **'ఉదా: బావి దగ్గర పొలం'**
  String get farmerPlotAddLabelHint;

  /// Optional label step title.
  ///
  /// In te, this message translates to:
  /// **'పొలానికి పేరు (అవసరమైతే)'**
  String get farmerPlotAddLabelTitle;

  /// While GPS locks.
  ///
  /// In te, this message translates to:
  /// **'మీ చోటు చూస్తున్నాం…'**
  String get farmerPlotAddLocating;

  /// Location permission denied.
  ///
  /// In te, this message translates to:
  /// **'లొకేషన్ లేకుండా పొలం గుర్తించలేము'**
  String get farmerPlotAddLocationDenied;

  /// Pin step button.
  ///
  /// In te, this message translates to:
  /// **'ఈ చోటు గుర్తించండి'**
  String get farmerPlotAddMarkSpot;

  /// Location step when neither the village nor another plot has a location.
  ///
  /// In te, this message translates to:
  /// **'మీ గ్రామం లొకేషన్ దొరకలేదు. ఈ పొలం జోడించమని మీ FA కి చెప్పండి.'**
  String get farmerPlotAddNoLocation;

  /// Pin step body.
  ///
  /// In te, this message translates to:
  /// **'పొలంలో నిలబడి, ఈ చోటు గుర్తించండి నొక్కండి.'**
  String get farmerPlotAddPinBody;

  /// Pin step title.
  ///
  /// In te, this message translates to:
  /// **'మీ పొలంలో నిలబడండి'**
  String get farmerPlotAddPinTitle;

  /// Final step button.
  ///
  /// In te, this message translates to:
  /// **'పొలం సేవ్ చేయండి'**
  String get farmerPlotAddSave;

  /// Snackbar after the plot is saved.
  ///
  /// In te, this message translates to:
  /// **'పొలం జోడించాం'**
  String get farmerPlotAddSaved;

  /// Add plot title.
  ///
  /// In te, this message translates to:
  /// **'కొత్త పొలం'**
  String get farmerPlotAddTitle;

  /// Location step body while GPS is not wired.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పటికి మీ గ్రామం లొకేషన్ వాడుతాం. మీ FA వచ్చినప్పుడు పొలం సరైన చోటు గుర్తిస్తారు.'**
  String get farmerPlotAddVillagePinBody;

  /// Location step title while GPS is not wired: the village location is used as the pin.
  ///
  /// In te, this message translates to:
  /// **'మీ గ్రామం దగ్గర గుర్తిస్తాం'**
  String get farmerPlotAddVillagePinTitle;

  /// Voice prompt for the area step.
  ///
  /// In te, this message translates to:
  /// **'మీ పొలం ఎన్ని ఎకరాలు, ఎన్ని గుంటలు ఉందో వేయండి.'**
  String get farmerPlotAddVoiceHelpArea;

  /// Voice prompt for the field name step.
  ///
  /// In te, this message translates to:
  /// **'కావాలంటే మీ పొలానికి ఒక పేరు పెట్టండి. తర్వాత ముందుకు నొక్కండి.'**
  String get farmerPlotAddVoiceHelpLabel;

  /// Voice prompt for the pin step.
  ///
  /// In te, this message translates to:
  /// **'మీ పొలం మధ్యలో నిలబడి, ఈ చోటు గుర్తించండి నొక్కండి.'**
  String get farmerPlotAddVoiceHelpPin;

  /// Voice prompt for the location step while GPS is not wired.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పటికి ఈ పొలానికి మీ గ్రామం లొకేషన్ వాడుతాం. మీ FA వచ్చినప్పుడు సరైన చోటు గుర్తిస్తారు. ముందుకు నొక్కండి.'**
  String get farmerPlotAddVoiceHelpVillagePin;

  /// Accuracy too low.
  ///
  /// In te, this message translates to:
  /// **'GPS సరిగా లేదు. ఆకాశం కనిపించే చోట నిలబడి మళ్ళీ ప్రయత్నించండి.'**
  String get farmerPlotAddWeakGps;

  /// Snackbar after the season is closed.
  ///
  /// In te, this message translates to:
  /// **'పంట ముగిసింది'**
  String get farmerSeasonCloseClosed;

  /// Warning before closing.
  ///
  /// In te, this message translates to:
  /// **'ఇది మళ్ళీ మార్చలేరు.'**
  String get farmerSeasonCloseNoUndo;

  /// Outcome question; options are enum.season_status.harvested/abandoned.
  ///
  /// In te, this message translates to:
  /// **'ఈ పంట ఏమైంది?'**
  String get farmerSeasonCloseQuestion;

  /// Close season title.
  ///
  /// In te, this message translates to:
  /// **'పంట ముగించండి'**
  String get farmerSeasonCloseTitle;

  /// Voice prompt for close season.
  ///
  /// In te, this message translates to:
  /// **'కోత పూర్తయిందా, లేక పంట వదిలేశారా? ఒకటి ఎంచుకోండి.'**
  String get farmerSeasonCloseVoiceHelp;

  /// Tag on the current season code.
  ///
  /// In te, this message translates to:
  /// **'ఇప్పటి సీజన్'**
  String get farmerSeasonStartCurrent;

  /// Skips the sowing date.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా విత్తలేదు'**
  String get farmerSeasonStartNotSown;

  /// Optional previous crop step.
  ///
  /// In te, this message translates to:
  /// **'ఇంతకు ముందు ఇక్కడ ఏ పంట వేశారు?'**
  String get farmerSeasonStartPreviousCrop;

  /// Season picker option, e.g. "రబీ 2026-27"; season from enum.season_kind.
  ///
  /// In te, this message translates to:
  /// **'{season} {year}'**
  String farmerSeasonStartSeasonLabel({
    required String season,
    required String year,
  });

  /// Skips an optional step.
  ///
  /// In te, this message translates to:
  /// **'తెలియదు, వదిలేయండి'**
  String get farmerSeasonStartSkip;

  /// Sowing date step.
  ///
  /// In te, this message translates to:
  /// **'ఎప్పుడు విత్తారు?'**
  String get farmerSeasonStartSowingDate;

  /// Snackbar after the season is saved.
  ///
  /// In te, this message translates to:
  /// **'పంట మొదలైంది'**
  String get farmerSeasonStartStarted;

  /// Start season title.
  ///
  /// In te, this message translates to:
  /// **'పంట మొదలుపెట్టండి'**
  String get farmerSeasonStartTitle;

  /// Voice prompt for start season.
  ///
  /// In te, this message translates to:
  /// **'సీజన్, పంట ఎంచుకోండి. విత్తిన రోజు తెలిస్తే అది కూడా ఇవ్వండి.'**
  String get farmerSeasonStartVoiceHelp;

  /// Crop picker step.
  ///
  /// In te, this message translates to:
  /// **'ఏ పంట?'**
  String get farmerSeasonStartWhichCrop;

  /// Season picker step (codes from season_codes.all_open).
  ///
  /// In te, this message translates to:
  /// **'ఏ సీజన్?'**
  String get farmerSeasonStartWhichSeason;

  /// Action on the no-visits card (wireframe).
  ///
  /// In te, this message translates to:
  /// **'FA కి కాల్'**
  String get farmerStateCallFa;

  /// Generic error card title.
  ///
  /// In te, this message translates to:
  /// **'ఏదో తప్పు జరిగింది'**
  String get farmerStateErrorTitle;

  /// Voice prompt for the error card.
  ///
  /// In te, this message translates to:
  /// **'ఏదో తప్పు జరిగింది. మళ్ళీ ప్రయత్నించండి నొక్కండి.'**
  String get farmerStateErrorVoice;

  /// Voice prompt for the empty inbox.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా సలహాలు లేవు. కొత్త సలహాలు వస్తే ఇక్కడ కనిపిస్తాయి.'**
  String get farmerStateNoAdviceVoice;

  /// Action on the no-FA card (wireframe).
  ///
  /// In te, this message translates to:
  /// **'సహాయ కేంద్రానికి కాల్'**
  String get farmerStateNoFaAction;

  /// Home with no FA assigned (wireframe).
  ///
  /// In te, this message translates to:
  /// **'మీ FA త్వరలో కాల్ చేస్తారు'**
  String get farmerStateNoFaTitle;

  /// Voice prompt for the no-FA card.
  ///
  /// In te, this message translates to:
  /// **'మీ FA త్వరలో కాల్ చేస్తారు. అవసరమైతే సహాయ కేంద్రానికి కాల్ చేయండి.'**
  String get farmerStateNoFaVoice;

  /// F4 empty card body (wireframe).
  ///
  /// In te, this message translates to:
  /// **'మీ FA మొదటి సందర్శన ప్లాన్ చేస్తారు.'**
  String get farmerStateNoVisitsBody;

  /// F4 empty card title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'ఇంకా సందర్శనలు లేవు'**
  String get farmerStateNoVisitsTitle;

  /// Voice prompt for the no-visits card.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా సందర్శనలు లేవు. మీ FA మొదటి సందర్శన ప్లాన్ చేస్తారు.'**
  String get farmerStateNoVisitsVoice;

  /// Offline card body (wireframe "Showing saved ... from 7:00 am").
  ///
  /// In te, this message translates to:
  /// **'{time} కి సేవ్ చేసిన వివరాలు చూపిస్తున్నాం'**
  String farmerStateOfflineBody({required DateTime time});

  /// Offline with no cached data.
  ///
  /// In te, this message translates to:
  /// **'ఇంకా ఏమీ సేవ్ కాలేదు. ఇంటర్నెట్ వచ్చాక మళ్ళీ ప్రయత్నించండి.'**
  String get farmerStateOfflineNothingSaved;

  /// Voice prompt for the offline card when nothing is saved on the phone.
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు. ఇంకా ఏమీ సేవ్ కాలేదు. ఇంటర్నెట్ వచ్చాక మళ్ళీ ప్రయత్నించండి.'**
  String get farmerStateOfflineNothingVoice;

  /// Offline card title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు'**
  String get farmerStateOfflineTitle;

  /// Voice prompt for the offline banner shown over saved details (Home).
  ///
  /// In te, this message translates to:
  /// **'ఇంటర్నెట్ లేదు. ఇంతకు ముందు సేవ్ చేసిన వివరాలు చూపిస్తున్నాం.'**
  String get farmerStateOfflineVoice;

  /// Button that opens the district > mandal > village browser.
  ///
  /// In te, this message translates to:
  /// **'జిల్లా, మండలం నుంచి వెతకండి'**
  String get farmerVillageBrowse;

  /// Browser step 1.
  ///
  /// In te, this message translates to:
  /// **'జిల్లా ఎంచుకోండి'**
  String get farmerVillageChooseDistrict;

  /// Browser step 2.
  ///
  /// In te, this message translates to:
  /// **'మండలం ఎంచుకోండి'**
  String get farmerVillageChooseMandal;

  /// Browser step 3.
  ///
  /// In te, this message translates to:
  /// **'గ్రామం ఎంచుకోండి'**
  String get farmerVillageChooseVillage;

  /// Confirm button after choosing a village.
  ///
  /// In te, this message translates to:
  /// **'అవును, ఇదే నా గ్రామం'**
  String get farmerVillageConfirm;

  /// Empty search result.
  ///
  /// In te, this message translates to:
  /// **'{query} పేరుతో గ్రామం దొరకలేదు'**
  String farmerVillageNoResults({required String query});

  /// Second line of a village search result.
  ///
  /// In te, this message translates to:
  /// **'{mandal} మండలం, {district} జిల్లా'**
  String farmerVillageResultArea({
    required String district,
    required String mandal,
  });

  /// Search field hint (Telugu or English).
  ///
  /// In te, this message translates to:
  /// **'గ్రామం పేరు టైప్ చేయండి'**
  String get farmerVillageSearchHint;

  /// Village picker subtitle.
  ///
  /// In te, this message translates to:
  /// **'మీ పొలం ఉన్న గ్రామం ఎంచుకోండి'**
  String get farmerVillageSubtitle;

  /// Village picker title.
  ///
  /// In te, this message translates to:
  /// **'మీ గ్రామం'**
  String get farmerVillageTitle;

  /// Voice prompt for the village picker.
  ///
  /// In te, this message translates to:
  /// **'మీ పొలం ఉన్న గ్రామం పేరు టైప్ చేయండి. దొరకకపోతే జిల్లా, మండలం నుంచి వెతకండి.'**
  String get farmerVillageVoiceHelp;

  /// Issue whose advice_status is unresolved.
  ///
  /// In te, this message translates to:
  /// **'సలహా ఇంకా రాలేదు. మీ FA తర్వాత చెబుతారు.'**
  String get farmerVisitsAdvicePending;

  /// Visit row header (wireframe "12 అక్టో · సురేష్").
  ///
  /// In te, this message translates to:
  /// **'{date} · {name}'**
  String farmerVisitsByFa({required DateTime date, required String name});

  /// Next visit banner note (wireframe "Suresh will call before coming").
  ///
  /// In te, this message translates to:
  /// **'{name} గారు వచ్చే ముందు కాల్ చేస్తారు'**
  String farmerVisitsCallBefore({required String name});

  /// Advised product line (wireframe "మందు: Sample 5 SG").
  ///
  /// In te, this message translates to:
  /// **'మందు: {name}'**
  String farmerVisitsMedicine({required String name});

  /// Next visit banner label (wireframe).
  ///
  /// In te, this message translates to:
  /// **'FA వచ్చే రోజు'**
  String get farmerVisitsNextVisit;

  /// Visit with no issues.
  ///
  /// In te, this message translates to:
  /// **'సమస్యలు ఏమీ కనిపించలేదు'**
  String get farmerVisitsNoIssues;

  /// Photo count on a visit row.
  ///
  /// In te, this message translates to:
  /// **'{count, plural, one{1 ఫోటో} other{{count} ఫోటోలు}}'**
  String farmerVisitsPhotos({required int count});

  /// Line on salt-only advice (wireframe).
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ మందు లేదు, దుకాణంలో అడగండి'**
  String get farmerVisitsSaltOnly;

  /// Opens the advice detail (F8a/F8b).
  ///
  /// In te, this message translates to:
  /// **'సలహా చూడండి'**
  String get farmerVisitsSeeAdvice;

  /// Tag on an advised Shanmukha product (wireframe).
  ///
  /// In te, this message translates to:
  /// **'షణ్ముఖ మందు'**
  String get farmerVisitsShanmukhaProduct;

  /// Crop stage at the visit; stage name comes from the server. Telugu stage names already include the word ("పూత దశ"), English ones don't ("Flowering"), so only English adds it.
  ///
  /// In te, this message translates to:
  /// **'{stage}'**
  String farmerVisitsStage({required String stage});

  /// F4 title (wireframe).
  ///
  /// In te, this message translates to:
  /// **'సందర్శనలు'**
  String get farmerVisitsTitle;

  /// Voice prompt for F4.
  ///
  /// In te, this message translates to:
  /// **'మీ FA మీ పొలానికి వచ్చిన రోజులు, చూసిన సమస్యలు, ఇచ్చిన సలహాలు ఇక్కడ ఉన్నాయి. పైన FA వచ్చే రోజు ఉంది.'**
  String get farmerVisitsVoiceHelp;
}

class _OrbitLocalizationsDelegate
    extends LocalizationsDelegate<OrbitLocalizations> {
  const _OrbitLocalizationsDelegate();

  @override
  Future<OrbitLocalizations> load(Locale locale) {
    return SynchronousFuture<OrbitLocalizations>(
      lookupOrbitLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_OrbitLocalizationsDelegate old) => false;
}

OrbitLocalizations lookupOrbitLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return OrbitLocalizationsEn();
    case 'te':
      return OrbitLocalizationsTe();
  }

  throw FlutterError(
    'OrbitLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
