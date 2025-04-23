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
    final timetableStr = prefs.getString('optimizedTimetable');
    final attendanceStr = prefs.getString('attendanceLog') ?? '{}';

    if (semesterStartStr == null || timetableStr == null) return;

    semesterStart = DateTime.parse(semesterStartStr);
    if (date.isBefore(semesterStart!)) return;

    final optimizedTimetable = jsonDecode(timetableStr);
    final attendanceLog = Map<String, dynamic>.from(jsonDecode(attendanceStr));

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
    final extras = List<Map<String, dynamic>>.from(
      attendanceLog['extra_$dateKey'] ?? [],
    );

    final daySchedule = List<Map<String, dynamic>>.from(
      optimizedTimetable[currentDay] ?? [],
    );

    final loadedAttendance = Map<String, String>.from(
      attendanceLog[dateKey] ?? {},
    );

    setState(() {
      todaySchedule = {'day': currentDay, 'classes': daySchedule};
      attendance = loadedAttendance;
      extraClasses = extras;
    });
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

    final previousStatus = attendance[time];
    setState(() {
      attendance[time] = status;
    });

    final className = await _getClassNameForTime(
      selectedDate,
      time,
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

    if (status != null && status != 'Cancelled') {
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
    final timetableStr = prefs.getString('optimizedTimetable');
    if (timetableStr == null) return null;

    final timetable = jsonDecode(timetableStr);
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

    for (final session in timetable[dayName] ?? []) {
      if (session['start'] == time) return session['class'];
    }

    for (final extra in extras) {
      if (extra['start'] == time) return extra['name'];
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
                    child: Text(
                      "📅 Date: $dateStr",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        ...classes.map(
                          (item) => _buildClassCard(
                            subject: item['class'],
                            time: "${item['start']} - ${item['end']}",
                            status: attendance[item['start']] ?? 'Cancelled',
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
                            status: attendance[item['start']] ?? 'Cancelled',
                            timeKey: item['start'],
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
                        final className = await _getClassNameForTime(
                          selectedDate,
                          timeKey,
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
                            (e) => e['start'] == timeKey,
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
                        .map(
                          (s) => ChoiceChip(
                            label: Text(s),
                            selected: status == s,
                            selectedColor: getCardColor(subject, s),
                            onSelected: (_) => markAttendance(timeKey, s),
                          ),
                        )
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
      builder:
          (_) => AlertDialog(
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
                    if (picked != null) setState(() => startTime = picked);
                  },
                  child: const Text("Pick Start Time"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (picked != null) setState(() => endTime = picked);
                  },
                  child: Text(
                    endTime == null
                        ? "Pick End Time"
                        : "End: ${endTime!.format(context)}",
                  ),
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
                  if (_nameController.text.trim().isEmpty ||
                      startTime == null ||
                      endTime == null)
                    return;
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
                    if (!(newEnd.hour <= existingStart.hour ||
                        newStart.hour >= existingEnd.hour)) {
                      conflicts = true;
                      break;
                    }
                  }

                  for (var extra in extraClasses) {
                    final existingStart = _parseTime(extra['start']);
                    final existingEnd = _parseTime(extra['end']);
                    if (!(newEnd.hour <= existingStart.hour ||
                        newStart.hour >= existingEnd.hour)) {
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
                      'name': _nameController.text.trim(),
                      'start': id,
                      'end': endId,
                    });
                    attendance[id] = 'Cancelled';
                  });

                  saveAttendanceForDate();
                  Navigator.pop(context);
                },
                child: const Text("Add"),
              ),
            ],
          ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':').map(int.parse).toList();
    return TimeOfDay(hour: parts[0], minute: parts[1]);
  }
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