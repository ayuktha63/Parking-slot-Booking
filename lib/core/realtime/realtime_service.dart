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
import '../../shared/models/ids.dart';

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
        parkingAreaId: parseId(json['parking_area_id'], 'slot:update.parking_area_id'),
        vehicleType: json['vehicle_type'] as String? ?? '',
        slotId: parseId(json['slot_id'], 'slot:update.slot_id'),
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
        bookingId: parseId(json['id'], 'booking:update.id'),
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
        holdId: parseId(json['hold_id'], 'hold:expired.hold_id'),
        // Optional: only the hold id is acted on, and an older hold has no slot id.
        slotId: parseOptionalId(json['slot_id'], 'hold:expired.slot_id'),
      );

  final int holdId;
  final int? slotId;
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
        parkingAreaId: parseId(json['parking_area_id'], 'parking:config.parking_area_id'),
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

  /// Parking rooms wanted by what is on screen, oldest first.
  ///
  /// Screens stack — a lot's page, and its spot grid on top — but the server keeps
  /// one parking room per socket. The newest request wins; closing it restores the
  /// one beneath. With a single slot, closing the grid left the lot page in no room
  /// at all, so an operator's change never reached it.
  final List<({int token, int parkingAreaId, String vehicleType})> _subscriptions = [];
  int _nextToken = 0;

  ({int token, int parkingAreaId, String vehicleType})? get _subscription =>
      _subscriptions.isEmpty ? null : _subscriptions.last;

  /// The room the socket should be in right now.
  @visibleForTesting
  ({int parkingAreaId, String vehicleType})? get activeParkingRoom {
    final active = _subscription;
    return active == null ? null : (parkingAreaId: active.parkingAreaId, vehicleType: active.vehicleType);
  }

  /// Parses one socket payload onto its stream. A malformed payload is dropped:
  /// events only prompt a refetch of the server's state, so losing one costs a
  /// moment of staleness, while throwing inside the socket callback costs more.
  void _deliver<T>(
    Object? data,
    StreamController<T> sink,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (data is! Map) return;
    try {
      sink.add(parse(data.cast<String, dynamic>()));
    } on FormatException catch (e) {
      if (kDebugMode) debugPrint('socket payload dropped: ${e.message}');
    }
  }

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

    socket.on('slot:update', (data) => _deliver(data, _slotUpdates, SlotUpdateEvent.fromJson));
    socket.on('booking:update', (data) => _deliver(data, _bookingUpdates, BookingUpdateEvent.fromJson));
    socket.on('hold:expired', (data) => _deliver(data, _holdExpiries, HoldExpiredEvent.fromJson));
    socket.on('parking:config', (data) => _deliver(data, _configChanges, ParkingConfigChangedEvent.fromJson));

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
  /// Joins a lot's room — `vehicleType` 'car', 'bike', or 'all' for the lot-wide
  /// room. Returns a handle for [unsubscribeFromParking].
  int subscribeToParking({required int parkingAreaId, required String vehicleType}) {
    final token = ++_nextToken;
    _subscriptions.add((token: token, parkingAreaId: parkingAreaId, vehicleType: vehicleType));
    _emitSubscribe(parkingAreaId, vehicleType);
    return token;
  }

  void _emitSubscribe(int parkingAreaId, String vehicleType) {
    _socket?.emit('parking:subscribe', {
      'parking_area_id': parkingAreaId,
      'vehicle_type': vehicleType,
    });
  }

  /// Releases one subscription. If it was the active room, the one beneath it is
  /// rejoined; screens can close in any order, so this goes by handle, not position.
  void unsubscribeFromParking(int token) {
    final index = _subscriptions.indexWhere((s) => s.token == token);
    if (index == -1) return;
    final wasActive = index == _subscriptions.length - 1;
    final released = _subscriptions.removeAt(index);
    if (!wasActive) return;

    final next = _subscription;
    if (next != null) {
      _emitSubscribe(next.parkingAreaId, next.vehicleType);
    } else {
      _socket?.emit('parking:unsubscribe', {
        'parking_area_id': released.parkingAreaId,
        'vehicle_type': released.vehicleType,
      });
    }
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
