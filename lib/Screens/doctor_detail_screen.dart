import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/models/booking.dart';
import 'package:zimdoctors/services/doctor_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class DoctorDetailScreen extends StatelessWidget {
  static const String id = '/doctor_detail_screen';
  final Doctor doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                      image: DecorationImage(
                        image: NetworkImage(doctor.image),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    doctor.name,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    doctor.specialty,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        doctor.location,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard(
                    'Patients',
                    doctor.patients.toString(),
                    const Color(0xFFE3F2FD),
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Experience',
                    doctor.experience,
                    const Color(0xFFFCE4EC),
                    Colors.pink,
                  ),
                  _buildStatCard(
                    'Fee',
                    '\$${doctor.fee}',
                    const Color(0xFFE8F5E9),
                    Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Doctor',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    doctor.description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Available Dates',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  doctor.availableDates.isNotEmpty
                      ? SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: doctor.availableDates.length,
                            itemBuilder: (context, index) {
                              final date = doctor.availableDates[index];
                              final parsedDate = DateTime.parse(date);
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF57E659,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat('EEE').format(parsedDate),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF57E659),
                                      ),
                                    ),
                                    Text(
                                      DateFormat('dd MMM').format(parsedDate),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      : Text(
                          'No availability set yet',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                  const SizedBox(height: 30),
                  Text(
                    'Communication',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCommunicationItem(
                    icon: Icons.chat_bubble_outline,
                    title: 'Messaging',
                    subtitle: 'Send SMS to the doctor',
                    color: const Color(0xFF422121),
                    iconColor: Colors.pink[200]!,
                  ),
                  const SizedBox(height: 12),
                  _buildCommunicationItem(
                    icon: FontAwesomeIcons.whatsapp,
                    title: 'WhatsApp',
                    subtitle: 'WhatsApp your doctor directly.',
                    color: const Color(0xFF1E2F2F),
                    iconColor: Colors.green[400]!,
                  ),
                  const SizedBox(height: 12),
                  _buildCommunicationItem(
                    icon: Icons.call_outlined,
                    title: 'Call Doctor',
                    subtitle: 'Call your doctor directly.',
                    color: const Color(0xFF1E2832),
                    iconColor: Colors.blue[300]!,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _showBookingDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        'Book Appointment',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingDialog(BuildContext context) async {
    if (doctor.availableDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This doctor has not set any available dates yet.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedDate;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            'Select Available Date',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: doctor.availableDates.length,
              itemBuilder: (context, index) {
                final date = doctor.availableDates[index];
                return ListTile(
                  title: Text(
                    DateFormat(
                      'EEEE, dd MMM yyyy',
                    ).format(DateTime.parse(date)),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    selectedDate = date;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final doctorService = DoctorService();
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please login to book an appointment'),
              ),
            );
          }
          return;
        }

        // Check for double booking
        final isBooked = await doctorService.isSlotBooked(
          doctor.id,
          selectedDate!,
          pickedTime.format(context),
        );

        if (isBooked) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This slot is already booked. Please choose another time.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final booking = Booking(
          id: '', // Will be generated by Firestore
          doctorId: doctor.id,
          patientId: user.uid,
          patientName:
              user.displayName ?? user.email?.split('@').first ?? 'Patient',
          date: selectedDate!,
          time: pickedTime.format(context),
          status: 'pending',
          createdAt: DateTime.now(),
        );

        try {
          await doctorService.createBooking(booking);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Booking request sent successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color bgColor,
    Color iconColor,
  ) {
    IconData icon;
    if (label == 'Patients') {
      icon = Icons.people_outline;
    } else if (label == 'Experience') {
      icon = Icons.workspace_premium_outlined;
    } else {
      icon = Icons.star_border;
    }

    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
