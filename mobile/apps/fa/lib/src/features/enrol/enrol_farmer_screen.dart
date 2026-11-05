import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../device/device.dart';
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/fa_header.dart';
import '../../shared/formatters.dart';
import '../../shared/helpline.dart';
import '../../shared/navigation.dart';
import 'consent_panel.dart';
import 'enrol_support.dart';

/// A4a enrol a farmer, step 1: phone, name, photo, language, consent.
///
/// The number is looked up once (online only; the lookup is rate limited):
/// `new` goes on, `mine` opens the farmer, `unassigned_in_my_area` goes on
/// and the server merges the self sign-up, `outside_my_area` / `other_fa`
/// stop with Call HO, `deactivated` stops. A farmer already on the phone is
/// recognised without the lookup. Offline, lookup, OTP and photo are
/// skipped: the number is checked at sync and the farmer is enrolled consent
/// pending.
///
/// Continue queues EnrolFarmer (with the consent proof when the farmer read
/// out the code, and the village from GPS), acknowledges the new-farmer
/// alert it was opened from, and opens step 2.
class EnrolFarmerScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const EnrolFarmerScreen({super.key, this.phone, this.alertId});

  /// A phone number to start with (from an alert or lookup).
  final String? phone;

  /// The new-farmer alert this enrolment answers.
  final String? alertId;

  @override
  ConsumerState<EnrolFarmerScreen> createState() => _EnrolFarmerScreenState();
}

/// Where the lookup of one number stands.
sealed class _Lookup {
  const _Lookup();
}

final class _Checking extends _Lookup {
  const _Checking();
}

final class _Looked extends _Lookup {
  const _Looked(this.result);
  final PhoneLookup result;
}

/// The lookup failed with something other than no network: carry on, the
/// number is checked at sync.
final class _LookupFailed extends _Lookup {
  const _LookupFailed(this.error);
  final ApiError error;
}

enum _PhotoState { none, uploading, uploaded, failed }

class _EnrolFarmerScreenState extends ConsumerState<EnrolFarmerScreen> {
  late final TextEditingController _phone;
  final _name = TextEditingController();
  final _nameTe = TextEditingController();
  Language _language = Language.te;

  /// Lookups by normalised phone, so each number is asked once.
  final _lookups = <String, _Lookup>{};
  bool _lookupOffline = false;

  CapturedPhoto? _photo;
  _PhotoState _photoState = _PhotoState.none;
  String? _photoKey;
  String? _photoFarmerId;
  String? _photoPhone;

  ConsentOutcome? _consent;
  bool _saving = false;
  bool _showErrors = false;
  bool _prefilled = false;

  /// The name field (`name` or `name_te`) `FaActions` found too long: it
  /// counts bytes, and a Telugu letter is 3 of them.
  String? _tooLongField;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: nationalMobile(widget.phone) ?? '');
    unawaited(_afterTerritory());
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _nameTe.dispose();
    super.dispose();
  }

  String? get _e164 => normalizeIndianMobile(_phone.text);

  bool get _offline => !ref.read(phoneOnlineProvider) || _lookupOffline;

  Future<void> _afterTerritory() async {
    final Territory t;
    try {
      t = await ref.read(territoryProvider.future);
    } on Object {
      return;
    }
    if (!mounted) return;
    _prefill(t);
    await _maybeLookup();
  }

  /// Names and language from the alert's farmer or the self sign-up on the
  /// phone, once.
  void _prefill(Territory t) {
    if (_prefilled) return;
    _prefilled = true;
    final alert = widget.alertId == null ? null : t.alert(widget.alertId!);
    final e164 = _e164;
    final f =
        (alert?.farmerId == null ? null : t.farmer(alert!.farmerId!)) ??
        (e164 == null ? null : t.farmerByPhone(e164));
    if (f == null) return;
    if (_phone.text.isEmpty) {
      _phone.text = nationalMobile(f.phone) ?? '';
    }
    if (f.status != FarmerStatus.pendingProfile) return;
    setState(() {
      _name.text = f.name ?? '';
      _nameTe.text = f.nameTe ?? '';
      _language = f.language;
    });
  }

  /// Looks the number up once, online, unless the phone already knows it.
  Future<void> _maybeLookup() async {
    final e164 = _e164;
    if (e164 == null || _lookups.containsKey(e164)) return;
    final t = ref.read(territoryProvider).value;
    if (t == null || t.farmerByPhone(e164) != null) return;
    if (_offline) return;
    setState(() => _lookups[e164] = const _Checking());
    _Lookup result;
    try {
      result = _Looked(
        await ref.read(enrolmentRepositoryProvider).lookupPhone(e164),
      );
    } on ApiError catch (e) {
      if (e.isNetwork) {
        if (mounted) {
          setState(() {
            _lookups.remove(e164);
            _lookupOffline = true;
          });
        }
        return;
      }
      result = _LookupFailed(e);
    }
    if (mounted) setState(() => _lookups[e164] = result);
  }

  void _phoneChanged(String _) {
    if (_photoPhone != null && _photoPhone != _e164) _clearPhoto();
    setState(() {
      // The consent was read out for another number: it no longer counts,
      // even when the panel is not on screen to say so (an "already yours"
      // number hides it).
      if (_consent case final c? when c.proof.phone != _e164) _consent = null;
    });
    unawaited(_maybeLookup());
  }

  void _clearPhoto() {
    _photo = null;
    _photoKey = null;
    _photoFarmerId = null;
    _photoPhone = null;
    _photoState = _PhotoState.none;
  }

  Future<void> _retryLookup() async {
    final e164 = _e164;
    setState(() {
      if (e164 != null) _lookups.remove(e164);
      _lookupOffline = false;
    });
    await _maybeLookup();
  }

  // -------------------------------------------------------------------------
  // Photo (online only): capture, upload URL for the farmer ID the
  // enrolment will use, PUT, keep the storage key for EnrolFarmer.

  Future<void> _takePhoto() async {
    final l10n = context.l10n;
    final e164 = _e164;
    final messenger = ScaffoldMessenger.of(context);
    if (e164 == null) {
      setState(() => _showErrors = true);
      return;
    }
    final CapturedPhoto? photo;
    try {
      photo = await ref.read(photoCaptureProvider).take();
    } on CameraUnavailable {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.faEnrolPhotoNoCamera)));
      return;
    }
    if (photo == null || !mounted) return;
    setState(() {
      _photo = photo;
      _photoPhone = e164;
      _photoKey = null;
    });
    await _upload();
  }

  Future<void> _upload() async {
    final photo = _photo;
    final e164 = _photoPhone;
    if (photo == null || e164 == null) return;
    setState(() => _photoState = _PhotoState.uploading);
    try {
      final farmerId =
          _photoFarmerId ??
          await ref.read(faActionsProvider).farmerIdForPhone(e164);
      // The FA may have left meanwhile: `ref` is gone then.
      if (!mounted) return;
      final target = await ref
          .read(enrolmentRepositoryProvider)
          .createFarmerPhotoUpload(
            farmerId: farmerId,
            contentType: photo.contentType,
            bytes: photo.bytes.length,
          );
      if (!mounted) return;
      await ref.read(photoUploaderProvider).upload(target, photo.bytes);
      if (!mounted || _photo != photo) return;
      setState(() {
        _photoFarmerId = farmerId;
        _photoKey = target.storageKey;
        _photoState = _PhotoState.uploaded;
      });
    } on ApiError catch (e) {
      if (!mounted || _photo != photo) return;
      setState(() {
        _photoState = _PhotoState.failed;
        if (e.isNetwork) _lookupOffline = true;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Continue.

  Future<bool> _confirmNoConsent() async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.faEnrolNoConsentTitle),
        content: Text(l10n.faEnrolNoConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.faEnrolNoConsentConfirm),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  /// The village the enrolment goes in: the self sign-up's own, else the
  /// one nearest the GPS (step 2 shows it and can change it), else the
  /// first of the area.
  Future<String?> _village(Territory t, String e164) async {
    final alert = widget.alertId == null ? null : t.alert(widget.alertId!);
    final known =
        t.farmerByPhone(e164)?.villageId ??
        (alert?.farmerId == null
            ? null
            : t.farmer(alert!.farmerId!)?.villageId);
    if (known != null && t.village(known) != null) return known;
    try {
      final fix = await ref
          .read(locationServiceProvider)
          .currentFix()
          .timeout(const Duration(seconds: 10));
      final near = t.nearestVillage(fix.point);
      if (near != null) return near.id;
    } on Object {
      // No GPS: fall through.
    }
    return t.villages.isEmpty ? null : t.villages.first.id;
  }

  Future<void> _continue(Territory t) async {
    if (_saving) return;
    final e164 = _e164;
    final name = _name.text.trim();
    if (e164 == null || name.isEmpty || name.length > 100) {
      setState(() => _showErrors = true);
      return;
    }
    final consent = _consent;
    if (consent == null && !_offline && !await _confirmNoConsent()) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final actions = ref.read(faActionsProvider);
    try {
      final villageId = await _village(t, e164);
      if (villageId == null) throw const FaActionError(FaActionError.noData);
      final id = await actions.enrolFarmer(
        farmerId: _photoPhone == e164 ? _photoFarmerId : null,
        phone: e164,
        name: name,
        nameTe: _nameTe.text,
        language: _language,
        villageId: villageId,
        photoKey: _photoPhone == e164 ? _photoKey : null,
        proof: consent?.proof,
        audioPlayed: consent?.audioPlayed ?? false,
        noticeVersion: faConsentNoticeVersion,
      );
      // The enrolment closes the farmer's new-farmer alert on the phone
      // when the farmer is on it (the projector does what the server does),
      // and then this sends nothing. A self sign-up with no FA is not on the
      // phone: the enrolment gets a new ID the server merges later, so the
      // alert is acknowledged here to take it off the badge now. The server
      // applies an AckAlert of an alert it already closed.
      if (widget.alertId case final alertId?) {
        try {
          await actions.ackAlert(alertId);
        } on FaActionError {
          // Gone: nothing to do.
        }
      }
      if (!mounted) return;
      // The router can keep this page under step 2: back from there must
      // find it usable, not stuck in "saving".
      setState(() => _saving = false);
      context.go(AppRoutes.enrolPlot(id));
    } on FaActionError catch (e) {
      if (!mounted) return;
      final field = e.code == FaActionError.tooLong ? e.field : null;
      setState(() {
        _saving = false;
        if (field == 'name' || field == 'name_te') _tooLongField = field;
      });
      if (e.code == FaActionError.alreadyEnrolled) return; // card shows it
      if (_tooLongField != null) return; // the field says it
      showActionError(context, e);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showActionError(context, e);
    }
  }

  bool get _dirty =>
      _name.text.trim().isNotEmpty || _consent != null || _photo != null;

  Future<void> _leave() async {
    if (_saving) return;
    if (_dirty) {
      final l10n = context.l10n;
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.faEnrolLeaveTitle),
          content: Text(l10n.faEnrolLeaveBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.faEnrolLeaveStay),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.faEnrolLeaveConfirm),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    goBack(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final territory = watchTerritory(ref);
    // Rebuild when the network comes or goes.
    ref.watch(phoneOnlineProvider);
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        body: Column(
          children: [
            FaHeader(
              title: l10n.faEnrolTitle,
              subtitle: enrolStepLine(l10n, 1),
              onBack: _leave,
              backLabel: l10n.faEnrolBackToFarmers,
            ),
            Expanded(
              child: AsyncValueView(
                value: territory,
                onRetry: () => ref.invalidate(territoryProvider),
                data: _form,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(Territory t) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final e164 = _e164;
    final offline = _offline;
    final local = e164 == null ? null : t.farmerByPhone(e164);
    final lookup = e164 == null ? null : _lookups[e164];

    // What the number is, from the phone first, then the lookup.
    Widget? status;
    var canGoOn = e164 != null;
    var claim = false;
    if (local != null && local.status != FarmerStatus.pendingProfile) {
      status = _mineCard(t, local.id);
      canGoOn = false;
    } else if (local != null) {
      status = EnrolNotice(
        icon: OrbitIcons.info,
        tone: orbit.info,
        title: l10n.faEnrolPendingTitle,
        body: l10n.faEnrolPendingBody,
        live: true,
      );
    } else if (lookup is _Checking) {
      canGoOn = false;
      status = Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: OrbitSize.iconMd,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: OrbitSpace.s12),
            Expanded(
              child: Text(
                l10n.faEnrolChecking,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    } else if (lookup is _LookupFailed) {
      status = EnrolNotice(
        icon: OrbitIcons.warning,
        tone: orbit.warning,
        title: l10n.faEnrolLookupFailedTitle,
        body:
            '${errorText(context, lookup.error)} ${l10n.faEnrolCheckedAtSync}',
        live: true,
        actions: [
          OrbitButton(
            label: l10n.commonRetry,
            icon: OrbitIcons.refresh,
            variant: OrbitButtonVariant.secondary,
            onPressed: _retryLookup,
          ),
        ],
      );
    } else if (lookup is _Looked) {
      final r = lookup.result;
      switch (r.status) {
        case PhoneLookupStatus.newFarmer:
          break;
        case PhoneLookupStatus.mine:
          status = _mineCard(t, r.farmerId);
          canGoOn = false;
        case PhoneLookupStatus.unassignedInMyArea:
          claim = true;
          status = EnrolNotice(
            icon: OrbitIcons.info,
            tone: orbit.info,
            title: l10n.faEnrolRegisteredTitle,
            body: l10n.faEnrolRegisteredBody,
            live: true,
          );
        case PhoneLookupStatus.outsideMyArea:
          canGoOn = false;
          status = _stopCard(
            l10n.faEnrolOutsideTitle,
            l10n.faEnrolOutsideBody,
            withCallHo: true,
          );
        case PhoneLookupStatus.otherFa:
          canGoOn = false;
          status = _stopCard(
            l10n.faEnrolOtherFaTitle,
            l10n.faEnrolOtherFaBody,
            withCallHo: true,
          );
        case PhoneLookupStatus.deactivated:
          canGoOn = false;
          status = _stopCard(
            l10n.faEnrolDeactivatedTitle,
            l10n.faEnrolDeactivatedBody,
            withCallHo: false,
          );
        case PhoneLookupStatus.unknown:
          canGoOn = false;
          status = _stopCard(
            l10n.faEnrolUnknownTitle,
            l10n.faEnrolUnknownBody,
            withCallHo: true,
          );
      }
    }

    final phoneError = _showErrors && e164 == null
        ? l10n.faEnrolPhoneInvalid
        : null;
    final name = _name.text.trim();
    final nameError = _tooLongField == 'name'
        ? l10n.faActionErrorTooLong
        : !_showErrors
        ? null
        : name.isEmpty
        ? l10n.faEnrolNameRequired
        : name.length > 100
        ? l10n.faActionErrorTooLong
        : null;
    final showForm = e164 == null || canGoOn || lookup is _Checking;
    final busy = _saving || _photoState == _PhotoState.uploading;

    return EnrolScroll(
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        OrbitSpace.s16,
        OrbitSpace.s16,
        OrbitSpace.s24,
      ),
      children: [
        const EnrolSteps(current: 0),
        const SizedBox(height: OrbitSpace.s16),
        if (offline) ...[
          OrbitBanner(
            kind: OrbitBannerKind.offline,
            title: l10n.faEnrolOfflineTitle,
            message: l10n.faEnrolOfflineBody,
            action: _lookupOffline
                ? TextButton(
                    onPressed: _saving ? null : _retryLookup,
                    child: Text(l10n.commonRetry),
                  )
                : null,
          ),
          const SizedBox(height: OrbitSpace.s16),
        ],
        PhoneField(
          key: const Key('enrol.phone'),
          controller: _phone,
          label: l10n.faEnrolPhoneLabel,
          errorText: phoneError,
          enabled: !_saving,
          textInputAction: TextInputAction.next,
          onChanged: _phoneChanged,
        ),
        if (status != null) ...[const SizedBox(height: OrbitSpace.s12), status],
        if (showForm) ...[
          const SizedBox(height: OrbitSpace.s16),
          EnrolFieldLabel(l10n.faEnrolNameLabel),
          TextField(
            key: const Key('enrol.name'),
            controller: _name,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(errorText: nameError),
            onChanged: (_) => setState(() {
              if (_tooLongField == 'name') _tooLongField = null;
            }),
          ),
          const SizedBox(height: OrbitSpace.s12),
          EnrolFieldLabel(l10n.faEnrolNameTeLabel),
          TextField(
            key: const Key('enrol.name_te'),
            controller: _nameTe,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              errorText: _tooLongField == 'name_te'
                  ? l10n.faActionErrorTooLong
                  : null,
            ),
            onChanged: (_) => setState(() {
              if (_tooLongField == 'name_te') _tooLongField = null;
            }),
          ),
          const SizedBox(height: OrbitSpace.s16),
          _photoRow(offline),
          const SizedBox(height: OrbitSpace.s16),
          EnrolFieldLabel(l10n.faEnrolLanguageLabel),
          EnrolChoiceChips<Language>(
            semanticLabel: l10n.faEnrolLanguageLabel,
            selected: _language,
            onSelected: _saving
                ? null
                : (lang) => setState(() => _language = lang),
            choices: [
              for (final lang in Language.values)
                EnrolChoice(
                  lang,
                  l10n.enumLabel('language', lang.wire) ?? lang.wire,
                ),
            ],
          ),
          const SizedBox(height: OrbitSpace.s16),
          ConsentPanel(
            phone: _phone.text,
            language: _language,
            enabled: !_saving,
            offline: offline,
            onChanged: (c) => setState(() => _consent = c),
          ),
          const SizedBox(height: OrbitSpace.s20),
          OrbitButton(
            label: claim ? l10n.faEnrolContinueClaim : l10n.commonNext,
            icon: OrbitIcons.chevronRight,
            loading: _saving,
            onPressed: (canGoOn || e164 == null) && !busy
                ? () => _continue(t)
                : null,
          ),
          if (!offline) ...[
            const SizedBox(height: OrbitSpace.s12),
            InfoRow(icon: OrbitIcons.offline, text: l10n.faEnrolOfflineHint),
          ],
        ],
        if (!showForm) ...[
          const SizedBox(height: OrbitSpace.s16),
          Text(l10n.faEnrolOtherNumber, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }

  /// "Already your farmer": open them, finish their enrolment, or record
  /// consent.
  Widget _mineCard(Territory t, String? farmerId) {
    final l10n = context.l10n;
    final orbit = OrbitColors.of(context);
    final f = farmerId == null ? null : t.farmer(farmerId);
    final row = f == null ? null : t.farmerRow(f.id);
    final finish = f == null ? null : finishEnrolmentLocation(t, f.id);
    final needsConsent =
        row?.enrolmentGaps.contains(EnrolmentGap.consent) ?? false;
    return EnrolNotice(
      icon: OrbitIcons.verified,
      tone: orbit.success,
      title: l10n.faEnrolMineTitle,
      body: f == null
          ? l10n.faEnrolMineBodyUnknown
          : l10n.faEnrolMineBody(name: f.displayName(contentLanguage(context))),
      live: true,
      actions: [
        if (finish != null)
          OrbitButton(
            label: l10n.faEnrolFinishEnrolment,
            icon: OrbitIcons.enrol,
            onPressed: () => context.go(finish),
          ),
        if (needsConsent && f != null)
          OrbitButton(
            label: l10n.faEnrolRecordConsent,
            icon: OrbitIcons.consent,
            variant: OrbitButtonVariant.secondary,
            onPressed: () => showRecordConsentSheet(context, farmerId: f.id),
          ),
        if (farmerId != null)
          OrbitButton(
            label: l10n.faEnrolOpenFarmer,
            icon: OrbitIcons.person,
            variant: OrbitButtonVariant.secondary,
            onPressed: () => context.go(AppRoutes.farmer(farmerId)),
          ),
      ],
    );
  }

  Widget _stopCard(String title, String body, {required bool withCallHo}) {
    final l10n = context.l10n;
    final orbit = OrbitColors.of(context);
    return EnrolNotice(
      icon: OrbitIcons.alert,
      tone: orbit.danger,
      title: title,
      body: body,
      live: true,
      actions: [
        if (withCallHo)
          OrbitButton(
            label: l10n.faEnrolCallHo,
            icon: OrbitIcons.phoneCall,
            variant: OrbitButtonVariant.call,
            onPressed: () => callHo(context, ref),
          ),
      ],
    );
  }

  Widget _photoRow(bool offline) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final photo = _photo;
    if (offline && _photoState != _PhotoState.uploaded) {
      return InfoRow(icon: OrbitIcons.camera, text: l10n.faEnrolPhotoOffline);
    }
    if (photo == null) {
      return OrbitButton(
        label: l10n.faEnrolPhoto,
        icon: OrbitIcons.camera,
        variant: OrbitButtonVariant.secondary,
        onPressed: _saving ? null : _takePhoto,
      );
    }
    final (String text, IconData icon) = switch (_photoState) {
      _PhotoState.uploading => (l10n.faEnrolPhotoUploading, OrbitIcons.upload),
      _PhotoState.uploaded => (l10n.faEnrolPhotoAdded, OrbitIcons.success),
      _ => (l10n.faEnrolPhotoFailed, OrbitIcons.warning),
    };
    return EnrolCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(OrbitRadius.md),
            ),
            child: Image.memory(
              photo.bytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              semanticLabel: l10n.faEnrolPhoto,
            ),
          ),
          const SizedBox(width: OrbitSpace.s12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(icon, size: OrbitSize.iconMd),
                  const SizedBox(width: OrbitSpace.s6),
                  Expanded(
                    child: Text(text, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
          if (_photoState == _PhotoState.failed)
            TextButton(onPressed: _upload, child: Text(l10n.commonRetry))
          else if (_photoState == _PhotoState.uploaded)
            TextButton(
              onPressed: _saving ? null : _takePhoto,
              child: Text(l10n.faEnrolPhotoRetake),
            ),
        ],
      ),
    );
  }
}
