import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'homepage.dart';
import 'dart:math';

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

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
    );

    if (picked != null) {
      int roundedMinute = (picked.minute < 30) ? 0 : 30;

      final rounded = TimeOfDay(hour: picked.hour, minute: roundedMinute);
      setState(() {
        if (isStart) {
          _startTime = rounded;
        } else {
          _endTime = rounded;
        }
      });
    }
  }

  void _addSessionToBuffer() {
    if (_formKey.currentState!.validate() &&
        _startTime != null &&
        _endTime != null &&
        _selectedDay != null) {
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

  Future<void> _completeSession() async {
    if (semesterStartDate == null || timetable.isEmpty) return;

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
          (_) => AlertDialog(
            title: const Text('Edit Session'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: newDay,
                  items:
                      days
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                  onChanged: (val) => newDay = val,
                  decoration: const InputDecoration(labelText: 'Day'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: newStart!,
                    );
                    if (picked != null) newStart = picked;
                  },
                  child: Text(
                    "Start: ${newStart != null ? newStart!.format(context) : 'Select time'}",
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: newEnd!,
                    );
                    if (picked != null) newEnd = picked;
                  },
                  child: Text(
                    "End: ${newEnd != null ? newEnd!.format(context) : 'Select time'}",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    timetable.removeAt(index);
                  });
                  Navigator.pop(context);
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    timetable[index] = {
                      ...session,
                      'day': newDay,
                      'start': newStart,
                      'end': newEnd,
                    };
                  });
                  Navigator.pop(context);
                },
                child: const Text("Save Changes"),
              ),
            ],
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
