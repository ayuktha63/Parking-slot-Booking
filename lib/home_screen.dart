import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'booking_screen.dart';
import 'profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// --- NEW IMPORTS ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
// ---

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
  String apiHostRouting = '10.0.2.2:3001'; // A* Routing API (Port 3001)

  // --- NEW STATE VARIABLES ---
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.85);
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  int _currentPageIndex = 0;
  // ---

  @override
  void initState() {
    super.initState();
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      apiHost = '127.0.0.1';
      apiHostRouting = '127.0.0.1:3001';
    }
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() => isLoading = true);
    await _getCurrentLocation();
    await _fetchParkingAreas();
    setState(() => isLoading = false);

    // After fetching, show route for the first item
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
      _mapController.move(_currentLocation!, 15.0);
    } catch (e) {
      _showErrorSnackBar("Failed to get current location: $e");
    }
  }

  Future<void> _fetchParkingAreas() async {
    // This function is mostly the same, just simplified
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
      // After filtering, update route for the first item in the new list
      _routePoints.clear();
      if (filteredPlaces.isNotEmpty) {
        _pageController.jumpToPage(0);
        _onPageChanged(0);
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // --- NEW ROUTING FUNCTIONS ---

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });
    final place = filteredPlaces[index];
    _fetchAndDisplayRoute(place["lat"], place["lng"]);
  }

  Future<String?> _getNearestNodeId(double lat, double lng) async {
    try {
      final response = await http.get(
          Uri.parse('http://$apiHostRouting/nearest-node?lat=$lat&lng=$lng'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['nodeId'];
      }
    } catch (e) {
      print("Error fetching nearest node: $e");
    }
    return null;
  }

  Future<void> _fetchAndDisplayRoute(double destLat, double destLng) async {
    if (_currentLocation == null) {
      _showErrorSnackBar("Current location not available. Cannot fetch route.");
      return;
    }

    // 1. Get nearest node for start (user's location)
    final startId = await _getNearestNodeId(
        _currentLocation!.latitude, _currentLocation!.longitude);

    // 2. Get nearest node for end (parking location)
    final endId = await _getNearestNodeId(destLat, destLng);

    if (startId == null || endId == null) {
      _showErrorSnackBar("Could not find nodes for routing.");
      return;
    }

    // 3. Get the route from your A* server
    try {
      final response = await http.post(
        Uri.parse('http://$apiHostRouting/route'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'start': startId, 'end': endId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> coordinates = data['coordinates'];
        final List<LatLng> route = coordinates
            .map((c) => LatLng(c['lat'].toDouble(), c['lon'].toDouble()))
            .toList();

        setState(() {
          _routePoints = route;
        });

        // Fit map to show the entire route
        if (route.isNotEmpty) {
          _mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: [_currentLocation!, ...route],
              padding: const EdgeInsets.all(50.0),
            ),
          );
        }
      } else {
        _showErrorSnackBar("Failed to get route: ${response.body}");
      }
    } catch (e) {
      _showErrorSnackBar("Error fetching route: $e");
    }
  }

  // ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("ParkEasy"),
        backgroundColor: const Color(0xFF3F51B5),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded, color: Colors.white),
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
          // --- MAP BACKGROUND ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ??
                  const LatLng(8.5241, 76.9366), // Fallback center
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: Colors.blue,
                    strokeWidth: 5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // User's Location Marker
                  if (_currentLocation != null)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: _currentLocation!,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                  // Destination Marker
                  if (filteredPlaces.isNotEmpty)
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: LatLng(
                        filteredPlaces[_currentPageIndex]["lat"],
                        filteredPlaces[_currentPageIndex]["lng"],
                      ),
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
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

          // --- HORIZONTAL SCROLLING PARKING LIST ---
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 200, // Adjust height as needed
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredPlaces.isEmpty
                      ? const Center(
                          child: Text(
                            "No parking areas found.",
                            style: TextStyle(
                              color: Colors.white,
                              backgroundColor: Colors.black54,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        onChanged: _filterParkingPlaces,
        decoration: const InputDecoration(
          hintText: "Search parking location",
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // --- MODIFIED PARKING CARD ---
  Widget _buildParkingCard(BuildContext context, Map<String, dynamic> place) {
    final carSlotsText = place["cars"] == 0 ? "Full" : place["cars"].toString();
    final bikeSlotsText =
        place["bikes"] == 0 ? "Full" : place["bikes"].toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _navigateToBookingScreen(context, place),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: const Color(0xFF3F51B5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Book Now", style: TextStyle(fontSize: 16)),
              ),
            ),
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
      // Refresh parking areas after booking
      _fetchParkingAreas();
    });
  }

  Widget _buildInfoItem(
      {required IconData icon, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Not used in this layout, but keeping it
  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showErrorSnackBar("Could not open Google Maps");
    }
  }
}
