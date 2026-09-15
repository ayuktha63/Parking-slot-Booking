// ─────────────────────────────────────────────────────────────────────────────
// REAL TIME
//
// One socket for the app, with an authenticated handshake.
//
// What it is for, precisely: the slot grid must change under the customer's finger
// when someone else takes a slot. Without that, two people spend two minutes each
// filling in a checkout form for the same space and one of them is refused at the
// end — which is the single worst moment a booking product can produce.
//
// What it is NOT for: deciding anything. Every event here updates a local view of
// server state that the server will re-assert on the next request. A socket message
// is a hint to redraw, never a source of truth. If the socket never connects, the
// app is slower to notice a change and otherwise works identically.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

/// A slot changed state in a lot we are watching.
@immutable
class SlotUpdateEvent {
  const SlotUpdateEvent({
    required this.parkingAreaId,
    required this.vehicleType,
    required this.slotId,
    required this.status,
    required this.heldByYou,
    this.expiresAt,
  });

  factory SlotUpdateEvent.fromJson(Map<String, dynamic> json) => SlotUpdateEvent(
        parkingAreaId: (json['parking_area_id'] as num?)?.toInt() ?? 0,
        vehicleType: json['vehicle_type'] as String? ?? '',
        slotId: (json['slot_id'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'available',
        // Resolved per-socket by the server from the token, never from a payload
        // the client could have influenced.
        heldByYou: json['held_by_you'] == true,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')?.toUtc(),
      );

  final int parkingAreaId;
  final String vehicleType;
  final int slotId;
  final String status;
  final bool heldByYou;
  final DateTime? expiresAt;
}

/// One of the caller's bookings changed.
@immutable
class BookingUpdateEvent {
  const BookingUpdateEvent({required this.bookingId, required this.status});

  factory BookingUpdateEvent.fromJson(Map<String, dynamic> json) => BookingUpdateEvent(
        bookingId: (json['id'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
      );

  final int bookingId;
  final String status;
}

/// The caller's hold lapsed. The server's word on it, which settles any
/// disagreement with a device whose timer stalled.
@immutable
class HoldExpiredEvent {
  const HoldExpiredEvent({required this.holdId, required this.slotId});

  factory HoldExpiredEvent.fromJson(Map<String, dynamic> json) => HoldExpiredEvent(
        holdId: (json['hold_id'] as num?)?.toInt() ?? 0,
        slotId: (json['slot_id'] as num?)?.toInt() ?? 0,
      );

  final int holdId;
  final int slotId;
}

/// The parking area the customer is looking at was reconfigured by its operator.
///
/// Price, hours, amenities or capacity. The payload says what changed, never the
/// new value — a client acting on values from a socket would be treating an event
/// as the source of truth.
@immutable
class ParkingConfigChangedEvent {
  const ParkingConfigChangedEvent({required this.parkingAreaId, required this.change});

  factory ParkingConfigChangedEvent.fromJson(Map<String, dynamic> json) =>
      ParkingConfigChangedEvent(
        parkingAreaId: (json['parking_area_id'] as num?)?.toInt() ?? 0,
        change: json['change'] as String? ?? 'unknown',
      );

  final int parkingAreaId;
  final String change;
}

/// Returns a currently valid access token, refreshing the session if needed.
typedef AccessTokenProvider = Future<String?> Function();

class RealtimeService {
  RealtimeService(this._accessToken);

  final AccessTokenProvider _accessToken;

  io.Socket? _socket;

  final _slotUpdates = StreamController<SlotUpdateEvent>.broadcast();
  final _bookingUpdates = StreamController<BookingUpdateEvent>.broadcast();
  final _holdExpiries = StreamController<HoldExpiredEvent>.broadcast();
  final _configChanges = StreamController<ParkingConfigChangedEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  final _resyncs = StreamController<void>.broadcast();

  /// Set after the first successful connection, so a later connect is known to
  /// be a RE-connect.
  bool _connectedBefore = false;

  Stream<SlotUpdateEvent> get slotUpdates => _slotUpdates.stream;
  Stream<BookingUpdateEvent> get bookingUpdates => _bookingUpdates.stream;
  Stream<HoldExpiredEvent> get holdExpiries => _holdExpiries.stream;
  Stream<ParkingConfigChangedEvent> get configChanges => _configChanges.stream;
  Stream<bool> get connectionState => _connection.stream;

  /// Fires when the socket comes back after being disconnected.
  ///
  /// Events sent while the app was offline — a server restart, a tunnel, a
  /// phone switching networks — are simply gone; socket.io does not replay
  /// them. Anything showing server state must refetch when this fires, or the
  /// operator's check-in that happened during the gap never reaches the screen.
  Stream<void> get resyncs => _resyncs.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// The room currently subscribed to, so a reconnect can restore it.
  ({int parkingAreaId, String vehicleType})? _subscription;

  Future<void> connect() async {
    if (_socket != null) return;

    // The handshake carries the access token, fetched fresh on EVERY connect
    // attempt. A token captured once at startup is expired fifteen minutes later;
    // the server then accepts the reconnect as anonymous, never joins the user
    // room, and booking events stop arriving with no visible error.
    final socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(8)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .setAuthFn((callback) {
            _accessToken().then(
              (token) => callback(token == null ? <String, dynamic>{} : {'token': token}),
              onError: (Object _) => callback(<String, dynamic>{}),
            );
          })
          .build(),
    );

    socket.onConnect((_) {
      _connection.add(true);
      if (_connectedBefore) _resyncs.add(null);
      _connectedBefore = true;
      // Re-subscribe: a reconnect starts with no rooms, and silently not being in
      // one looks exactly like "nothing is happening".
      final pending = _subscription;
      if (pending != null) {
        _emitSubscribe(pending.parkingAreaId, pending.vehicleType);
      }
    });

    socket.onDisconnect((_) => _connection.add(false));

    socket.on('slot:update', (data) {
      if (data is Map) {
        _slotUpdates.add(SlotUpdateEvent.fromJson(data.cast<String, dynamic>()));
      }
    });

    socket.on('booking:update', (data) {
      if (data is Map) {
        _bookingUpdates.add(BookingUpdateEvent.fromJson(data.cast<String, dynamic>()));
      }
    });

    socket.on('hold:expired', (data) {
      if (data is Map) {
        _holdExpiries.add(HoldExpiredEvent.fromJson(data.cast<String, dynamic>()));
      }
    });

    socket.on('parking:config', (data) {
      if (data is Map) {
        _configChanges.add(ParkingConfigChangedEvent.fromJson(data.cast<String, dynamic>()));
      }
    });

    socket.onConnectError((error) {
      // Not surfaced to the user: real time is an enhancement, and an app that
      // shows a connection error for a feature nobody asked for is worse than one
      // that quietly refetches.
      if (kDebugMode) debugPrint('socket connect error: $error');
      _connection.add(false);
    });

    _socket = socket;
    socket.connect();
  }

  /// Watches one lot and vehicle type.
  ///
  /// The server leaves any previous parking room on subscribe, so switching lots
  /// cannot accumulate subscriptions — a real defect in the operator app, which
  /// joined a new room on every vehicle-type switch and never left the old one, so
  /// events arrived two and three times over.
  void subscribeToParking({required int parkingAreaId, required String vehicleType}) {
    _subscription = (parkingAreaId: parkingAreaId, vehicleType: vehicleType);
    _emitSubscribe(parkingAreaId, vehicleType);
  }

  void _emitSubscribe(int parkingAreaId, String vehicleType) {
    _socket?.emit('parking:subscribe', {
      'parking_area_id': parkingAreaId,
      'vehicle_type': vehicleType,
    });
  }

  void unsubscribeFromParking() {
    final current = _subscription;
    _subscription = null;
    if (current == null) return;
    _socket?.emit('parking:unsubscribe', {
      'parking_area_id': current.parkingAreaId,
      'vehicle_type': current.vehicleType,
    });
  }

  /// Reconnects with a new token after sign-in or sign-out, because the room
  /// membership the server grants depends on who the handshake says you are.
  Future<void> reauthenticate() async {
    await disconnect();
    await connect();
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    socket.dispose();
    _connection.add(false);
  }

  Future<void> dispose() async {
    await disconnect();
    await _slotUpdates.close();
    await _bookingUpdates.close();
    await _holdExpiries.close();
    await _configChanges.close();
    await _connection.close();
    await _resyncs.close();
  }
}
