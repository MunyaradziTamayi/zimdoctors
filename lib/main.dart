import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zimdoctors/Screens/ai_chat_screen.dart';
import 'package:zimdoctors/Screens/home_screen.dart';
import 'package:zimdoctors/Screens/login_screen.dart';
import 'package:zimdoctors/Screens/registration_screen.dart';
import 'package:zimdoctors/Screens/doctors_screen.dart';
import 'package:zimdoctors/Screens/profile_screen.dart';
import 'package:zimdoctors/widgets/add_doctor_form.dart';
import 'package:zimdoctors/Screens/welcome_screen.dart';
import 'package:zimdoctors/Screens/doctor_detail_screen.dart';
import 'package:zimdoctors/Screens/doctor_dashboard_screen.dart';
import 'package:zimdoctors/Screens/doctor_availability_allocation_screen.dart';
import 'package:zimdoctors/Screens/mdpcz_registry_sync_debug_screen.dart';
import 'package:zimdoctors/models/doctor.dart';
import 'package:zimdoctors/constants.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // ignore: avoid_print
    print('Warning: failed to load .env: $e');
  }
  await Firebase.initializeApp();
  runApp(const zimdoctors());
}

class zimdoctors extends StatelessWidget {
  const zimdoctors({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zim Doctors',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.primary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: AppColors.textSecondary.withAlpha(128)),
        ),
      ),
      initialRoute: Welcomescreen.id,
      routes: {
        Homescreen.id: (context) => const Homescreen(),
        LoginScreen.id: (context) => const LoginScreen(),
        RegistrationScreen.id: (context) => const RegistrationScreen(),
        DoctorsScreen.id: (context) => const DoctorsScreen(),
        ChatScreen.id: (context) => const ChatScreen(),
        Welcomescreen.id: (context) => const Welcomescreen(),
        DoctorDashboardScreen.id: (context) => const DoctorDashboardScreen(),
        DoctorAvailabilityAllocationScreen.id: (context) =>
            const DoctorAvailabilityAllocationScreen(),
        DoctorDetailScreen.id: (context) {
          final doctor = ModalRoute.of(context)!.settings.arguments as Doctor;
          return DoctorDetailScreen(doctor: doctor);
        },
        AddDoctorForm.id: (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return AddDoctorForm(
            email: args['email'],
            password: args['password'],
            name: args['name'],
            phone: args['phone'],
            specialty: args['specialty'],
            registrationNumber: args['registrationNumber'],
            imagePath: args['imagePath'],
          );
        },
        ProfileScreen.id: (context) => const ProfileScreen(),
        MdpczRegistrySyncDebugScreen.id: (context) =>
            const MdpczRegistrySyncDebugScreen(),
      },
    );
  }
}
