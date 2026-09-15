// ─────────────────────────────────────────────────────────────────────────────
// SEARCH
//
// "Where do you want to park?" — an area, a landmark or a place by name.
// Picking a place opens it; picking an area (or submitting text) searches for it
// and returns to the map, which frames what was found.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/discovery_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/interaction.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(discoveryQueryProvider).searchTerm ?? '');
  late String _term = _controller.text;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(t);
    ref.read(discoveryQueryProvider.notifier).setSearchTerm(t);
    context.pop();
  }

  void _openParking(int id) {
    final router = GoRouter.of(context);
    context.pop();
    router.push(Routes.parkingDetail(id));
  }

  @override
  Widget build(BuildContext context) {
    final recents = ref.watch(recentSearchesProvider);
    final suggestions = ref.watch(searchSuggestionsProvider(_term));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.pageInset,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: AppTextField(
                      controller: _controller,
                      autofocus: true,
                      hint: 'Where do you want to park?',
                      prefixIcon: Icons.search_rounded,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => setState(() => _term = v),
                      onSubmitted: _submit,
                      suffix: _term.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              tooltip: 'Clear',
                              onPressed: () {
                                _controller.clear();
                                setState(() => _term = '');
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const Hairline(),
            Expanded(
              child: _term.trim().length < 2
                  ? _RecentsView(
                      recents: recents,
                      onTap: _submit,
                      onRemove: (t) => ref.read(recentSearchesProvider.notifier).remove(t),
                      onClear: () => ref.read(recentSearchesProvider.notifier).clear(),
                    )
                  : suggestions.when(
                      loading: () => const _SuggestionSkeleton(),
                      error: (_, __) => const EmptyStateView(
                        icon: Icons.wifi_off_rounded,
                        title: 'Search is unavailable',
                        message: 'Check your connection and try again.',
                        compact: true,
                      ),
                      data: (items) => items.isEmpty
                          ? _NoMatches(term: _term.trim(), onSearchAnyway: () => _submit(_term))
                          : ListView(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                              children: [
                                for (final s in items)
                                  ListRow(
                                    icon: s.isParking
                                        ? Icons.local_parking_rounded
                                        : Icons.place_outlined,
                                    title: s.title,
                                    subtitle: s.subtitle ??
                                        (s.parkingCount == null
                                            ? null
                                            : '${s.parkingCount} parking place${s.parkingCount == 1 ? '' : 's'}'),
                                    value: s.distanceMetres == null
                                        ? null
                                        : _distance(s.distanceMetres!),
                                    chevron: false,
                                    onTap: () {
                                      if (s.isParking && s.parkingId != null) {
                                        _openParking(s.parkingId!);
                                      } else {
                                        _submit(s.title);
                                      }
                                    },
                                  ),
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _distance(int metres) => metres < 1000
      ? '${(metres / 10).round() * 10} m'
      : '${(metres / 1000).toStringAsFixed(1)} km';
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.term, required this.onSearchAnyway});

  final String term;
  final VoidCallback onSearchAnyway;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        ListRow(
          icon: Icons.search_rounded,
          title: 'Search for "$term"',
          subtitle: 'Look for parking matching this on the map',
          chevron: false,
          onTap: onSearchAnyway,
        ),
      ],
    );
  }
}

class _RecentsView extends StatelessWidget {
  const _RecentsView({
    required this.recents,
    required this.onTap,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> recents;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (recents.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_rounded,
        title: 'Find a place to park',
        message: 'Search by area, landmark or the name of a parking place.',
        compact: true,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        SectionHeader(title: 'Recent', actionLabel: 'Clear', onAction: onClear),
        for (final term in recents)
          ListRow(
            icon: Icons.history_rounded,
            title: term,
            chevron: false,
            onTap: () => onTap(term),
            trailing: Pressable(
              onTap: () => onRemove(term),
              depth: PressDepth.firm,
              tint: false,
              borderRadius: AppRadius.chip,
              semanticLabel: 'Remove $term',
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Icon(Icons.close_rounded, size: 18, color: AppColors.inkTertiary),
              ),
            ),
          ),
      ],
    );
  }
}

class _SuggestionSkeleton extends StatelessWidget {
  const _SuggestionSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageInset, vertical: AppSpacing.md),
        child: Row(
          children: [
            LoadingSkeleton.circle(size: 40),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoadingSkeleton.text(width: 180, height: 14),
                  SizedBox(height: AppSpacing.sm),
                  LoadingSkeleton.text(width: 110, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
