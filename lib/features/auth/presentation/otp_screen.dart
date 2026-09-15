// ─────────────────────────────────────────────────────────────────────────────
// SIGN IN — CODE
//
// Step 2: verify the one-time code and establish a real session (an access token
// and a rotating refresh token kept in the platform keychain).
//
// Six boxes over a single hidden field, so paste and SMS autofill both work.
// Six digits submit on their own.
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
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _length = 6;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _submitting = false;
  ApiException? _error;

  Timer? _ticker;
  int _resendIn = 0;

  /// Captured once: the controller forgets the phone as soon as verification
  /// succeeds, while this screen is still on its way out.
  String? _phone;

  @override
  void initState() {
    super.initState();
    _phone = ref.read(authControllerProvider.notifier).pendingPhone;
    final challenge = ref.read(authControllerProvider.notifier).pendingChallenge;
    _resendIn = challenge?.resendAfterSeconds ?? 30;
    _startTicker();

    // Outside production the API returns the code so development does not wait
    // on a real message. Never present in a release build: the server refuses to
    // start in production with that flag on, and this check is a second lock.
    final devOtp = challenge?.devOtp;
    if (devOtp != null && !AppConfig.isProduction) {
      _controller.text = devOtp;
    }

    _controller.addListener(() {
      setState(() => _error = null);
      if (_controller.text.length == _length && !_submitting) _submit();
    });

    _focusNode.addListener(() => setState(() {}));

    if (_controller.text.length == _length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
    }
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
    if (code.length != _length || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(code);
      // The router moves on by itself once the session exists; stay in the
      // verifying state until it does rather than flashing back to "Next".
    } on Object catch (e) {
      if (!mounted) return;
      // Clear before setting the error: the controller listener dismisses the
      // error on every change, so the other order erases it in the same frame.
      _controller.clear();
      setState(() {
        _submitting = false;
        _error = e is ApiException
            ? e
            : ApiException(
                kind: ApiErrorKind.unknown,
                message: "We couldn't check that code. Please try again.",
              );
      });
      // The field is disabled while verifying; focus it once it is enabled again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  Future<void> _resend() async {
    final phone = _phone;
    if (phone == null || _resendIn > 0) return;
    setState(() => _error = null);
    try {
      final challenge = await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      setState(() => _resendIn = challenge.resendAfterSeconds);
      _startTicker();
      showToast(context, 'New code sent');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  String _formatPhone(String? phone) {
    if (phone == null || phone.length != 10) return phone == null ? 'your phone' : '+91 $phone';
    return '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone;
    final text = _controller.text;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageInset,
                  AppSpacing.huge,
                  AppSpacing.pageInset,
                  AppSpacing.lg,
                ),
                children: [
                  Text('Enter the 6-digit code', style: context.text.displaySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text.rich(
                    TextSpan(
                      style: context.text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
                      children: [
                        const TextSpan(text: 'Sent to '),
                        TextSpan(
                          text: _formatPhone(phone),
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Stack(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < _length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _DigitBox(
                                digit: i < text.length ? text[i] : null,
                                active: _focusNode.hasFocus &&
                                    !_submitting &&
                                    (i == text.length ||
                                        (i == _length - 1 && text.length == _length)),
                                error: _error != null,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            autofocus: true,
                            enabled: !_submitting,
                            keyboardType: TextInputType.number,
                            showCursor: false,
                            enableInteractiveSelection: false,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(_length),
                            ],
                            decoration: const InputDecoration(
                              counterText: '',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!.message,
                      style: context.text.bodyMedium?.copyWith(color: AppColors.negative),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PillButton(
                      label: _resendIn > 0
                          ? 'Resend code in 0:${_resendIn.toString().padLeft(2, '0')}'
                          : 'Resend code',
                      icon: Icons.refresh_rounded,
                      onPressed: _resendIn > 0 || _submitting ? null : _resend,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageInset,
                AppSpacing.sm,
                AppSpacing.pageInset,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  const BackCircleButton(),
                  const Spacer(),
                  PrimaryButton(
                    label: 'Next',
                    trailingIcon: Icons.arrow_forward_rounded,
                    expand: false,
                    isLoading: _submitting,
                    onPressed: text.length == _length ? _submit : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({required this.digit, required this.active, required this.error});

  final String? digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.instant,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: AppRadius.field,
        border: Border.all(
          color: error
              ? AppColors.negative
              : active
                  ? AppColors.ink
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: Text(
        digit ?? '',
        style: AppTypography.numeric(size: 24, weight: FontWeight.w700),
      ),
    );
  }
}
