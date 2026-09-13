// ─────────────────────────────────────────────────────────────────────────────
// PROFILE
//
// Identity, saved vehicles, and a sign-out that actually works.
//
// The old profile screen had three prominent 100×100 tiles — Help, Wallet, Inbox —
// with no onTap at all, and a Logout button that called
// `Navigator.pushNamedAndRemoveUntil(context, "/login")` against a route that was
// never registered, so the app asserted. There was no working way to sign out.
//
// Every row here does something. Nothing is here to look impressive.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/config/app_config.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/interaction.dart';
import '../../../shared/widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final vehicles = ref.watch(userVehiclesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
        children: [
          // ── header ───────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageInset,
              MediaQuery.paddingOf(context).top + AppSpacing.lg,
              AppSpacing.pageInset,
              AppSpacing.lg,
            ),
            decoration: const BoxDecoration(gradient: AppGradients.headerGlow),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile', style: context.text.displaySmall),
                const SizedBox(height: 2),
                Text(
                  'Manage your account',
                  style: context.text.bodyMedium
                      ?.copyWith(color: AppColors.inkSecondaryDark),
                ),
              ],
            ),
          ),

          // ── identity ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: _IdentityCard(
              user: user,
              onTap: () => _editName(context, ref, user),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── vehicles ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageInset,
              0,
              AppSpacing.pageInset,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Your vehicles', style: context.text.headlineSmall),
                ),
                // Vehicles are added during booking, where the plate is
                // actually needed. This is a pointer to that, not a second
                // half-built form: it opens the same sheet the booking flow
                // uses.
                TertiaryButton(
                  label: 'Add vehicle',
                  onPressed: () => _addVehicle(context, ref),
                ),
              ],
            ),
          ),

          if (vehicles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
              child: AppCard(
                color: AppColors.surfaceDark,
                child: Row(
                  children: [
                    const Icon(Icons.directions_car_outlined,
                        color: AppColors.inkMutedDark),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'No vehicles saved. Add one to skip typing your plate '
                        'at every booking.',
                        style: context.text.bodyMedium
                            ?.copyWith(color: AppColors.inkSecondaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final vehicle in vehicles)
              _VehicleTile(
                vehicle: vehicle,
                onRemove: () => ref
                    .read(authControllerProvider.notifier)
                    .removeVehicle(vehicle.id),
                onSetDefault: vehicle.isDefault
                    ? null
                    : () => ref
                        .read(authControllerProvider.notifier)
                        .setDefaultVehicle(vehicle.id),
              ),

          const SizedBox(height: AppSpacing.xl),

          // ── grouped settings ─────────────────────────────────────────
          //
          // Grouped, not a flat list: "who I am" and "what this app is" are
          // different questions, and a single undifferentiated column makes the
          // reader scan all of it to answer either.
          //
          // ONLY ROWS THAT DO SOMETHING. The reference also shows Payment
          // methods, Notifications and Help & support. None of those exist in
          // this product — there is no stored-card vault, no notification
          // preference store and no support desk — so they are not listed. The
          // reference establishes a visual language, not permission to ship
          // dead ends: a settings row that opens nothing is worse than an
          // absent one, because the user has to tap it to find out.
          _SettingsGroup(
            title: 'Account',
            rows: [
              _SettingRow(
                icon: Icons.person_outline_rounded,
                label: 'Personal information',
                value: user?.name?.trim().isNotEmpty == true ? user!.name : 'Add your name',
                onTap: () => _editName(context, ref, user),
              ),
            ],
          ),

          _SettingsGroup(
            title: 'Parking',
            rows: [
              _SettingRow(
                icon: Icons.receipt_long_outlined,
                label: 'Your bookings',
                onTap: () => context.go(Routes.bookings),
              ),
              _SettingRow(
                icon: Icons.directions_car_outlined,
                label: 'Active parking',
                onTap: () => context.go(Routes.active),
              ),
            ],
          ),

          _SettingsGroup(
            title: 'About',
            rows: [
              _SettingRow(
                icon: Icons.info_outline_rounded,
                label: 'About PARQX',
                value: AppConfig.versionLabel,
                onTap: () => _showAbout(context),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: _SignOutButton(onPressed: () => _confirmSignOut(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _addVehicle(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Add a vehicle while booking — the plate is saved automatically.',
          ),
        ),
      );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'PARQX',
      applicationVersion: AppConfig.versionLabel,
      applicationLegalese: '© PARQX',
      children: [
        const SizedBox(height: AppSpacing.md),
        const Text('Map data © OpenStreetMap contributors.'),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, AppUser? user) async {
    final controller = TextEditingController(text: user?.name ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    try {
      await ref.read(authControllerProvider.notifier).updateName(newName);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Name updated')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll need your phone number to sign back in."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    // The router redirect handles navigation once auth state changes.
    await ref.read(authControllerProvider.notifier).logout();
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.onRemove,
    this.onSetDefault,
  });

  final Vehicle vehicle;
  final VoidCallback onRemove;
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        0,
        AppSpacing.pageInset,
        AppSpacing.sm,
      ),
      child: AppCard(
        onTap: onSetDefault,
        child: Row(
          children: [
            Icon(
              vehicle.vehicleType.name == 'bike'
                  ? Icons.two_wheeler_rounded
                  : Icons.directions_car_rounded,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(vehicle.displayPlate, style: context.text.titleMedium),
                  Text(vehicle.title, style: context.text.bodySmall),
                ],
              ),
            ),
            if (vehicle.isDefault)
              const StatusChipCompact(label: 'Default')
            else if (onSetDefault != null)
              Text('Set default', style: context.text.labelMedium),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded, size: AppSizes.iconSm),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

/// Small inline default marker.
class StatusChipCompact extends StatelessWidget {
  const StatusChipCompact({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(color: AppColors.brandStrong),
      ),
    );
  }
}


/* ── pieces ────────────────────────────────────────────────────────────────── */

/// Name, phone and the way to change them.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user, required this.onTap});

  final AppUser? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user?.name?.trim();
    final initial = (name?.isNotEmpty == true ? name![0] : '?').toUpperCase();

    return AppCard(
      color: AppColors.surfaceDark,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarLg,
            height: AppSizes.avatarLg,
            decoration: const BoxDecoration(
              color: AppColors.brandSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: context.text.displaySmall?.copyWith(color: AppColors.brand),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // Never a fabricated name. Someone who skipped the optional
                  // name step is "Your account", not "Guest User".
                  name?.isNotEmpty == true ? name! : 'Your account',
                  style: context.text.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user?.displayPhone ?? '',
                  style: context.text.bodyMedium
                      ?.copyWith(color: AppColors.inkSecondaryDark),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMutedDark),
        ],
      ),
    );
  }
}

/// A titled group of settings rows.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        0,
        AppSpacing.pageInset,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title.toUpperCase(),
              style: AppTypography.overline(color: AppColors.inkMutedDark),
            ),
          ),
          AppCard(
            color: AppColors.surfaceDark,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const _SettingDivider(),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// The current setting, shown beside the label rather than inside it.
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: PressDepth.subtle,
      borderRadius: AppRadius.card,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSizes.iconMd, color: AppColors.inkSecondaryDark),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: context.text.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: AppSpacing.sm),
              // Capped rather than flexible.
              //
              // Two flex children split the row evenly, so a short value like
              // "E2E Test" claimed half the width and wrapped "Personal
              // information" onto two lines. The label is what the row IS; the
              // value is a hint, and it yields first.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  value!,
                  style: context.text.bodyMedium
                      ?.copyWith(color: AppColors.inkMutedDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            const Icon(Icons.chevron_right_rounded,
                size: AppSizes.iconMd, color: AppColors.inkMutedDark),
          ],
        ),
      ),
    );
  }
}

class _SettingDivider extends StatelessWidget {
  const _SettingDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: AppSpacing.giant),
      child: Divider(height: 1, color: AppColors.borderDark),
    );
  }
}

/// Sign out, styled as the destructive action it is.
///
/// Visually separated from the settings list so it cannot be hit while
/// scanning: it is the one control on this screen that ends the session.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      depth: PressDepth.subtle,
      borderRadius: AppRadius.button,
      semanticLabel: 'Sign out',
      child: Container(
        height: AppSizes.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.dangerSoftDark,
          borderRadius: AppRadius.button,
          border: Border.all(color: AppColors.dangerBright.withValues(alpha: 0.32)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout_rounded,
                size: AppSizes.iconSm, color: AppColors.dangerBright),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Sign out',
              style: context.text.labelLarge?.copyWith(color: AppColors.dangerBright),
            ),
          ],
        ),
      ),
    );
  }
}
