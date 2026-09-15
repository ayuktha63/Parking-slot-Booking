// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT
//
// Who you are, your vehicles, and the way out. Every row does something real:
// there is no row here for a feature the app does not have.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/interaction.dart';
import '../../../shared/widgets/parqx_controls.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final vehicles = ref.watch(userVehiclesProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final name = user?.name?.trim();
    final hasName = name != null && name.isNotEmpty && !(user?.needsProfile ?? true);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(
        padding: EdgeInsets.only(bottom: bottomInset + AppSpacing.xl),
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageInset,
                AppSpacing.xl,
                AppSpacing.pageInset,
                AppSpacing.xl,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasName ? name : 'Your account',
                          style: context.text.displaySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          user?.displayPhone ?? '',
                          style: context.text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Pressable(
                    onTap: () => _editName(context, ref, user),
                    depth: PressDepth.firm,
                    tint: false,
                    borderRadius: AppRadius.chip,
                    semanticLabel: 'Edit your name',
                    child: Container(
                      width: AppSizes.avatarLg,
                      height: AppSizes.avatarLg,
                      decoration: const BoxDecoration(color: AppColors.fill, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: hasName
                          ? Text(name[0].toUpperCase(), style: context.text.headlineLarge)
                          : const Icon(Icons.person_rounded, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: Row(
              children: [
                Expanded(
                  child: _Tile(
                    icon: Icons.directions_car_filled_rounded,
                    label: 'Vehicles',
                    onTap: () => context.push(Routes.vehicles),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Tile(
                    icon: Icons.receipt_long_rounded,
                    label: 'Activity',
                    onTap: () => context.go(Routes.bookings),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Tile(
                    icon: Icons.local_parking_rounded,
                    label: 'Park',
                    onTap: () => context.go(Routes.home),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _GroupGap(),
          ListRow(
            icon: Icons.person_outline_rounded,
            title: 'Name',
            value: hasName ? name : 'Add your name',
            onTap: () => _editName(context, ref, user),
          ),
          ListRow(
            icon: Icons.directions_car_outlined,
            title: 'Saved vehicles',
            value: vehicles.isEmpty
                ? 'None yet'
                : '${vehicles.length} saved',
            onTap: () => context.push(Routes.vehicles),
          ),
          ListRow(
            icon: Icons.phone_iphone_rounded,
            title: 'Phone number',
            value: user?.displayPhone,
            chevron: false,
          ),
          const _GroupGap(),
          ListRow(
            icon: Icons.info_outline_rounded,
            title: 'About PARQX',
            value: AppConfig.versionLabel,
            onTap: () => _showAbout(context),
          ),
          const _GroupGap(),
          ListRow(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            destructive: true,
            chevron: false,
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Center(child: ParqxWordmark(size: 16)),
        ],
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
        const Text('Map data ${AppConfig.mapAttribution}.'),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, AppUser? user) async {
    final saved = await showAppSheet<bool>(
      context: context,
      child: _EditNameSheet(initial: user?.needsProfile == true ? '' : (user?.name ?? '')),
    );
    if (saved == true && context.mounted) showToast(context, 'Name updated');
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppSheet<bool>(
      context: context,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'Sign out?', subtitle: 'You can sign back in with your phone number.'),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.pageInset, AppSpacing.sm, AppSpacing.pageInset, AppSpacing.lg),
              child: Builder(
                builder: (sheetContext) => Column(
                  children: [
                    PrimaryButton(
                      label: 'Sign out',
                      tone: ButtonTone.danger,
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TertiaryButton(label: 'Stay signed in', onPressed: () => Navigator.of(sheetContext).pop(false)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: PressDepth.standard,
      borderRadius: AppRadius.card,
      semanticLabel: label,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(color: AppColors.fill, borderRadius: AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 26),
            Text(label, style: context.text.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _GroupGap extends StatelessWidget {
  const _GroupGap();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: SizedBox(height: 8, width: double.infinity, child: ColoredBox(color: AppColors.fillSubtle)),
    );
  }
}

class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet({required this.initial});

  final String initial;

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter at least 2 characters');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateName(name);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldError('name') ?? e.message);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'Your name', subtitle: 'Parking operators see it when you arrive.'),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.pageInset, AppSpacing.sm, AppSpacing.pageInset, AppSpacing.lg),
              child: Column(
                children: [
                  AppTextField(
                    controller: _controller,
                    hint: 'Full name',
                    autofocus: true,
                    errorText: _error,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(label: 'Save', isLoading: _saving, onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
