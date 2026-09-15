// ─────────────────────────────────────────────────────────────────────────────
// SIGN IN — NAME
//
// Step 3, first sign-in only. A name (operators see it on their arrivals board)
// and, optionally, the vehicle — which saves typing a plate at every booking.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/parqx_controls.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();

  VehicleType _vehicleType = VehicleType.car;
  bool _submitting = false;
  String? _nameError;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() => _nameError = null));
    _plateController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _nameController.text.trim().length >= 2;

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final plate = _plateController.text.trim();
      await ref.read(authControllerProvider.notifier).completeProfile(
            name: _nameController.text.trim(),
            vehicleType: plate.isNotEmpty ? _vehicleType.wire : null,
            numberPlate: plate.isNotEmpty ? plate : null,
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.kind == ApiErrorKind.validation) {
          _nameError = e.fieldError('name');
          if (_nameError == null) _error = e;
        } else {
          _error = e;
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPlate = _plateController.text.trim().isNotEmpty;
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
                  Text("What's your name?", style: context.text.displaySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Parking operators see it when you arrive.',
                    style: context.text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    controller: _nameController,
                    hint: 'Full name',
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    errorText: _nameError,
                    maxLength: 60,
                  ),
                  const SizedBox(height: AppSpacing.huge),
                  Text('Your vehicle', style: context.text.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Optional. Saves typing your number plate every time you book.',
                    style: context.text.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Segmented<VehicleType>(
                    value: _vehicleType,
                    semanticLabel: 'Vehicle type',
                    onChanged: (type) => setState(() => _vehicleType = type),
                    options: const [
                      SegmentOption(
                        value: VehicleType.car,
                        label: 'Car',
                        icon: Icons.directions_car_filled_rounded,
                      ),
                      SegmentOption(
                        value: VehicleType.bike,
                        label: 'Bike',
                        icon: Icons.two_wheeler_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _plateController,
                    hint: 'Number plate, e.g. KA 01 AB 1234',
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    maxLength: 16,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 \-]')),
                      UpperCaseTextFormatter(),
                    ],
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    InlineBanner(message: _error!.message, tone: BannerTone.danger),
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
              child: PrimaryButton(
                label: hasPlate ? 'Save and continue' : 'Continue without a vehicle',
                trailingIcon: Icons.arrow_forward_rounded,
                isLoading: _submitting,
                onPressed: _canSubmit ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
