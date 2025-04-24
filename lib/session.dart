import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'homepage.dart';
import 'dart:math';
import 'dart:convert';

class SessionPage extends StatefulWidget {
  const SessionPage({Key? key}) : super(key: key);

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  DateTime? semesterStartDate;
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _instructorController = TextEditingController();
  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  List<Map<String, dynamic>> timetable = [];
  List<Map<String, dynamic>> tempSessions = [];

  final List<String> days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final Map<String, Color> subjectColors = {};

  Color getColorForSubject(String subject) {
    if (!subjectColors.containsKey(subject)) {
      subjectColors[subject] =
          Colors.primaries[Random().nextInt(Colors.primaries.length)].shade200;
    }
    return subjectColors[subject]!;
  }

  Future<void> optimizeTimetable(BuildContext context) async {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var session in timetable) {
      final day = session['day'];
      grouped.putIfAbsent(day, () => []).add(session);
    }

    String globalEarliest = '23:59';
    String globalLatest = '00:00';

    for (var sessions in grouped.values) {
      for (var session in sessions) {
        final start =
            session['start'] is TimeOfDay
                ? formatTimeOfDay(session['start'])
                : session['start'];
        final end =
            session['end'] is TimeOfDay
                ? formatTimeOfDay(session['end'])
                : session['end'];

        if (_isEarlier(start, globalEarliest)) globalEarliest = start;
        if (_isLater(end, globalLatest)) globalLatest = end;
      }
    }

    Map<String, List<Map<String, dynamic>>> optimized = {};

    for (var day in days) {
      final sessions =
          grouped[day]?.map((session) {
            final start =
                session['start'] is TimeOfDay
                    ? formatTimeOfDay(session['start'])
                    : session['start'];
            final end =
                session['end'] is TimeOfDay
                    ? formatTimeOfDay(session['end'])
                    : session['end'];
            return {
              'subject': session['subject'],
              'instructor': session['instructor'],
              'start': start,
              'end': end,
            };
          }).toList() ??
          [];

      sessions.sort((a, b) => a['start'].compareTo(b['start']));

      List<Map<String, dynamic>> daySchedule = [];
      String currentTime = globalEarliest;

      if (sessions.isEmpty) {
        daySchedule.add({
          'class': 'YIPPEE',
          'start': globalEarliest,
          'end': globalLatest,
        });
      } else {
        for (var session in sessions) {
          final start = session['start'];
          final end = session['end'];

          if (_isEarlier(currentTime, start)) {
            daySchedule.add({
              'class': 'Break',
              'start': currentTime,
              'end': start,
            });
          }

          daySchedule.add({
            'class': session['subject'],
            'professor': session['instructor'],
            'start': start,
            'end': end,
          });

          currentTime = end;
        }

        if (_isEarlier(currentTime, globalLatest)) {
          daySchedule.add({
            'class': 'Break',
            'start': currentTime,
            'end': globalLatest,
          });
        }
      }

      optimized[day] = daySchedule;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('optimizedTimetable', jsonEncode(optimized));
  }

  bool _isEarlier(String time1, String time2) {
    final t1 = time1.split(':').map(int.parse).toList();
    final t2 = time2.split(':').map(int.parse).toList();
    return t1[0] < t2[0] || (t1[0] == t2[0] && t1[1] < t2[1]);
  }

  bool _isLater(String time1, String time2) {
    final t1 = time1.split(':').map(int.parse).toList();
    final t2 = time2.split(':').map(int.parse).toList();
    return t1[0] > t2[0] || (t1[0] == t2[0] && t1[1] > t2[1]);
  }

  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        semesterStartDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (picked.hour >= 6 && picked.hour <= 18) {
        final rounded = TimeOfDay(hour: picked.hour, minute: 0);

        setState(() {
          if (isStart) {
            _startTime = rounded;
          } else {
            _endTime = rounded;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a time between 6 AM and 6 PM')),
        );
      }
    }
  }

  void _addSessionToBuffer() {
    if (_formKey.currentState!.validate() &&
        _startTime != null &&
        _endTime != null &&
        _selectedDay != null) {
      if (_endTime!.hour < _startTime!.hour ||
          (_endTime!.hour == _startTime!.hour &&
              _endTime!.minute <= _startTime!.minute)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ End time must be after start time.")),
        );
        return;
      }
      final newSession = {
        'subject': _subjectController.text.trim(),
        'instructor': _instructorController.text.trim(),
        'day': _selectedDay!,
        'start': _startTime!,
        'end': _endTime!,
      };

      bool overlaps = tempSessions.any((session) {
        final TimeOfDay? newStart = newSession['start'] as TimeOfDay?;
        final TimeOfDay? newEnd = newSession['end'] as TimeOfDay?;
        final TimeOfDay? existingStart = session['start'] as TimeOfDay?;
        final TimeOfDay? existingEnd = session['end'] as TimeOfDay?;

        if (newStart == null ||
            newEnd == null ||
            existingStart == null ||
            existingEnd == null) {
          return false;
        }

        return session['day'] == newSession['day'] &&
            newStart.hour < existingEnd.hour &&
            newEnd.hour > existingStart.hour;
      });

      if (overlaps) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This time overlaps with another session.'),
          ),
        );
        return;
      }

      setState(() {
        tempSessions.add(newSession);
        _startTime = null;
        _endTime = null;
        _selectedDay = null;
      });
    }
  }

  void _commitSubjectToTimetable() {
    if (_formKey.currentState!.validate() &&
        _startTime != null &&
        _endTime != null &&
        _selectedDay != null) {
      if (_endTime!.hour < _startTime!.hour ||
          (_endTime!.hour == _startTime!.hour &&
              _endTime!.minute <= _startTime!.minute)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ End time must be after start time.")),
        );
        return;
      }
      final currentSession = {
        'subject': _subjectController.text.trim(),
        'instructor': _instructorController.text.trim(),
        'day': _selectedDay!,
        'start': _startTime!,
        'end': _endTime!,
      };

      bool alreadyAdded = tempSessions.any(
        (session) =>
            session['day'] == currentSession['day'] &&
            session['start'] == currentSession['start'] &&
            session['end'] == currentSession['end'] &&
            session['subject'] == currentSession['subject'],
      );

      if (!alreadyAdded) {
        tempSessions.add(currentSession);
      }
    }

    if (tempSessions.isEmpty) return;

    List<Map<String, dynamic>> nonConflicting = [];
    List<Map<String, dynamic>> conflicting = [];

    for (var newSession in tempSessions) {
      bool overlaps = timetable.any((session) {
        return session['day'] == newSession['day'] &&
            newSession['start'].hour < session['end'].hour &&
            newSession['end'].hour > session['start'].hour;
      });

      if (overlaps) {
        conflicting.add(newSession);
      } else {
        nonConflicting.add(newSession);
      }
    }

    setState(() {
      timetable.addAll(nonConflicting);
      tempSessions.clear();
      _subjectController.clear();
      _instructorController.clear();
      _startTime = null;
      _endTime = null;
      _selectedDay = null;
    });

    if (conflicting.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some sessions were not added due to time conflicts.'),
        ),
      );
    }
  }

  Future<void> optimizeAndSaveAsVersion(BuildContext context) async {
  await optimizeTimetable(context);

  final prefs = await SharedPreferences.getInstance();
  final optimizedJson = prefs.getString('optimizedTimetable');
  if (optimizedJson == null || semesterStartDate == null) return;

  final fromDate = semesterStartDate!.toIso8601String().split('T').first;

  List<dynamic> versions = [];
  final versionList = prefs.getString('timetableVersions');
  if (versionList != null) {
    versions = jsonDecode(versionList);
  }

  versions.removeWhere((v) => v['from'] == fromDate);

  versions.add({
    'from': fromDate,
    'data': jsonDecode(optimizedJson),
  });

  await prefs.setString('timetableVersions', jsonEncode(versions));
}

  Future<void> _completeSession() async {
    if (semesterStartDate == null || timetable.isEmpty) return;
    await optimizeAndSaveAsVersion(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Setup Completion'),
            content: const Text(
              'Are you sure you want to complete the setup and go to the homepage?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Complete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sessionSetupComplete', true);
    await prefs.setString('semesterStartDate', semesterStartDate.toString());

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  List<int> getTimeSlots() {
    return List.generate(12, (index) => index + 6);
  }

  void _showEditDialog(int index) async {
    final session = timetable[index];
    TimeOfDay start = session['start'];
    TimeOfDay end = session['end'];
    String day = session['day'];

    String? newDay = day;
    TimeOfDay? newStart = start;
    TimeOfDay? newEnd = end;

    await showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Edit Session'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: newDay,
                      items:
                          days
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
                              )
                              .toList(),
                      onChanged: (val) => setDialogState(() => newDay = val),
                      decoration: const InputDecoration(labelText: 'Day'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: newStart!,
                        );
                        if (picked != null &&
                            picked.hour >= 6 &&
                            picked.hour <= 18) {
                          setDialogState(
                            () =>
                                newStart = TimeOfDay(
                                  hour: picked.hour,
                                  minute: 0,
                                ),
                          );
                        } else if (picked != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select a time between 6 AM and 6 PM',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text("Pick Start Time"),
                    ),
                    if (newStart != null)
                      Text("Picked Start Time: ${newStart!.format(context)}"),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: newEnd!,
                        );
                        if (picked != null &&
                            picked.hour >= 6 &&
                            picked.hour <= 18) {
                          setDialogState(
                            () =>
                                newEnd = TimeOfDay(
                                  hour: picked.hour,
                                  minute: 0,
                                ),
                          );
                        } else if (picked != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select a time between 6 AM and 6 PM',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text("Pick End Time"),
                    ),
                    if (newEnd != null)
                      Text("Picked End Time: ${newEnd!.format(context)}"),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      setState(() => timetable.removeAt(index));
                    },
                    child: const Text(
                      "Delete",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (newStart == null || newEnd == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "❗ Please select both start and end times.",
                            ),
                          ),
                        );
                        return;
                      }

                      if (newEnd!.hour < newStart!.hour ||
                          (newEnd!.hour == newStart!.hour &&
                              newEnd!.minute <= newStart!.minute)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "❌ End time must be after start time.",
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(dialogContext);
                      setState(() {
                        timetable[index] = {
                          ...session,
                          'day': newDay,
                          'start': newStart!,
                          'end': newEnd!,
                        };
                      });
                    },
                    child: const Text("Save Changes"),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _buildTempSessionsList() {
    if (tempSessions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Pending Times for Current Subject:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...tempSessions.map((session) {
          return ListTile(
            title: Text(
              "${session['day']} | ${session['start'].format(context)} - ${session['end'].format(context)}",
            ),
          );
        }).toList(),
        const Divider(),
      ],
    );
  }

  Widget _buildTimetableGrid() {
    final timeSlots = getTimeSlots();
    final rendered = <String>{};

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 80),
              ...timeSlots.map((hour) {
                final nextHour = (hour + 1).clamp(0, 24);
                return Container(
                  width: 80,
                  height: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00 - ${nextHour.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
            ],
          ),
          ...days.map((day) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 60,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 4, right: 4),
                  child: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...timeSlots.map((hour) {
                  final key = '$day-$hour';
                  if (rendered.contains(key)) return const SizedBox.shrink();

                  final index = timetable.indexWhere(
                    (c) =>
                        c['day'] == day &&
                        c['start'].hour <= hour &&
                        c['end'].hour > hour,
                  );

                  if (index == -1) {
                    return Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                      ),
                    );
                  } else {
                    final entry = timetable[index];
                    int startHour = entry['start'].hour;
                    int endHour = entry['end'].hour;
                    int duration = endHour - startHour;

                    for (int i = 0; i < duration; i++) {
                      rendered.add('$day-${startHour + i}');
                    }

                    return GestureDetector(
                      onTap: () => _showEditDialog(index),
                      child: Container(
                        width: 80.0 * duration,
                        height: 60,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: getColorForSubject(entry['subject']),
                          border: Border.all(color: Colors.black26),
                        ),
                        child: FittedBox(
                          child: Text(
                            entry['subject'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }
                }).toList(),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Semester Schedule"),
        backgroundColor: Color(0xFFb3e5fc),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => _pickDate(context),
              child: Text(
                semesterStartDate == null
                    ? "Select Semester Start Date"
                    : "Start Date: ${semesterStartDate!.toLocal().toString().split(' ')[0]}",
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: "Subject Name",
                    ),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? "Enter subject"
                                : null,
                  ),
                  TextFormField(
                    controller: _instructorController,
                    decoration: const InputDecoration(
                      labelText: "Instructor (Optional)",
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedDay,
                    items:
                        days
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => _selectedDay = val),
                    hint: const Text("Select Day"),
                    validator: (val) => val == null ? "Select day" : null,
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _pickTime(context, true),
                        child: Text(
                          _startTime == null
                              ? "Pick Start Time"
                              : _startTime!.format(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _pickTime(context, false),
                        child: Text(
                          _endTime == null
                              ? "Pick End Time"
                              : _endTime!.format(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _addSessionToBuffer,
                    child: const Text("+ Add Another Time for This Subject"),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _commitSubjectToTimetable,
                    child: const Text("Add Subject to Timetable"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildTempSessionsList(),
            const Text(
              "Weekly Timetable",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildTimetableGrid(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _completeSession,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Complete!"),
            ),
          ],
        ),
      ),
    );
  }
}