/// What a conflict card shows as the FA's side: the value the FA has now,
/// and whether a later edit is held in the card.
///
/// An edit the FA makes to a plot or farmer while its earlier edit is in
/// conflict does not go anywhere on its own: `FaActions` folds it into the
/// conflicted entry (its payload carries the latest values), so the screens
/// change nothing until Keep mine sends it, or Keep HO's drops it. The card
/// says so instead of showing the value the server compared.
library;

import '../local/local.dart';

/// The FA's side of conflict [entry].
typedef ConflictMine = ({Object? value, bool laterEdit});

/// The FA's latest value of the conflicting field and whether an edit was
/// folded in after the conflict came back.
ConflictMine conflictMine(OutboxEntry entry) {
  final c = entry.conflict;
  final field = c?.field;
  final folded = entry.meta[OutboxMeta.folded];
  final hasFolded = folded is List && folded.isNotEmpty;
  if (c == null || field == null) {
    return (value: c?.yours, laterEdit: hasFolded);
  }
  final payload = entry.payload;
  final fields = payload['fields'];
  final Object? latest;
  final bool known;
  if (fields is Map && fields.containsKey(field)) {
    (latest, known) = (fields[field], true);
  } else if (payload.containsKey(field)) {
    (latest, known) = (payload[field], true);
  } else {
    (latest, known) = (null, false);
  }
  if (!known) return (value: c.yours, laterEdit: hasFolded);
  final changed = !_same(latest, c.yours);
  return (value: latest, laterEdit: hasFolded || changed);
}

bool _same(Object? a, Object? b) =>
    a is num && b is num ? (a - b).abs() < 1e-9 : a == b;
