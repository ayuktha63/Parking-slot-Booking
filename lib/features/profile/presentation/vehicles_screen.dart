// ─────────────────────────────────────────────────────────────────────────────
// VEHICLES
//
// The account's saved vehicles, backed by /me/vehicles: add, set the default the
// booking screen pre-selects, and remove.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/parqx_controls.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../auth/presentation/profile_setup_screen.dart' show UpperCaseTextFormatter;

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(userVehiclesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Vehicles')),
      body: vehicles.isEmpty
          ? const EmptyStateView(
              icon: Icons.directions_car_filled_outlined,
              title: 'No saved vehicles',
              message: 'Save your vehicle once and it is filled in every time you book.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const Hairline(indent: 72, endIndent: AppSpacing.pageInset),
              itemBuilder: (context, i) => _VehicleRow(vehicle: vehicles[i]),
            ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: 'Add a vehicle',
          icon: Icons.add_rounded,
          onPressed: () async {
            final added = await showAppSheet<bool>(context: context, child: const _AddVehicleSheet());
            if (added == true && context.mounted) showToast(context, 'Vehicle saved');
          },
        ),
      ),
    );
  }
}

class _VehicleRow extends ConsumerWidget {
  const _VehicleRow({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListRow(
      leading: IconDisc(
        icon: vehicle.vehicleType == VehicleType.bike
            ? Icons.two_wheeler_rounded
            : Icons.directions_car_filled_rounded,
      ),
      title: vehicle.displayPlate,
      subtitle: [
        vehicle.title,
        if (vehicle.isDefault) 'Default',
      ].join(' · '),
      chevron: false,
      trailing: PopupMenuButton<String>(
        tooltip: 'Vehicle options',
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (action) async {
          final auth = ref.read(authControllerProvider.notifier);
          try {
            if (action == 'default') {
              await auth.setDefaultVehicle(vehicle.id);
              if (context.mounted) showToast(context, '${vehicle.displayPlate} is now your default');
            } else if (action == 'remove') {
              await auth.removeVehicle(vehicle.id);
              if (context.mounted) showToast(context, 'Vehicle removed');
            }
          } on ApiException catch (e) {
            if (context.mounted) showToast(context, e.message);
          }
        },
        itemBuilder: (_) => [
          if (!vehicle.isDefault) const PopupMenuItem(value: 'default', child: Text('Make default')),
          PopupMenuItem(
            value: 'remove',
            child: Text('Remove', style: context.text.bodyLarge?.copyWith(color: AppColors.negative)),
          ),
        ],
      ),
    );
  }
}

class _AddVehicleSheet extends ConsumerStatefulWidget {
  const _AddVehicleSheet();

  @override
  ConsumerState<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends ConsumerState<_AddVehicleSheet> {
  final _plate = TextEditingController();
  final _label = TextEditingController();
  VehicleType _type = VehicleType.car;
  bool _makeDefault = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plate.addListener(() => setState(() => _error = null));
    _makeDefault = false;
  }

  /// The server makes the first vehicle of each type that type's default, so
  /// for a first car or first bike the choice is not the customer's to make.
  bool get _firstOfType => !ref.read(userVehiclesProvider).any((v) => v.vehicleType == _type);

  @override
  void dispose() {
    _plate.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final plate = _plate.text.trim();
    if (plate.replaceAll(RegExp(r'[\s-]'), '').length < 4) {
      setState(() => _error = 'Enter the full number plate');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).addVehicle(
            vehicleType: _type.wire,
            numberPlate: plate,
            label: _label.text.trim().isEmpty ? null : _label.text.trim(),
            isDefault: _firstOfType || _makeDefault,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldError('number_plate') ?? e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader(title: 'Add a vehicle'),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.pageInset, AppSpacing.xs, AppSpacing.pageInset, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Segmented<VehicleType>(
                      value: _type,
                      semanticLabel: 'Vehicle type',
                      onChanged: (t) => setState(() => _type = t),
                      options: const [
                        SegmentOption(value: VehicleType.car, label: 'Car', icon: Icons.directions_car_filled_rounded),
                        SegmentOption(value: VehicleType.bike, label: 'Bike', icon: Icons.two_wheeler_rounded),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Number plate',
                      controller: _plate,
                      hint: 'KA 01 AB 1234',
                      autofocus: true,
                      errorText: _error,
                      maxLength: 16,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 \-]')),
                        UpperCaseTextFormatter(),
                      ],
                      style: AppTypography.code(size: 16, spacing: 1),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Nickname (optional)',
                      controller: _label,
                      hint: _type == VehicleType.bike ? 'e.g. Office scooter' : 'e.g. Family car',
                      maxLength: 30,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Default ${_type.label.toLowerCase()}'),
                      subtitle: Text(
                        _firstOfType
                            ? 'Your first ${_type.label.toLowerCase()} is pre-selected when you book'
                            : 'Pre-selected when you book a ${_type.label.toLowerCase()} spot',
                      ),
                      value: _firstOfType || _makeDefault,
                      onChanged: _firstOfType ? null : (v) => setState(() => _makeDefault = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(label: 'Save vehicle', isLoading: _saving, onPressed: _save),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
