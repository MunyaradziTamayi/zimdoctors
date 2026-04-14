import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:zimdoctors/Screens/ai_chat_screen.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/Screens/doctors_screen.dart';
import 'package:zimdoctors/services/doctor_service.dart';
import 'package:zimdoctors/services/user_location_service.dart';
import 'package:zimdoctors/Screens/login_screen.dart';
import 'package:zimdoctors/Screens/doctor_detail_screen.dart';
import 'package:zimdoctors/utils/availability_utils.dart';

class Homescreen extends StatefulWidget {
  static String id = '/home_screen';

  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  final _auth = FirebaseAuth.instance;
  final _doctorService = DoctorService();
  final _userLocationService = UserLocationService();
  late User loggedInUser;
  String? userPhoto;
  String? localImagePath;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  UserLocation? _userLocation;
  UserLocationFailureReason? _locationFailureReason;
  bool _isLocating = false;
  bool _locationDialogShown = false;

  void getCurrentUser() {
    final user = _auth.currentUser;

    if (user != null) {
      setState(() {
        loggedInUser = user;
        userPhoto = user.photoURL;
      });
      print(loggedInUser.email);
    }
  }

  @override
  void initState() {
    super.initState();
    getCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshUserLocation();
      _scheduleLocationDialogIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _refreshUserLocation() async {
    if (_isLocating) return;

    setState(() {
      _isLocating = true;
      _locationFailureReason = null;
    });

    try {
      final location = await _userLocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _userLocation = location;
        _isLocating = false;
      });
    } on UserLocationFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _userLocation = null;
        _locationFailureReason = e.reason;
        _isLocating = false;
      });
      _scheduleLocationDialogIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userLocation = null;
        _locationFailureReason = UserLocationFailureReason.permissionDenied;
        _isLocating = false;
      });
      _scheduleLocationDialogIfNeeded();
    }
  }

  Future<void> _onLocationActionPressed() async {
    switch (_locationFailureReason) {
      case UserLocationFailureReason.serviceDisabled:
        _scheduleLocationDialogIfNeeded(force: true);
        break;
      case UserLocationFailureReason.permissionDeniedForever:
        _scheduleLocationDialogIfNeeded(force: true);
        break;
      case UserLocationFailureReason.permissionDenied:
      case null:
        await _refreshUserLocation();
        break;
    }
  }

  void _scheduleLocationDialogIfNeeded({bool force = false}) {
    if (_locationDialogShown && !force) return;

    final reason = _locationFailureReason;
    if (reason == null && !force) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_locationDialogShown && !force) return;

      final currentReason = _locationFailureReason;
      if (currentReason == null && !force) return;

      _locationDialogShown = true;
      unawaited(_showEnableLocationDialog(currentReason));
    });
  }

  Future<void> _showEnableLocationDialog(UserLocationFailureReason? reason) {
    String title = 'Turn on location';
    String message = 'Please turn on location services to see doctors near you.';

    switch (reason) {
      case UserLocationFailureReason.permissionDeniedForever:
      case UserLocationFailureReason.permissionDenied:
        title = 'Enable location';
        message = 'Please allow location access to see doctors near you.';
        break;
      case UserLocationFailureReason.serviceDisabled:
      case null:
        break;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.85),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Not now',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _refreshUserLocation();
            },
            child: Text(
              'Retry',
              style: GoogleFonts.inter(color: const Color(0xFF57E659)),
            ),
          ),
        ],
      ),
    );
  }

  bool _doctorMatchesUserLocation(Doctor doctor) {
    final userLocation = _userLocation;
    if (userLocation == null) return false;

    final doctorLocation = doctor.location.toLowerCase();

    final rawCandidates = <String?>[
      userLocation.subLocality,
      userLocation.locality,
      userLocation.administrativeArea,
      userLocation.country,
    ];

    final seen = <String>{};
    final candidates = <String>[];
    for (final value in rawCandidates) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (seen.add(normalized)) candidates.add(normalized);
    }

    for (final token in candidates) {
      if (doctorLocation.contains(token)) return true;
    }
    return false;
  }

  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    final headerLocationText = _userLocation?.bestLabel ??
        (_isLocating ? 'Locating...' : _locationActionText());

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                              Icons.logout,
                              onTap: () async {
                                final shouldLogout = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    title: Text(
                                      'Logout',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                      ),
                                    ),
                                    content: Text(
                                      'Are you sure you want to logout?',
                                      style: GoogleFonts.inter(
                                        color: Colors.grey[300],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text(
                                          'Logout',
                                          style: TextStyle(color: Colors.redAccent),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (shouldLogout == true) {
                                  try {
                                    await _auth.signOut();
                                    if (!mounted) return;
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      LoginScreen.id,
                                      (route) => false,
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Logout failed: $e')),
                                    );
                                  }
                                }
                              },
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
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  backgroundImage: (localImagePath != null &&
                                          localImagePath!.isNotEmpty)
                                      ? FileImage(File(localImagePath!))
                                          as ImageProvider
                                      : (userPhoto != null &&
                                              userPhoto!.isNotEmpty)
                                          ? NetworkImage(userPhoto!)
                                          : null,
                                  child: (localImagePath == null ||
                                              localImagePath!.isEmpty) &&
                                          (userPhoto == null ||
                                              userPhoto!.isEmpty)
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

	                        // Title
	                        Column(
	                          crossAxisAlignment: CrossAxisAlignment.start,
	                          children: [
	                            GestureDetector(
	                              onTap: _isLocating ? null : _onLocationActionPressed,
	                              child: Row(
	                                mainAxisSize: MainAxisSize.min,
	                                children: [
	                                  Icon(
	                                    Icons.location_on_outlined,
	                                    size: 16,
	                                    color: _userLocation == null
	                                        ? Colors.grey[500]
	                                        : const Color(0xFF57E659),
	                                  ),
	                                  const SizedBox(width: 6),
	                                  Text(
	                                    headerLocationText,
	                                    style: GoogleFonts.inter(
	                                      fontSize: 13,
	                                      fontWeight: FontWeight.w600,
	                                      color: _userLocation == null
	                                          ? Colors.grey[400]
	                                          : const Color(0xFF57E659),
	                                    ),
	                                  ),
	                                  if (_isLocating) ...[
	                                    const SizedBox(width: 10),
	                                    const SizedBox(
	                                      width: 14,
	                                      height: 14,
	                                      child: CircularProgressIndicator(
	                                        strokeWidth: 2,
	                                        color: Color(0xFF57E659),
	                                      ),
	                                    ),
	                                  ],
	                                ],
	                              ),
	                            ),
	                            const SizedBox(height: 12),
	                            Row(
	                              children: [
	                                Text(
	                                  'Zim Doctors',
	                                  style: GoogleFonts.inter(
	                                    fontSize: 28, 
	                                    fontWeight: FontWeight.w600,
	                                    color: Colors.white,
	                                  ),
	                                ),
	                              ],
	                            ),
	                            const SizedBox(height: 6),
	                         
	                           
	                          ],
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
                                  controller: _searchController,
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value.toLowerCase();
                                    });
                                  },
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Search doctors...',
                                    hintStyle: TextStyle(color: Colors.grey[600]),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Colors.grey[500],
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              color: Colors.grey,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                              });
                                            },
                                          )
                                        : null,
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Featured Content
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Featured Doctor Card with Blur Effect
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(20), // Reduced from 24
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.1),
                                      Colors.white.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 10), // Reduced from 20
                                    // Animated Microphone Icon
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(seconds: 2),
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: 0.95 + (0.1 * value),
                                          child: Container(
                                            width: 110, // Reduced from 140
                                            height: 110, // Reduced from 140
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  const Color(
                                                    0xFF8B5CF6,
                                                  ).withOpacity(0.3),
                                                  const Color(
                                                    0xFFEC4899,
                                                  ).withOpacity(0.2),
                                                  Colors.transparent,
                                                ],
                                                stops: const [0.0, 0.5, 1.0],
                                              ),
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 80, // Reduced from 100
                                                height: 80, // Reduced from 100
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      Color(0xFF8B5CF6),
                                                      Color(0xFFEC4899),
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Color(0xFF8B5CF6),
                                                      blurRadius: 20, // Reduced from 30
                                                      spreadRadius: 3, // Reduced from 5
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.mic_rounded,
                                                  size: 40, // Reduced from 50
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24), // Reduced from 32
                                    // AI Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14, // Reduced from 16
                                        vertical: 6, // Reduced from 8
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 5, // Reduced from 6
                                            height: 5, // Reduced from 6
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF57E659),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'AI-Powered Healthcare',
                                            style: GoogleFonts.inter(
                                              fontSize: 11, // Reduced from 12
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16), // Reduced from 24
                                    // Headline
                                    Text(
                                      'Chat with ZimDocs AI',
                                      style: GoogleFonts.inter(
                                        fontSize: 22, // Reduced from 26
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8), // Reduced from 12
                                    // Description
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Text(
                                        'Instant medical advice and health guidance, just one click away.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13, // Reduced from 14
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white.withOpacity(0.8),
                                          height: 1.3, // Reduced from 1.4
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 24), // Reduced from 32
                                    // Start Chat Button
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(24), // Reduced from 28
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 5,
                                          sigmaY: 5,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          height: 50, // Reduced from 56
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              24, // Reduced from 28
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                context,
                                                ChatScreen.id,
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.chat_bubble_rounded,
                                                  color: Colors.white,
                                                  size: 18, // Reduced from 22
                                                ),
                                                const SizedBox(width: 10), // Reduced from 12
                                                Text(
                                                  'Start Chat Now',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15, // Reduced from 16
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Book Doctor Button
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 5,
                                          sigmaY: 5,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF57E659)
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            border: Border.all(
                                              color: const Color(0xFF57E659)
                                                  .withOpacity(0.35),
                                              width: 1,
                                            ),
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _showBookDoctorDialog,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.calendar_month,
                                                  color: Color(0xFF57E659),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Book a Doctor',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color:
                                                        const Color(0xFF57E659),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10), // Reduced from 20
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        _buildRecommendedDoctorsSection(),
                        const SizedBox(height: 24),
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
                        StreamBuilder<List<Doctor>>(
                          stream: _doctorService.getDoctors(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF57E659),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading doctors',
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(
                                child: Text(
                                  'No doctors available',
                                  style: GoogleFonts.inter(color: Colors.grey),
                                ),
                              );
                            }

                            final doctors = snapshot.data!
                                .where((doctor) {
                                  final name = doctor.name.toLowerCase();
                                  final specialty = doctor.specialty
                                      .toLowerCase();
                                  final location = doctor.location
                                      .toLowerCase();
                                  return name.contains(_searchQuery) ||
                                      specialty.contains(_searchQuery) ||
                                      location.contains(_searchQuery);
                                })
                                .toList();

                            doctors.sort((a, b) {
                              final aEarliest =
                                  AvailabilityUtilsX.earliestUpcomingSlot(
                                availableDates: a.availableDates,
                                availabilitySlots: a.availabilitySlots,
                              );
                              final bEarliest =
                                  AvailabilityUtilsX.earliestUpcomingSlot(
                                availableDates: b.availableDates,
                                availabilitySlots: b.availabilitySlots,
                              );

                              if (aEarliest == null && bEarliest == null) {
                                return b.rating.compareTo(a.rating);
                              }
                              if (aEarliest == null) return 1;
                              if (bEarliest == null) return -1;

                              final byTime = aEarliest.compareTo(bEarliest);
                              if (byTime != 0) return byTime;
                              return b.rating.compareTo(a.rating);
                            });

                            if (doctors.isEmpty) {
                              return Center(
                                child: Text(
                                  'No matches for "$_searchQuery"',
                                  style: GoogleFonts.inter(color: Colors.grey),
                                ),
                              );
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: doctors.map(_buildDoctorCard).toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                          _buildNavItem(
                            2,
                            Icons.people_outline,
                            DoctorsScreen.id,
                          ),
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

  String _locationHintText() {
    switch (_locationFailureReason) {
      case UserLocationFailureReason.serviceDisabled:
        return 'Turn on location services to see doctors near you.';
      case UserLocationFailureReason.permissionDeniedForever:
        return 'Allow location access to see doctors near you.';
      case UserLocationFailureReason.permissionDenied:
      case null:
        return 'Allow location access to see doctors near you.';
    }
  }

  String _locationActionText() {
    switch (_locationFailureReason) {
      case UserLocationFailureReason.serviceDisabled:
        return 'Turn on location';
      case UserLocationFailureReason.permissionDeniedForever:
        return 'Turn on location';
      case UserLocationFailureReason.permissionDenied:
      case null:
        return _userLocation == null ? 'Enable location' : 'Refresh';
    }
  }

  Widget _buildRecommendedDoctorsSection() {
    final locationLabel = _userLocation?.bestLabel;

	    return Column(
	      crossAxisAlignment: CrossAxisAlignment.start,
	      children: [
	        Row(
	          children: [
	            Expanded(
	              child: Text(
	                'Available Doctors Near You',
	                maxLines: 1,
	                overflow: TextOverflow.ellipsis,
	                style: GoogleFonts.inter(
	                  fontSize: 18,
	                  fontWeight: FontWeight.w600,
	                  color: Colors.white,
	                ),
	              ),
	            ),
	            const SizedBox(width: 12),
	            Flexible(
	              child: TextButton(
	                onPressed: _isLocating ? null : _onLocationActionPressed,
	                child: Row(
	                  mainAxisSize: MainAxisSize.min,
	                  children: [
	                    _isLocating
	                        ? const SizedBox(
	                            width: 16,
	                            height: 16,
	                            child: CircularProgressIndicator(
	                              strokeWidth: 2,
	                              color: Color(0xFF57E659),
	                            ),
	                          )
	                        : const Icon(
	                            Icons.my_location,
	                            size: 16,
	                            color: Color(0xFF57E659),
	                          ),
	                    const SizedBox(width: 6),
	                    Flexible(
	                      child: Text(
	                        locationLabel ?? _locationActionText(),
	                        maxLines: 1,
	                        overflow: TextOverflow.ellipsis,
	                        style: GoogleFonts.inter(
	                          fontSize: 12,
	                          fontWeight: FontWeight.w600,
	                          color: const Color(0xFF57E659),
	                        ),
	                      ),
	                    ),
	                  ],
	                ),
	              ),
	            ),
	          ],
	        ),
	        const SizedBox(height: 12),
	        if (_userLocation == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _locationHintText(),
                    style: GoogleFonts.inter(
                      color: Colors.grey[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _isLocating ? null : _onLocationActionPressed,
                  child: Text(
                    _locationActionText(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF57E659),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          StreamBuilder<List<Doctor>>(
            stream: _doctorService.getDoctors(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 110,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF57E659),
                    ),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Text(
                  'Unable to load nearby recommendations.',
                  style: GoogleFonts.inter(color: Colors.grey),
                );
              }

              final allDoctors = List<Doctor>.from(snapshot.data!)
                ..sort((a, b) {
                  final aEarliest = AvailabilityUtilsX.earliestUpcomingSlot(
                    availableDates: a.availableDates,
                    availabilitySlots: a.availabilitySlots,
                  );
                  final bEarliest = AvailabilityUtilsX.earliestUpcomingSlot(
                    availableDates: b.availableDates,
                    availabilitySlots: b.availabilitySlots,
                  );

                  if (aEarliest == null && bEarliest == null) {
                    return b.rating.compareTo(a.rating);
                  }
                  if (aEarliest == null) return 1;
                  if (bEarliest == null) return -1;

                  final byTime = aEarliest.compareTo(bEarliest);
                  if (byTime != 0) return byTime;
                  return b.rating.compareTo(a.rating);
                });
              final nearby =
                  allDoctors.where(_doctorMatchesUserLocation).toList();

              if (nearby.isEmpty) {
                return Text(
                  'No doctors found near "${_userLocation?.bestLabel ?? 'you'}".',
                  style: GoogleFonts.inter(color: Colors.grey),
                );
              }

              final topNearby = nearby.take(10).toList();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: topNearby.map(_buildDoctorCard).toList(),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
    return SizedBox(
      width: 200, // Fixed width for horizontal scrolling
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(
            context,
            DoctorDetailScreen.id,
            arguments: doctor,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: const Color(0xFF2C2C2C),
                backgroundImage:
                    doctor.image.isNotEmpty ? NetworkImage(doctor.image) : null,
                child: doctor.image.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 35,
                        color: Colors.white,
                      )
                    : null,
                onBackgroundImageError: doctor.image.isNotEmpty
                    ? (exception, stackTrace) => print('Error loading image')
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                doctor.name,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                doctor.specialty,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF57E659),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
	              Row(
	                mainAxisAlignment: MainAxisAlignment.center,
	                children: [
	                  Icon(
	                    Icons.location_on,
                    size: 12,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      doctor.location,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
	                  ),
	                ],
	              ),
	              if (doctor.surgeryLocation.trim().isNotEmpty) ...[
	                const SizedBox(height: 6),
	                Row(
	                  mainAxisAlignment: MainAxisAlignment.center,
	                  children: [
	                    Icon(
	                      Icons.local_hospital_outlined,
	                      size: 12,
	                      color: Colors.grey[500],
	                    ),
	                    const SizedBox(width: 4),
	                    Flexible(
	                      child: Text(
	                        doctor.surgeryLocation,
	                        style: GoogleFonts.inter(
	                          fontSize: 11,
	                          color: Colors.grey[400],
	                        ),
	                        maxLines: 1,
	                        overflow: TextOverflow.ellipsis,
	                      ),
	                    ),
	                  ],
	                ),
	              ],
	              const SizedBox(height: 6),
	              Row(
	                mainAxisAlignment: MainAxisAlignment.center,
	                children: [
	                  Icon(
                    Icons.monetization_on,
                    size: 12,
                    color: Colors.amber[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Fee: \$${doctor.fee}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.amber[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.availableDates.isNotEmpty
                              ? DateFormat('dd MMM').format(
                                  DateTime.parse(doctor.availableDates.first),
                                )
                              : 'N/A',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          doctor.availableDates.isNotEmpty
                              ? 'Available'
                              : 'No Slots',
                          style: GoogleFonts.inter(
                            fontSize: 9,
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
                    decoration: const BoxDecoration(
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

  Widget _buildGlassIcon(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildGlassTimeSlot(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Text(
        time,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
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

  Future<void> _showBookDoctorDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Book an appointment',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Do you already know which doctor you want to see?',
          style: GoogleFonts.inter(color: Colors.grey[300], height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatScreen(recommendDoctor: true),
                ),
              );
            },
            child: Text(
              "No, help me choose",
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DoctorsScreen(autofocusSearch: true),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF57E659),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Yes, search',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
