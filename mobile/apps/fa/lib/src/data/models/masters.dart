import 'package:orbit_core/orbit_core.dart';

import 'common.dart';
import 'enums.dart';

/// A crop stage (`SnapStage`). Days count from sowing (sowing day = 0).
final class SnapStage {
  /// Creates a stage.
  const SnapStage({
    required this.id,
    required this.code,
    required this.name,
    required this.nameTe,
    required this.seq,
    required this.startDay,
    required this.endDay,
  });

  /// Reads a `SnapStage` object.
  factory SnapStage.fromJson(Map<String, Object?> json) => SnapStage(
    id: json.reqString('id'),
    code: json.reqString('code'),
    name: json.reqString('name'),
    nameTe: json.reqString('name_te'),
    seq: json.reqInt('seq'),
    startDay: json.reqInt('start_day'),
    endDay: json.reqInt('end_day'),
  );

  /// Stage ID (`LogVisitPayload.stage_id`).
  final String id;

  /// `flowering`.
  final String code;

  /// "Flowering".
  final String name;

  /// "పూత దశ".
  final String nameTe;

  /// Order, 1-based.
  final int seq;

  /// First day after sowing.
  final int startDay;

  /// Last day after sowing.
  final int endDay;

  /// True when [daysAfterSowing] falls in this stage.
  bool contains(int daysAfterSowing) =>
      daysAfterSowing >= startDay && daysAfterSowing <= endDay;

  /// The name to show in [language].
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  /// The `SnapStage` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'name_te': nameTe,
    'seq': seq,
    'start_day': startDay,
    'end_day': endDay,
  };

  @override
  bool operator ==(Object other) =>
      other is SnapStage &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.seq == seq &&
      other.startDay == startDay &&
      other.endDay == endDay;

  @override
  int get hashCode =>
      Object.hash(id, code, name, nameTe, seq, startDay, endDay);

  @override
  String toString() => 'SnapStage($code, $startDay-$endDay)';
}

/// A crop with its stage calendar (`SnapCrop`).
final class SnapCrop {
  /// Creates a crop.
  const SnapCrop({
    required this.id,
    required this.code,
    required this.name,
    required this.nameTe,
    required this.durationDays,
    required this.stages,
  });

  /// Reads a `SnapCrop` object.
  factory SnapCrop.fromJson(Map<String, Object?> json) => SnapCrop(
    id: json.reqString('id'),
    code: json.reqString('code'),
    name: json.reqString('name'),
    nameTe: json.reqString('name_te'),
    durationDays: json.optInt('duration_days'),
    stages: json.objects('stages', SnapStage.fromJson),
  );

  /// Crop ID.
  final String id;

  /// `cotton`.
  final String code;

  /// "Cotton".
  final String name;

  /// "పత్తి".
  final String nameTe;

  /// About how long the crop takes, or null.
  final int? durationDays;

  /// Stages in order.
  final List<SnapStage> stages;

  /// The stage for [daysAfterSowing], or null before the first or after the
  /// last stage.
  SnapStage? stageAt(int daysAfterSowing) {
    for (final s in stages) {
      if (s.contains(daysAfterSowing)) return s;
    }
    return null;
  }

  /// The name to show in [language].
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  /// The `SnapCrop` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'name_te': nameTe,
    'duration_days': durationDays,
    'stages': [for (final s in stages) s.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is SnapCrop &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.durationDays == durationDays &&
      listEquals(other.stages, stages);

  @override
  int get hashCode =>
      Object.hash(id, code, name, nameTe, durationDays, Object.hashAll(stages));

  @override
  String toString() => 'SnapCrop($code)';
}

/// A pest, disease or deficiency of one crop (`SnapIssue`).
final class SnapIssue {
  /// Creates an issue.
  const SnapIssue({
    required this.id,
    required this.cropId,
    required this.type,
    required this.name,
    required this.nameTe,
  });

  /// Reads a `SnapIssue` object.
  factory SnapIssue.fromJson(Map<String, Object?> json) => SnapIssue(
    id: json.reqString('id'),
    cropId: json.reqString('crop_id'),
    type: IssueType.fromWire(json.reqString('type')),
    name: json.reqString('name'),
    nameTe: json.reqString('name_te'),
  );

  /// Issue ID (`LogVisitIssue.issue_id`).
  final String id;

  /// The crop it affects.
  final String cropId;

  /// Pest, disease or deficiency.
  final IssueType type;

  /// "Pink bollworm".
  final String name;

  /// Telugu name.
  final String nameTe;

  /// The name to show in [language].
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  /// The `SnapIssue` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'crop_id': cropId,
    'type': type.wire,
    'name': name,
    'name_te': nameTe,
  };

  @override
  bool operator ==(Object other) =>
      other is SnapIssue &&
      other.id == id &&
      other.cropId == cropId &&
      other.type == type &&
      other.name == name &&
      other.nameTe == nameTe;

  @override
  int get hashCode => Object.hash(id, cropId, type, name, nameTe);
}

/// An active ingredient (`SnapSalt`).
final class SnapSalt {
  /// Creates a salt.
  const SnapSalt({required this.id, required this.name, required this.nameTe});

  /// Reads a `SnapSalt` object.
  factory SnapSalt.fromJson(Map<String, Object?> json) => SnapSalt(
    id: json.reqString('id'),
    name: json.reqString('name'),
    nameTe: json.optString('name_te'),
  );

  /// Salt ID.
  final String id;

  /// "Emamectin benzoate 5% SG".
  final String name;

  /// Telugu name, or null.
  final String? nameTe;

  /// The name to show in [language].
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  /// The `SnapSalt` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'name_te': nameTe};

  @override
  bool operator ==(Object other) =>
      other is SnapSalt &&
      other.id == id &&
      other.name == name &&
      other.nameTe == nameTe;

  @override
  int get hashCode => Object.hash(id, name, nameTe);
}

/// A product pack (`SnapSKU`).
final class SnapSku {
  /// Creates a SKU.
  const SnapSku({
    required this.id,
    required this.code,
    required this.productName,
    required this.productNameTe,
    required this.saltId,
    required this.packSize,
    required this.mrpPaise,
    required this.cashbackEligible,
  });

  /// Reads a `SnapSKU` object.
  factory SnapSku.fromJson(Map<String, Object?> json) => SnapSku(
    id: json.reqString('id'),
    code: json.reqString('code'),
    productName: json.reqString('product_name'),
    productNameTe: json.optString('product_name_te'),
    saltId: json.reqString('salt_id'),
    packSize: json.reqString('pack_size'),
    mrpPaise: json.reqInt('mrp_paise'),
    cashbackEligible: json.reqBool('cashback_eligible'),
  );

  /// SKU ID.
  final String id;

  /// SKU code.
  final String code;

  /// Product name in English.
  final String productName;

  /// Product name in Telugu, or null.
  final String? productNameTe;

  /// The salt it contains.
  final String saltId;

  /// "100 g".
  final String packSize;

  /// MRP in paise (orbit_core `Money.paise`).
  final int mrpPaise;

  /// Counts for farmer cashback.
  final bool cashbackEligible;

  /// The product name to show in [language].
  String displayName(Language language) =>
      pickText(language, te: productNameTe, en: productName);

  /// The `SnapSku` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'product_name': productName,
    'product_name_te': productNameTe,
    'salt_id': saltId,
    'pack_size': packSize,
    'mrp_paise': mrpPaise,
    'cashback_eligible': cashbackEligible,
  };

  @override
  bool operator ==(Object other) =>
      other is SnapSku &&
      other.id == id &&
      other.code == code &&
      other.productName == productName &&
      other.productNameTe == productNameTe &&
      other.saltId == saltId &&
      other.packSize == packSize &&
      other.mrpPaise == mrpPaise &&
      other.cashbackEligible == cashbackEligible;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    productName,
    productNameTe,
    saltId,
    packSize,
    mrpPaise,
    cashbackEligible,
  );
}

/// An approved advisory rule: for an issue, which salt (and optionally SKU)
/// at what dose (`SnapRule`). The FA picks one per issue in the visit log
/// (`LogVisitIssue.advisory_rule_id` = [id]).
final class SnapRule {
  /// Creates a rule.
  const SnapRule({
    required this.id,
    required this.ruleKey,
    required this.version,
    required this.issueId,
    required this.saltId,
    required this.skuId,
    required this.dosePerAcre,
    required this.dosePerAcreTe,
  });

  /// Reads a `SnapRule` object.
  factory SnapRule.fromJson(Map<String, Object?> json) => SnapRule(
    id: json.reqString('id'),
    ruleKey: json.reqString('rule_key'),
    version: json.reqInt('version'),
    issueId: json.reqString('issue_id'),
    saltId: json.reqString('salt_id'),
    skuId: json.optString('sku_id'),
    dosePerAcre: json.reqString('dose_per_acre'),
    dosePerAcreTe: json.reqString('dose_per_acre_te'),
  );

  /// The ID of this rule version.
  final String id;

  /// Stable ID shared by every version of the rule.
  final String ruleKey;

  /// Rule version.
  final int version;

  /// The issue it treats.
  final String issueId;

  /// The salt to use.
  final String saltId;

  /// The suggested SKU, or null.
  final String? skuId;

  /// "80 g per acre".
  final String dosePerAcre;

  /// Telugu dose text.
  final String dosePerAcreTe;

  /// The dose text to show in [language].
  String displayDose(Language language) =>
      pickText(language, te: dosePerAcreTe, en: dosePerAcre);

  /// The `SnapRule` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'id': id,
    'rule_key': ruleKey,
    'version': version,
    'issue_id': issueId,
    'salt_id': saltId,
    'sku_id': skuId,
    'dose_per_acre': dosePerAcre,
    'dose_per_acre_te': dosePerAcreTe,
  };

  @override
  bool operator ==(Object other) =>
      other is SnapRule &&
      other.id == id &&
      other.ruleKey == ruleKey &&
      other.version == version &&
      other.issueId == issueId &&
      other.saltId == saltId &&
      other.skuId == skuId &&
      other.dosePerAcre == dosePerAcre &&
      other.dosePerAcreTe == dosePerAcreTe;

  @override
  int get hashCode => Object.hash(
    id,
    ruleKey,
    version,
    issueId,
    saltId,
    skuId,
    dosePerAcre,
    dosePerAcreTe,
  );
}

/// Season codes for today, for StartSeason (`SnapSeasonCodes`). Recomputed
/// daily by the server, not tied to the masters version.
final class SnapSeasonCodes {
  /// Creates season codes.
  const SnapSeasonCodes({
    required this.current,
    required this.next,
    required this.allOpen,
    required this.validUntil,
  });

  /// From the orbit_core calendar (mock data, or a snapshot past
  /// [validUntil]).
  factory SnapSeasonCodes.fromSet(SeasonCodeSet set) => SnapSeasonCodes(
    current: set.current,
    next: set.next,
    allOpen: set.allOpen,
    validUntil: set.validUntil,
  );

  /// Reads a `SnapSeasonCodes` object.
  factory SnapSeasonCodes.fromJson(Map<String, Object?> json) =>
      SnapSeasonCodes(
        current: json.reqString('current'),
        next: json.reqString('next'),
        allOpen: json.strings('all_open'),
        validUntil: json.reqDate('valid_until'),
      );

  /// The season today (`kharif-2026`).
  final String current;

  /// The next season.
  final String next;

  /// Previous, current and next, oldest first: the season picker's options.
  final List<String> allOpen;

  /// Last IST day of [current]; after it, compute codes locally until the
  /// next snapshot.
  final LocalDate validUntil;

  /// The `SnapSeasonCodes` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'current': current,
    'next': next,
    'all_open': [...allOpen],
    'valid_until': validUntil.toIso(),
  };

  @override
  bool operator ==(Object other) =>
      other is SnapSeasonCodes &&
      other.current == current &&
      other.next == next &&
      listEquals(other.allOpen, allOpen) &&
      other.validUntil == validUntil;

  @override
  int get hashCode =>
      Object.hash(current, next, Object.hashAll(allOpen), validUntil);
}

/// Crops, issues, salts, SKUs and approved rules, the same for every FA
/// (`SnapMasters`, snapshot section `masters`).
final class SnapMasters {
  /// Creates masters.
  const SnapMasters({
    required this.version,
    required this.seasonCodes,
    required this.crops,
    required this.issues,
    required this.salts,
    required this.skus,
    required this.rules,
  });

  /// Reads a `SnapMasters` object.
  factory SnapMasters.fromJson(Map<String, Object?> json) => SnapMasters(
    version: json.reqInt('version'),
    seasonCodes: SnapSeasonCodes.fromJson(json.reqMap('season_codes')),
    crops: json.objects('crops', SnapCrop.fromJson),
    issues: json.objects('issues', SnapIssue.fromJson),
    salts: json.objects('salts', SnapSalt.fromJson),
    skus: json.objects('skus', SnapSku.fromJson),
    rules: json.objects('rules', SnapRule.fromJson),
  );

  /// Masters version.
  final int version;

  /// Season codes for StartSeason.
  final SnapSeasonCodes seasonCodes;

  /// Active crops with stages.
  final List<SnapCrop> crops;

  /// Active issues.
  final List<SnapIssue> issues;

  /// Salts.
  final List<SnapSalt> salts;

  /// SKUs.
  final List<SnapSku> skus;

  /// Approved rules.
  final List<SnapRule> rules;

  /// The crop with [id], or null.
  SnapCrop? cropById(String id) => _byId(crops, id, (c) => c.id);

  /// The issue with [id], or null.
  SnapIssue? issueById(String id) => _byId(issues, id, (i) => i.id);

  /// The salt with [id], or null.
  SnapSalt? saltById(String id) => _byId(salts, id, (s) => s.id);

  /// The SKU with [id], or null.
  SnapSku? skuById(String id) => _byId(skus, id, (s) => s.id);

  /// The rule with [id], or null.
  SnapRule? ruleById(String id) => _byId(rules, id, (r) => r.id);

  /// Issues of the crop [cropId] (the visit log's issue picker).
  List<SnapIssue> issuesForCrop(String cropId) => [
    for (final i in issues)
      if (i.cropId == cropId) i,
  ];

  /// Rules that treat [issueId] (the advice picker).
  List<SnapRule> rulesForIssue(String issueId) => [
    for (final r in rules)
      if (r.issueId == issueId) r,
  ];

  static T? _byId<T>(List<T> items, String id, String Function(T) idOf) {
    for (final item in items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  /// The `SnapMasters` JSON, as the server writes it ([fromJson] reads it back
  /// unchanged), for storing the snapshot on the phone.
  Map<String, Object?> toJson() => {
    'version': version,
    'season_codes': seasonCodes.toJson(),
    'crops': [for (final c in crops) c.toJson()],
    'issues': [for (final i in issues) i.toJson()],
    'salts': [for (final s in salts) s.toJson()],
    'skus': [for (final s in skus) s.toJson()],
    'rules': [for (final r in rules) r.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is SnapMasters &&
      other.version == version &&
      other.seasonCodes == seasonCodes &&
      listEquals(other.crops, crops) &&
      listEquals(other.issues, issues) &&
      listEquals(other.salts, salts) &&
      listEquals(other.skus, skus) &&
      listEquals(other.rules, rules);

  @override
  int get hashCode => Object.hash(
    version,
    seasonCodes,
    Object.hashAll(crops),
    Object.hashAll(issues),
    Object.hashAll(salts),
    Object.hashAll(skus),
    Object.hashAll(rules),
  );
}
