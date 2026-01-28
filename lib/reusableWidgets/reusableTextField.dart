import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget buildTextField({
  required ValueChanged<String> onChanged,
  required String hint,
  required IconData icon,
 

  bool obscureText = false,
}) {
  return TextField(
    onChanged: onChanged,
    obscureText: obscureText,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );
}

Widget buildLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    ),
  );
}
