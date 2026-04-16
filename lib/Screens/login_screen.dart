import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:zimdoctors/Screens/home_screen.dart';
import 'package:zimdoctors/Screens/doctor_dashboard_screen.dart';
import 'package:zimdoctors/Screens/registration_screen.dart';
import 'package:zimdoctors/reusableWidgets/reusableTextField.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  static String id = 'login_Screen';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  bool isDoctor = false;
  bool rememberMe = false;
  bool isLoading = false;
  String email = '';
  String password = '';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  void _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('userEmail');
    if (savedEmail != null) {
      setState(() {
        email = savedEmail;
        _emailController.text = savedEmail;
        rememberMe = true;
      });
    }
  }

  void _saveUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('userEmail', email);
    } else {
      await prefs.remove('userEmail');
    }
  }

  void _showForgotPasswordDialog() {
    String resetEmail = email;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            'Reset Password',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          content: TextField(
            onChanged: (value) => resetEmail = value,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(color: Colors.grey[600]),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[600]!),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF57E659)),
              ),
            ),
            controller: TextEditingController(text: resetEmail),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.grey[400]),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                if (resetEmail.isEmpty) return;
                try {
                  await _auth.sendPasswordResetEmail(email: resetEmail);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Password reset email sent!',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString(),
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Send',
                style: GoogleFonts.inter(color: const Color(0xFF57E659)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (notification) {
            notification.disallowIndicator();
            return true;
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFF57E659),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.black,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zim Doctors',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Healthcare at your fingertips',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  'Welcome Back',
                  style: GoogleFonts.inter(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in as a ${isDoctor ? 'Doctor' : 'User'} to continue.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 40),

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

                // Fields
                buildLabel('Email'),
                buildTextField(
                  controller: _emailController,
                  onChanged: (value) {
                    email = value;
                  },
                  hint: 'example@email.com',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 20),

                buildLabel('Password'),
                buildTextField(
                  controller: _passwordController,
                  onChanged: (value) {
                    password = value;
                  },
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 16),

                // Remember Me & Forgot Password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Theme(
                            data: ThemeData(
                              unselectedWidgetColor: Colors.grey[600],
                            ),
                            child: Checkbox(
                              value: rememberMe,
                              onChanged: (v) => setState(() => rememberMe = v!),
                              activeColor: const Color(0xFF57E659),
                              checkColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF57E659),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _showForgotPasswordDialog,
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.inter(
                          color: Colors.red[400],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        isLoading = true;
                      });
                      try {
                        final credential = await _auth
                            .signInWithEmailAndPassword(
                              email: email,
                              password: password,
                            );
                        if (credential.user != null) {
                          _saveUserEmail();
                          if (isDoctor) {
                            Navigator.pushNamed(
                              context,
                              DoctorDashboardScreen.id,
                            );
                          } else {
                            Navigator.pushNamed(context, Homescreen.id);
                          }
                        }
                      } catch (e) {
                        print(e);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString(),
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF57E659),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            'Sign In',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[800])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Or Sign In With',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[800])),
                  ],
                ),
                const SizedBox(height: 24),

                // Social Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              FontAwesomeIcons.google,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Google',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              FontAwesomeIcons.facebookF,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Facebook',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Footer
                Center(
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, RegistrationScreen.id),
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign up',
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
      ),
    );
  }
}
