import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/services/doctor_service.dart';
import 'package:zimdoctors/Screens/doctor_detail_screen.dart';
import 'package:zimdoctors/services/user_location_service.dart';
import 'package:intl/intl.dart';
import 'package:zimdoctors/utils/availability_utils.dart';

class DoctorsScreen extends StatefulWidget {
  static const String id = '/doctors_screen';
  final String? initialQuery;
  final bool autofocusSearch;

  const DoctorsScreen({
    super.key,
    this.initialQuery,
    this.autofocusSearch = false,
  });

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final DoctorService _doctorService = DoctorService();
  final UserLocationService _userLocationService = UserLocationService();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  UserLocation? _userLocation;
  bool _isLocatingLocation = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _searchQuery = initial.toLowerCase();
    }
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    if (_isDisposed) return;
    setState(() {
      _isLocatingLocation = true;
    });

    try {
      final location = await _userLocationService.getCurrentLocation();
      if (_isDisposed) return;
      setState(() {
        _userLocation = location;
      });
    } catch (_) {
      if (_isDisposed) return;
      setState(() {
        _userLocation = null;
      });
    } finally {
      if (_isDisposed) return;
      setState(() {
        _isLocatingLocation = false;
      });
    }
  }

  Future<void> _refreshUserLocation() async {
    await _loadUserLocation();
  }

  bool _doctorMatchesUserLocation(Doctor doctor) {
    final userLocation = _userLocation;
    if (userLocation == null) return false;

    final doctorLocation = '${doctor.location} ${doctor.surgeryLocation}'
        .toLowerCase();

    final rawCandidates = <String?>[
      userLocation.bestLabel,
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

  String get _locationActionLabel {
    if (_isLocatingLocation) return 'Checking...';
    return _userLocation == null ? 'Enable location' : 'Refresh';
  }

  Widget _buildNearbyDoctorCard(Doctor doctor) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, DoctorDetailScreen.id, arguments: doctor);
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF2C2C2C),
              backgroundImage: doctor.image.isNotEmpty
                  ? NetworkImage(doctor.image)
                  : null,
              child: doctor.image.isEmpty
                  ? const Icon(Icons.person, size: 28, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              doctor.name,
              style: GoogleFonts.inter(
                fontSize: 13,
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
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF57E659),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    doctor.location,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF57E659),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Book now',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
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
    _isDisposed = true;
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: widget.autofocusSearch,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search doctors...',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Doctor>>(
        stream: _doctorService.getDoctors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                'No doctors found',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            );
          }

          final allDoctors = List<Doctor>.from(snapshot.data!);
          allDoctors.sort((a, b) {
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

          final doctors = allDoctors.where((doctor) {
            final name = doctor.name.toLowerCase();
            final specialty = doctor.specialty.toLowerCase();
            final location = doctor.location.toLowerCase();
            return name.contains(_searchQuery) ||
                specialty.contains(_searchQuery) ||
                location.contains(_searchQuery);
          }).toList();

          final nearbyDoctors = allDoctors
              .where(_doctorMatchesUserLocation)
              .take(4)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Nearby doctors',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _refreshUserLocation,
                    child: Text(
                      _locationActionLabel,
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _userLocation == null
                    ? 'Enable location to see doctors near you.'
                    : 'Showing doctors near ${_userLocation?.bestLabel ?? 'you'}.',
                style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (nearbyDoctors.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _userLocation == null
                        ? 'Location is not available yet. Tap to enable location.'
                        : 'No doctors found in your area right now.',
                    style: GoogleFonts.inter(color: Colors.grey[400]),
                  ),
                )
              else
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: nearbyDoctors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return _buildNearbyDoctorCard(nearbyDoctors[index]);
                    },
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'All doctors',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (doctors.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'No matches for "$_searchQuery"',
                    style: GoogleFonts.inter(color: Colors.grey[400]),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 305,
                  ),
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          DoctorDetailScreen.id,
                          arguments: doctor,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: const Color(0xFF2C2C2C),
                              backgroundImage: doctor.image.isNotEmpty
                                  ? NetworkImage(doctor.image)
                                  : null,
                              onBackgroundImageError: doctor.image.isNotEmpty
                                  ? (_, __) {}
                                  : null,
                              child: doctor.image.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 35,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              doctor.name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
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
                                fontSize: 11,
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
                                  size: 11,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    doctor.location,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.grey[400],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (doctor.surgeryLocation.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_hospital_outlined,
                                    size: 11,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      doctor.surgeryLocation,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.grey[400],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.monetization_on,
                                  size: 11,
                                  color: Colors.amber[400],
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Fee: \$${doctor.fee}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.amber[400],
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doctor.availableDates.isNotEmpty
                                            ? DateFormat('dd MMM').format(
                                                DateTime.parse(
                                                  doctor.availableDates.first,
                                                ),
                                              )
                                            : 'N/A',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        doctor.availableDates.isNotEmpty
                                            ? 'Available'
                                            : 'No Slots',
                                        style: GoogleFonts.inter(
                                          fontSize: 8,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_outward,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
