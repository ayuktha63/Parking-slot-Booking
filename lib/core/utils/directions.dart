// ─────────────────────────────────────────────────────────────────────────────
// DIRECTIONS
//
// Hands navigation to the phone's own maps app with the lot's real coordinates.
// PARQX does not route; it gets you to the place that routes best.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openDirectionsTo(BuildContext context, LatLng position, String label) async {
  final geo = Uri.parse(
    'geo:${position.latitude},${position.longitude}'
    '?q=${position.latitude},${position.longitude}(${Uri.encodeComponent(label)})',
  );
  final web = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${position.latitude},${position.longitude}',
  );
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (await canLaunchUrl(geo)) {
    await launchUrl(geo, mode: LaunchMode.externalApplication);
  } else if (await canLaunchUrl(web)) {
    await launchUrl(web, mode: LaunchMode.externalApplication);
  } else {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('No maps app is available on this device.')));
  }
}
