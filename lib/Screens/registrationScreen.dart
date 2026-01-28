import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zimdoctors/Screens/loginScreen.dart';
import 'package:zimdoctors/reusableWidgets/reusableTextField.dart';

class RegistrationScreen extends StatefulWidget {
  static String id = 'registration_screen';
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late String fullName;
  late String email;
  late String password;
  late String specialization;
  String phoneNumber="";
  bool isDoctor = false;
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign up as a ${isDoctor ? 'Doctor' : 'User'} to get started.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 32),

              // Role Toggle
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isDoctor = false),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !isDoctor
                                ? const Color(0xFF57E659)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'User',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: !isDoctor ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isDoctor = true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDoctor
                                ? const Color(0xFF57E659)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Doctor',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: isDoctor ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Image Picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF1E1E1E),
                        backgroundImage: _image != null
                            ? FileImage(_image!)
                            : null,
                        child: _image == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF57E659),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Fields
              buildLabel('Full Name'),
              buildTextField(
                onChanged: (value) {
                  fullName = value;
                },
                hint: 'Munyaradzi Tamayi',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 20),

              buildLabel('Email'),
              buildTextField(
                onChanged: (value) {
                  email = value;
                },
                hint: 'example@email.com',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 20),

              buildLabel('Phone Number'),
              buildTextField(
                onChanged: (value) {
                  phoneNumber = value;
                },
                hint: '+263 ...',
                icon: Icons.phone_outlined, 
              ),
              const SizedBox(height: 20),

              if (isDoctor) ...[
                buildLabel('Specialization'),
                buildTextField(
                  onChanged: (value) {
                    specialization = value;
                  },
                  hint: 'Cardiologist',
                  icon: Icons.medical_services_outlined,
                ),
                const SizedBox(height: 20),
              ],

              buildLabel('Password'),
              buildTextField(
                onChanged: (value) {
                  password = value;
                },
                hint: 'Create a password',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 32),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    print('email :$email');
                    print('phone :$phoneNumber');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF57E659),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, LoginScreen.id),
                  child: RichText(
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF57E659),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
