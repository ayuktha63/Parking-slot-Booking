// ─────────────────────────────────────────────────────────────────────────────
// SIGN IN — CODE
//
// Step 2: verify the one-time code and establish a real session.
//
// On success the app receives an access token and a rotating refresh token; the
// refresh token goes to the platform keychain, which is the first persistence
// either app has ever had.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _submitting = false;
  ApiException? _error;

  Timer? _ticker;
  int _resendIn = 0;

  @override
  void initState() {
    super.initState();

    final challenge = ref.read(authControllerProvider.notifier).pendingChallenge;
    _resendIn = challenge?.resendAfterSeconds ?? 30;
    _startTicker();

    // Outside production the API returns the code so nobody waits on a WhatsApp
    // message during development. Never present in a release build — the server
    // refuses to start in production with that flag on.
    final devOtp = challenge?.devOtp;
    if (devOtp != null && !AppConfig.isProduction) {
      _controller.text = devOtp;
    }

    _controller.addListener(() {
      if (_error != null) setState(() => _error = null);
      // Six digits entered: submit without making the user reach for a button.
      if (_controller.text.length == 6 && !_submitting) _submit();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 999));
      if (_resendIn == 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6 || _submitting) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(code);
      // The router's redirect takes over: Home, or the profile step for a new user.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _controller.clear();
      });
      _focusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    final phone = ref.read(authControllerProvider.notifier).pendingPhone;
    if (phone == null || _resendIn > 0) return;

    setState(() => _error = null);
    try {
      final challenge = await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      setState(() => _resendIn = challenge.resendAfterSeconds);
      _startTicker();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('New code sent')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(authControllerProvider.notifier).pendingPhone;

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('Enter the code', style: context.text.displayMedium),
              const SizedBox(height: AppSpacing.md),
              Text.rich(
                TextSpan(
                  style: context.text.bodyMedium,
                  children: [
                    const TextSpan(text: 'Sent to '),
                    TextSpan(
                      text: phone == null ? 'your phone' : '+91 $phone',
                      style: context.text.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // A single wide field with generous letter spacing reads as a code
              // entry without the focus-management problems of six separate boxes.
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                enabled: !_submitting,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: context.text.displayLarge?.copyWith(
                  letterSpacing: 14,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '······',
                  contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                InlineBanner(
                  message: _error!.message,
                  icon: Icons.error_outline_rounded,
                  tone: BannerTone.danger,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              PrimaryButton(
                label: 'Verify',
                isLoading: _submitting,
                onPressed: _controller.text.length == 6 ? _submit : null,
              ),

              const SizedBox(height: AppSpacing.lg),

              Center(
                child: _resendIn > 0
                    ? Text('Resend code in ${_resendIn}s', style: context.text.bodySmall)
                    : TertiaryButton(
                        label: 'Resend code',
                        icon: Icons.refresh_rounded,
                        onPressed: _resend,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
