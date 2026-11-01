import 'package:flutter/foundation.dart';

import 'common.dart';

/// What a notice is (`Notice.kind`).
enum NoticeKind implements WireEnum {
  /// HO or CIV crop advisory.
  advisory('advisory'),

  /// Advice from an FA visit.
  visitAdvice('visit_advice'),

  /// System message (e.g. FA assigned).
  system('system'),

  /// A kind this app version does not know.
  unknown('');

  const NoticeKind(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static NoticeKind fromWire(String? wire) =>
      enumFromWire(values, wire, NoticeKind.unknown);
}

/// Who sent a notice, shown as the card's tag (`Notice.sender`).
enum NoticeSender implements WireEnum {
  /// Shanmukha head office.
  ho('ho'),

  /// CIV partner.
  civ('civ'),

  /// The farmer's FA.
  fa('fa'),

  /// The system.
  system('system'),

  /// A sender this app version does not know.
  unknown('');

  const NoticeSender(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static NoticeSender fromWire(String? wire) =>
      enumFromWire(values, wire, NoticeSender.unknown);
}

/// One card in My Crop Advisory (F5) (`Notice`).
@immutable
class Notice {
  /// Creates a notice.
  const Notice({
    required this.id,
    required this.kind,
    required this.sender,
    required this.titleTe,
    required this.bodyTe,
    required this.titleEn,
    required this.bodyEn,
    required this.audioUrl,
    required this.refType,
    required this.refId,
    required this.pinned,
    required this.readAt,
    required this.listenedAt,
    required this.createdAt,
  });

  /// Notice ID; also the audio cache key.
  final String id;

  /// Advisory, visit advice or system.
  final NoticeKind kind;

  /// Card tag.
  final NoticeSender sender;

  /// Telugu title (always present).
  final String titleTe;

  /// Telugu body (always present).
  final String bodyTe;

  /// English title.
  final String? titleEn;

  /// English body.
  final String? bodyEn;

  /// Short-lived presigned voice-note URL: download once, cache the file by
  /// [id], never cache the URL.
  final String? audioUrl;

  /// What it is about (`visit`, `farmer`, `fa_assignment`).
  final String? refType;

  /// ID of that thing.
  final String? refId;

  /// Show first.
  final bool pinned;

  /// When opened (UTC); null = unread.
  final DateTime? readAt;

  /// When the voice note was played to the end (UTC).
  final DateTime? listenedAt;

  /// Sent (UTC).
  final DateTime createdAt;

  /// True once opened (listening also marks read).
  bool get isRead => readAt != null;

  /// True once the voice note was played to the end.
  bool get isListened => listenedAt != null;

  /// Title in [language], Telugu when English is missing.
  String title(Language language) =>
      pickText(language, te: titleTe, en: titleEn);

  /// Body in [language], Telugu when English is missing.
  String body(Language language) => pickText(language, te: bodyTe, en: bodyEn);

  /// A copy with the given fields replaced (null keeps the current value),
  /// e.g. to mark read optimistically.
  Notice copyWith({DateTime? readAt, DateTime? listenedAt, bool? pinned}) =>
      Notice(
        id: id,
        kind: kind,
        sender: sender,
        titleTe: titleTe,
        bodyTe: bodyTe,
        titleEn: titleEn,
        bodyEn: bodyEn,
        audioUrl: audioUrl,
        refType: refType,
        refId: refId,
        pinned: pinned ?? this.pinned,
        readAt: readAt ?? this.readAt,
        listenedAt: listenedAt ?? this.listenedAt,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Notice &&
      other.id == id &&
      other.kind == kind &&
      other.sender == sender &&
      other.titleTe == titleTe &&
      other.bodyTe == bodyTe &&
      other.titleEn == titleEn &&
      other.bodyEn == bodyEn &&
      other.audioUrl == audioUrl &&
      other.refType == refType &&
      other.refId == refId &&
      other.pinned == pinned &&
      other.readAt == readAt &&
      other.listenedAt == listenedAt &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    sender,
    titleTe,
    bodyTe,
    titleEn,
    bodyEn,
    audioUrl,
    refType,
    refId,
    pinned,
    readAt,
    listenedAt,
    createdAt,
  );

  @override
  String toString() => 'Notice($id, ${kind.wire}, read: $isRead)';
}
