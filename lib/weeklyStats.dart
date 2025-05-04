import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WeeklyStatsPage extends StatefulWidget {
  const WeeklyStatsPage({super.key});

  @override
  State<WeeklyStatsPage> createState() => _WeeklyStatsPageState();
}

class _WeeklyStatsPageState extends State<WeeklyStatsPage> {
  List<Map<String, dynamic>> weeklyStats = [];

  @override
  void initState() {
    super.initState();
    loadWeeklyStats();
  }

  void _incrementSubject(
    Map<String, Map<String, int>> subjectStats,
    String subject,
    String status,
  ) {
    subjectStats.putIfAbsent(subject, () => {'total': 0, 'present': 0});
    if (status != 'Cancelled') {
      subjectStats[subject]!['total'] =
          (subjectStats[subject]!['total'] ?? 0) + 1;
    }
    if (status == 'Present') {
      subjectStats[subject]!['present'] =
          (subjectStats[subject]!['present'] ?? 0) + 1;
    }
  }

  Future<void> loadWeeklyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final attendanceStr = prefs.getString('attendanceLog') ?? '{}';
    final startStr = prefs.getString('semesterStartDate');
    if (startStr == null) return;

    final log = Map<String, dynamic>.from(jsonDecode(attendanceStr));
    final semesterStart = DateTime.parse(startStr);
    DateTime now = DateTime.now();

    final versionList = prefs.getString('timetableVersions');
    if (versionList == null) return;
    List<dynamic> versions = jsonDecode(versionList);
    versions.sort((a, b) => a['from'].compareTo(b['from']));

    DateTime weekStart = semesterStart;
    DateTime firstSaturday = semesterStart.add(
      Duration(days: 6 - semesterStart.weekday % 7),
    );
    DateTime weekEnd = firstSaturday;

    while (weekStart.isBefore(now.add(const Duration(days: 1)))) {
      Map<String, Map<String, int>> subjectStats = {};

      for (
        DateTime d = weekStart;
        d.isBefore(weekEnd.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))
      ) {
        Map<String, dynamic>? dayTimetable;
        for (final version in versions) {
          final fromDate = DateTime.parse(version['from']);
          if (d.isAfter(fromDate) || d.isAtSameMomentAs(fromDate)) {
            dayTimetable = version['data'];
          } else {
            break;
          }
        }
        if (dayTimetable == null) continue;

        final key = d.toIso8601String().split('T')[0];
        final entries = Map<String, dynamic>.from(log[key] ?? {});
        final extras = List<Map<String, dynamic>>.from(log['extra_$key'] ?? []);

        final dayName =
            [
              'Sunday',
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
            ][d.weekday % 7];
        final sessions = List<Map<String, dynamic>>.from(
          dayTimetable[dayName] ?? [],
        );

        final timeToName = {for (var s in sessions) s['start']: s['class']};

        for (var entry in entries.entries) {
          final time = entry.key;
          final value = entry.value;

          if (time.startsWith('extra_')) continue;

          String? originalName;
          String? status;

          if (value is String) {
            status = value;
            originalName = timeToName[time];
          } else if (value is Map) {
            status = value['status'];
            originalName = value['originalName'] ?? timeToName[time];
          }

          if (originalName != null && status != null) {
            _incrementSubject(subjectStats, originalName, status);
          }
        }

        for (var extra in extras) {
          final name = extra['name'];
          final start = extra['start'];
          final extraKey = 'extra_$start';
          final status = entries[extraKey];

          if (name != null && (status == 'Present' || status == 'Absent')) {
            _incrementSubject(subjectStats, name, status);
          }
        }
      }

      bool isCurrentWeek =
          now.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          now.isBefore(weekEnd.add(const Duration(days: 1)));

      setState(() {
        weeklyStats.add({
          'range':
              "${weekStart.toLocal().toString().split(" ")[0]} – ${weekEnd.toLocal().toString().split(" ")[0]}",
          'present': subjectStats.values.fold(
            0,
            (sum, v) => sum + (v['present'] ?? 0),
          ),
          'total': subjectStats.values.fold(
            0,
            (sum, v) => sum + (v['total'] ?? 0),
          ),
          'current': isCurrentWeek,
          'subjects': subjectStats,
        });
      });

      weekStart = weekEnd.add(const Duration(days: 1));
      weekEnd = weekStart.add(const Duration(days: 6));
      if (weekEnd.isAfter(now)) weekEnd = now;
      if (weekEnd.isBefore(weekStart)) break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Weekly Stats"),
        backgroundColor: const Color(0xFFb3e5fc),
      ),
      body:
          weeklyStats.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: weeklyStats.length,
                itemBuilder: (context, index) {
                  final week = weeklyStats[index];
                  final total = week['total'] ?? 0;
                  final present = week['present'] ?? 0;
                  final range = week['range'];
                  final isCurrent = week['current'] ?? false;
                  final subjectStats = week['subjects'] as Map<String, dynamic>;

                  final attendedTextStyle = TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: present == total ? Colors.green : Colors.grey[800],
                  );

                  return GestureDetector(
                    onTap:
                        total > 0
                            ? () {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (context) {
                                  return Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Container(
                                      width: 300,
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Week ${index + 1} Details',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            "$range",
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            "Subject-wise Attendance:",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...subjectStats.entries.map((entry) {
                                            final name = entry.key;
                                            final stats = entry.value;
                                            final present =
                                                stats['present'] ?? 0;
                                            final total = stats['total'] ?? 0;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      "$present/$total",
                                                      textAlign: TextAlign.left,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            (present == 0 &&
                                                                    total == 0)
                                                                ? Colors.grey
                                                                : (present ==
                                                                    total)
                                                                ? Colors.green
                                                                : Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                            : null,
                    child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.indigo,
                                  child: Text(
                                    "${index + 1}",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Week ${index + 1} ($range)",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isCurrent)
                                  const Icon(
                                    Icons.circle,
                                    color: Colors.green,
                                    size: 12,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (total == 0)
                              const Text(
                                "NO CLASSES this week",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Total Classes: $total",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Total Classes Attended: $present",
                                    style: attendedTextStyle,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}