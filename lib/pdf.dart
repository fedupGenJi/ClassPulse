import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> generateSemesterSummaryAndReset(BuildContext context) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("PDF summary generation coming soon..."),
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('sessionSetupComplete', false);
}