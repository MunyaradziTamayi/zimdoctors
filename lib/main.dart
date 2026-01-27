import 'package:flutter/material.dart';
import 'package:zimdoctors/Screens/homeScreen.dart';
import 'package:zimdoctors/Screens/loginScreen.dart';
import 'package:zimdoctors/Screens/registrationScreen.dart';


void main() {
  runApp(const zimdoctors());
}

class zimdoctors extends StatelessWidget {
  const zimdoctors({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            color:Colors.white60
          )
        )
      ),
      initialRoute:RegistrationScreen.id,
      routes: {
          Homescreen.id : (context)=> Homescreen(),
          LoginScreen.id:(context)=>LoginScreen(),
          RegistrationScreen.id:(context)=>RegistrationScreen()
  
      },
    );
  }
}