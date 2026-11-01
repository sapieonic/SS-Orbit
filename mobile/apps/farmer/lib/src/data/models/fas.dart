import 'package:flutter/foundation.dart';

import 'common.dart';

/// FA status (`FarmerFACard.status`).
enum FaStatus implements WireEnum {
  /// Working.
  active('active'),

  /// Serving notice.
  leaving('leaving'),

  /// No longer working.
  inactive('inactive'),

  /// A status this app version does not know.
  unknown('');

  const FaStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static FaStatus fromWire(String? wire) =>
      enumFromWire(values, wire, FaStatus.unknown);
}

/// An FA as the farmer app shows them (`FarmerFACard`).
@immutable
class FarmerFaCard {
  /// Creates a card.
  const FarmerFaCard({
    required this.id,
    required this.code,
    required this.name,
    required this.nameTe,
    required this.phone,
    required this.level,
    required this.languages,
    required this.workingHours,
    required this.photoKey,
    required this.status,
  });

  /// FA ID.
  final String id;

  /// Login code, e.g. `FA-KDP-014`.
  final String code;

  /// English name.
  final String name;

  /// Telugu name.
  final String? nameTe;

  /// E.164 phone for the Call (`tel:`) and WhatsApp (`wa.me`) buttons.
  final String phone;

  /// The FA's allocation level.
  final AreaLevel level;

  /// Languages spoken (`te`, `en`).
  final List<String> languages;

  /// e.g. `Mon-Sat 8am-5pm`.
  final String? workingHours;

  /// Photo storage key (no farmer-facing URL yet).
  final String? photoKey;

  /// Working status.
  final FaStatus status;

  /// The name to show in [language], falling back to the other one.
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  @override
  bool operator ==(Object other) =>
      other is FarmerFaCard &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.phone == phone &&
      other.level == level &&
      listEquals(other.languages, languages) &&
      other.workingHours == workingHours &&
      other.photoKey == photoKey &&
      other.status == status;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    nameTe,
    phone,
    level,
    Object.hashAll(languages),
    workingHours,
    photoKey,
    status,
  );

  @override
  String toString() => 'FarmerFaCard($code, $name)';
}

/// One row of "Look for FAs" (F3) (`FAOption`).
@immutable
class FaOption {
  /// Creates an option.
  const FaOption({
    required this.fa,
    required this.coverageLevel,
    required this.isLead,
    required this.isMyFa,
  });

  /// The FA.
  final FarmerFaCard fa;

  /// The allocation level that covers the farmer's village.
  final AreaLevel coverageLevel;

  /// Lead FA for that area.
  final bool isLead;

  /// The farmer's assigned FA.
  final bool isMyFa;

  @override
  bool operator ==(Object other) =>
      other is FaOption &&
      other.fa == fa &&
      other.coverageLevel == coverageLevel &&
      other.isLead == isLead &&
      other.isMyFa == isMyFa;

  @override
  int get hashCode => Object.hash(fa, coverageLevel, isLead, isMyFa);
}

/// An FA's ID and names (`FAName`), on visits.
@immutable
class FaName {
  /// Creates a name.
  const FaName({required this.id, required this.name, required this.nameTe});

  /// FA ID.
  final String id;

  /// English name.
  final String name;

  /// Telugu name.
  final String? nameTe;

  /// The name to show in [language], falling back to the other one.
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  @override
  bool operator ==(Object other) =>
      other is FaName &&
      other.id == id &&
      other.name == name &&
      other.nameTe == nameTe;

  @override
  int get hashCode => Object.hash(id, name, nameTe);
}

/// Call-back request status (`Callback.status`).
enum CallbackStatus implements WireEnum {
  /// Waiting for the FA.
  open('open'),

  /// The FA closed it (called back).
  closed('closed'),

  /// The farmer withdrew it.
  cancelled('cancelled'),

  /// A status this app version does not know.
  unknown('');

  const CallbackStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static CallbackStatus fromWire(String? wire) =>
      enumFromWire(values, wire, CallbackStatus.unknown);
}

/// "Ask your FA to call you back" (`Callback`).
@immutable
class Callback {
  /// Creates a call-back request.
  const Callback({
    required this.id,
    required this.farmerId,
    required this.faId,
    required this.status,
    required this.requestedAt,
    required this.closedAt,
  });

  /// Request ID.
  final String id;

  /// The farmer.
  final String farmerId;

  /// The FA asked to call.
  final String faId;

  /// Open, closed or cancelled.
  final CallbackStatus status;

  /// When the farmer asked (UTC).
  final DateTime requestedAt;

  /// When it was closed or cancelled (UTC).
  final DateTime? closedAt;

  /// True while the FA has not called back and the farmer has not cancelled.
  bool get isOpen => status == CallbackStatus.open;

  /// A copy with the given fields replaced (null keeps the current value).
  Callback copyWith({CallbackStatus? status, DateTime? closedAt}) => Callback(
    id: id,
    farmerId: farmerId,
    faId: faId,
    status: status ?? this.status,
    requestedAt: requestedAt,
    closedAt: closedAt ?? this.closedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Callback &&
      other.id == id &&
      other.farmerId == farmerId &&
      other.faId == faId &&
      other.status == status &&
      other.requestedAt == requestedAt &&
      other.closedAt == closedAt;

  @override
  int get hashCode =>
      Object.hash(id, farmerId, faId, status, requestedAt, closedAt);

  @override
  String toString() => 'Callback($id, ${status.wire})';
}
