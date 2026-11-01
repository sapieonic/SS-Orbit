import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/call_buttons.dart';
import '../../shared/sign_in_scaffold.dart';
import '../../shared/voice.dart';

/// F1, phone step: language choice, the phone number and "Send OTP".
///
/// On success the session moves to `otpSent` and the router shows the OTP
/// step by itself. Rate limits and network trouble are shown in place.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _phone;
  bool _sending = false;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    // After "Change number" on the OTP step the number comes back prefilled.
    final saved = ref.read(sessionProvider).phone;
    _phone = TextEditingController(
      text: saved == null ? '' : _nationalDigits(saved),
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  static String _nationalDigits(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    return digits.length > IndianMobileNumberFormatter.length
        ? digits.substring(digits.length - IndianMobileNumberFormatter.length)
        : digits;
  }

  bool get _complete =>
      _phone.text.length == IndianMobileNumberFormatter.length;

  bool get _valid => isValidIndianMobile(_phone.text);

  Future<void> _send() async {
    if (!_valid || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).requestOtp(_phone.text);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setLanguage(Language language) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionProvider.notifier).setLanguage(language);
    } on Object catch (e) {
      // The app language changed; only saving it on this phone (or an active
      // farmer's profile) failed. Worded in the new language, which the
      // screen rebuilds in.
      if (!mounted) return;
      final l10n = lookupOrbitLocalizations(Locale(language.wire));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorTextIn(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final language = ref.watch(appLanguageProvider);
    final showDev = ref.watch(mockScenarioProvider) != null;

    final fieldError = switch (_error) {
      ApiError(code: ApiErrorCode.validationFailed) =>
        l10n.farmerLoginPhoneInvalid,
      _ when _complete && !_valid => l10n.farmerLoginPhoneInvalid,
      _ => null,
    };
    final otherError = _error?.code == ApiErrorCode.validationFailed
        ? null
        : _error;

    return SignInScaffold(
      header: ScreenHeader(
        title: l10n.commonAppName,
        subtitle: l10n.farmerLoginTagline,
        listen: const ScreenListenButton(
          voiceKey: VoiceKeys.farmerLoginVoiceHelpPhone,
        ),
      ),
      content: [
        InfoRow(
          icon: OrbitIcons.language,
          text: l10n.farmerLoginChooseLanguage,
        ),
        const SizedBox(height: OrbitSpace.s8),
        SegmentedTabs(
          labels: [
            l10n.labelLanguage(Language.te.wire),
            l10n.labelLanguage(Language.en.wire),
          ],
          selectedIndex: language == Language.te ? 0 : 1,
          onChanged: _sending
              ? null
              : (i) => _setLanguage(i == 0 ? Language.te : Language.en),
        ),
        const SizedBox(height: OrbitSpace.s24),
        Text(l10n.farmerLoginPhoneTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: OrbitSpace.s4),
        Text(
          l10n.farmerLoginPhoneSubtitle,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: OrbitSpace.s16),
        PhoneField(
          controller: _phone,
          hint: l10n.farmerLoginPhoneHint,
          errorText: fieldError,
          enabled: !_sending,
          onChanged: (_) => setState(() {
            if (_error?.code == ApiErrorCode.validationFailed) _error = null;
          }),
          onSubmitted: (_) => _send(),
        ),
        if (otherError != null) ...[
          const SizedBox(height: OrbitSpace.s12),
          InlineError(errorText(context, otherError)),
        ],
        if (showDev)
          const Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _DevMenuButton(),
          ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrbitButton(
            label: l10n.farmerLoginSendOtp,
            icon: OrbitIcons.send,
            size: OrbitButtonSize.hero,
            loading: _sending,
            onPressed: _valid ? _send : null,
          ),
          const SizedBox(height: OrbitSpace.s4),
          const HelplineLink(),
        ],
      ),
    );
  }
}

/// The way into the dev menu, shown only on mock data. Deliberately small
/// and English-only: farmers never see it in staging or prod.
class _DevMenuButton extends StatelessWidget {
  const _DevMenuButton();

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Developer tools',
    icon: Icon(
      OrbitIcons.settings,
      size: OrbitSize.iconMd,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    onPressed: () => context.push(Routes.dev),
  );
}
