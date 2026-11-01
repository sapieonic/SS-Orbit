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
