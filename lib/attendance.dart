import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AttendancePage extends StatefulWidget {
  final bool triggerSave;

  const AttendancePage({super.key, this.triggerSave = false});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime selectedDate = DateTime.now();
  DateTime? semesterStart;
  Map<String, dynamic> todaySchedule = {};
  Map<String, String> attendance = {};
  Map<String, Map<String, int>> attendanceSummary = {};
  List<Map<String, dynamic>> extraClasses = [];
  String? activeVersionDateStr;

  @override
  void initState() {
    super.initState();
    loadDataForDate(selectedDate).then((_) {
      if (widget.triggerSave) {
        saveAttendanceForDate().then((_) {
          Navigator.pop(context, true);
        });
      }
    });
  }

  Future<void> loadDataForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final semesterStartStr = prefs.getString('semesterStartDate');
    final versionList = prefs.getString('timetableVersions');
    final attendanceStr = prefs.getString('attendanceLog') ?? '{}';

    if (semesterStartStr == null || versionList == null) return;

    semesterStart = DateTime.parse(semesterStartStr);
    if (date.isBefore(semesterStart!)) return;

    List<dynamic> versions = jsonDecode(versionList);
    versions.sort((a, b) => a['from'].compareTo(b['from']));

    Map<String, dynamic>? versionToUse;

    for (final version in versions) {
      final fromDate = DateTime.parse(version['from']);
      if (date.isAfter(fromDate) || date.isAtSameMomentAs(fromDate)) {
        versionToUse = version['data'];
        activeVersionDateStr = version['from'];
      } else {
        break;
      }
    }

    if (versionToUse == null) return;

    final currentDay =
        [
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ][date.weekday % 7];

    final dateKey = date.toIso8601String().split('T').first;
    final attendanceLog = Map<String, dynamic>.from(jsonDecode(attendanceStr));

    final extras = List<Map<String, dynamic>>.from(
      attendanceLog['extra_$dateKey'] ?? [],
    );

    final daySchedule = List<Map<String, dynamic>>.from(
      versionToUse[currentDay] ?? [],
    );

    final loadedAttendance = Map<String, String>.from(
      attendanceLog[dateKey] ?? {},
    );

    setState(() {
      todaySchedule = {'day': currentDay, 'classes': daySchedule};
      attendance = loadedAttendance;
      extraClasses = extras;
    });
    await purgeObsoleteAttendance();
  }

  Future<void> purgeObsoleteAttendance() async {
  final prefs = await SharedPreferences.getInstance();
  final dateKey = selectedDate.toIso8601String().split('T').first;
  final currentDay = todaySchedule['day'];
  final attendanceLogStr = prefs.getString('attendanceLog') ?? '{}';
  final summaryStr = prefs.getString('attendanceSummary') ?? '{}';

  final log = Map<String, dynamic>.from(jsonDecode(attendanceLogStr));
  final summary = Map<String, Map<String, dynamic>>.from(
    (jsonDecode(summaryStr) as Map).map(
      (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
    ),
  );

  for (final key in prefs.getKeys()) {
    if (!key.startsWith('removed_')) continue;

    final date = DateTime.parse(key.split('_')[1]);
    if (selectedDate.isBefore(date)) continue;

    final removed = prefs.getStringList(key) ?? [];
    for (final entry in removed) {
      final parts = entry.split('|');
      if (parts.length != 3) continue;

      final day = parts[0], time = parts[1], subject = parts[2];
      if (currentDay != day) continue;

      final actualKey = time;

      if (attendance.containsKey(actualKey)) {
        final status = attendance[actualKey];
        if (status != 'Cancelled') {
          final normalized = subject.toLowerCase().replaceAll(' ', '');
          summary[normalized] ??= {
            'originalName': subject,
            'total': 0,
            'present': 0,
          };
          summary[normalized]!['total'] = (summary[normalized]!['total'] ?? 1) - 1;
          if (status == 'Present') {
            summary[normalized]!['present'] = (summary[normalized]!['present'] ?? 1) - 1;
          }
        }

        attendance.remove(actualKey);
      }
    }
  }

  await prefs.setString('attendanceLog', jsonEncode(log));
  await prefs.setString('attendanceSummary', jsonEncode(summary));
}

  Future<void> saveAttendanceForDate() async {
    final prefs = await SharedPreferences.getInstance();
    final attendanceStr = prefs.getString('attendanceLog') ?? '{}';
    final attendanceLog = Map<String, dynamic>.from(jsonDecode(attendanceStr));

    final key = selectedDate.toIso8601String().split('T').first;
    attendanceLog[key] = attendance;
    attendanceLog['extra_$key'] = extraClasses;

    await prefs.setString('attendanceLog', jsonEncode(attendanceLog));
  }

  Future<void> markAttendance(String time, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final summaryStr = prefs.getString('attendanceSummary') ?? '{}';
    final summary = Map<String, Map<String, dynamic>>.from(
      (jsonDecode(summaryStr) as Map).map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
      ),
    );

    final isExtra = time.startsWith('extra_');
    final actualTime = isExtra ? time.substring(6) : time;

    final previousStatus = attendance[time];
    setState(() {
      attendance[time] = status;
    });

    final hasExtraAtSameTime = extraClasses.any(
      (e) => e['start'] == actualTime,
    );
    if (!isExtra && status == 'Cancelled' && hasExtraAtSameTime) {
      return;
    }

    final className = await _getClassNameForTime(
      selectedDate,
      actualTime,
      extraClasses,
    );
    if (className == null) return;

    final normalized = className.toLowerCase().replaceAll(' ', '');
    summary[normalized] ??= {
      'originalName': className,
      'total': 0,
      'present': 0,
    };

    if (previousStatus != null && previousStatus != 'Cancelled') {
      summary[normalized]!['total'] = (summary[normalized]!['total'] ?? 1) - 1;
      if (previousStatus == 'Present') {
        summary[normalized]!['present'] =
            (summary[normalized]!['present'] ?? 1) - 1;
      }
    }

    if (status != 'Cancelled') {
      summary[normalized]!['total'] = (summary[normalized]!['total'] ?? 0) + 1;
      if (status == 'Present') {
        summary[normalized]!['present'] =
            (summary[normalized]!['present'] ?? 0) + 1;
      }
    }

    await prefs.setString('attendanceSummary', jsonEncode(summary));
    saveAttendanceForDate();
  }

  Future<String?> _getClassNameForTime(
    DateTime date,
    String time,
    List<Map<String, dynamic>> extras,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final versionList = prefs.getString('timetableVersions');
    if (versionList == null) return null;

    List<dynamic> versions = jsonDecode(versionList);
    versions.sort((a, b) => a['from'].compareTo(b['from']));

    Map<String, dynamic>? selectedVersion;

    for (final version in versions) {
      final from = DateTime.parse(version['from']);
      if (date.isAfter(from) || date.isAtSameMomentAs(from)) {
        selectedVersion = version['data'];
      } else {
        break;
      }
    }

    if (selectedVersion == null) return null;
    final timetable = selectedVersion;

    final dayName =
        [
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ][date.weekday % 7];

    for (final extra in extras) {
      if (extra['start'] == time) return extra['name'];
    }

    for (final session in timetable[dayName] ?? []) {
      if (session['start'] == time) return session['class'];
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = selectedDate.toLocal().toString().split(" ")[0];
    final classes = todaySchedule['classes'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Attendance'),
        backgroundColor: const Color(0xFFb3e5fc),
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _pickDate),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExtraClassDialog,
        label: const Text("Extra Class"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.orangeAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body:
          classes.isEmpty && extraClasses.isEmpty
              ? Center(
                child: Text("📭 No classes for ${todaySchedule['day'] ?? ''}"),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "📅 Date: $dateStr",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (activeVersionDateStr != null)
                          Text(
                            "🗓️ Using schedule from: $activeVersionDateStr",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        ...classes.map(
                          (item) => _buildClassCard(
                            subject: item['class'],
                            time: "${item['start']} - ${item['end']}",
                            status: attendance[item['start']],
                            isBreak:
                                item['class'] == 'Break' ||
                                item['class'] == 'YIPPEE',
                            timeKey: item['start'],
                            allowCancelled: true,
                          ),
                        ),
                        ...extraClasses.map(
                          (item) => _buildClassCard(
                            subject: item['name'],
                            time: "${item['start']} - ${item['end']}",
                            status:
                                attendance["extra_${item['start']}"] ??
                                'Cancelled',
                            timeKey: "extra_${item['start']}",
                            isExtra: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: semesterStart ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      loadDataForDate(picked);
    }
  }

  Widget _buildClassCard({
    required String subject,
    required String time,
    required String? status,
    required String timeKey,
    bool isBreak = false,
    bool isExtra = false,
    bool allowCancelled = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: getCardColor(subject, status),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              isBreak
                  ? const Icon(Icons.free_breakfast)
                  : Icon(
                    getStatusIcon(status) ?? Icons.school_outlined,
                    color: Colors.black54,
                  ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subject,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isBreak ? Colors.deepPurple : Colors.black,
                  ),
                ),
              ),
              if (isExtra)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Extra Class",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final isExtra = timeKey.startsWith("extra_");
                        final actualTime =
                            isExtra
                                ? timeKey.replaceFirst('extra_', '')
                                : timeKey;

                        final className = await _getClassNameForTime(
                          selectedDate,
                          actualTime,
                          extraClasses,
                        );
                        if (className != null) {
                          final prefs = await SharedPreferences.getInstance();
                          final summaryStr =
                              prefs.getString('attendanceSummary') ?? '{}';
                          final summary =
                              Map<String, Map<String, dynamic>>.from(
                                (jsonDecode(summaryStr) as Map).map(
                                  (k, v) =>
                                      MapEntry(k, Map<String, dynamic>.from(v)),
                                ),
                              );
                          final normalized = className.toLowerCase().replaceAll(
                            ' ',
                            '',
                          );
                          if (attendance[timeKey] != 'Cancelled') {
                            summary[normalized]!['total'] -= 1;
                            if (attendance[timeKey] == 'Present') {
                              summary[normalized]!['present'] -= 1;
                            }
                          }
                          await prefs.setString(
                            'attendanceSummary',
                            jsonEncode(summary),
                          );
                        }

                        setState(() {
                          extraClasses.removeWhere(
                            (e) => e['start'] == actualTime,
                          );
                          attendance.remove(timeKey);
                        });
                        saveAttendanceForDate();
                      },
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text("⏰ $time", style: const TextStyle(color: Colors.black54)),
          if (!isBreak)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Wrap(
                spacing: 8,
                children:
                    (allowCancelled
                            ? ['Present', 'Absent', 'Cancelled']
                            : ['Present', 'Absent'])
                        .map((s) {
                          final hasExtraAtSameTime = extraClasses.any(
                            (e) => e['start'] == timeKey,
                          );
                          final isDisabled =
                              isBreak ||
                              (!isExtra &&
                                  attendance[timeKey] == 'Cancelled' &&
                                  hasExtraAtSameTime);
                          return ChoiceChip(
                            label: Text(s),
                            selected: status != null && status == s,
                            selectedColor: getCardColor(subject, s),
                            onSelected:
                                isDisabled
                                    ? null
                                    : (_) => markAttendance(timeKey, s),
                          );
                        })
                        .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Color getCardColor(String subject, String? status) {
    if (subject == 'Break') return Colors.amber[100]!;
    if (subject == 'YIPPEE') return Colors.purple[100]!;

    switch (status) {
      case 'Present':
        return Colors.green[100]!;
      case 'Absent':
        return Colors.red[100]!;
      case 'Cancelled':
        return Colors.grey[300]!;
      default:
        return Colors.white;
    }
  }

  IconData? getStatusIcon(String? status) {
    switch (status) {
      case 'Present':
        return Icons.check_circle;
      case 'Absent':
        return Icons.cancel;
      case 'Cancelled':
        return Icons.do_not_disturb;
      default:
        return null;
    }
  }

  Future<void> _addExtraClassDialog() async {
    final _nameController = TextEditingController();
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Extra Class"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Class Name"),
                  ),
                  const SizedBox(height: 8),
                  if (startTime != null)
                    Text("Picked Start Time: ${startTime!.format(context)}"),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 8, minute: 0),
                      );
                      if (picked != null) {
                        setDialogState(() => startTime = picked);
                      }
                    },
                    child: const Text("Pick Start Time"),
                  ),
                  const SizedBox(height: 8),
                  if (endTime != null)
                    Text("Picked End Time: ${endTime!.format(context)}"),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) {
                        setDialogState(() => endTime = picked);
                      }
                    },
                    child: const Text("Pick End Time"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty || startTime == null || endTime == null)
                      return;

                    if (name.toLowerCase() == 'break' ||
                        name.toLowerCase() == 'yippee') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "❌ 'Break' and 'YIPPEE' are not allowed as class names.",
                          ),
                        ),
                      );
                      return;
                    }

                    final newStart = startTime!;
                    final newEnd = endTime!;

                    if (newEnd.hour < newStart.hour ||
                        (newEnd.hour == newStart.hour &&
                            newEnd.minute <= newStart.minute)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("❌ End time must be after start time."),
                        ),
                      );
                      return;
                    }

                    bool conflicts = false;

                    for (var session in todaySchedule['classes']) {
                      final key = session['start'];
                      if (attendance[key] == 'Cancelled' ||
                          session['class'] == 'Break' ||
                          session['class'] == 'YIPPEE')
                        continue;

                      final existingStart = _parseTime(session['start']);
                      final existingEnd = _parseTime(session['end']);

                      final existingStartTime = DateTime(
                        0,
                        1,
                        1,
                        existingStart.hour,
                        existingStart.minute,
                      );
                      final existingEndTime = DateTime(
                        0,
                        1,
                        1,
                        existingEnd.hour,
                        existingEnd.minute,
                      );
                      final newStartTime = DateTime(
                        0,
                        1,
                        1,
                        newStart.hour,
                        newStart.minute,
                      );
                      final newEndTime = DateTime(
                        0,
                        1,
                        1,
                        newEnd.hour,
                        newEnd.minute,
                      );

                      if (newStartTime.isBefore(existingEndTime) &&
                          newEndTime.isAfter(existingStartTime)) {
                        conflicts = true;
                        break;
                      }
                    }

                    for (var extra in extraClasses) {
                      final existingStart = _parseTime(extra['start']);
                      final existingEnd = _parseTime(extra['end']);

                      final existingStartTime = DateTime(
                        0,
                        1,
                        1,
                        existingStart.hour,
                        existingStart.minute,
                      );
                      final existingEndTime = DateTime(
                        0,
                        1,
                        1,
                        existingEnd.hour,
                        existingEnd.minute,
                      );
                      final newStartTime = DateTime(
                        0,
                        1,
                        1,
                        newStart.hour,
                        newStart.minute,
                      );
                      final newEndTime = DateTime(
                        0,
                        1,
                        1,
                        newEnd.hour,
                        newEnd.minute,
                      );

                      if (newStartTime.isBefore(existingEndTime) &&
                          newEndTime.isAfter(existingStartTime)) {
                        conflicts = true;
                        break;
                      }
                    }

                    if (conflicts) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Time conflicts with existing non-cancelled class.",
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      final id =
                          "${newStart.hour.toString().padLeft(2, '0')}:${newStart.minute.toString().padLeft(2, '0')}";
                      final endId =
                          "${newEnd.hour.toString().padLeft(2, '0')}:${newEnd.minute.toString().padLeft(2, '0')}";
                      extraClasses.add({
                        'label': 'Extra Class',
                        'name': name,
                        'start': id,
                        'end': endId,
                      });
                    });

                    saveAttendanceForDate();
                    Navigator.pop(context);
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

TimeOfDay _parseTime(String time) {
  final parts = time.split(':').map(int.parse).toList();
  return TimeOfDay(hour: parts[0], minute: parts[1]);
}

Future<Map<String, Map<String, int>>> getAttendanceSummary() async {
  final prefs = await SharedPreferences.getInstance();
  final summaryStr = prefs.getString('attendanceSummary') ?? '{}';
  return Map<String, Map<String, int>>.from(
    (jsonDecode(summaryStr) as Map).map(
      (k, v) => MapEntry(k, Map<String, int>.from(v)),
    ),
  );
}

Future<Map<String, dynamic>> fetchTodayClassesForHomePage() async {
  final prefs = await SharedPreferences.getInstance();
  final semesterStartStr = prefs.getString('semesterStartDate');
  final attendanceStr = prefs.getString('attendanceLog') ?? '{}';
  final versionList = prefs.getString('timetableVersions');

  if (semesterStartStr == null || versionList == null) return {};

  final semesterStart = DateTime.parse(semesterStartStr);
  final today = DateTime.now();
  if (today.isBefore(semesterStart)) return {};

  List<dynamic> versions = jsonDecode(versionList);
  versions.sort((a, b) => a['from'].compareTo(b['from']));

  Map<String, dynamic>? currentTimetable;

  for (final version in versions) {
    final fromDate = DateTime.parse(version['from']);
    if (today.isAfter(fromDate) || today.isAtSameMomentAs(fromDate)) {
      currentTimetable = version['data'];
    } else {
      break;
    }
  }

  if (currentTimetable == null) return {};

  final currentDay =
      [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ][today.weekday % 7];

  final dateKey = today.toIso8601String().split('T')[0];
  final attendanceLog = jsonDecode(attendanceStr);

  final extras = List<Map<String, dynamic>>.from(
    attendanceLog['extra_$dateKey'] ?? [],
  );

  final daySchedule = List<Map<String, dynamic>>.from(
    currentTimetable[currentDay] ?? [],
  );

  final nonYippeeClasses =
      daySchedule
          .where(
            (item) => item['class'] != 'Break' && item['class'] != 'YIPPEE',
          )
          .toList();

  final attendanceMap = Map<String, String>.from(attendanceLog[dateKey] ?? {});

  final isYippeeDay =
      nonYippeeClasses.isEmpty &&
      extras.isEmpty &&
      daySchedule.any((c) => c['class'] == 'YIPPEE');

  return {
    'classes': nonYippeeClasses,
    'extras': extras,
    'attendance': attendanceMap,
    'isYippee': isYippeeDay,
  };
}