import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schedule.dart';
import 'attendance.dart';
import 'statsPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = '';
  String userGmail = '';
  String userCourse = '';

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? '';
      userGmail = prefs.getString('userGmail') ?? '';
      userCourse = prefs.getString('userCourse') ?? '';
    });
  }

  void _showFancyProfileDialog() {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFb3e5fc),
                    child: Icon(Icons.person, size: 50, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  _profileDetail(Icons.email, userGmail),
                  const SizedBox(height: 8),
                  _profileDetail(Icons.school, userCourse),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFb3e5fc),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _profileDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _triggerAttendanceSummaryAndNavigate() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AttendancePage(triggerSave: true),
      ),
    );

    if (updated == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StatsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFb3e5fc),
        elevation: 2,
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Colors.black54),
          ),
          onPressed: _showFancyProfileDialog,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.black87),
            onPressed: _triggerAttendanceSummaryAndNavigate,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttendancePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TimetableGridPage()),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Welcome to Attendance Tracker!',
          style: TextStyle(fontSize: 18, color: Colors.black87),
        ),
      ),
    );
  }
}