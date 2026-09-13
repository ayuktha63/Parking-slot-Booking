// ─────────────────────────────────────────────────────────────────────────────
// FIRST RUN — NAME AND VEHICLE
//
// Shown once, only when the account has no real name yet.
//
// This is the step the old flow got backwards: registration collected a name and
// then sent the user BACK to the login screen to retype their phone number, so
// anyone who signed in before registering ended up permanently named "User" — and
// could never change it, because Edit Name called an endpoint that did not exist.
//
// The vehicle is optional here. A user who skips it is asked for a plate once, at
// booking time, and can save it then.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/parking.dart' show VehicleType;
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';

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
    _nameController.addListener(() {
      if (_nameError != null) setState(() => _nameError = null);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _nameController.text.trim().length >= 2;

  Future<void> _submit({required bool withVehicle}) async {
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
            vehicleType: withVehicle && plate.isNotEmpty ? _vehicleType.wire : null,
            numberPlate: withVehicle && plate.isNotEmpty ? plate : null,
          );
      // The router redirects to Home once the profile is complete.
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.huge),
              Text('Nice to meet you', style: context.text.displayMedium),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Just a name, so we know what to call you.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              AppTextField(
                label: 'Your name',
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                errorText: _nameError,
                maxLength: 60,
              ),

              const SizedBox(height: AppSpacing.xxl),

              Text('Add a vehicle', style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Optional — it saves typing your number plate later.',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  for (final type in VehicleType.values) ...[
                    if (type != VehicleType.values.first) const SizedBox(width: AppSpacing.sm),
                    AppFilterChip(
                      label: type.label,
                      icon: type == VehicleType.car
                          ? Icons.directions_car_rounded
                          : Icons.two_wheeler_rounded,
                      selected: _vehicleType == type,
                      onTap: () => setState(() => _vehicleType = type),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                label: 'Number plate',
                controller: _plateController,
                hint: 'KL 01 AB 1234',
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                maxLength: 16,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 \-]')),
                  UpperCaseTextFormatter(),
                ],
                onSubmitted: (_) => _submit(withVehicle: true),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                InlineBanner(
                  message: _error!.message,
                  icon: Icons.error_outline_rounded,
                  tone: BannerTone.danger,
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              PrimaryButton(
                label: 'Start parking',
                isLoading: _submitting,
                onPressed: _canSubmit ? () => _submit(withVehicle: true) : null,
              ),

              const SizedBox(height: AppSpacing.sm),

              Center(
                child: TertiaryButton(
                  label: 'Skip the vehicle for now',
                  onPressed:
                      _canSubmit && !_submitting ? () => _submit(withVehicle: false) : null,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plates are stored and compared uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
