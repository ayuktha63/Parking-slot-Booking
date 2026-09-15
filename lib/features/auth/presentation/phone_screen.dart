// ─────────────────────────────────────────────────────────────────────────────
// SIGN IN — PHONE
//
// Step 1 of real authentication: one question, one field, one black button that
// rides above the keyboard.
//
// The number is sent exactly as it will be verified — ten digits — so "+91..." and
// "98765..." can never become two accounts.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/parqx_controls.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _submitting = false;
  String? _fieldError;
  ApiException? _requestError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// A plausible Indian mobile number, so the button itself teaches the format.
  bool get _isValid => RegExp(r'^[6-9]\d{9}$').hasMatch(_digits);

  String get _digits => _controller.text.replaceAll(RegExp(r'\D'), '');

  void _onChanged() {
    setState(() {
      _fieldError = null;
      _requestError = null;
    });
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() {
      _submitting = true;
      _requestError = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(_digits);
      if (!mounted) return;
      context.push(Routes.otp);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.kind == ApiErrorKind.validation) {
          _fieldError = e.fieldError('phone') ?? e.message;
        } else {
          _requestError = e;
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionError = ref.watch(authControllerProvider).error;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageInset,
                  AppSpacing.lg,
                  AppSpacing.pageInset,
                  AppSpacing.lg,
                ),
                children: [
                  const Align(alignment: Alignment.centerLeft, child: ParqxWordmark(size: 20)),
                  const SizedBox(height: AppSpacing.huge),
                  Text("What's your phone number?", style: context.text.displaySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "We'll send you a code to confirm it's you.",
                    style: context.text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (sessionError != null) ...[
                    InlineBanner(
                      message: sessionError.message,
                      icon: Icons.lock_clock_rounded,
                      tone: BannerTone.warning,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: AppSizes.fieldHeight,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
                        decoration: const BoxDecoration(
                          color: AppColors.fill,
                          borderRadius: AppRadius.field,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '+91',
                              style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          hint: 'Mobile number',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.telephoneNumberNational],
                          maxLength: 10,
                          errorText: _fieldError,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onSubmitted: (_) => _submit(),
                          style: context.text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_requestError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    InlineBanner(
                      message: _requestError!.message,
                      tone: BannerTone.danger,
                      actionLabel: _requestError!.isRetryable ? 'Try again' : null,
                      onAction: _requestError!.isRetryable ? _submit : null,
                    ),
                  ],
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
              child: Column(
                children: [
                  Text(
                    'By continuing, you agree to our Terms and Privacy Policy.',
                    style: context.text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Continue',
                    trailingIcon: Icons.arrow_forward_rounded,
                    isLoading: _submitting,
                    onPressed: _isValid ? _submit : null,
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
