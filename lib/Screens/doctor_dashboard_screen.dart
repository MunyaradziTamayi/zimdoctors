import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zimdoctors/Screens/login_screen.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/models/booking.dart';
import 'package:zimdoctors/services/doctor_service.dart';
import 'package:intl/intl.dart';
import 'package:zimdoctors/models/notification.dart';
import 'package:zimdoctors/services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'package:zimdoctors/utils/date_utils.dart';

class DoctorDashboardScreen extends StatefulWidget {
  static const String id = '/doctor_dashboard_screen';

  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _doctorService = DoctorService();
  final _notificationService = NotificationService();
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();
  Doctor? _currentDoctor;
  bool _isLoading = true;
  File? _selectedImage;
  late TabController _tabController;

  final _descController = TextEditingController();
  final _feeController = TextEditingController();
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _expController = TextEditingController();
  final _locationController = TextEditingController();
  final _surgeryLocationController = TextEditingController();
  final _phoneController = TextEditingController();

  List<String> _tempAvailableDates = [];
  Map<String, List<String>> _tempAvailabilitySlots = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadDoctorData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descController.dispose();
    _feeController.dispose();
    _nameController.dispose();
    _specialtyController.dispose();
    _expController.dispose();
    _locationController.dispose();
    _surgeryLocationController.dispose();
    _phoneController.dispose();
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
          _nameController.text = doctor.name;
          _specialtyController.text = doctor.specialty;
          _expController.text = doctor.experience;
          _locationController.text = doctor.location;
          _surgeryLocationController.text = doctor.surgeryLocation;
          _phoneController.text = doctor.phoneNumber;
          final upcomingDates = DateUtilsX.upcomingIsoDates(doctor.availableDates);
          _tempAvailableDates = List.from(upcomingDates);
          _tempAvailabilitySlots = Map<String, List<String>>.fromEntries(
            doctor.availabilitySlots.entries
                .where((entry) => upcomingDates.contains(entry.key))
                .map(
                  (entry) => MapEntry(entry.key, List<String>.from(entry.value)),
                ),
          );
        }
      });
    }
  }

  void _purgePastAvailability() {
    final upcomingDates = DateUtilsX.upcomingIsoDates(_tempAvailableDates);
    _tempAvailableDates = List.from(upcomingDates);
    _tempAvailabilitySlots.removeWhere((key, value) => !upcomingDates.contains(key));
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

    return Scaffold(
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
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF57E659),
                  tabs: const [
                    Tab(text: 'Bookings'),
                    Tab(text: 'Profile'),
                    Tab(text: 'Stats'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          _buildProfileImage(),
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
          StreamBuilder<List<SystemNotification>>(
            stream: _notificationService.getActiveNotifications(_currentDoctor!.id),
            builder: (context, snapshot) {
              int count = snapshot.data?.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () => _showNotifications(context),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: Text(
                    'Logout',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  content: Text(
                    'Are you sure you want to logout?',
                    style: GoogleFonts.inter(color: Colors.grey[300]),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );

              if (shouldLogout != true) return;
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
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFF1E1E1E),
          backgroundImage: _selectedImage != null
              ? FileImage(_selectedImage!)
              : (_currentDoctor!.image.isNotEmpty
                  ? NetworkImage(_currentDoctor!.image)
                  : null) as ImageProvider?,
          child: _selectedImage == null && _currentDoctor!.image.isEmpty
              ? const Icon(Icons.person, size: 30, color: Colors.grey)
              : null,
        ),
        if (_tabController.index == 1) // Only show in profile tab
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF57E659),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 12, color: Colors.black),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
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
                if (booking.reason.trim().isNotEmpty)
                  Text(
                    booking.reason,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (booking.status == 'pending') ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: () async {
                final shouldConfirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: Text(
                      'Confirm appointment?',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    content: Text(
                      'Confirm ${booking.patientName} on ${booking.date} at ${booking.time}.\n\nReason: ${booking.reason}',
                      style: GoogleFonts.inter(color: Colors.grey[300]),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(color: Color(0xFF57E659)),
                        ),
                      ),
                    ],
                  ),
                );

                if (shouldConfirm != true) return;
                try {
                  await _doctorService.updateBookingStatus(
                    booking.id,
                    'confirmed',
                  );
                  await _notificationService.sendNotification(
                    userId: booking.patientId,
                    title: 'Appointment Confirmed',
                    body:
                        'Dr. ${_currentDoctor!.name} confirmed your appointment on ${booking.date} at ${booking.time}. Communication is available during the booked slot (paid appointments only).',
                    type: 'booking_confirmed',
                    data: {
                      'bookingId': booking.id,
                      'doctorId': booking.doctorId,
                      'patientId': booking.patientId,
                      'date': booking.date,
                      'time': booking.time,
                    },
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Appointment confirmed.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to confirm: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
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
          _buildSectionTitle('Full Name'),
          _buildTextField(_nameController),
          const SizedBox(height: 20),
          _buildSectionTitle('Specialty'),
          _buildTextField(_specialtyController),
          const SizedBox(height: 20),
          _buildSectionTitle('Experience'),
          _buildTextField(_expController),
          const SizedBox(height: 20),
          _buildSectionTitle('City / Area'),
          _buildTextField(_locationController),
          const SizedBox(height: 20),
          _buildSectionTitle('Surgery / Workplace'),
          _buildTextField(_surgeryLocationController),
          const SizedBox(height: 20),
          _buildSectionTitle('Phone Number'),
          _buildTextField(_phoneController),
          const SizedBox(height: 20),
          _buildSectionTitle('Profile Description'),
          _buildTextField(_descController, maxLines: 5),
          const SizedBox(height: 20),
          _buildSectionTitle('Consultation Fee (\$)'),
          _buildTextField(_feeController, keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          _buildSectionTitle('Available Dates & Slots'),
          Wrap(
            spacing: 8,
            children: [
              ..._tempAvailableDates.map(
                (date) => InputChip(
                  label: Text(
                    '$date (${_tempAvailabilitySlots[date]?.length ?? 0} slots)',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  onPressed:
                      DateUtilsX.isPastDate(date) ? null : () => _showSlotsDialog(date),
                  onDeleted: () {
                    setState(() {
                      _tempAvailableDates.remove(date);
                      _tempAvailabilitySlots.remove(date);
                    });
                  },
                  backgroundColor: DateUtilsX.isPastDate(date)
                      ? Colors.grey.shade900
                      : const Color(0xFF1E1E1E),
                  deleteIconColor: Colors.redAccent,
                ),
              ),
              ActionChip(
                label: const Icon(Icons.add, size: 16, color: Colors.black),
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
                        _tempAvailabilitySlots[formattedDate] = [];
                      });
                      _showSlotsDialog(formattedDate);
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
                _purgePastAvailability();
                
                String imageUrl = _currentDoctor!.image;
                if (_selectedImage != null) {
                  try {
                    imageUrl = await _doctorService.uploadProfileImage(
                      _selectedImage!, 
                      _currentDoctor!.id
                    );
                  } catch (e) {
                    print('Doctor profile image update failed: $e');
                    // Notification or snackbar could go here, but we continue with old image
                  }
                }

                final updatedDoctor = Doctor(
                  id: _currentDoctor!.id,
                  name: _nameController.text,
                  registrationNumber: _currentDoctor!.registrationNumber,
                  specialty: _specialtyController.text,
                  rating: _currentDoctor!.rating,
                  image: imageUrl,
                  experience: _expController.text,
                  patients: _currentDoctor!.patients,
                  fee: int.tryParse(_feeController.text) ?? _currentDoctor!.fee,
                  followUp: _currentDoctor!.followUp,
                  code: _currentDoctor!.code,
                  joined: _currentDoctor!.joined,
                  location: _locationController.text,
                  surgeryLocation: _surgeryLocationController.text,
                  phoneNumber: _phoneController.text,
                  description: _descController.text,
                  availableDates: _tempAvailableDates,
                  availabilitySlots: _tempAvailabilitySlots,
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

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: Color(0xFF57E659),
                  tabs: [
                    Tab(text: 'Active'),
                    Tab(text: 'History'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildNotificationList(isActive: true),
                      _buildNotificationList(isActive: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationList({required bool isActive}) {
    return StreamBuilder<List<SystemNotification>>(
      stream: isActive
          ? _notificationService.getActiveNotifications(_currentDoctor!.id)
          : _notificationService.getNotificationHistory(_currentDoctor!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF57E659)));
        }
        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty) {
          return Center(
            child: Text(
              'No notifications',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 20),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final bookingId = (notification.data?['bookingId'] is String)
                ? notification.data!['bookingId'] as String
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                leading: Icon(
                  notification.type == 'booking'
                      ? Icons.calendar_today
                      : Icons.notifications_outlined,
                  color: const Color(0xFF57E659),
                ),
                onTap: (!isActive ||
                        notification.type != 'booking' ||
                        bookingId == null)
                    ? null
                    : () async {
                        final shouldConfirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            title: Text(
                              'Confirm appointment?',
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                            content: Text(
                              notification.body,
                              style: GoogleFonts.inter(color: Colors.grey[300]),
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
                                  'Confirm',
                                  style: TextStyle(color: Color(0xFF57E659)),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (shouldConfirm != true) return;
                        try {
                          await _doctorService.updateBookingStatus(
                            bookingId,
                            'confirmed',
                          );

                          final patientId =
                              (notification.data?['patientId'] is String)
                                  ? notification.data!['patientId'] as String
                                  : null;
                          final date = (notification.data?['date'] is String)
                              ? notification.data!['date'] as String
                              : '';
                          final time = (notification.data?['time'] is String)
                              ? notification.data!['time'] as String
                              : '';
                          if (patientId != null && patientId.isNotEmpty) {
                            await _notificationService.sendNotification(
                              userId: patientId,
                              title: 'Appointment Confirmed',
                              body:
                                  'Dr. ${_currentDoctor!.name} confirmed your appointment on $date at $time. Communication is available during the booked slot (paid appointments only).',
                              type: 'booking_confirmed',
                              data: notification.data,
                            );
                          }

                          await _notificationService.moveToHistory(
                            notification.id,
                          );

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Appointment confirmed.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to confirm: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                title: Text(
                  notification.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  notification.body,
                  style: TextStyle(color: Colors.grey[400]),
                ),
                trailing: isActive 
                  ? IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Color(0xFF57E659)),
                      onPressed: () => _notificationService.moveToHistory(notification.id),
                    )
                  : null,
              ),
            );
          },
        );
      },
    );
  }

  void _showSlotsDialog(String date) async {
    final List<String> allSlots = [
      '08:00 - 09:00',
      '09:00 - 10:00',
      '10:00 - 11:00',
      '11:00 - 12:00',
      '12:00 - 13:00',
      '13:00 - 14:00',
      '14:00 - 15:00',
      '15:00 - 16:00',
      '16:00 - 17:00',
      '17:00 - 18:00',
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(
                'Slots for $date',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allSlots.length,
                  itemBuilder: (context, index) {
                    final slot = allSlots[index];
                    final isSelected =
                        _tempAvailabilitySlots[date]?.contains(slot) ?? false;
                    return CheckboxListTile(
                      title: Text(
                        slot,
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: isSelected,
                      activeColor: const Color(0xFF57E659),
                      checkColor: Colors.black,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _tempAvailabilitySlots[date] ??= [];
                            if (!_tempAvailabilitySlots[date]!.contains(slot)) {
                              _tempAvailabilitySlots[date]!.add(slot);
                            }
                          } else {
                            _tempAvailabilitySlots[date]?.remove(slot);
                          }
                        });
                        setModalState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Color(0xFF57E659)),
                  ),
                ),
              ],
            );
          },
        );
      },
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
