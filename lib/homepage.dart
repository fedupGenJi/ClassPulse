import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schedule.dart';
import 'weeklyStats.dart';
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

  Map<String, String> todayAttendance = {};
  List<Map<String, dynamic>> todayClasses = [];
  List<Map<String, dynamic>> extraClasses = [];

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _loadTodaySchedule();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? '';
      userGmail = prefs.getString('userGmail') ?? '';
      userCourse = prefs.getString('userCourse') ?? '';
    });
  }

  Future<void> _loadTodaySchedule() async {
    final data = await fetchTodayClassesForHomePage();
    setState(() {
      todayClasses = data['classes'] ?? [];
      extraClasses = data['extras'] ?? [];
      todayAttendance = data['attendance'] ?? {};
      if (data['isYippee'] == true) {
        todayClasses = [
          {'class': 'YIPPEE! Enjoy your free day 🎉', 'start': '', 'end': ''},
        ];
      }
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

  Widget _buildTodayCard(
    String title,
    String time,
    String status, {
    bool isExtra = false,
  }) {
    if (title.startsWith("YIPPEE!")) {
      double screenWidth = MediaQuery.of(context).size.width;
      return Container(
        width: screenWidth - 24,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber[100],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isExtra)
            const Text(
              "Extra Class",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(time, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            "Status: $status",
            style: TextStyle(
              color:
                  status == 'Present'
                      ? Colors.green
                      : status == 'Absent'
                      ? Colors.red
                      : Colors.grey,
            ),
          ),
        ],
      ),
    );
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
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WeeklyStatsPage()),
                ),
            icon: const Icon(Icons.timeline),
            tooltip: 'View Weekly Stats',
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.check_circle_outline, color: Colors.black87),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AttendancePage()),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodaySchedule,
        child: ListView(
          padding: const EdgeInsets.all(12.0),
          children: [
            const Text(
              "Today’s Classes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...todayClasses.map(
                    (cls) => _buildTodayCard(
                      cls['class'],
                      "${cls['start']} - ${cls['end']}",
                      todayAttendance[cls['start']] ?? 'Unmarked',
                    ),
                  ),
                  ...extraClasses.map(
                    (cls) => _buildTodayCard(
                      cls['name'],
                      "${cls['start']} - ${cls['end']}",
                      todayAttendance["extra_${cls['start']}"] ?? 'Unmarked',
                      isExtra: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Welcome to Attendance Tracker!',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}