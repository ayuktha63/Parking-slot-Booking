// ─────────────────────────────────────────────────────────────────────────────
// MONEY
//
// Integer paise, mirroring the backend exactly.
//
// The old app held a `final double price = 1`, charged Razorpay 100 paise, stored
// something else entirely, and rendered "$5.00" on the confirmation screen. A typed
// value object makes a unit mix-up a compile error rather than a support ticket.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

@immutable
class Money implements Comparable<Money> {
  const Money(this.paise);

  /// Parses a server value. Defensive by design: a null or malformed amount
  /// becomes zero rather than crashing a list that is mid-build.
  factory Money.fromJson(dynamic value) {
    if (value == null) return Money.zero;
    if (value is int) return Money(value < 0 ? 0 : value);
    if (value is num) return Money(value.round().clamp(0, 1 << 62));
    return Money(int.tryParse(value.toString()) ?? 0);
  }

  factory Money.rupees(num rupees) => Money((rupees * 100).round());

  static const Money zero = Money(0);

  final int paise;

  int get rupees => paise ~/ 100;
  int get paiseRemainder => paise % 100;
  bool get isZero => paise == 0;

  /// "₹40" or "₹40.50" — decimals only when they carry information.
  String get display => _format();

  /// Always shows decimals. For receipts and totals, where alignment matters.
  String get displayExact => _format(alwaysDecimals: true);

  /// "₹40/hr"
  String perHour() => '$display/hr';

  String _format({bool alwaysDecimals = false}) {
    final grouped = _groupIndian(rupees);
    if (paiseRemainder == 0 && !alwaysDecimals) return '₹$grouped';
    return '₹$grouped.${paiseRemainder.toString().padLeft(2, '0')}';
  }

  /// Indian digit grouping: 1234567 → "12,34,567"
  static String _groupIndian(int n) {
    final s = n.abs().toString();
    if (s.length <= 3) return n < 0 ? '-$s' : s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '${n < 0 ? '-' : ''}$buf,$last3';
  }

  Money operator +(Money other) => Money(paise + other.paise);
  Money operator -(Money other) => Money((paise - other.paise).clamp(0, 1 << 62));
  Money operator *(int factor) => Money(paise * factor);

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => display;
}
