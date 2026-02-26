import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zimdoctors/Screens/login_screen.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/models/booking.dart';
import 'package:zimdoctors/services/doctor_service.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class DoctorDashboardScreen extends StatefulWidget {
  static const String id = '/doctor_dashboard_screen';

  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final _doctorService = DoctorService();
  final _auth = FirebaseAuth.instance;
  Doctor? _currentDoctor;
  bool _isLoading = true;

  final _descController = TextEditingController();
  final _feeController = TextEditingController();
  List<String> _tempAvailableDates = [];

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorData() async {
    final doctor = await _doctorService.getCurrentDoctor();
    if (mounted) {
      setState(() {
        _currentDoctor = doctor;
        _isLoading = false;
        if (doctor != null) {
          _descController.text = doctor.description;
          _feeController.text = doctor.fee.toString();
          _tempAvailableDates = List.from(doctor.availableDates);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF57E659)),
        ),
      );
    }

    if (_currentDoctor == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Doctor profile not found',
                style: TextStyle(color: Colors.white),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, LoginScreen.id),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background Decoration
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF57E659).withOpacity(0.1),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const TabBar(
                    indicatorColor: Color(0xFF57E659),
                    tabs: [
                      Tab(text: 'Bookings'),
                      Tab(text: 'Profile'),
                      Tab(text: 'Stats'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildBookingsTab(),
                        _buildProfileTab(),
                        _buildStatsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF1E1E1E),
            backgroundImage: _currentDoctor!.image.isNotEmpty
                ? NetworkImage(_currentDoctor!.image)
                : null,
            child: _currentDoctor!.image.isEmpty
                ? const Icon(Icons.person, size: 30, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Dr. ${_currentDoctor!.name.split(' ').last}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _currentDoctor!.specialty,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await _auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, LoginScreen.id);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsTab() {
    return StreamBuilder<List<Booking>>(
      stream: _doctorService.getBookingsForDoctor(_currentDoctor!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Error loading bookings: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF57E659)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey[800]),
                const SizedBox(height: 16),
                Text(
                  'No bookings yet',
                  style: GoogleFonts.inter(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final booking = snapshot.data![index];
            return _buildBookingCard(booking);
          },
        );
      },
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF57E659).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF57E659)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.patientName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${booking.date} at ${booking.time}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: booking.status == 'pending'
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              booking.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: booking.status == 'pending'
                    ? Colors.orange
                    : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Profile Description'),
          _buildTextField(_descController, maxLines: 5),
          const SizedBox(height: 20),
          _buildSectionTitle('Consultation Fee (\$)'),
          _buildTextField(_feeController, keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          _buildSectionTitle('Available Dates'),
          Wrap(
            spacing: 8,
            children: [
              ..._tempAvailableDates.map(
                (date) => Chip(
                  label: Text(date, style: const TextStyle(fontSize: 12)),
                  onDeleted: () {
                    setState(() {
                      _tempAvailableDates.remove(date);
                    });
                  },
                  backgroundColor: const Color(0xFF1E1E1E),
                  deleteIconColor: Colors.redAccent,
                ),
              ),
              ActionChip(
                label: const Icon(Icons.add, size: 16),
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (pickedDate != null) {
                    final formattedDate = DateFormat(
                      'yyyy-MM-dd',
                    ).format(pickedDate);
                    if (!_tempAvailableDates.contains(formattedDate)) {
                      setState(() {
                        _tempAvailableDates.add(formattedDate);
                      });
                    }
                  }
                },
                backgroundColor: const Color(0xFF57E659),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                setState(() => _isLoading = true);
                final updatedDoctor = Doctor(
                  id: _currentDoctor!.id,
                  name: _currentDoctor!.name,
                  specialty: _currentDoctor!.specialty,
                  rating: _currentDoctor!.rating,
                  image: _currentDoctor!.image,
                  experience: _currentDoctor!.experience,
                  patients: _currentDoctor!.patients,
                  fee: int.tryParse(_feeController.text) ?? _currentDoctor!.fee,
                  followUp: _currentDoctor!.followUp,
                  code: _currentDoctor!.code,
                  joined: _currentDoctor!.joined,
                  location: _currentDoctor!.location,
                  phoneNumber: _currentDoctor!.phoneNumber,
                  description: _descController.text,
                  availableDates: _tempAvailableDates,
                );
                await _doctorService.updateDoctor(updatedDoctor);
                await _loadDoctorData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF57E659),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildStatRow(
            'Total Patients',
            _currentDoctor!.patients.toString(),
            Icons.people,
          ),
          const SizedBox(height: 15),
          _buildStatRow(
            'Average Rating',
            _currentDoctor!.rating.toString(),
            Icons.star,
          ),
          const SizedBox(height: 15),
          _buildStatRow('Experience', _currentDoctor!.experience, Icons.work),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF57E659)),
          const SizedBox(width: 20),
          Text(label, style: GoogleFonts.inter(color: Colors.grey[400])),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
