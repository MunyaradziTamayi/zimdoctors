import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zimdoctors/Screens/ai_chat_screen.dart';
import 'dart:ui';
import 'dart:io';
import 'package:zimdoctors/reusableWidgets/reusableElevatedBtn.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/Screens/doctors_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Homescreen extends StatefulWidget {
  static String id = '/home_screen';

  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  final _auth = FirebaseAuth.instance;
  late User loggedInUser;
  String? userPhoto;
  String? localImagePath;

  final List<Doctor> savedDoctors = [
    Doctor(
      id: '1',
      name: 'Dr. Matthew Clark',
      specialty: 'General Practitioner\nDubai',
      rating: 4.8,
      image: 'https://i.pravatar.cc/150?img=11',
      location: 'Dubai',
      phoneNumber: '+1234567890',
      experience: '10 years',
      patients: 120,
      fee: 50,
      followUp: 30,
      code: 'DOC001',
      joined: '2020',
      description:
          'Experienced General Practitioner with a focus on patient-centered care.',
    ),
    Doctor(
      id: '2',
      name: 'Dr. James Gun',
      specialty: 'Physiotherapist',
      rating: 4.9,
      image: 'https://i.pravatar.cc/150?img=12',
      location: 'London',
      phoneNumber: '+0987654321',
      experience: '12 years',
      patients: 200,
      fee: 80,
      followUp: 40,
      code: 'DOC002',
      joined: '2019',
      description:
          'Specialist in physiotherapy with a passion for rehabilitation and wellness.',
    ),
  ];

  void getCurrentUser() {
    final user = _auth.currentUser;

    if (user != null) {
      setState(() {
        loggedInUser = user;
        
      });
      print(loggedInUser.email);
    }
  }

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String) {
      setState(() {
        localImagePath = args;
      });
    }
  }

  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCircleIcon(
                            Icons.arrow_back,
                            onTap: () => Navigator.pop(context),
                          ),
                          Row(
                            children: [
                              _buildCircleIcon(Icons.calendar_today_outlined),
                              const SizedBox(width: 12),
                              _buildCircleIcon(
                                Icons.notifications_outlined,
                                hasDot: true,
                              ),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 22,
                                backgroundImage:
                                    (localImagePath != null &&
                                        localImagePath!.isNotEmpty)
                                    ? FileImage(File(localImagePath!))
                                          as ImageProvider
                                    : (userPhoto != null &&
                                          userPhoto!.isNotEmpty)
                                    ? NetworkImage(userPhoto!)
                                    : const NetworkImage(
                                        'https://i.pravatar.cc/150?img=3', // Default placeholder
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Book a Doctor',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Search Bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: TextField(
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(color: Colors.grey[600]),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.grey[500],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildCircleIcon(Icons.tune, size: 50),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Date Filters
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            reusableElevatedBtn(btntext: 'Cardiologist'),
                            SizedBox(width: 4),
                            reusableElevatedBtn(btntext: 'Oncologist'),
                            SizedBox(width: 4),
                            reusableElevatedBtn(btntext: 'Dentist'),
                            SizedBox(width: 4),
                            reusableElevatedBtn(btntext: 'Optician'),
                            SizedBox(width: 4),
                            reusableElevatedBtn(btntext: 'Gynacologist'),
                            SizedBox(width: 4),
                            reusableElevatedBtn(btntext: 'Physician'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Featured Doctor Card (Scrollable Content)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Previous Feature Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.lime,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 28,
                                        backgroundImage: NetworkImage(
                                          'https://i.pravatar.cc/150?img=5',
                                        ), // Doctor Image
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Available Today',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      _buildActionIcon(Icons.favorite_border),
                                      const SizedBox(width: 8),
                                      _buildActionIcon(
                                        Icons.chat_bubble_outline,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Dr. Rajaa Nourain',
                                style: GoogleFonts.inter(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Time Slots
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildTimeSlot('Today, 26 Jul'),
                                  _buildTimeSlot('Today, 26 Jul'),
                                  _buildTimeSlot('Today, 26 Jul'),
                                  _buildTimeSlot('Today, 26 Jul'),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // View All Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: const Color(0xFF57E659),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Text(
                                    'View All Appointment',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Popular Doctors',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, DoctorsScreen.id);
                              },
                              child: Text(
                                'View all',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF57E659),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: savedDoctors.map((doctor) {
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundImage: NetworkImage(
                                            doctor.image,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                doctor.name,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      doctor.specialty,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey[400],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '01 Aug',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                'Time 11:AM',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_outward,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Custom Bottom Navbar
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      height: 70,
                      width: 250,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(0, Icons.home_filled, Homescreen.id),
                          _buildNavItem(
                            1,
                            Icons.chat_rounded,
                            ChatScreen.id,
                          ), // Active tab
                          _buildNavItem(2, Icons.people_outline, Homescreen.id),
                          _buildNavItem(3, Icons.list, DoctorsScreen.id),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIcon(
    IconData icon, {
    VoidCallback? onTap,
    bool hasDot = false,
    double size = 44,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (hasDot)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xFF1E1E1E), width: 1.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(String label, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF57E659) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: isActive ? Colors.black : Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.black, size: 22),
    );
  }

  Widget _buildTimeSlot(String label) {
    return Container(
      width: 150, // Fixed width for grid look
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String routeName) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          Navigator.pushNamed(context, routeName);
          _selectedIndex = index;
        });
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
