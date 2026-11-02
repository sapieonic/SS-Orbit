import 'common.dart';

// Enums shared by the snapshot, the command payloads and the API results.
// Each has an `unknown` value (empty wire) for codes the server adds later;
// never send `unknown` in a command.

/// How a farmer came in (`SnapFarmer.source`, `Farmer.source`).
enum FarmerSource implements WireEnum {
  /// Signed up in the farmer app.
  self('self'),

  /// Enrolled by an FA.
  fa('fa'),

  /// Added by HO.
  ho('ho'),

  /// A source this app version does not know.
  unknown('');

  const FarmerSource(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static FarmerSource fromWire(String? wire) =>
      enumFromWire(values, wire, FarmerSource.unknown);
}

/// The farmer's plan (`Plan`, `SnapFarmer.plan`).
enum Plan implements WireEnum {
  /// Free plan.
  free('free'),

  /// Premium plan.
  premium('premium'),

  /// A plan this app version does not know.
  unknown('');

  const Plan(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static Plan fromWire(String? wire) =>
      enumFromWire(values, wire, Plan.unknown);
}

/// Farmer account status (`FarmerStatus`, `SnapFarmer.status`).
enum FarmerStatus implements WireEnum {
  /// Self sign-up not finished (the FA's enrolment completes it).
  pendingProfile('pending_profile'),

  /// Normal account.
  active('active'),

  /// Deactivated by HO.
  inactive('inactive'),

  /// A status this app version does not know.
  unknown('');

  const FarmerStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static FarmerStatus fromWire(String? wire) =>
      enumFromWire(values, wire, FarmerStatus.unknown);
}

/// What a consent is for (`ConsentPurpose`, `SyncConsentPurpose`,
/// `SnapFarmer.consents_granted`).
enum ConsentPurpose implements WireEnum {
  /// Joining the programme (required for an OTP-backed enrolment).
  programme('programme'),

  /// Sharing data with the soil-testing partner.
  soilPartner('soil_partner'),

  /// Government schemes and finance offers.
  schemesFinance('schemes_finance'),

  /// The loyalty programme.
  loyalty('loyalty'),

  /// A purpose this app version does not know.
  unknown('');

  const ConsentPurpose(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static ConsentPurpose fromWire(String? wire) =>
      enumFromWire(values, wire, ConsentPurpose.unknown);
}

/// Where a plot's area came from (`SnapPlot.area_source`,
/// `SavePlotPayload.area_source`).
enum AreaSource implements WireEnum {
  /// Measured by the server from the walked boundary.
  boundary('boundary'),

  /// Typed by the FA.
  typed('typed'),

  /// A source this app version does not know.
  unknown('');

  const AreaSource(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static AreaSource fromWire(String? wire) =>
      enumFromWire(values, wire, AreaSource.unknown);
}

/// Plot status (`SnapPlot.status`).
enum PlotStatus implements WireEnum {
  /// In use.
  active('active'),

  /// No longer farmed.
  archived('archived'),

  /// A status this app version does not know.
  unknown('');

  const PlotStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static PlotStatus fromWire(String? wire) =>
      enumFromWire(values, wire, PlotStatus.unknown);
}

/// Season status (`SnapSeason.status`).
enum SeasonStatus implements WireEnum {
  /// The crop is in the field.
  active('active'),

  /// Harvested.
  harvested('harvested'),

  /// Given up.
  abandoned('abandoned'),

  /// A status this app version does not know.
  unknown('');

  const SeasonStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static SeasonStatus fromWire(String? wire) =>
      enumFromWire(values, wire, SeasonStatus.unknown);
}

/// Visit status (`VisitStatus`, `SnapVisit.status`). The snapshot carries
/// planned visits and the latest done ones.
enum VisitStatus implements WireEnum {
  /// Planned, not yet logged.
  planned('planned'),

  /// Logged.
  done('done'),

  /// Cancelled by the FA.
  cancelled('cancelled'),

  /// The planned day passed without a log.
  missed('missed'),

  /// A status this app version does not know.
  unknown('');

  const VisitStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static VisitStatus fromWire(String? wire) =>
      enumFromWire(values, wire, VisitStatus.unknown);
}

/// Part of the day a visit is planned for (`SyncVisitSlot`,
/// `SnapVisit.planned_slot`).
enum VisitSlot implements WireEnum {
  /// Morning.
  morning('morning'),

  /// Afternoon.
  afternoon('afternoon'),

  /// Any time that day.
  any('any'),

  /// A slot this app version does not know.
  unknown('');

  const VisitSlot(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static VisitSlot fromWire(String? wire) =>
      enumFromWire(values, wire, VisitSlot.unknown);
}

/// How bad an issue is (`LogVisitIssue.severity`, `SnapVisitIssue.severity`).
enum Severity implements WireEnum {
  /// Low.
  low('low'),

  /// Moderate.
  moderate('moderate'),

  /// High.
  high('high'),

  /// A severity this app version does not know.
  unknown('');

  const Severity(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static Severity fromWire(String? wire) =>
      enumFromWire(values, wire, Severity.unknown);
}

/// Whether advice was recorded for a visit issue
/// (`SnapVisitIssue.advice_status`).
enum AdviceStatus implements WireEnum {
  /// The FA's rule checked out: salt, SKU and dose are set.
  given('given'),

  /// The rule did not check out (or none was picked): every advice field is
  /// null and HO follows up.
  unresolved('unresolved'),

  /// A status this app version does not know.
  unknown('');

  const AdviceStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value. `resolved` (the spelling in backend CONVENTIONS
  /// section 6) is read as [given]; the specs and the server send `given`.
  static AdviceStatus fromWire(String? wire) => wire == 'resolved'
      ? AdviceStatus.given
      : enumFromWire(values, wire, AdviceStatus.unknown);
}

/// Pest, disease or deficiency (`IssueType`, `SnapIssue.type`).
enum IssueType implements WireEnum {
  /// An insect or other pest.
  pest('pest'),

  /// A disease.
  disease('disease'),

  /// A nutrient deficiency.
  deficiency('deficiency'),

  /// A type this app version does not know.
  unknown('');

  const IssueType(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static IssueType fromWire(String? wire) =>
      enumFromWire(values, wire, IssueType.unknown);
}

/// What an FA alert is about (`FAAlert.kind`, `SnapAlert.kind`).
enum AlertKind implements WireEnum {
  /// A farmer signed up in the FA's area and needs enrolment.
  newFarmer('new_farmer'),

  /// A farmer asked for a call-back.
  callback('callback'),

  /// An invoice to check.
  invoiceCheck('invoice_check'),

  /// A note from HO.
  hoNote('ho_note'),

  /// A kind this app version does not know.
  unknown('');

  const AlertKind(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static AlertKind fromWire(String? wire) =>
      enumFromWire(values, wire, AlertKind.unknown);
}

/// FA alert status (`FAAlert.status`, `SnapAlert.status`, the `status`
/// filter of `GET /v1/fa/alerts`).
enum AlertStatus implements WireEnum {
  /// New.
  open('open'),

  /// The FA tapped "Got it" (AckAlert).
  acknowledged('acknowledged'),

  /// Closed by the system or HO.
  closed('closed'),

  /// A status this app version does not know.
  unknown('');

  const AlertStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static AlertStatus fromWire(String? wire) =>
      enumFromWire(values, wire, AlertStatus.unknown);
}

/// Image types the photo upload endpoints accept (`content_type` of
/// `FarmerPhotoUploadRequest`, `PhotoUploadRequest` and `LogVisitPhoto`).
enum PhotoContentType implements WireEnum {
  /// JPEG (what the app sends after compressing).
  jpeg('image/jpeg'),

  /// PNG.
  png('image/png'),

  /// WebP.
  webp('image/webp'),

  /// A type this app version does not know.
  unknown('');

  const PhotoContentType(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static PhotoContentType fromWire(String? wire) =>
      enumFromWire(values, wire, PhotoContentType.unknown);
}
