import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'registration.dart';
import 'homepage.dart';
import 'session.dart';
import 'notifications.dart';
import 'splashScreen.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  await NotificationService.init();
  await NotificationService.requestNotificationPermissions();
  await NotificationService.requestBackgroundExecutionPermission();
  await scheduleDailyNotificationTask();
  runApp(
    Phoenix(
      child: const AttendanceTrackerApp(),
    ),
  );
}

class AttendanceTrackerApp extends StatelessWidget {
  const AttendanceTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Tracker',
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SessionChecker extends StatefulWidget {
  const SessionChecker({Key? key}) : super(key: key);

  @override
  State<SessionChecker> createState() => _SessionCheckerState();
}

class _SessionCheckerState extends State<SessionChecker> {
  String? userEmail;

  @override
  void initState() {
    super.initState();
    checkSession();
  }

  Future<void> checkSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userGmail');
    });

    bool isSetupDone = prefs.getBool('sessionSetupComplete') ?? false;

    if (userEmail != null && userEmail!.isNotEmpty) {
      if (isSetupDone) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SessionPage()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistrationPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}