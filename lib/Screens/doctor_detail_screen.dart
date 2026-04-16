import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/models/booking.dart';
import 'package:zimdoctors/services/doctor_service.dart';
import 'package:zimdoctors/services/payment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zimdoctors/utils/date_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zimdoctors/utils/whatsapp_utils.dart';

class DoctorDetailScreen extends StatelessWidget {
  static const String id = '/doctor_detail_screen';
  final Doctor doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  String _buildWhatsAppBookingMessage(Booking booking) {
    final lines = <String>[
      'New appointment booking',
      '',
      'Patient: ${booking.patientName}',
      'Description: ${booking.reason}',
      'Scheduled: ${booking.date} at ${booking.time}',
      'Payment: ${booking.paymentStatus.toUpperCase()}',
      'Amount: \$${booking.amount.toStringAsFixed(2)}',
    ];
    return lines.join('\n');
  }

  Future<void> _promptWhatsAppNotifyDoctor(
    BuildContext context, {
    required Booking booking,
  }) async {
    final normalized = WhatsAppUtils.normalizeWaMeNumber(doctor.phoneNumber);
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Doctor phone number is missing; cannot open WhatsApp.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final message = _buildWhatsAppBookingMessage(booking);
    final waMeUri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$normalized',
      queryParameters: {'text': message},
    );

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Notify doctor on WhatsApp?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: GoogleFonts.inter(color: Colors.grey[300], height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Not now',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final ok = await launchUrl(
                  waMeUri,
                  mode: LaunchMode.externalApplication,
                );
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open WhatsApp.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not open WhatsApp: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF57E659),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Open WhatsApp',
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

  Stream<List<Booking>> _patientBookingsStream(String patientId) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('doctorId', isEqualTo: doctor.id)
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs
              .map((doc) => Booking.fromMap(doc.data(), doc.id))
              .toList();
          bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return bookings;
        });
  }

  _CommunicationGate _computeCommunicationGate(
    List<Booking> bookings, {
    required DateTime now,
  }) {
    final windows = <Booking, AppointmentWindow>{};
    for (final b in bookings) {
      final w = DateUtilsX.tryParseAppointmentWindow(b.date, b.time);
      if (w != null) windows[b] = w;
    }

    final paidNotCancelled = bookings.where((b) {
      if (b.paymentStatus != 'paid') return false;
      return b.status != 'cancelled';
    }).toList();

    final activeConfirmed =
        windows.entries
            .where(
              (e) =>
                  e.key.paymentStatus == 'paid' &&
                  e.key.status == 'confirmed' &&
                  (now.isAtSameMomentAs(e.value.start) ||
                      now.isAfter(e.value.start)) &&
                  now.isBefore(e.value.end),
            )
            .toList()
          ..sort((a, b) => b.value.start.compareTo(a.value.start));

    if (activeConfirmed.isNotEmpty) {
      final active = activeConfirmed.first;
      return _CommunicationGate(
        canCommunicate: true,
        message:
            'Communication is unlocked until ${DateFormat('HH:mm').format(active.value.end)}.',
        activeBooking: active.key,
        reschedulableBooking: null,
      );
    }

    final upcomingConfirmed =
        windows.entries
            .where(
              (e) =>
                  e.key.paymentStatus == 'paid' &&
                  e.key.status == 'confirmed' &&
                  now.isBefore(e.value.start),
            )
            .toList()
          ..sort((a, b) => a.value.start.compareTo(b.value.start));

    final upcomingPaid =
        windows.entries
            .where(
              (e) =>
                  e.key.paymentStatus == 'paid' &&
                  (e.key.status == 'pending' || e.key.status == 'confirmed') &&
                  now.isBefore(e.value.start),
            )
            .toList()
          ..sort((a, b) => a.value.start.compareTo(b.value.start));

    final reschedulableBooking = upcomingPaid.isNotEmpty
        ? upcomingPaid.first.key
        : null;

    if (paidNotCancelled.isEmpty) {
      return _CommunicationGate(
        canCommunicate: false,
        message: 'Communication unlocks only after you book and pay.',
        activeBooking: null,
        reschedulableBooking: null,
      );
    }

    if (upcomingConfirmed.isNotEmpty) {
      final next = upcomingConfirmed.first;
      final when = DateFormat(
        'EEE, dd MMM yyyy HH:mm',
      ).format(next.value.start);
      return _CommunicationGate(
        canCommunicate: false,
        message: 'Communication opens at $when and locks when the slot ends.',
        activeBooking: null,
        reschedulableBooking: reschedulableBooking,
      );
    }

    final hasPendingPaid = paidNotCancelled.any(
      (b) => b.status != 'confirmed' && b.status != 'cancelled',
    );
    if (hasPendingPaid) {
      return _CommunicationGate(
        canCommunicate: false,
        message:
            'Waiting for the doctor to confirm your paid appointment before communication opens.',
        activeBooking: null,
        reschedulableBooking: reschedulableBooking,
      );
    }

    final endedConfirmed =
        windows.entries
            .where(
              (e) =>
                  e.key.paymentStatus == 'paid' &&
                  e.key.status == 'confirmed' &&
                  !now.isBefore(e.value.end),
            )
            .toList()
          ..sort((a, b) => b.value.end.compareTo(a.value.end));

    if (endedConfirmed.isNotEmpty) {
      return _CommunicationGate(
        canCommunicate: false,
        message:
            'Your paid appointment time has ended; communication is locked again.',
        activeBooking: null,
        reschedulableBooking: null,
      );
    }

    return _CommunicationGate(
      canCommunicate: false,
      message: 'Communication is currently locked.',
      activeBooking: null,
      reschedulableBooking: reschedulableBooking,
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingDates = DateUtilsX.upcomingIsoDates(doctor.availableDates);
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
                      color: const Color(0xFF1E1E1E),
                      border: Border.all(color: Colors.white24, width: 2),
                      image: doctor.image.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(doctor.image),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: doctor.image.isEmpty
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
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
                  if (doctor.surgeryLocation.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            doctor.surgeryLocation,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  upcomingDates.isNotEmpty
                      ? SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: upcomingDates.length,
                            itemBuilder: (context, index) {
                              final date = upcomingDates[index];
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
                  Builder(
                    builder: (context) {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        const gateMessage = 'Please login to communicate.';
                        return Column(
                          children: [
                            _buildCommunicationItem(
                              icon: Icons.chat_bubble_outline,
                              title: 'Messaging',
                              subtitle: gateMessage,
                              color: const Color(0xFF422121),
                              iconColor: Colors.pinkAccent,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text(gateMessage)),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildCommunicationItem(
                              icon: FontAwesomeIcons.whatsapp,
                              title: 'WhatsApp',
                              subtitle: gateMessage,
                              color: const Color(0xFF1E2F2F),
                              iconColor: Colors.green,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text(gateMessage)),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildCommunicationItem(
                              icon: Icons.call_outlined,
                              title: 'Call Doctor',
                              subtitle: gateMessage,
                              color: const Color(0xFF1E2832),
                              iconColor: Colors.blueAccent,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text(gateMessage)),
                                );
                              },
                            ),
                          ],
                        );
                      }

                      return StreamBuilder<List<Booking>>(
                        stream: _patientBookingsStream(user.uid),
                        builder: (context, snapshot) {
                          final bookings = snapshot.data ?? const <Booking>[];
                          return StreamBuilder<int>(
                            stream: Stream<int>.periodic(
                              const Duration(seconds: 30),
                              (i) => i,
                            ),
                            initialData: 0,
                            builder: (context, _) {
                              final gate = _computeCommunicationGate(
                                bookings,
                                now: DateTime.now(),
                              );

                              Future<void> guardAndRun(
                                Future<void> Function() action,
                              ) async {
                                final gateNow = _computeCommunicationGate(
                                  bookings,
                                  now: DateTime.now(),
                                );
                                if (!context.mounted) return;
                                if (!gateNow.canCommunicate) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(gateNow.message)),
                                  );
                                  return;
                                }
                                try {
                                  await action();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }

                              return Column(
                                children: [
                                  _buildCommunicationItem(
                                    icon: Icons.chat_bubble_outline,
                                    title: 'Messaging',
                                    subtitle: gate.canCommunicate
                                        ? 'Send SMS to the doctor'
                                        : gate.message,
                                    color: const Color(0xFF422121),
                                    iconColor: Colors.pink[200]!,
                                    onTap: () {
                                      guardAndRun(() async {
                                        final Uri smsUri = Uri(
                                          scheme: 'sms',
                                          path: doctor.phoneNumber,
                                          queryParameters: <String, String>{
                                            'body':
                                                'Hello Dr. ${doctor.name}, ',
                                          },
                                        );
                                        if (await canLaunchUrl(smsUri)) {
                                          await launchUrl(
                                            smsUri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } else {
                                          throw 'Could not launch SMS app';
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildCommunicationItem(
                                    icon: FontAwesomeIcons.whatsapp,
                                    title: 'WhatsApp',
                                    subtitle: gate.canCommunicate
                                        ? 'WhatsApp your doctor directly.'
                                        : gate.message,
                                    color: const Color(0xFF1E2F2F),
                                    iconColor: Colors.green[400]!,
                                    onTap: () {
                                      guardAndRun(() async {
                                        String phoneNumber = doctor.phoneNumber
                                            .replaceAll(RegExp(r'[^\d+]'), '');
                                        if (!phoneNumber.startsWith('+')) {
                                          if (phoneNumber.startsWith('0')) {
                                            phoneNumber =
                                                '+263${phoneNumber.substring(1)}';
                                          } else {
                                            phoneNumber = '+263$phoneNumber';
                                          }
                                        }
                                        final Uri whatsappUri = Uri.parse(
                                          'https://wa.me/${phoneNumber.replaceAll('+', '')}',
                                        );
                                        if (await canLaunchUrl(whatsappUri)) {
                                          await launchUrl(
                                            whatsappUri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } else {
                                          throw 'Could not launch WhatsApp';
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildCommunicationItem(
                                    icon: Icons.call_outlined,
                                    title: 'Call Doctor',
                                    subtitle: gate.canCommunicate
                                        ? 'Call your doctor directly.'
                                        : gate.message,
                                    color: const Color(0xFF1E2832),
                                    iconColor: Colors.blue[300]!,
                                    onTap: () {
                                      guardAndRun(() async {
                                        final Uri telUri = Uri(
                                          scheme: 'tel',
                                          path: doctor.phoneNumber,
                                        );
                                        if (await canLaunchUrl(telUri)) {
                                          await launchUrl(
                                            telUri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } else {
                                          throw 'Could not launch dialer';
                                        }
                                      });
                                    },
                                  ),
                                  if (gate.reschedulableBooking != null) ...[
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showRescheduleDialog(
                                          context,
                                          booking: gate.reschedulableBooking!,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Color(0xFF57E659),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.schedule,
                                          color: Color(0xFF57E659),
                                        ),
                                        label: Text(
                                          'Reschedule Appointment',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF57E659),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
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
    final upcomingDates = DateUtilsX.upcomingIsoDates(doctor.availableDates);

    if (upcomingDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No upcoming dates available for this doctor.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final doctorService = DoctorService();

    Future<List<String>> loadAvailableSlots(String date) async {
      final slots = doctor.availabilitySlots[date] ?? [];
      final results = await Future.wait(
        slots.map((slot) async {
          final isBooked = await doctorService.isSlotBooked(
            doctor.id,
            date,
            slot,
          );
          return isBooked ? null : slot;
        }),
      );
      return results.whereType<String>().toList();
    }

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F141D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        String selectedDate = upcomingDates.first;
        String? selectedSlot;
        Future<List<String>> availableSlotsFuture = loadAvailableSlots(
          selectedDate,
        );

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Book Appointment',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose your preferred time slot',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF57E659),
                          backgroundImage: doctor.image.isNotEmpty
                              ? NetworkImage(doctor.image)
                              : null,
                          child: doctor.image.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.black,
                                  size: 28,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor.name,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                doctor.specialty,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF57E659),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Select Date',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: upcomingDates.length,
                      itemBuilder: (context, index) {
                        final date = upcomingDates[index];
                        final dt = DateTime.parse(date);
                        final isSelected = selectedDate == date;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDate = date;
                              selectedSlot = null;
                              availableSlotsFuture = loadAvailableSlots(date);
                            });
                          },
                          child: Container(
                            width: 88,
                            margin: EdgeInsets.only(
                              right: index == upcomingDates.length - 1 ? 0 : 12,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF57E659)
                                  : const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF57E659)
                                    : Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('E').format(dt),
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat('d').format(dt),
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('MMM').format(dt),
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Available Time Slots',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<String>>(
                    future: availableSlotsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(
                              color: Color(0xFF57E659),
                            ),
                          ),
                        );
                      }
                      final slots = snapshot.data ?? [];
                      if (slots.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No available slots for this date.',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: slots.map((slot) {
                          final isChosen = slot == selectedSlot;
                          return GestureDetector(
                            onTap: () => setState(() => selectedSlot = slot),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isChosen
                                    ? const Color(0xFF57E659)
                                    : const Color(0xFF111827),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isChosen
                                      ? const Color(0xFF57E659)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Text(
                                slot,
                                style: GoogleFonts.inter(
                                  color: isChosen ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedSlot == null
                          ? null
                          : () {
                              Navigator.pop(sheetContext, {
                                'date': selectedDate,
                                'slot': selectedSlot!,
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedSlot == null
                            ? Colors.white12
                            : const Color(0xFF57E659),
                        foregroundColor: selectedSlot == null
                            ? Colors.white54
                            : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        'Confirm Slot',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    final selectedDate = result['date'];
    final selectedSlot = result['slot'];
    if (selectedDate == null || selectedSlot == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to book an appointment')),
        );
      }
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _BookingReasonDialog(),
    );

    if (reason == null || reason.trim().isEmpty) return;

    final paymentResult = await _showPaymentModal(
      context,
      doctor.fee.toDouble(),
      user,
    );

    if (paymentResult != null && paymentResult['success'] == true) {
      final booking = Booking(
        id: '',
        doctorId: doctor.id,
        patientId: user.uid,
        patientName:
            user.displayName ?? user.email?.split('@').first ?? 'Patient',
        reason: reason.trim(),
        date: selectedDate,
        time: selectedSlot,
        status: 'pending',
        paymentStatus: 'paid',
        transactionRef: paymentResult['reference'],
        amount: doctor.fee.toDouble(),
        createdAt: DateTime.now(),
      );

      try {
        await doctorService.createBookingAtomic(booking);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Booking created! Awaiting doctor confirmation. Payment successful.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          await _promptWhatsAppNotifyDoctor(context, booking: booking);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().contains('already been booked')
                    ? 'This slot was just taken by another patient. Please contact support if you were charged.'
                    : 'Error saving booking: $e',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else if (paymentResult != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paymentResult['message'] ?? 'Payment failed or cancelled',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRescheduleDialog(
    BuildContext context, {
    required Booking booking,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first.')));
      return;
    }

    final currentWindow = DateUtilsX.tryParseAppointmentWindow(
      booking.date,
      booking.time,
    );
    if (currentWindow != null &&
        !DateTime.now().isBefore(currentWindow.start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can only reschedule before the appointment starts.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final upcomingDates = DateUtilsX.upcomingIsoDates(doctor.availableDates);
    if (upcomingDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No upcoming dates available for this doctor.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedDate;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            'Reschedule: Select Date',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: upcomingDates.length,
              itemBuilder: (context, index) {
                final date = upcomingDates[index];
                final isCurrent = date == booking.date;
                return ListTile(
                  title: Text(
                    DateFormat(
                      'EEEE, dd MMM yyyy',
                    ).format(DateTime.parse(date)),
                    style: TextStyle(
                      color: isCurrent ? const Color(0xFF57E659) : Colors.white,
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle: isCurrent
                      ? Text(
                          'Current date',
                          style: GoogleFonts.inter(color: Colors.grey[400]),
                        )
                      : null,
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

    if (selectedDate == null) return;
    if (DateUtilsX.isPastDate(selectedDate!)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That date has already passed. Pick another date.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final availableSlots = doctor.availabilitySlots[selectedDate] ?? [];
    if (availableSlots.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No time slots available for this date.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedSlot;
    final doctorService = DoctorService();

    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              'Reschedule: Select Time Slot',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<String>>(
                future:
                    Future.wait(
                      availableSlots.map((slot) async {
                        final isCurrent =
                            selectedDate == booking.date &&
                            slot == booking.time;
                        if (isCurrent) return slot;
                        final isBooked = await doctorService.isSlotBooked(
                          doctor.id,
                          selectedDate!,
                          slot,
                        );
                        return isBooked ? '' : slot;
                      }),
                    ).then(
                      (results) => results.where((s) => s.isNotEmpty).toList(),
                    ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF57E659),
                      ),
                    );
                  }
                  final freeSlots = snapshot.data ?? [];
                  if (freeSlots.isEmpty) {
                    return const Text(
                      'All slots are fully booked for this date.',
                      style: TextStyle(color: Colors.grey),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: freeSlots.length,
                    itemBuilder: (context, index) {
                      final slot = freeSlots[index];
                      final isCurrent =
                          selectedDate == booking.date && slot == booking.time;
                      return ListTile(
                        title: Text(
                          slot,
                          style: TextStyle(
                            color: isCurrent
                                ? const Color(0xFF57E659)
                                : Colors.white,
                            fontWeight: isCurrent
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: isCurrent
                            ? Text(
                                'Current time',
                                style: GoogleFonts.inter(
                                  color: Colors.grey[400],
                                ),
                              )
                            : null,
                        onTap: () {
                          selectedSlot = slot;
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    }

    if (selectedSlot == null) return;
    if (selectedDate == booking.date && selectedSlot == booking.time) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes selected.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await doctorService.rescheduleBookingAtomic(
        bookingId: booking.id,
        newDate: selectedDate!,
        newTime: selectedSlot!,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reschedule requested. Awaiting doctor confirmation for the new slot.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reschedule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _showPaymentModal(
    BuildContext context,
    double amount,
    User user,
  ) {
    String selectedProvider = 'PZW201'; // Default to Ecocash
    final phoneController = TextEditingController(text: '+263');
    bool isPaying = false;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Payment Details',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Amount: \$${amount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          color: const Color(0xFF57E659),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Select Mobile Money Provider',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildProviderOption(
                            'Ecocash',
                            'PZW201',
                            selectedProvider,
                            (val) =>
                                setModalState(() => selectedProvider = val),
                          ),
                          const SizedBox(width: 12),
                          _buildProviderOption(
                            'OneMoney',
                            'PZW202',
                            selectedProvider,
                            (val) =>
                                setModalState(() => selectedProvider = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Phone Number',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: phoneController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. 0771234567',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isPaying
                              ? null
                              : () async {
                                  setModalState(() => isPaying = true);
                                  try {
                                    final paymentService = PaymentService();
                                    final String txRef =
                                        'TXN_${DateTime.now().millisecondsSinceEpoch}';

                                    final response = await paymentService
                                        .initiateMobileMoneyPayment(
                                          amount: amount,
                                          currencyCode: 'USD',
                                          transactionDescription:
                                              'Doctor Consultation Fee',
                                          transactionReference: txRef,
                                          customerName:
                                              user.displayName ??
                                              user.email?.split('@').first ??
                                              'Patient',
                                          customerEmail: user.email ?? '',
                                          customerPhone: phoneController.text,
                                          paymentMethodCode: selectedProvider,
                                        );

                                    if (response.referenceNumber.isNotEmpty) {
                                      // In real scenario, we might poll for status here or wait for push notification
                                      if (context.mounted) {
                                        Navigator.pop(context, {
                                          'success': true,
                                          'reference': response.referenceNumber,
                                        });
                                      }
                                    } else {
                                      setModalState(() => isPaying = false);
                                      if (context.mounted) {
                                        _showErrorDialog(
                                          context,
                                          'Payment initialization failed. Please try again or contact support.',
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    setModalState(() => isPaying = false);
                                    if (context.mounted) {
                                      _showErrorDialog(
                                        context,
                                        'A payment error occurred: ${e.toString().replaceAll('Exception: ', '')}',
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF57E659),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isPaying
                              ? const CircularProgressIndicator(
                                  color: Colors.black,
                                )
                              : Text(
                                  'Pay Now',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context, {
                              'success': true,
                              'reference':
                                  'TEST_REF_${DateTime.now().millisecondsSinceEpoch}',
                            });
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey[800]!),
                            ),
                          ),
                          child: Text(
                            'Skip Payment (Testing Only)',
                            style: GoogleFonts.inter(
                              color: Colors.grey[400],
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProviderOption(
    String name,
    String code,
    String selected,
    Function(String) onSelect,
  ) {
    bool isSelected = selected == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF57E659).withOpacity(0.1)
                : const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF57E659) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              name,
              style: GoogleFonts.inter(
                color: isSelected ? const Color(0xFF57E659) : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Text(
                'Payment Failed',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(color: Colors.grey[400], height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CLOSE',
                style: GoogleFonts.inter(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF57E659),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'RETRY',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CommunicationGate {
  final bool canCommunicate;
  final String message;
  final Booking? activeBooking;
  final Booking? reschedulableBooking;

  const _CommunicationGate({
    required this.canCommunicate,
    required this.message,
    required this.activeBooking,
    required this.reschedulableBooking,
  });
}

class _BookingReasonDialog extends StatefulWidget {
  const _BookingReasonDialog();

  @override
  State<_BookingReasonDialog> createState() => _BookingReasonDialogState();
}

class _BookingReasonDialogState extends State<_BookingReasonDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        'Reason for booking',
        style: GoogleFonts.inter(color: Colors.white),
      ),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'e.g. Headache for 3 days...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          errorText: _errorText,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[800]!),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF57E659)),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            final trimmed = _controller.text.trim();
            if (trimmed.isEmpty) {
              setState(() => _errorText = 'Reason is required');
              return;
            }
            Navigator.pop(context, trimmed);
          },
          child: const Text(
            'Continue',
            style: TextStyle(color: Color(0xFF57E659)),
          ),
        ),
      ],
    );
  }
}
