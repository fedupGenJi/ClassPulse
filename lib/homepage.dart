import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schedule.dart';
import 'weeklyStats.dart';
import 'attendance.dart';
import 'statsPage.dart';
import 'history.dart';
import 'dart:convert';

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
  Map<String, dynamic> attendanceSummary = {};

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

  String normalizeName(String name) {
    return name.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  Future<void> _loadTodaySchedule() async {
    final data = await fetchTodayClassesForHomePage();
    final prefs = await SharedPreferences.getInstance();
    final summaryStr = prefs.getString('attendanceSummary') ?? '{}';

    setState(() {
      todayClasses = data['classes'] ?? [];
      extraClasses = data['extras'] ?? [];
      todayAttendance = data['attendance'] ?? {};
      attendanceSummary = jsonDecode(summaryStr);
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
            icon: const Icon(Icons.help_outline),
            tooltip: 'View Schedule History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TimetableHistoryPage(),
                ),
              );
            },
          ),
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
                  ...todayClasses.map((cls) {
                    final title = cls['class'];
                    final startTime = cls['start'];
                    final status = todayAttendance[startTime] ?? 'Unmarked';

                    double? percentage;
                    for (var entry in attendanceSummary.entries) {
                      final stats = entry.value;
                      if ((stats['originalName'] ?? entry.key) == title) {
                        final present = stats['present'] ?? 0;
                        final total = stats['total'] ?? 0;
                        if (total > 0) percentage = present / total;
                        break;
                      }
                    }

                    return TodayClassCard(
                      title: title,
                      time: "${cls['start']} - ${cls['end']}",
                      status: status,
                      attendancePercentage: percentage,
                    );
                  }),
                  ...extraClasses.map((cls) {
                    String rawTitle = cls['name'];
                    String title = rawTitle;
                    double? percentage;

                    for (var entry in attendanceSummary.entries) {
                      final key = entry.key;
                      final stats = entry.value;
                      String normalizedKey = normalizeName(
                        stats['originalName'] ?? key,
                      );
                      if (normalizeName(rawTitle) == normalizedKey) {
                        title = stats['originalName'] ?? key;
                        final present = stats['present'] ?? 0;
                        final total = stats['total'] ?? 0;
                        if (total > 0) percentage = present / total;
                        break;
                      }
                    }

                    final startTime = "extra_${cls['start']}";
                    final status = todayAttendance[startTime] ?? 'Unmarked';

                    return TodayClassCard(
                      title: title,
                      time: "${cls['start']} - ${cls['end']}",
                      status: status,
                      isExtra: true,
                      attendancePercentage: percentage,
                    );
                  }),
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

class TodayClassCard extends StatefulWidget {
  final String title;
  final String time;
  final String status;
  final bool isExtra;
  final double? attendancePercentage;

  const TodayClassCard({
    super.key,
    required this.title,
    required this.time,
    required this.status,
    this.isExtra = false,
    this.attendancePercentage,
  });

  @override
  State<TodayClassCard> createState() => _TodayClassCardState();
}

class _TodayClassCardState extends State<TodayClassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String emoji;
    String tooltip;
    Gradient backgroundGradient;

    if (widget.attendancePercentage == null) {
      emoji = '❓';
      tooltip = "Attendance unknown";
      backgroundGradient = const RadialGradient(
        center: Alignment.bottomCenter,
        radius: 1.2,
        colors: [
          Color.fromARGB(255, 194, 201, 186),
          Color.fromARGB(255, 130, 118, 102),
        ],
      );
    } else if (widget.attendancePercentage! >= 0.8) {
      emoji = '😎';
      tooltip = "You are doing great!";
      backgroundGradient = const RadialGradient(
        center: Alignment.bottomCenter,
        radius: 1.2,
        colors: [
          Color.fromARGB(255, 194, 201, 186),
          Color.fromARGB(255, 104, 240, 14),
        ],
      );
    } else {
      emoji = '😰⚠️';
      tooltip = "Go to your classes";
      backgroundGradient = const RadialGradient(
        center: Alignment.bottomCenter,
        radius: 1.2,
        colors: [
          Color.fromARGB(255, 194, 201, 186),
          Color.fromARGB(255, 235, 252, 0),
        ],
      );
    }

    if (widget.title.startsWith("YIPPEE!")) {
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
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: backgroundGradient,
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
            if (widget.isExtra)
              const Text(
                "Extra Class",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(widget.time, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Status: ${widget.status}",
                  style: TextStyle(
                    color:
                        widget.status == 'Present'
                            ? Colors.green.shade900
                            : widget.status == 'Absent'
                            ? Colors.red.shade900
                            : Colors.grey.shade700,
                  ),
                ),
                Tooltip(
                  message: tooltip,
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}