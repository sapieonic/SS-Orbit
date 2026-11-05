import 'common.dart';
import 'snapshot.dart';

/// One alert from `GET /v1/fa/alerts` (`FAAlert`).
///
/// `FAAlert` is `SnapAlert` plus the farmer's name and phone, so it wraps a
/// [SnapAlert] instead of repeating its fields. The Alerts tab normally reads
/// the snapshot's alerts (offline); this list is for an online refresh and
/// for alerts older than the snapshot keeps. Acknowledge with the AckAlert
/// command, never directly.
final class FaAlert {
  /// Creates an alert.
  const FaAlert({required this.alert, this.farmerName, this.farmerPhone});

  /// Reads an `FAAlert` object.
  factory FaAlert.fromJson(Map<String, Object?> json) => FaAlert(
    alert: SnapAlert.fromJson(json),
    farmerName: json.optString('farmer_name'),
    farmerPhone: json.optString('farmer_phone'),
  );

  /// The alert fields shared with the snapshot.
  final SnapAlert alert;

  /// The farmer's name, or null.
  final String? farmerName;

  /// The farmer's E.164 phone (for "Call Ravi K"), or null.
  final String? farmerPhone;

  /// Shortcut for `alert.id`.
  String get id => alert.id;

  @override
  bool operator ==(Object other) =>
      other is FaAlert &&
      other.alert == alert &&
      other.farmerName == farmerName &&
      other.farmerPhone == farmerPhone;

  @override
  int get hashCode => Object.hash(alert, farmerName, farmerPhone);

  @override
  String toString() => 'FaAlert(${alert.id}, $farmerName)';
}
