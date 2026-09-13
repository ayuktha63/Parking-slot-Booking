// ─────────────────────────────────────────────────────────────────────────────
// BOOKINGS
//
// Four tabs over one endpoint. The server decides which statuses constitute
// "upcoming" and which "completed", because the operator app has to agree with it.
//
// Every card offers actions the SERVER said are possible — `booking.actions` — so a
// button is never shown for something that would be refused. That is the difference
// between a considered UI and one that hopes.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/parqx_photo.dart';
import '../../../shared/widgets/states.dart';
import 'cancel_booking_sheet.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: BookingBucket.values.length, vsync: this);

  @override
  void initState() {
    super.initState();
    // Open on Active when something is in progress — the thing most likely to be
    // wanted is the thing happening right now.
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _selectMostRelevantTab());
  }

  Future<void> _selectMostRelevantTab() async {
    final counts = await ref.read(bookingCountsProvider.future);
    if (!mounted) return;
    if (counts.active > 0) {
      _tabs.animateTo(BookingBucket.active.index);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The subscription lives on AppShell, so it covers every tab rather than only
    // this one. Watching it again here would be a second listener on one stream.
    final counts = ref.watch(bookingCountsProvider).valueOrNull ?? BookingCounts.empty;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        toolbarHeight: 76,
        // Title and subtitle, matching every other top-level screen. A bare
        // "Bookings" told the user what they already knew from the tab they
        // tapped; the second line says what the screen actually holds.
        titleSpacing: AppSpacing.pageInset,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bookings', style: context.text.displaySmall),
            const SizedBox(height: 2),
            Text(
              'Your parking history',
              style: context.text.bodyMedium
                  ?.copyWith(color: AppColors.inkSecondaryDark),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          // A filled pill on the selected tab rather than an underline: the
          // underline is Material's mark, and on a dark ground a 2px rule under
          // small text is close to invisible.
          indicator: const BoxDecoration(
            color: AppColors.brand,
            borderRadius: AppRadius.chip,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.symmetric(vertical: 7),
          dividerColor: Colors.transparent,
          labelColor: AppColors.onBrand,
          unselectedLabelColor: AppColors.inkMutedDark,
          labelStyle: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: context.text.labelMedium,
          labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: BookingBucket.values.map((bucket) {
            final count = counts.forBucket(bucket);
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(bucket.label),
                  if (count > 0) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _CountBadge(count: count, active: _tabs.index == bucket.index),
                  ],
                ],
              ),
            );
          }).toList(growable: false),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: BookingBucket.values
            .map((bucket) => _BucketView(bucket: bucket))
            .toList(growable: false),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.active});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: active ? AppColors.brand : context.colors.surfaceContainerHighest,
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        '$count',
        style: context.text.labelSmall?.copyWith(
          color: active ? AppColors.onBrand : context.colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/* ── one tab ───────────────────────────────────────────────────────────────── */

/// One day's worth of bookings.
class _DayGroup {
  const _DayGroup({required this.label, required this.bookings});
  final String? label;
  final List<Booking> bookings;
}

/// Groups by the LOCAL calendar day of the booking's entry time.
///
/// Relative labels only for the two days a customer thinks in — anything
/// further out is a date, because "in 9 days" is harder to act on than
/// "Fri, 22 Sep". Bookings with no entry time keep their own unlabelled group
/// rather than being silently filed under today.
List<_DayGroup> _groupByDay(List<Booking> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final buckets = <DateTime?, List<Booking>>{};
  for (final booking in items) {
    final entry = booking.window.entryTime?.toLocal();
    final day = entry == null ? null : DateTime(entry.year, entry.month, entry.day);
    buckets.putIfAbsent(day, () => []).add(booking);
  }

  String label(DateTime day) {
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(day);
  }

  final keys = buckets.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    });

  return [
    for (final key in keys)
      _DayGroup(label: key == null ? null : label(key), bookings: buckets[key]!),
  ];
}

class _BucketView extends ConsumerWidget {
  const _BucketView({required this.bucket});

  final BookingBucket bucket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingListProvider(bucket));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingListProvider(bucket));
        ref.invalidate(bookingCountsProvider);
        await ref.read(bookingListProvider(bucket).future);
      },
      child: bookings.when(
        loading: () => const _ListSkeleton(),
        error: (error, _) => ListView(
          children: [
            const SizedBox(height: AppSpacing.huge),
            ErrorStateView(
              error: asApiException(error),
              onRetry: () => ref.invalidate(bookingListProvider(bucket)),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) return _EmptyBucket(bucket: bucket);

          // Grouped by day.
          //
          // A flat list of bookings makes the reader do the date arithmetic:
          // every card repeats a full date, and "is that one today?" takes a
          // second per row. Grouping lifts the date out once per day and lets
          // the cards carry only the time — which is the thing that actually
          // differs between two bookings on the same day.
          //
          // Only where a day is meaningful. Cancelled bookings are read as a
          // list of things that did not happen, not as a schedule.
          final grouped = bucket == BookingBucket.cancelled
              ? <_DayGroup>[_DayGroup(label: null, bookings: items)]
              : _groupByDay(items);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageInset,
              AppSpacing.lg,
              AppSpacing.pageInset,
              AppSpacing.bottomNavClearance,
            ),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final group = grouped[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (group.label != null) ...[
                    if (index > 0) const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        group.label!,
                        style: context.text.titleMedium
                            ?.copyWith(color: AppColors.inkSecondaryDark),
                      ),
                    ),
                  ],
                  for (var i = 0; i < group.bookings.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    BookingCard(booking: group.bookings[i]),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyBucket extends StatelessWidget {
  const _EmptyBucket({required this.bucket});

  final BookingBucket bucket;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = switch (bucket) {
      BookingBucket.upcoming => (
          'No upcoming bookings',
          'Reserve a slot and it will appear here with your booking code and directions.',
          Icons.event_available_outlined,
        ),
      BookingBucket.active => (
          'You are not parked right now',
          'When you check in, your live parking session shows here.',
          Icons.local_parking_outlined,
        ),
      BookingBucket.completed => (
          'No completed bookings yet',
          'Finished parking sessions and their receipts appear here.',
          Icons.history_rounded,
        ),
      BookingBucket.cancelled => (
          'Nothing cancelled',
          'Cancelled and expired bookings are kept here for your records.',
          Icons.cancel_outlined,
        ),
    };

    return ListView(
      children: [
        const SizedBox(height: AppSpacing.huge),
        EmptyStateView(
          title: title,
          message: message,
          icon: icon,
          action: bucket == BookingBucket.upcoming
              ? SizedBox(
                  width: 200,
                  child: Builder(
                    builder: (context) => PrimaryButton(
                      label: 'Find parking',
                      icon: Icons.search_rounded,
                      onPressed: () => context.go(Routes.home),
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/* ── card ──────────────────────────────────────────────────────────────────── */

/// One booking.
///
/// The action row is built from `booking.actions`, which the server computed. No
/// button appears for something that would be refused, and none is shown that does
/// nothing.
class BookingCard extends ConsumerWidget {
  const BookingCard({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      color: AppColors.surfaceDark,
      onTap: () => context.push(Routes.bookingDetail(booking.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The same photograph the customer chose the place by. Without it
              // the booking screens were the only surface in the product with no
              // imagery, and a list of bookings read as a database export.
              ParqxPhoto(
                url: booking.parking.coverPhotoUrl,
                seed: booking.parking.name,
                width: 56,
                height: 56,
                borderRadius: AppRadius.tile,
                dimmed: booking.status.isTerminal,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.parking.name,
                      style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (booking.parking.shortLocation != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: AppSizes.iconXs, color: AppColors.inkMutedDark),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                                // Locality and city, not the street line:
                                // the full address truncated on every card.
                              booking.parking.shortLocation!,
                              style: context.text.bodySmall
                                  ?.copyWith(color: AppColors.inkMutedDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              BookingStatusChip(booking: booking),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: context.colors.outline),
          const SizedBox(height: AppSpacing.md),

          // Wrapped so a long plate or a narrow screen reflows rather than clipping.
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              if (booking.window.entryTime != null)
                _Fact(
                  icon: Icons.schedule_rounded,
                  label: _whenLabel(booking),
                ),
              if (booking.slot != null)
                _Fact(icon: Icons.grid_view_rounded, label: 'Slot ${booking.slot!.code}'),
              if (booking.vehicle.numberPlate != null)
                _Fact(
                  icon: booking.vehicle.type.wire == 'bike'
                      ? Icons.two_wheeler_rounded
                      : Icons.directions_car_rounded,
                  label: booking.vehicle.numberPlate!,
                ),
              _Fact(
                icon: Icons.payments_outlined,
                label: booking.amount.payable.display,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          _ActionRow(booking: booking),
        ],
      ),
    );
  }

  static String _whenLabel(Booking booking) {
    final entry = booking.window.entryTime;
    if (entry == null) return '—';

    final now = DateTime.now();
    final isToday = entry.year == now.year && entry.month == now.month && entry.day == now.day;
    final isTomorrow = entry.difference(DateTime(now.year, now.month, now.day)).inDays == 1;

    final time = DateFormat('h:mm a').format(entry);
    if (isToday) return 'Today, $time';
    if (isTomorrow) return 'Tomorrow, $time';
    return DateFormat('d MMM, h:mm a').format(entry);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconXs, color: context.colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: context.text.bodySmall),
      ],
    );
  }
}

/// Status, in the shared colour language. Never red for a normal outcome — red is
/// reserved for things that are actually wrong.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (booking.status) {
      BookingStatus.pendingPayment => (
          AppColors.warningSoft,
          AppColors.warning,
          Icons.hourglass_top_rounded,
        ),
      BookingStatus.confirmed => (
          AppColors.successSoft,
          AppColors.success,
          Icons.check_circle_rounded,
        ),
      BookingStatus.checkedIn => (
          AppColors.brandSoft,
          AppColors.brandStrong,
          Icons.local_parking_rounded,
        ),
      BookingStatus.completed => (
          AppColors.slotOccupiedSoft,
          AppColors.slotOccupied,
          Icons.task_alt_rounded,
        ),
      BookingStatus.cancelled => (
          AppColors.slotClosedSoft,
          AppColors.inkMuted,
          Icons.cancel_outlined,
        ),
      BookingStatus.expired => (
          AppColors.slotClosedSoft,
          AppColors.inkMuted,
          Icons.timer_off_outlined,
        ),
      BookingStatus.noShow => (
          AppColors.dangerSoft,
          AppColors.danger,
          Icons.person_off_outlined,
        ),
      BookingStatus.unknown => (
          AppColors.slotClosedSoft,
          AppColors.inkMuted,
          Icons.help_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.chip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconXs, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            booking.statusLabel,
            style: context.text.labelSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// The actions this booking actually supports.
class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <Widget>[];

    if (booking.actions.canPay) {
      actions.add(Expanded(
        child: PrimaryButton(
          label: 'Complete payment',
          size: AppButtonSize.compact,
          onPressed: () => context.push(Routes.bookingDetail(booking.id)),
        ),
      ));
    }

    if (booking.actions.canCheckIn) {
      actions.add(Expanded(
        child: PrimaryButton(
          label: 'Check in',
          size: AppButtonSize.compact,
          onPressed: () => _checkIn(context, ref),
        ),
      ));
    }

    if (booking.isParked) {
      actions.add(Expanded(
        child: PrimaryButton(
          label: 'Open parking',
          size: AppButtonSize.compact,
          onPressed: () => context.push(Routes.bookingDetail(booking.id)),
        ),
      ));
    }

    if (booking.parking.hasCoordinates &&
        (booking.status == BookingStatus.confirmed || booking.isParked)) {
      actions.add(Expanded(
        child: SecondaryButton(
          label: 'Directions',
          size: AppButtonSize.compact,
          onPressed: () => openDirections(context, booking),
        ),
      ));
    }

    if (booking.actions.isCancellable && !booking.actions.canPay) {
      actions.add(Expanded(
        child: SecondaryButton(
          label: 'Cancel',
          size: AppButtonSize.compact,
          onPressed: () => showCancelBookingSheet(context, ref, booking),
        ),
      ));
    }

    if (booking.status == BookingStatus.completed) {
      actions.add(Expanded(
        child: SecondaryButton(
          label: 'Book again',
          size: AppButtonSize.compact,
          onPressed: () => context.push(Routes.parkingDetail(booking.parking.id)),
        ),
      ));
      actions.add(Expanded(
        child: SecondaryButton(
          label: 'Receipt',
          size: AppButtonSize.compact,
          onPressed: () => context.push(Routes.bookingDetail(booking.id)),
        ),
      ));
    }

    // Cancelled and expired bookings are kept for the record. Tapping the card
    // opens the detail; there is no separate button that would do the same thing.
    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          actions[i],
        ],
      ],
    );
  }

  Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(bookingActionsProvider).checkIn(booking.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Checked in. Enjoy your stay.')));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Hands off to the platform's maps app. Shared by every screen that offers
/// directions, so the fallback behaviour is written once.
Future<void> openDirections(BuildContext context, Booking booking) async {
  final position = booking.parking.position;
  if (position == null) return;

  final uri = Uri.parse(
    'geo:${position.latitude},${position.longitude}'
    '?q=${position.latitude},${position.longitude}'
    '(${Uri.encodeComponent(booking.parking.name)})',
  );
  final fallback = Uri.parse(
    'https://www.google.com/maps/search/?api=1'
    '&query=${position.latitude},${position.longitude}',
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (await canLaunchUrl(fallback)) {
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('No maps app is available on this device.')));
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.pageInset),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => const LoadingSkeleton(height: 150),
    );
  }
}
