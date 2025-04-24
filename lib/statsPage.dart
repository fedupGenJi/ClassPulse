import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Map<String, dynamic> attendanceData = {};
  final List<Color> subjectColors = [
    Colors.blueAccent,
    Colors.deepPurple,
    Colors.teal,
    Colors.deepOrange,
    Colors.green,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.redAccent,
  ];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final summaryStr = prefs.getString('attendanceSummary') ?? '{}';
    final versionListStr = prefs.getString('timetableVersions');

    if (versionListStr == null) {
      setState(() {
        attendanceData = {};
      });
      return;
    }

    final summary = Map<String, dynamic>.from(jsonDecode(summaryStr));
    final versions = List<Map<String, dynamic>>.from(
      jsonDecode(versionListStr),
    );

    versions.sort(
      (a, b) => DateTime.parse(b['from']).compareTo(DateTime.parse(a['from'])),
    );
    final latestTimetable = versions.first['data'] as Map<String, dynamic>;

    final currentSubjects = <String>{};
    for (final day in latestTimetable.values) {
      for (final session in List<Map<String, dynamic>>.from(day)) {
        final subject = session['class'];
        if (subject != 'Break' && subject != 'YIPPEE') {
          currentSubjects.add(subject.toLowerCase().replaceAll(' ', ''));
        }
      }
    }

    summary.removeWhere((key, value) {
      final total = value['total'] ?? 0;
      final isInCurrentTimetable = currentSubjects.contains(key);
      return total == 0 && !isInCurrentTimetable;
    });

    setState(() {
      attendanceData = summary;
    });
  }

  Color getColorForIndex(int index) {
    return subjectColors[index % subjectColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      appBar: AppBar(
        title: const Text("📊 Attendance Summary"),
        backgroundColor: const Color(0xFFb3e5fc),
      ),
      body:
          attendanceData.isEmpty
              ? const Center(
                child: Text(
                  "No attendance data available yet!",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: attendanceData.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = attendanceData.entries.elementAt(index);
                  final subjectKey = entry.key;
                  final stats = entry.value;
                  final present = stats['present'] ?? 0;
                  final total = stats['total'] ?? 0;
                  final originalName = stats['originalName'] ?? subjectKey;
                  final percent =
                      total > 0
                          ? (present.toDouble() / total.toDouble())
                          : null;
                  final mainColor = getColorForIndex(index);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    startDegreeOffset: -90,
                                    centerSpaceRadius: 30,
                                    sectionsSpace: 0,
                                    sections:
                                        percent != null
                                            ? [
                                              PieChartSectionData(
                                                value: percent * 100,
                                                color: mainColor,
                                                radius: 40,
                                                showTitle: false,
                                              ),
                                              PieChartSectionData(
                                                value: 100.0 - (percent * 100),
                                                color: Colors.grey.shade300,
                                                radius: 40,
                                                showTitle: false,
                                              ),
                                            ]
                                            : [
                                              PieChartSectionData(
                                                value: 100,
                                                color: Colors.grey.shade200,
                                                radius: 40,
                                                showTitle: false,
                                              ),
                                            ],
                                  ),
                                  swapAnimationDuration: const Duration(
                                    milliseconds: 800,
                                  ),
                                  swapAnimationCurve: Curves.easeInOutCubic,
                                ),
                                Text(
                                  percent != null
                                      ? "${(percent * 100).toStringAsFixed(2)}%"
                                      : "X",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  originalName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: mainColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  total == 0
                                      ? "No classes scheduled yet."
                                      : "You were present in $present out of $total classes.",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}