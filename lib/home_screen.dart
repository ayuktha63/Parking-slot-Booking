import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'booking_screen.dart';
import 'profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchParkingAreas();
  }

  Future<void> _fetchParkingAreas() async {
    setState(() => isLoading = true);
    try {
      final response =
          await http.get(Uri.parse('http://localhost:3000/api/parking_areas'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<Map<String, dynamic>> tempPlaces = [];

        for (var area in data) {
          final carSlotsResponse = await http.get(Uri.parse(
              'http://localhost:3000/api/parking_areas/${area['_id']}/slots?vehicle_type=car'));
          final bikeSlotsResponse = await http.get(Uri.parse(
              'http://localhost:3000/api/parking_areas/${area['_id']}/slots?vehicle_type=bike'));

          int availableCars = 0;
          int availableBikes = 0;

          if (carSlotsResponse.statusCode == 200) {
            final carSlots = jsonDecode(carSlotsResponse.body);
            availableCars =
                carSlots.where((slot) => slot['is_booked'] == false).length;
          } else {
            print(
                'Failed to fetch car slots for ${area['_id']}: ${carSlotsResponse.statusCode}');
          }

          if (bikeSlotsResponse.statusCode == 200) {
            final bikeSlots = jsonDecode(bikeSlotsResponse.body);
            availableBikes =
                bikeSlots.where((slot) => slot['is_booked'] == false).length;
          } else {
            print(
                'Failed to fetch bike slots for ${area['_id']}: ${bikeSlotsResponse.statusCode}');
          }

          tempPlaces.add({
            "_id": area['_id'],
            "name": area['name'],
            "cars": availableCars,
            "bikes": availableBikes,
            "lat": area['location']['lat'].toDouble(), // Fetch latitude
            "lng": area['location']['lng'].toDouble(), // Fetch longitude
          });
        }

        setState(() {
          parkingPlaces = tempPlaces;
          filteredPlaces = List.from(parkingPlaces);
          isLoading = false;
        });
      } else {
        print(
            'Failed to fetch parking areas: ${response.statusCode}, Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Failed to load parking areas: ${response.statusCode}")),
        );
        setState(() => isLoading = false);
      }
    } catch (error) {
      print('Error fetching parking areas: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading parking areas: $error")),
      );
      setState(() => isLoading = false);
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
    });
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open Google Maps")),
      );
    }
  }

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
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchSection(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                "Available Parking Spots",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF303030),
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredPlaces.isEmpty
                      ? const Center(child: Text("No parking areas available"))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: filteredPlaces.length,
                          itemBuilder: (context, index) {
                            final place = filteredPlaces[index];
                            return _buildParkingCard(context, place);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Find your best",
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          Text(
            "Parking Space",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF303030),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingCard(BuildContext context, Map<String, dynamic> place) {
    final carSlotsText = place["cars"] == 0 ? "Full" : place["cars"].toString();
    final bikeSlotsText =
        place["bikes"] == 0 ? "Full" : place["bikes"].toString();

    return Container(
      margin: const EdgeInsets.only(
          bottom: 16), // Fixed typo from 'custom' to 'bottom'
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_parking,
                color: Color(0xFF3F51B5),
                size: 28,
              ),
            ),
            title: Text(
              place["name"],
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  icon: Icons.directions_car,
                  value: carSlotsText,
                  label: "Cars",
                ),
                _buildInfoItem(
                  icon: Icons.motorcycle,
                  value: bikeSlotsText,
                  label: "Bikes",
                ),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _navigateToBookingScreen(context, place),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        backgroundColor: const Color(0xFF3F51B5),
                      ),
                      child: const Text("Book Now"),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          _openGoogleMaps(place["lat"], place["lng"]),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        side: const BorderSide(color: Color(0xFF3F51B5)),
                      ),
                      child: const Text(
                        "Get Location",
                        style: TextStyle(color: Color(0xFF3F51B5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}
