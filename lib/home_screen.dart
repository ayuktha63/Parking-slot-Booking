// home_screen.dart
import 'package:flutter/material.dart';
import 'booking_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> parkingPlaces = [
    {
      "name": "Palayam Parking",
      "cars": 20,
      "bikes": 10,
      "icon": Icons.local_mall,
      "color": Color(0xFF4CAF50),
    },
    {
      "name": "Thambanoor Parking",
      "cars": 15,
      "bikes": 8,
      "icon": Icons.location_city,
      "color": Color(0xFFF44336),
    },
    {
      "name": "Police Quaters Parking",
      "cars": 30,
      "bikes": 15,
      "icon": Icons.stadium,
      "color": Color(0xFFFF9800),
    },
    {
      "name": "Kowdiar Parking",
      "cars": 50,
      "bikes": 25,
      "icon": Icons.airplanemode_active,
      "color": Color(0xFF9C27B0),
    },
  ];

  List<Map<String, dynamic>> filteredPlaces = [];

  @override
  void initState() {
    super.initState();
    filteredPlaces = parkingPlaces;
  }

  void _filterParkingPlaces(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredPlaces = parkingPlaces;
      } else {
        filteredPlaces = parkingPlaces
            .where((place) =>
                place["name"].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false, // This removes the back button
        title: Text("ParkEasy"),
        actions: [
          IconButton(
            icon: Icon(Icons.person_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchSection(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Find your best",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          Text(
            "Parking Space",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF303030),
            ),
          ),
          SizedBox(height: 20),
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
              decoration: InputDecoration(
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
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: place["color"].withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                place["icon"],
                color: place["color"],
                size: 28,
              ),
            ),
            title: Text(
              place["name"],
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                    icon: Icons.directions_car,
                    value: place["cars"].toString(),
                    label: "Cars"),
                _buildInfoItem(
                    icon: Icons.motorcycle,
                    value: place["bikes"].toString(),
                    label: "Bikes"),
                ElevatedButton(
                  onPressed: () =>
                      _navigateToBookingScreen(context, place["name"]),
                  child: Text("Book Now"),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToBookingScreen(BuildContext context, String location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(location: location),
      ),
    );
  }

  Widget _buildInfoItem(
      {required IconData icon, required String value, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
