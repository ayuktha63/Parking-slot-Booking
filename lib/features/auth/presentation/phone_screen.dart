// ─────────────────────────────────────────────────────────────────────────────
// SIGN IN — PHONE
//
// Step 1 of real authentication.
//
// The screen it replaces was named `_verifyPhone` and verified nothing: it posted
// the number to `/api/users/register`, an endpoint that cannot fail, and treated any
// 200/201 as a successful login. Typing any digits granted that identity — including
// a stranger's, which also granted their full booking history.
//
// It also displayed a "+91" prefix that was NOT prepended to the value sent, so
// "+919876543210" and "9876543210" created two different accounts.
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
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';

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

  /// Enabled only on a plausible Indian mobile number, so the button state itself
  /// teaches the format instead of waiting for a server rejection.
  bool get _isValid => RegExp(r'^[6-9]\d{9}$').hasMatch(_digits);

  String get _digits => _controller.text.replaceAll(RegExp(r'\D'), '');

  void _onChanged() {
    if (_fieldError != null || _requestError != null) {
      setState(() {
        _fieldError = null;
        _requestError = null;
      });
    } else {
      setState(() {}); // refresh the button's enabled state
    }
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _requestError = null;
    });

    try {
      // The normalised digits are what is sent — no decorative prefix that the
      // request then ignores.
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
    // Surfaces "your session ended" after a refresh failure, so the user knows why
    // they are looking at this screen.
    final sessionError = ref.watch(authControllerProvider).error;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 2),

                      Text('PARQX',
                          style: AppTypography.wordmark(size: 34, color: AppColors.brand)),
                      const SizedBox(height: AppSpacing.xxxl),

                      Text('Find parking,\nreserve in seconds',
                          style: context.text.displayMedium),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        "We'll text you a code to confirm it's you.",
                        style: context.text.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxxl),

                      if (sessionError != null) ...[
                        InlineBanner(
                          message: sessionError.message,
                          icon: Icons.lock_clock_rounded,
                          tone: BannerTone.warning,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      AppTextField(
                        label: 'Mobile number',
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        maxLength: 10,
                        errorText: _fieldError,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        onSubmitted: (_) => _submit(),
                        prefix: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Text('+91', style: context.text.bodyLarge),
                        ),
                      ),

                      if (_requestError != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        InlineBanner(
                          message: _requestError!.message,
                          icon: Icons.error_outline_rounded,
                          tone: BannerTone.danger,
                          actionLabel: _requestError!.isRetryable ? 'Retry' : null,
                          onAction: _requestError!.isRetryable ? _submit : null,
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),

                      PrimaryButton(
                        label: 'Continue',
                        isLoading: _submitting,
                        onPressed: _isValid ? _submit : null,
                      ),

                      const Spacer(flex: 3),

                      Center(
                        child: Text(
                          'By continuing you agree to our Terms and Privacy Policy.',
                          style: context.text.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
