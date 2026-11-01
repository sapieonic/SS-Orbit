import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// Every icon the Orbit apps use, named by meaning.
///
/// Backed by Lucide (ISC licence, via the pinned `flutter_lucide` package),
/// which matches the wireframes' 24 px, 2 px round-stroke style. Apps never
/// import the icon package: add a member here instead, so the set can be
/// swapped in one place. All members are `const`, so release builds keep only
/// the glyphs in use (icon tree shaking).
abstract final class OrbitIcons {
  // Navigation and general actions.

  /// Home tab.
  static const IconData home = LucideIcons.house;

  /// Back (screen header).
  static const IconData back = LucideIcons.arrow_left;

  /// Disclosure / "see more" chevron.
  static const IconData chevronRight = LucideIcons.chevron_right;

  /// Previous.
  static const IconData chevronLeft = LucideIcons.chevron_left;

  /// Close or dismiss.
  static const IconData close = LucideIcons.x;

  /// Search.
  static const IconData search = LucideIcons.search;

  /// Settings.
  static const IconData settings = LucideIcons.settings;

  /// Sign out.
  static const IconData logOut = LucideIcons.log_out;

  /// Add (plot, photo, ...).
  static const IconData add = LucideIcons.plus;

  /// Retry or refresh.
  static const IconData refresh = LucideIcons.refresh_cw;

  /// Share.
  static const IconData share = LucideIcons.share_2;

  /// Edit or change (a name, a detail).
  static const IconData edit = LucideIcons.pencil;

  /// Send.
  static const IconData send = LucideIcons.send;

  // Calls and messages.

  /// Phone call.
  static const IconData phone = LucideIcons.phone;

  /// Outgoing call ("call me back").
  static const IconData phoneCall = LucideIcons.phone_call;

  /// WhatsApp (Lucide has no brand icons; a chat bubble).
  static const IconData whatsApp = LucideIcons.message_circle;

  /// Text message or advisory note.
  static const IconData message = LucideIcons.message_square_text;

  /// Helpline.
  static const IconData helpline = LucideIcons.headset;

  /// Notifications.
  static const IconData bell = LucideIcons.bell;

  /// Notices and announcements (advisory inbox).
  static const IconData notice = LucideIcons.megaphone;

  /// Inbox.
  static const IconData inbox = LucideIcons.inbox;

  // Voice.

  /// Listen (speaker).
  static const IconData listen = LucideIcons.volume_2;

  /// Audio not available.
  static const IconData listenUnavailable = LucideIcons.volume_x;

  /// Stop playback.
  static const IconData stop = LucideIcons.square;

  /// Pause playback.
  static const IconData pause = LucideIcons.pause;

  /// Microphone (ask by voice).
  static const IconData mic = LucideIcons.mic;

  // Status.

  /// Tick.
  static const IconData check = LucideIcons.check;

  /// Success, done.
  static const IconData success = LucideIcons.circle_check;

  /// Failed, error.
  static const IconData error = LucideIcons.circle_x;

  /// Warning.
  static const IconData warning = LucideIcons.triangle_alert;

  /// Attention.
  static const IconData alert = LucideIcons.circle_alert;

  /// Information.
  static const IconData info = LucideIcons.info;

  /// Pending, scheduled, time.
  static const IconData pending = LucideIcons.clock;

  /// No internet.
  static const IconData offline = LucideIcons.wifi_off;

  /// Not synced.
  static const IconData cloudOff = LucideIcons.cloud_off;

  /// Locked feature (FAR-06 padlock).
  static const IconData lock = LucideIcons.lock;

  /// Verified (FA badge).
  static const IconData verified = LucideIcons.badge_check;

  /// Help.
  static const IconData help = LucideIcons.circle_question_mark;

  /// Pinned notice.
  static const IconData pin = LucideIcons.pin;

  /// Low severity.
  static const IconData severityLow = LucideIcons.signal_low;

  /// Moderate severity.
  static const IconData severityModerate = LucideIcons.signal_medium;

  /// High severity.
  static const IconData severityHigh = LucideIcons.signal_high;

  // Farm and services.

  /// Calendar.
  static const IconData calendar = LucideIcons.calendar;

  /// Crop calendar.
  static const IconData cropCalendar = LucideIcons.calendar_days;

  /// Visit planned or done.
  static const IconData visit = LucideIcons.calendar_check;

  /// Crop, seedling.
  static const IconData crop = LucideIcons.sprout;

  /// Leaf (disease, advisory).
  static const IconData leaf = LucideIcons.leaf;

  /// Pests and disease.
  static const IconData pests = LucideIcons.bug;

  /// Weather.
  static const IconData weather = LucideIcons.cloud_sun;

  /// Rain.
  static const IconData rain = LucideIcons.cloud_rain;

  /// Sunny.
  static const IconData sun = LucideIcons.sun;

  /// Water, irrigation.
  static const IconData water = LucideIcons.droplets;

  /// Soil test.
  static const IconData soilTest = LucideIcons.flask_conical;

  /// Government schemes.
  static const IconData schemes = LucideIcons.landmark;

  /// Field services.
  static const IconData services = LucideIcons.wrench;

  /// Tractor, machinery.
  static const IconData tractor = LucideIcons.tractor;

  /// Premium plan.
  static const IconData premium = LucideIcons.crown;

  /// Wallet.
  static const IconData wallet = LucideIcons.wallet;

  /// Rupee amount.
  static const IconData rupee = LucideIcons.indian_rupee;

  /// Bill or receipt.
  static const IconData bill = LucideIcons.receipt_indian_rupee;

  /// Shop or dealer.
  static const IconData shop = LucideIcons.store;

  /// Product.
  static const IconData product = LucideIcons.package;

  /// Shanmukha product found.
  static const IconData productFound = LucideIcons.package_check;

  /// Task list.
  static const IconData tasks = LucideIcons.list_checks;

  /// Location, village, plot.
  static const IconData location = LucideIcons.map_pin;

  /// Person, profile.
  static const IconData person = LucideIcons.user;

  /// People, farmers.
  static const IconData people = LucideIcons.users;

  /// Camera.
  static const IconData camera = LucideIcons.camera;

  /// Photo or gallery.
  static const IconData photo = LucideIcons.image;

  /// Language.
  static const IconData language = LucideIcons.globe;

  /// Consent and privacy.
  static const IconData consent = LucideIcons.shield_check;

  /// Document.
  static const IconData document = LucideIcons.file_text;
}
