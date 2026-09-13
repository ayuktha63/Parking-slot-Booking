// ─────────────────────────────────────────────────────────────────────────────
// SEARCH
//
// Server-backed search with suggestions and recents.
//
// The old "search" was a TextField that ran `name.contains()` over whatever had
// already been downloaded, so it could only ever find a lot already on screen. This
// queries the backend across name, locality, city and landmark, and offers area
// suggestions alongside specific lots.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/discovery_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/states.dart';
import '../data/parking_repository.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _term = '';

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
    context.pop();
    context.push(Routes.parkingDetail(id));
  }

  @override
  Widget build(BuildContext context) {
    final recents = ref.watch(recentSearchesProvider);
    final suggestions = ref.watch(searchSuggestionsProvider(_term));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: const BackButton(),
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _term = v),
          onSubmitted: _submit,
          style: context.text.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search area, landmark or parking',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            suffixIcon: _term.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _term = '');
                    },
                  ),
          ),
        ),
      ),
      body: _term.trim().length < 2
          ? _RecentsView(
              recents: recents,
              onTap: _submit,
              onRemove: (t) => ref.read(recentSearchesProvider.notifier).remove(t),
              onClear: () => ref.read(recentSearchesProvider.notifier).clear(),
            )
          : suggestions.when(
              loading: () => const _SuggestionSkeleton(),
              error: (_, __) => EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'Search unavailable',
                message: 'We could not search right now. Check your connection and try again.',
                compact: true,
              ),
              data: (items) => items.isEmpty
                  ? EmptyStateView(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message: 'Nothing found for "${_term.trim()}". Try a different area or landmark.',
                      compact: true,
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: AppSpacing.pageInset + 40,
                        color: context.colors.outline,
                      ),
                      itemBuilder: (context, i) => _SuggestionTile(
                        suggestion: items[i],
                        onTap: () {
                          final s = items[i];
                          if (s.isParking && s.parkingId != null) {
                            _openParking(s.parkingId!);
                          } else {
                            _submit(s.title);
                          }
                        },
                      ),
                    ),
            ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.onTap});

  final SearchSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isParking = suggestion.isParking;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(AppRadius.rSm),
        ),
        child: Icon(
          isParking ? Icons.local_parking_rounded : Icons.place_outlined,
          size: AppSizes.iconSm,
          color: context.colors.onSurfaceVariant,
        ),
      ),
      title: Text(suggestion.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: suggestion.subtitle == null
          ? (suggestion.parkingCount != null
              ? Text('${suggestion.parkingCount} parking areas')
              : null)
          : Text(suggestion.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: suggestion.distanceMetres == null
          ? const Icon(Icons.north_west_rounded, size: AppSizes.iconSm)
          : Text(
              _distance(suggestion.distanceMetres!),
              style: context.text.bodySmall,
            ),
    );
  }

  static String _distance(int metres) =>
      metres < 1000 ? '${(metres / 10).round() * 10} m' : '${(metres / 1000).toStringAsFixed(1)} km';
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
        title: 'Search for parking',
        message: 'Try an area, a landmark, or the name of a parking lot.',
        compact: true,
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(child: Text('Recent', style: context.text.titleSmall)),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
        ),
        for (final term in recents)
          ListTile(
            onTap: () => onTap(term),
            leading: const Icon(Icons.history_rounded),
            title: Text(term),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, size: AppSizes.iconSm),
              onPressed: () => onRemove(term),
              tooltip: 'Remove',
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
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pageInset,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            LoadingSkeleton(height: 40, width: 40),
            SizedBox(width: AppSpacing.md),
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
