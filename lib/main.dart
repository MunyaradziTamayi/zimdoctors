import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zimdoctors/Screens/ai_chat_screen.dart';
import 'package:zimdoctors/Screens/home_screen.dart';
import 'package:zimdoctors/Screens/login_screen.dart';
import 'package:zimdoctors/Screens/registration_screen.dart';
import 'package:zimdoctors/Screens/doctors_screen.dart';
import 'package:zimdoctors/widgets/add_doctor_form.dart';
import 'package:zimdoctors/Screens/welcome_screen.dart';
import 'package:zimdoctors/Screens/doctor_detail_screen.dart';
import 'package:zimdoctors/Screens/doctor_dashboard_screen.dart';
import 'package:zimdoctors/models/doctor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // Allow app to run even if .env isn't present (e.g. CI/build servers).
    // Still log so it's easier to debug "API key not configured" issues.
    // ignore: avoid_print
    print('Warning: failed to load .env: $e');
  }
  await Firebase.initializeApp();
  runApp(zimdoctors());
}

class zimdoctors extends StatelessWidget {
  const zimdoctors({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        textTheme: TextTheme(bodyMedium: TextStyle(color: Colors.white60)),
      ),
      initialRoute: Welcomescreen.id,
      routes: {
        Homescreen.id: (context) => Homescreen(),
        LoginScreen.id: (context) => LoginScreen(),
        RegistrationScreen.id: (context) => RegistrationScreen(),
        DoctorsScreen.id: (context) => DoctorsScreen(),
        ChatScreen.id: (context) => ChatScreen(),
        Welcomescreen.id: (context) => Welcomescreen(),
        DoctorDashboardScreen.id: (context) => DoctorDashboardScreen(),
        DoctorDetailScreen.id: (context) {
          final doctor = ModalRoute.of(context)!.settings.arguments as Doctor;
          return DoctorDetailScreen(doctor: doctor);
        },
        AddDoctorForm.id: (context) {
          // Extract arguments using ModalRoute
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
      },
    );
  }
}
