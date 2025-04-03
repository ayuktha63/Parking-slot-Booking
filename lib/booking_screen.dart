import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'SuccessAnimationScreen.dart';

class BookingScreen extends StatefulWidget {
  final String location;
  final String parkingId;

  const BookingScreen(
      {super.key, required this.location, required this.parkingId});

  @override
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String? selectedVehicle;
  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;
  Set<String> selectedSlotIds = {};
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  List<dynamic> availableSlots = [];
  bool isLoading = true;

  List<String> vehicleTypes = ["Car", "Bike"];

  @override
  void initState() {
    super.initState();
    _fetchAvailableSlots();
  }

  Future<void> _fetchAvailableSlots() async {
    setState(() => isLoading = true);
    try {
      String url =
          'http://localhost:3000/api/parking_areas/${widget.parkingId}/slots';
      if (startDate != null && startTime != null) {
        final entryDateTime = DateTime(
          startDate!.year,
          startDate!.month,
          startDate!.day,
          startTime!.hour,
          startTime!.minute,
        );
        url += '?entry_time=${entryDateTime.toIso8601String()}';
        if (endDate != null && endTime != null) {
          final exitDateTime = DateTime(
            endDate!.year,
            endDate!.month,
            endDate!.day,
            endTime!.hour,
            endTime!.minute,
          );
          url += '&exit_time=${exitDateTime.toIso8601String()}';
        }
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          availableSlots = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        print(
            'Failed to load slots: Status ${response.statusCode}, Body: ${response.body}');
        _showErrorDialog(
            "Failed to load available slots: ${response.statusCode} - ${response.body}");
        setState(() => isLoading = false);
      }
    } catch (error) {
      print('Error fetching slots: $error');
      _showErrorDialog("Error loading slots: $error");
      setState(() => isLoading = false);
    }
  }

  Future<void> _confirmBooking() async {
    if (selectedVehicle != null &&
        _vehicleNumberController.text.isNotEmpty &&
        selectedSlotIds.isNotEmpty &&
        startDate != null &&
        startTime != null &&
        endDate != null &&
        endTime != null) {
      final entryDateTime = DateTime(
        startDate!.year,
        startDate!.month,
        startDate!.day,
        startTime!.hour,
        startTime!.minute,
      );
      final exitDateTime = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
        endTime!.hour,
        endTime!.minute,
      );

      try {
        for (String slotId in selectedSlotIds) {
          final response = await http.post(
            Uri.parse('http://localhost:3000/api/bookings'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'parking_id': widget.parkingId,
              'slot_id': slotId,
              'vehicle_type': selectedVehicle!.toLowerCase(),
              'number_plate': _vehicleNumberController.text,
              'entry_time': entryDateTime.toIso8601String(),
              'exit_time': exitDateTime.toIso8601String(),
            }),
          );

          if (response.statusCode != 200) {
            print(
                'Booking failed: Status ${response.statusCode}, Body: ${response.body}');
            _showErrorDialog("Failed to book slot: ${response.body}");
            return;
          }
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessAnimationScreen(
              location: widget.location,
              date: startDate!,
              time: startTime!,
              vehicleType: selectedVehicle!,
              slots: selectedSlotIds
                  .map((id) => availableSlots.firstWhere(
                      (slot) => slot['_id'] == id)['slot_number'] as int)
                  .toList(),
            ),
          ),
        );
      } catch (error) {
        print('Error booking: $error');
        _showErrorDialog("Error confirming booking: $error");
      }
    } else {
      _showErrorDialog("Please complete all selections");
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3F51B5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
        _fetchAvailableSlots(); // Refresh slots with new time
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3F51B5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        startTime = picked;
        _fetchAvailableSlots(); // Refresh slots with new time
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? (startDate ?? DateTime.now()),
      firstDate: startDate ?? DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3F51B5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
        _fetchAvailableSlots(); // Refresh slots with new time
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3F51B5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        endTime = picked;
        _fetchAvailableSlots(); // Refresh slots with new time
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text("Booking Error"),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK", style: TextStyle(color: Color(0xFF3F51B5))),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Book a Parking Spot"),
        elevation: 0,
        backgroundColor: const Color(0xFF3F51B5),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFF3F51B5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Book at ${widget.location}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Reserve your parking space now",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Parking Details"),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: "Select Vehicle Type",
                              labelStyle: TextStyle(color: Color(0xFF3F51B5)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Color(0xFF3F51B5)),
                              ),
                              prefixIcon: Icon(Icons.directions_car,
                                  color: Color(0xFF3F51B5)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: selectedVehicle,
                            items: vehicleTypes.map((vehicle) {
                              return DropdownMenuItem(
                                value: vehicle,
                                child: Text(vehicle),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() {
                              selectedVehicle = value;
                              selectedSlotIds.clear();
                              _fetchAvailableSlots();
                            }),
                            dropdownColor: Colors.white,
                            icon: Icon(Icons.arrow_drop_down,
                                color: Color(0xFF3F51B5)),
                          ),
                          if (selectedVehicle != null) ...[
                            SizedBox(height: 16),
                            TextField(
                              controller: _vehicleNumberController,
                              decoration: InputDecoration(
                                labelText: selectedVehicle == "Car"
                                    ? "Car Number Plate"
                                    : "Bike Number Plate",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: Icon(
                                  selectedVehicle == "Car"
                                      ? Icons.directions_car
                                      : Icons.motorcycle,
                                  color: Color(0xFF3F51B5),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  _buildSectionTitle("Entry & Exit Timing"),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => _selectStartDate(context),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF3F51B5).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.calendar_today,
                                      color: Color(0xFF3F51B5)),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Entry Date",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        startDate != null
                                            ? "${startDate!.day}/${startDate!.month}/${startDate!.year}"
                                            : "Select Entry Date",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios,
                                    size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _selectStartTime(context),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF3F51B5).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.access_time,
                                      color: Color(0xFF3F51B5)),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Entry Time",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        startTime != null
                                            ? startTime!.format(context)
                                            : "Select Entry Time",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios,
                                    size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _selectEndDate(context),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF3F51B5).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.calendar_today,
                                      color: Color(0xFF3F51B5)),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Exit Date",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        endDate != null
                                            ? "${endDate!.day}/${endDate!.month}/${endDate!.year}"
                                            : "Select Exit Date",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios,
                                    size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _selectEndTime(context),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF3F51B5).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.access_time,
                                      color: Color(0xFF3F51B5)),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Exit Time",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        endTime != null
                                            ? endTime!.format(context)
                                            : "Select Exit Time",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios,
                                    size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  _buildSectionTitle("Select Parking Slots"),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLegendItem(Colors.grey[300]!, "Available"),
                            _buildLegendItem(Color(0xFF4CAF50), "Selected"),
                            _buildLegendItem(Colors.red[300]!, "Occupied"),
                          ],
                        ),
                        SizedBox(height: 20),
                        isLoading
                            ? Center(child: CircularProgressIndicator())
                            : availableSlots.isEmpty
                                ? Center(child: Text("No available slots"))
                                : Wrap(
                                    spacing: 10.0,
                                    runSpacing: 10.0,
                                    children: availableSlots
                                        .where((slot) =>
                                            selectedVehicle == null ||
                                            slot['vehicle_type']
                                                    .toLowerCase() ==
                                                selectedVehicle!.toLowerCase())
                                        .map((slot) {
                                      final slotId = slot['_id'];
                                      final slotNumber = slot['slot_number'];
                                      final isSelected =
                                          selectedSlotIds.contains(slotId);
                                      final isOccupied =
                                          slot['status'] == 'booked';

                                      return GestureDetector(
                                        onTap: isOccupied
                                            ? null
                                            : () {
                                                setState(() {
                                                  if (isSelected) {
                                                    selectedSlotIds
                                                        .remove(slotId);
                                                  } else {
                                                    selectedSlotIds.add(slotId);
                                                  }
                                                });
                                              },
                                        child: AnimatedContainer(
                                          duration: Duration(milliseconds: 200),
                                          width: 65,
                                          height: 65,
                                          decoration: BoxDecoration(
                                            color: isOccupied
                                                ? Colors.red[300]
                                                : isSelected
                                                    ? Color(0xFF4CAF50)
                                                    : Colors.grey[300],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: Color(0xFF4CAF50)
                                                          .withOpacity(0.4),
                                                      blurRadius: 8,
                                                      offset: Offset(0, 2),
                                                    )
                                                  ]
                                                : [],
                                          ),
                                          child: Center(
                                            child: Text(
                                              "$slotNumber",
                                              style: TextStyle(
                                                color: isOccupied || isSelected
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Color(0xFF3F51B5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _confirmBooking,
                      child: Text(
                        "Confirm Booking",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Color(0xFF3F51B5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF303030),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
