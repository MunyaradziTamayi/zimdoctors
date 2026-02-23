import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zimdoctors/Screens/home_screen.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/services/doctor_service.dart';

class AddDoctorForm extends StatefulWidget {
  static String id = 'add_doctor_screen';
  final String? name;
  final String? phone;
  final String? specialty;
  final String? imagePath;
  final String email;
  final String password;

  const AddDoctorForm({
    super.key,
    required this.email,
    required this.password,
    this.name,
    this.phone,
    this.specialty,
    this.imagePath,
  });

  @override
  State<AddDoctorForm> createState() => _AddDoctorFormState();
}

class _AddDoctorFormState extends State<AddDoctorForm> {
  final _formKey = GlobalKey<FormState>();
  final _doctorService = DoctorService();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _specialtyController;
  final _ratingController = TextEditingController(text: '4.5');
  final _imageController = TextEditingController(); // For URL if needed
  final _locationController = TextEditingController();
  late TextEditingController _phoneController;
  final _experienceController = TextEditingController();
  final _patientsController = TextEditingController(text: '0');
  final _feeController = TextEditingController();
  final _followUpController = TextEditingController(text: '0');
  final _codeController = TextEditingController(); // Generated after auth
  final _joinedController = TextEditingController(
    text: DateTime.now().year.toString(),
  );
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name ?? '');
    _specialtyController = TextEditingController(text: widget.specialty ?? '');
    _phoneController = TextEditingController(text: widget.phone ?? '');
    _codeController.text = 'DOC...'; // Placeholder until auth
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Create User in Firebase Auth
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
        );

        final user = userCredential.user;
        if (user == null) throw Exception('Failed to create user');
        final uid = user.uid;

        // Update code with actual UID
        final docCode = 'DOC${uid.substring(0, 5).toUpperCase()}';

        String imageUrl = '';

        // 2. Upload image if path is provided
        if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
          imageUrl = await _doctorService.uploadProfileImage(
            File(widget.imagePath!),
            uid,
          );
        } else if (_imageController.text.isNotEmpty) {
          imageUrl = _imageController.text.trim();
        }

        // 3. Create Doctor in Firestore
        final newDoctor = Doctor(
          id: uid,
          name: _nameController.text.trim(),
          specialty: _specialtyController.text.trim(),
          rating: double.tryParse(_ratingController.text) ?? 0.0,
          image: imageUrl,
          location: _locationController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          experience: _experienceController.text.trim(),
          patients: int.tryParse(_patientsController.text) ?? 0,
          fee: int.tryParse(_feeController.text) ?? 0,
          followUp: int.tryParse(_followUpController.text) ?? 0,
          code: docCode,
          joined: _joinedController.text.trim(),
          description: _descriptionController.text.trim(),
          availableDates: [],
        );

        await _doctorService.createDoctor(newDoctor);

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Homescreen.id,
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Doctor profile created successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating profile: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _ratingController.dispose();
    _imageController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    _patientsController.dispose();
    _feeController.dispose();
    _followUpController.dispose();
    _codeController.dispose();
    _joinedController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Complete Profile',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Doctor',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                _buildTextField(label: 'Name', controller: _nameController),
                _buildTextField(
                  label: 'Specialty',
                  controller: _specialtyController,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Rating',
                        controller: _ratingController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        label: 'Code',
                        controller: _codeController,
                        readOnly: true, // Auto-generated
                      ),
                    ),
                  ],
                ),
                // Conditional Image Field
                if (widget.imagePath == null)
                  _buildTextField(
                    label: 'Image URL',
                    controller: _imageController,
                  ),

                _buildTextField(
                  label: 'Location',
                  controller: _locationController,
                ),
                _buildTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                _buildTextField(
                  label: 'Experience',
                  controller: _experienceController,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Fee',
                        controller: _feeController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        label: 'Follow Up (days)',
                        controller: _followUpController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                _buildTextField(
                  label: 'Description',
                  controller: _descriptionController,
                  maxLines: 3,
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF57E659),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'Complete Registration',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        style: const TextStyle(color: Colors.white),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF57E659)),
          ),
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
        ),
      ),
    );
  }
}
