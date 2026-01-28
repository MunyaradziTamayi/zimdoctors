import 'package:flutter/material.dart';

class reusableElevatedBtn extends StatelessWidget {

  reusableElevatedBtn({required this.btntext});

  final String btntext;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      onPressed: () {},
      child: Text(btntext),
    );
  }
}
