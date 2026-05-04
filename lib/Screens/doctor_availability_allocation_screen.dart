import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/services/doctor_service.dart';
import 'package:zimdoctors/utils/date_utils.dart';

class DoctorAvailabilityAllocationScreen extends StatefulWidget {
  static const String id = '/doctor_availability_allocation_screen';

  const DoctorAvailabilityAllocationScreen({super.key});

  @override
  State<DoctorAvailabilityAllocationScreen> createState() =>
      _DoctorAvailabilityAllocationScreenState();
}

class _DoctorAvailabilityAllocationScreenState
    extends State<DoctorAvailabilityAllocationScreen> {
  final _doctorService = DoctorService();

  Doctor? _doctor;
  bool _isLoading = true;
  bool _isSaving = false;

  List<String> _tempAvailableDates = [];
  Map<String, List<String>> _tempAvailabilitySlots = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final doctor = await _doctorService.getCurrentDoctor();
    if (!mounted) return;

    setState(() {
      _doctor = doctor;
      _tempAvailableDates = List<String>.from(doctor?.availableDates ?? []);
      _tempAvailabilitySlots = Map<String, List<String>>.fromEntries(
        (doctor?.availabilitySlots ?? {}).entries.map(
          (e) => MapEntry(e.key, List<String>.from(e.value)),
        ),
      );
      _isLoading = false;
    });
  }

  void _purgePastAvailability() {
    final upcomingDates = DateUtilsX.upcomingIsoDates(_tempAvailableDates);
    final keep = upcomingDates.toSet();
    _tempAvailableDates = upcomingDates;
    _tempAvailabilitySlots.removeWhere((key, _) => !keep.contains(key));
  }

  Future<void> _showSlotsDialog(String date) async {
    final allSlots = <String>[
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

  Future<void> _pickDateAndAdd() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (pickedDate == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
    if (_tempAvailableDates.contains(formattedDate)) return;

    setState(() {
      _tempAvailableDates.add(formattedDate);
      _tempAvailabilitySlots[formattedDate] = [];
    });
    await _showSlotsDialog(formattedDate);
  }

  Future<void> _save() async {
    final doctor = _doctor;
    if (doctor == null) return;

    setState(() => _isSaving = true);
    try {
      _purgePastAvailability();

      final updatedDoctor = Doctor(
        id: doctor.id,
        name: doctor.name,
        registrationNumber: doctor.registrationNumber,
        specialty: doctor.specialty,
        rating: doctor.rating,
        image: doctor.image,
        experience: doctor.experience,
        patients: doctor.patients,
        fee: doctor.fee,
        followUp: doctor.followUp,
        code: doctor.code,
        joined: doctor.joined,
        location: doctor.location,
        surgeryLocation: doctor.surgeryLocation,
        phoneNumber: doctor.phoneNumber,
        description: doctor.description,
        availableDates: List<String>.from(_tempAvailableDates),
        availabilitySlots: Map<String, List<String>>.fromEntries(
          _tempAvailabilitySlots.entries.map(
            (e) => MapEntry(e.key, List<String>.from(e.value)),
          ),
        ),
        isVerified: doctor.isVerified,
        verifiedAt: doctor.verifiedAt,
        verificationProvider: doctor.verificationProvider,
        verificationUrl: doctor.verificationUrl,
      );

      await _doctorService.updateDoctor(updatedDoctor);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocation of Dates & Slots'),
        backgroundColor: const Color(0xFF0E0F0F),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _doctor == null
              ? Center(
                  child: Text(
                    'Doctor profile not found',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Dates & Slots',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._tempAvailableDates.map(
                            (date) => InputChip(
                              label: Text(
                                '$date (${_tempAvailabilitySlots[date]?.length ?? 0} slots)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: DateUtilsX.isPastDate(date)
                                  ? null
                                  : () => _showSlotsDialog(date),
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
                            label: const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.black,
                            ),
                            onPressed: _pickDateAndAdd,
                            backgroundColor: const Color(0xFF57E659),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF57E659),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

