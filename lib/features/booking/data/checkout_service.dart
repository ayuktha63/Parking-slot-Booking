// ─────────────────────────────────────────────────────────────────────────────
// CHECKOUT SERVICE
//
// The only place in the app that touches the Razorpay plugin.
//
// Isolated for three reasons: the plugin's callback API is awkward to use from a
// state notifier, it is the one dependency that cannot run in a test, and keeping
// it behind a Future-returning method means the rest of the booking flow is plain
// async code.
//
// What this class deliberately does NOT do is decide whether a payment succeeded.
// It reports what the gateway handed back. The server decides what that means.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../shared/models/booking.dart';

/// How checkout ended, from the device's point of view.
enum CheckoutOutcome {
  /// The gateway returned a signature. NOT proof of payment — the server still
  /// has to verify it, and may reject it.
  returned,

  /// The customer dismissed the sheet.
  cancelled,

  /// The gateway reported a failure (declined card, timeout, network).
  failed,

  /// Checkout could not be opened at all.
  unavailable,
}

@immutable
class CheckoutResult {
  const CheckoutResult({
    required this.outcome,
    this.orderId,
    this.paymentId,
    this.signature,
    this.message,
    this.code,
  });

  const CheckoutResult.cancelled({String? message})
      : this(outcome: CheckoutOutcome.cancelled, message: message);

  final CheckoutOutcome outcome;

  /// Present only when [outcome] is [CheckoutOutcome.returned].
  final String? orderId;
  final String? paymentId;
  final String? signature;

  final String? message;
  final String? code;

  /// True when there is something for the server to verify. Note the wording: a
  /// signature to check, not a payment that worked.
  bool get hasSignature =>
      outcome == CheckoutOutcome.returned &&
      (orderId?.isNotEmpty ?? false) &&
      (paymentId?.isNotEmpty ?? false) &&
      (signature?.isNotEmpty ?? false);
}

class CheckoutService {
  Razorpay? _razorpay;
  Completer<CheckoutResult>? _pending;

  /// Opens Checkout and completes when the gateway reports back.
  ///
  /// One checkout at a time: a second call while one is open completes the new
  /// request as unavailable rather than leaving two completers racing for the same
  /// callbacks.
  Future<CheckoutResult> open({required PaymentOrder order}) async {
    if (_pending != null && !_pending!.isCompleted) {
      return const CheckoutResult(
        outcome: CheckoutOutcome.unavailable,
        message: 'A payment is already in progress.',
      );
    }

    if (!order.isUsable) {
      // No key id means the deployment has no gateway configured. Saying so is the
      // honest outcome; opening an empty sheet is not.
      return const CheckoutResult(
        outcome: CheckoutOutcome.unavailable,
        message: 'Payments are not available right now. Please try again shortly.',
      );
    }

    final completer = Completer<CheckoutResult>();
    _pending = completer;

    final razorpay = Razorpay();
    _razorpay = razorpay;

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      _complete(CheckoutResult(
        outcome: CheckoutOutcome.returned,
        orderId: response.orderId ?? order.providerOrderId,
        paymentId: response.paymentId,
        signature: response.signature,
      ));
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      // Razorpay reports a user dismissal through the same error channel as a real
      // failure. Distinguishing them matters: one deserves "payment failed", the
      // other deserves saying nothing at all.
      final isCancellation = response.code == Razorpay.PAYMENT_CANCELLED;
      _complete(CheckoutResult(
        outcome: isCancellation ? CheckoutOutcome.cancelled : CheckoutOutcome.failed,
        code: response.code?.toString(),
        message: isCancellation ? null : _readableFailure(response.message),
      ));
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      // The customer left for a wallet app. The payment may still complete, and the
      // webhook will tell us — so this is not a failure.
      _complete(CheckoutResult(
        outcome: CheckoutOutcome.returned,
        orderId: order.providerOrderId,
        message: 'Finishing payment in ${response.walletName ?? 'your wallet app'}',
      ));
    });

    try {
      razorpay.open({
        'key': order.keyId,
        'order_id': order.providerOrderId,
        // Sent for display only. The order was created server-side for this exact
        // amount and the gateway charges what the ORDER says, not what is passed
        // here — so a tampered value cannot change what is collected.
        'amount': order.amount.paise,
        'currency': order.currency,
        'name': 'PARQX',
        'description': order.description,
        if (order.bookingCode != null) 'receipt': order.bookingCode,
        // Phone and name only. PARQX never collects an email address, so there is
        // none to prefill and none is fabricated.
        'prefill': {
          if (order.prefillContact != null) 'contact': order.prefillContact,
          if (order.prefillName != null) 'name': order.prefillName,
        },
        // The app's ink colour, so the gateway sheet reads as part of PARQX.
        'theme': {'color': '#000000'},
        'retry': {'enabled': true, 'max_count': 2},
        'timeout': 300,
      });
    } on Object catch (e) {
      _complete(CheckoutResult(
        outcome: CheckoutOutcome.unavailable,
        message: 'Checkout could not be opened.',
        code: e.runtimeType.toString(),
      ));
    }

    return completer.future;
  }

  void _complete(CheckoutResult result) {
    final pending = _pending;
    _pending = null;
    _disposeRazorpay();
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  /// Razorpay's own messages are sometimes a JSON blob. Show the readable part, or
  /// nothing — never a raw payload.
  String? _readableFailure(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{')) return trimmed;
    final match = RegExp(r'"description"\s*:\s*"([^"]+)"').firstMatch(trimmed);
    return match?.group(1);
  }

  void _disposeRazorpay() {
    try {
      _razorpay?.clear();
    } on Object {
      // Clearing a plugin that never opened is not an error worth surfacing.
    }
    _razorpay = null;
  }

  /// Called when the owning provider is disposed, so a pending checkout does not
  /// leave a completer that nothing will ever complete.
  void dispose() {
    final pending = _pending;
    _pending = null;
    _disposeRazorpay();
    if (pending != null && !pending.isCompleted) {
      pending.complete(const CheckoutResult(
        outcome: CheckoutOutcome.cancelled,
        message: 'Payment was interrupted.',
      ));
    }
  }
}
