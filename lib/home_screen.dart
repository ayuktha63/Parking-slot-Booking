import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'booking_screen.dart'; // Make sure this file exists
import 'profile_screen.dart'; // Make sure this file exists
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// 💡 Using the suggested package for better web performance
// import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

// --- THEME COLORS ---
class AppColors {
  static const Color appBackground = Color(0xFF1C1C1E);
  static const Color cardSurface = Color(0xFF2C2C2E);
  static const Color appBarColor = Color(0xFF1C1C1E);
  static const Color searchBarColor = Color(0xFF2C2C2E);
  static const Color infoItemBg = Color(0xFF3A3A3C);

  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB0B0B5);
  static const Color hintText = Color(0xFF8E8E93);
  static const Color darkText = Color(0xFF000000); // For white buttons

  static const Color markerColor = Color(0xFF000000); // Black accent
  static const Color routeColor = Color.fromARGB(255, 82, 82, 83);
  static const Color outlinedButtonColor = Color(0xFF8E8E93);
  static const Color elevatedButtonBg = Color(0xFFFFFFFF);

  static const Color shadow = Color.fromRGBO(0, 0, 0, 0.3);
  static const Color errorRed = Color(0xFFD32F2F); // A dark red for errors
}
// --- END THEME COLORS ---

class HomeScreen extends StatefulWidget {
  final String phoneNumber;
  const HomeScreen({super.key, required this.phoneNumber});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> parkingPlaces = [];
  List<Map<String, dynamic>> filteredPlaces = [];
  bool isLoading = true;
  String apiHost = '10.0.2.2'; // Main API (Port 3000)

  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.85);
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  double _routeDistance = 0.0; // To store route distance in km
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      apiHost = '127.0.0.1';
    }
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() => isLoading = true);
    await _getCurrentLocation();
    await _fetchParkingAreas();
    setState(() => isLoading = false);

    if (filteredPlaces.isNotEmpty) {
      _onPageChanged(0);
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar("Location permissions are permanently denied.");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      if (mounted) {
        _mapController.move(_currentLocation!, 15.0);
      }
    } catch (e) {
      _showErrorSnackBar("Failed to get current location: $e");
    }
  }

  Future<void> _fetchParkingAreas() async {
    try {
      final response =
          await http.get(Uri.parse('http://$apiHost:3000/api/parking_areas'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          parkingPlaces = data
              .map((area) => {
                    "_id": area['_id'],
                    "name": area['name'],
                    "cars": area['available_car_slots'] ?? 0,
                    "bikes": area['available_bike_slots'] ?? 0,
                    "lat": area['location']['lat'].toDouble(),
                    "lng": area['location']['lng'].toDouble(),
                  })
              .toList();
          filteredPlaces = List.from(parkingPlaces);
        });
      } else {
        _showErrorSnackBar(
            "Failed to load parking areas: ${response.statusCode}");
      }
    } catch (error) {
      _showErrorSnackBar("Error loading parking areas: $error");
    }
  }

  void _filterParkingPlaces(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredPlaces = List.from(parkingPlaces);
      } else {
        filteredPlaces = parkingPlaces
            .where((place) =>
                place["name"].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _routePoints.clear();
      _routeDistance = 0.0;
      if (filteredPlaces.isNotEmpty) {
        _pageController.jumpToPage(0);
        _onPageChanged(0);
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= filteredPlaces.length) return;
    setState(() {
      _currentPageIndex = index;
    });
    final place = filteredPlaces[index];
    _fetchAndDisplayRoute(place["lat"], place["lng"]);
  }

  Future<void> _fetchAndDisplayRoute(double destLat, double destLng) async {
    if (_currentLocation == null) {
      _showErrorSnackBar("Current location not available. Cannot fetch route.");
      return;
    }

    final startLat = _currentLocation!.latitude;
    final startLng = _currentLocation!.longitude;

    final url =
        'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$destLng,$destLat?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final routeData = data['routes'][0];
          final double distanceInKm = (routeData['distance'] ?? 0.0) / 1000.0;
          final List<dynamic> coordinates =
              routeData['geometry']['coordinates'];
          final List<LatLng> route = coordinates
              .map((c) => LatLng((c as List<dynamic>)[1].toDouble(),
                  (c as List<dynamic>)[0].toDouble()))
              .toList();

          setState(() {
            _routePoints = route;
            _routeDistance = distanceInKm;
          });

          if (route.isNotEmpty && mounted) {
            _mapController.fitCamera(
              CameraFit.coordinates(
                coordinates: [_currentLocation!, ...route],
                padding: const EdgeInsets.all(50.0),
              ),
            );
          }
        } else {
          _showErrorSnackBar("No route found.");
        }
      } else {
        _showErrorSnackBar("Failed to get route: ${response.body}");
      }
    } catch (e) {
      _showErrorSnackBar("Error fetching route: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "ParkEasy",
          style: GoogleFonts.poppins(color: AppColors.primaryText),
        ),
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.person_rounded, color: AppColors.primaryText),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(phoneNumber: widget.phoneNumber)),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ??
                  const LatLng(8.5241, 76.9366), // Fallback center
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                // --- LIGHT MAP AS REQUESTED ---
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                tileProvider: NetworkTileProvider(),
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: AppColors.routeColor,
                    strokeWidth: 5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (_currentLocation != null)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _currentLocation!,
                      child: const Icon(
                        Icons.my_location,
                        color: AppColors.markerColor,
                        size: 30,
                      ),
                    ),
                  if (filteredPlaces.isNotEmpty &&
                      _currentPageIndex < filteredPlaces.length)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: LatLng(
                        filteredPlaces[_currentPageIndex]["lat"],
                        filteredPlaces[_currentPageIndex]["lng"],
                      ),
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.markerColor, // Use accent color
                        size: 35,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // --- SEARCH BAR ---
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: _buildSearchSection(),
          ),

          // --- DISTANCE DISPLAY ---
          if (_routeDistance > 0)
            Positioned(
              top: 75,
              left: 15,
              right: 15,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        spreadRadius: 1,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    "Distance: ${_routeDistance.toStringAsFixed(1)} km",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

          // --- HORIZONTAL SCROLLING PARKING LIST ---
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 200,
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                      color: AppColors.primaryText,
                    ))
                  : filteredPlaces.isEmpty
                      ? const Center(
                          child: Text(
                            "No parking areas found.",
                            style: TextStyle(
                              color: AppColors.primaryText,
                              backgroundColor: Colors.transparent,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: filteredPlaces.length,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) {
                            final place = filteredPlaces[index];
                            return _buildParkingCard(context, place);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.searchBarColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        onChanged: _filterParkingPlaces,
        style: const TextStyle(color: AppColors.primaryText),
        decoration: const InputDecoration(
          hintText: "Search parking location",
          hintStyle: TextStyle(color: AppColors.hintText),
          prefixIcon: Icon(Icons.search, color: AppColors.hintText),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildParkingCard(BuildContext context, Map<String, dynamic> place) {
    final carSlotsText = place["cars"] == 0 ? "Full" : place["cars"].toString();
    final bikeSlotsText =
        place["bikes"] == 0 ? "Full" : place["bikes"].toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place["name"],
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildInfoItem(
                  icon: Icons.directions_car,
                  value: carSlotsText,
                  label: "Cars",
                ),
                const SizedBox(width: 12),
                _buildInfoItem(
                  icon: Icons.motorcycle,
                  value: bikeSlotsText,
                  label: "Bikes",
                ),
              ],
            ),
            const Spacer(),
            // --- MODIFIED BUTTON SECTION ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _openGoogleMaps(place["lat"], place["lng"]),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(
                          color: AppColors.outlinedButtonColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      "Directions",
                      style:
                          TextStyle(fontSize: 16, color: AppColors.primaryText),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _navigateToBookingScreen(context, place),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppColors.elevatedButtonBg,
                      foregroundColor: AppColors.darkText,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child:
                        const Text("Book Now", style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
            // --- END OF MODIFIED SECTION ---
          ],
        ),
      ),
    );
  }

  void _navigateToBookingScreen(
      BuildContext context, Map<String, dynamic> place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          location: place["name"],
          parkingId: place["_id"],
          phoneNumber: widget.phoneNumber,
        ),
      ),
    ).then((_) {
      // Refresh parking data when returning from booking
      _fetchParkingAreas();
    });
  }

  Widget _buildInfoItem(
      {required IconData icon, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.infoItemBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondaryText),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- FIXED GOOGLE MAPS LAUNCHER ---
  Future<void> _openGoogleMaps(double destLat, double destLng) async {
    if (_currentLocation == null) {
      _showErrorSnackBar("Current location not available for directions.");
      return;
    }

    final double startLat = _currentLocation!.latitude;
    final double startLng = _currentLocation!.longitude;

    // Correct Google Maps URL format
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$destLat,$destLng';

    final Uri url = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url,
          mode: LaunchMode.externalApplication); // Opens in Google Maps app
    } else {
      _showErrorSnackBar("Could not open Google Maps");
    }
  }
}
