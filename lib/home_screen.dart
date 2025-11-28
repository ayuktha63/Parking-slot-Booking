// home_screen.dart
import 'dart:convert';
import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'booking_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';
import 'package:geolocator/geolocator.dart';

class AppColors {
  static const Color background = Color(0xFFF7F7F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color subtleText = Color(0xFF9AA0A6);
  static const Color titleText = Color(0xFF222222);
  static const Color accent = Color(0xFF7B61FF); // purple
  static const Color gold = Color(0xFFFCC417);
  static const Color glassBg = Color.fromRGBO(255, 255, 255, 0.15);
  static const Color shadow = Color.fromRGBO(33, 33, 33, 0.08);
  static const Color hint = Color(0xFFB0B0B5);
  static const Color white = Colors.white;
  static const Color error = Color(0xFFD32F2F);
}

class HomeScreen extends StatefulWidget {
  final String phoneNumber;
  const HomeScreen({super.key, required this.phoneNumber});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String apiHost = 'backend-parking-bk8y.onrender.com';

  bool isLoading = true;
  String userName = "Prasad";
  String userLocationLabel = "Trivandrum, Kerala";
  LatLng? _currentLocation;

  List<Map<String, dynamic>> parkingPlaces = [];
  List<Map<String, dynamic>> nearbyPlaces = [];
  List<Map<String, dynamic>> popularPlaces = [];

  String searchQuery = "";
  bool nearbyExpanded = false;
  bool popularExpanded = false;

  @override
  void initState() {
    super.initState();
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      apiHost = '127.0.0.1';
    }
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => isLoading = true);
    await _getDeviceLocation();
    await _fetchUserProfile();
    await _fetchParkingAreas();
    setState(() => isLoading = false);
  }

  Future<void> _getDeviceLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);

      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await http
          .get(Uri.parse('https://$apiHost/api/users/${widget.phoneNumber}'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          userName = json['name'] ?? userName;
          userLocationLabel = json['address'] ??
              "${json['city'] ?? ""}, ${json['state'] ?? ""}".trim();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchParkingAreas() async {
    try {
      final response =
          await http.get(Uri.parse('https://$apiHost/api/parking_areas'));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;

        parkingPlaces = list.map<Map<String, dynamic>>((area) {
          return {
            "id": area['id'],
            "name": area['name'] ?? "Parking",
            "cars": area['available_car_slots'] ?? 0,
            "bikes": area['available_bike_slots'] ?? 0,
            "lat": (area['location']?['lat'] ?? 0.0).toDouble(),
            "lng": (area['location']?['lng'] ?? 0.0).toDouble(),
            "photo": area['photo_url'] ??
                area['image'] ??
                "https://images.pexels.com/photos/210019/pexels-photo-210019.jpeg",
            "popularity_score": area['popularity_score'] ?? 0,
          };
        }).toList();

        _computeLists();
      }
    } catch (_) {
      parkingPlaces = [];
    }
  }

  void _computeLists() {
    if (_currentLocation != null) {
      double lat = _currentLocation!.latitude;
      double lng = _currentLocation!.longitude;

      final withDist = parkingPlaces.map((p) {
        double d = _distanceInKm(lat, lng, p['lat'], p['lng']);
        return {...p, "distanceKm": d};
      }).toList();

      withDist.sort((a, b) => a['distanceKm'].compareTo(b['distanceKm']));
      nearbyPlaces = withDist.where((p) => p['distanceKm'] <= 8).toList();
    } else {
      nearbyPlaces = parkingPlaces.take(6).toList();
    }

    popularPlaces = List.from(parkingPlaces);
    popularPlaces.sort(
        (a, b) => (b['popularity_score']).compareTo(a['popularity_score']));
  }

  double _distanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    double dLat = _deg(lat2 - lat1);
    double dLon = _deg(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg(lat1)) * cos(_deg(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg(double deg) => deg * pi / 180;

  String _eta(Map<String, dynamic> place) {
    if (_currentLocation == null) return "-";

    double dist = _distanceInKm(_currentLocation!.latitude,
        _currentLocation!.longitude, place['lat'], place['lng']);

    double minutes = (dist / 30) * 60;
    if (minutes < 1) return "1 min";
    return "${minutes.round()} min";
  }

  String _formatKm(Map<String, dynamic> place) {
    if (_currentLocation == null) return "-";

    double dist = _distanceInKm(_currentLocation!.latitude,
        _currentLocation!.longitude, place['lat'], place['lng']);

    return "${dist.toStringAsFixed(1)} km";
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> list) {
    if (searchQuery.isEmpty) return list;
    return list
        .where(
            (p) => p['name'].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final collapsedCardWidth = min(300.0, width * 0.72);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            _buildMainContent(collapsedCardWidth),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: _buildGlassyNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(double collapsedCardWidth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreetingRow(),
          const SizedBox(height: 20),
          _buildHeading(),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 18),

          // NEARBY
          _buildSectionHeader(
              "Nearby Parking",
              () => setState(() => nearbyExpanded = !nearbyExpanded),
              nearbyExpanded),
          const SizedBox(height: 12),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : nearbyExpanded
                  ? _buildFullWidthList(_applySearch(nearbyPlaces))
                  : SizedBox(
                      height: 245,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _applySearch(nearbyPlaces).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => SizedBox(
                            width: collapsedCardWidth,
                            child: _buildParkingCard(
                                _applySearch(nearbyPlaces)[index])),
                      ),
                    ),

          const SizedBox(height: 22),

          // POPULAR
          _buildSectionHeader(
              "Popular Parking",
              () => setState(() => popularExpanded = !popularExpanded),
              popularExpanded),
          const SizedBox(height: 12),
          isLoading
              ? const SizedBox.shrink()
              : popularExpanded
                  ? _buildFullWidthList(_applySearch(popularPlaces))
                  : SizedBox(
                      height: 245,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _applySearch(popularPlaces).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => SizedBox(
                            width: collapsedCardWidth,
                            child: _buildParkingCard(
                                _applySearch(popularPlaces)[index])),
                      ),
                    ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildGreetingRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $userName",
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.titleText),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.subtleText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      userLocationLabel,
                      style: GoogleFonts.poppins(
                          color: AppColors.subtleText, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ProfileScreen(phoneNumber: widget.phoneNumber))),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.person, color: AppColors.titleText),
          ),
        )
      ],
    );
  }

  Widget _buildHeading() {
    return Text(
      "Ready to find your perfect\nParking spot?",
      style: GoogleFonts.poppins(
        fontSize: 23,
        fontWeight: FontWeight.w600,
        color: AppColors.titleText,
        height: 1.05,
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap, bool expanded) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.titleText)),
        InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Text("See all",
                  style:
                      GoogleFonts.poppins(color: AppColors.hint, fontSize: 13)),
              const SizedBox(width: 6),
              Icon(expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: AppColors.hint),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildFullWidthList(List<Map<String, dynamic>> list) {
    return Column(
      children: list
          .map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildParkingCard(p),
              ))
          .toList(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // 🔥 Full white search bar
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v.trim()),
              style: GoogleFonts.poppins(
                color: AppColors.titleText,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white, // 🔥 OVERRIDES DARK THEME
                hintText: "Search for parking spot",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade400, // 🔥 soft placeholder
                  fontSize: 13,
                ),
                prefixIcon: Icon(Icons.search,
                    color: Colors.grey.shade500,
                    size: 20), // 🔥 soft search icon
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              ),
            ),
          ),

          // Filter Chip
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_outlined,
                      size: 18, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Text("Filters",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.titleText,
                      ))
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildParkingCard(Map<String, dynamic> place) {
    final cars = place['cars'] ?? 0;
    final bikes = place['bikes'] ?? 0;
    final eta = _eta(place);
    final dist = _formatKm(place);

    final photoUrl = place['photo'];

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BookingScreen(
                    location: place['name'],
                    parkingId: place['id'].toString(),
                    phoneNumber: widget.phoneNumber,
                  ))),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // auto height
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14), topRight: Radius.circular(14)),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200], child: const Icon(Icons.image)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1 — slots and price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text("$cars cars",
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: AppColors.subtleText)),
                          const SizedBox(width: 12),
                          const Icon(Icons.pedal_bike,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text("$bikes bikes",
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: AppColors.subtleText)),
                        ],
                      ),
                      Text("₹30/hr",
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.titleText)),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Parking Name
                  Text(
                    place['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.titleText),
                  ),

                  const SizedBox(height: 10),

                  // ETA + Distance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(eta,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: AppColors.subtleText)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(dist,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: AppColors.subtleText)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGlassyNavBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home, "Home", () {}),
              _navItem(Icons.map_outlined, "Map", () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            MyBookingsScreen(phoneNumber: widget.phoneNumber)));
              }),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MyBookingsScreen(
                              phoneNumber: widget.phoneNumber)));
                },
                child: Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.accent.withOpacity(0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: const Icon(Icons.local_parking_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
              _navItem(Icons.list_alt, "Bookings", () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            MyBookingsScreen(phoneNumber: widget.phoneNumber)));
              }),
              _navItem(Icons.account_circle, "Profile", () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(phoneNumber: widget.phoneNumber)));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: Colors.white.withOpacity(0.85))),
        ],
      ),
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}
