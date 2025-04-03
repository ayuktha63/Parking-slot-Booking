import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'dart:convert';
import 'dart:typed_data'; // For Uint8List
import 'phone_screen.dart'; // Import PhoneScreen for logout navigation

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  XFile? _profileImageFile;
  Uint8List? _profileImageBytes;
  String? _profileImageUrl;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bikeNumberController = TextEditingController();
  final TextEditingController _carNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No user logged in');
      return;
    }

    final phoneNumber = user.phoneNumber!;
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/profile?phone=$phoneNumber'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _nameController.text = data['name'] ?? '';
          _bikeNumberController.text = data['bike_number_plate'] ?? '';
          _carNumberController.text = data['car_number_plate'] ?? '';
          _profileImageUrl = data['profile_image'];
          _profileImageFile = null;
          _profileImageBytes = null;
        });
      } else {
        print(
            'Failed to fetch profile: ${response.statusCode} - ${response.body}');
        setState(() {
          _nameController.text = '';
          _bikeNumberController.text = '';
          _carNumberController.text = '';
          _profileImageUrl = null;
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
      setState(() {
        _nameController.text = '';
        _bikeNumberController.text = '';
        _carNumberController.text = '';
        _profileImageUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _profileImageFile = pickedFile;
          _profileImageBytes = bytes;
          _profileImageUrl = null;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No user logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to update your profile')),
      );
      return;
    }

    final phoneNumber = user.phoneNumber!;
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('http://localhost:3000/api/profile?phone=$phoneNumber'),
      );

      request.fields['name'] = _nameController.text;
      request.fields['bike_number_plate'] = _bikeNumberController.text;
      request.fields['car_number_plate'] = _carNumberController.text;

      if (_profileImageBytes != null) {
        String filename = _profileImageFile?.name ?? 'profile_image.jpg';
        if (!filename.toLowerCase().endsWith('.jpg') &&
            !filename.toLowerCase().endsWith('.jpeg') &&
            !filename.toLowerCase().endsWith('.png')) {
          filename = 'profile_image.jpg';
        }
        String mimeType = filename.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        print(
            'Uploading file: $filename, MIME type: $mimeType, bytes length: ${_profileImageBytes!.length}');
        request.files.add(http.MultipartFile.fromBytes(
          'profile_image',
          _profileImageBytes!,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ));
      } else {
        print('No image selected for upload');
      }

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile updated successfully")),
        );
        await _fetchProfile();
      } else {
        print(
            'Failed to update profile: ${response.statusCode} - $responseBody');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile: ${response.statusCode} - ${jsonDecode(responseBody)['message'] ?? 'Unknown error'}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  void _logout() async {
    try {
      await _auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => PhoneScreen()),
        (route) => false,
      );
    } catch (e) {
      print('Error logging out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final phoneNumber = user?.phoneNumber ?? "Not available";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Profile",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3F51B5),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _profileImageBytes != null
                      ? MemoryImage(_profileImageBytes!)
                      : _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                  child: _profileImageBytes == null && _profileImageUrl == null
                      ? Icon(Icons.camera_alt,
                          size: 40, color: Colors.grey[600])
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Tap to upload profile photo",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: const Color(0xFF1E88E5)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Phone Number",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          phoneNumber,
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Name",
                labelStyle: GoogleFonts.poppins(),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.person, color: const Color(0xFF1E88E5)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _bikeNumberController,
              decoration: InputDecoration(
                labelText: "Bike Number Plate",
                labelStyle: GoogleFonts.poppins(),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon:
                    Icon(Icons.motorcycle, color: const Color(0xFF1E88E5)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _carNumberController,
              decoration: InputDecoration(
                labelText: "Car Number Plate",
                labelStyle: GoogleFonts.poppins(),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon:
                    Icon(Icons.directions_car, color: const Color(0xFF1E88E5)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: Text(
                  "Update Profile",
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: Text(
                  "Logout",
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bikeNumberController.dispose();
    _carNumberController.dispose();
    super.dispose();
  }
}
