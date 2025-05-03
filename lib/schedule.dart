import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'editSession.dart';

class TimetableGridPage extends StatefulWidget {
  @override
  _TimetableGridPageState createState() => _TimetableGridPageState();
}

class _TimetableGridPageState extends State<TimetableGridPage> {
  Map<String, List<Map<String, dynamic>>> timetable = {};
  bool isLoading = true;
  String? activeFromDate;

  final List<String> daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    loadTimetable();
  }

  Map<String, Color> classColors = {};
  final List<Color> availableColors = [
    Color(0xFFFFCDD2),
    Color(0xFFBBDEFB),
    Color(0xFFC8E6C9),
    Color(0xFFFFF9C4),
    Color(0xFFD1C4E9),
    Color(0xFFFFE0B2),
    Color(0xFFB2DFDB),
    Color(0xFFFFF8E1),
    Color(0xFFDCEDC8),
    Color(0xFFE1BEE7),
  ];

  Color getClassColor(String className) {
    if (className == 'Break') return Colors.white54;
    if (className == 'YIPPEE') return Colors.pink[100]!;

    if (!classColors.containsKey(className)) {
      classColors[className] =
          availableColors[classColors.length % availableColors.length];
    }

    return classColors[className]!;
  }

  Future<void> loadTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final versionList = prefs.getString('timetableVersions');
    if (versionList == null) return;

    List<dynamic> versions = jsonDecode(versionList);
    versions.sort((a, b) => a['from'].compareTo(b['from']));

    final today = DateTime.now();
    Map<String, dynamic>? selected;

    for (final version in versions) {
      final from = DateTime.parse(version['from']);
      if (today.isAfter(from) || today.isAtSameMomentAs(from)) {
        selected = version['data'];
        activeFromDate = version['from'];
      } else {
        break;
      }
    }

    if (selected == null) return;

    timetable = selected.map((key, value) {
      return MapEntry(key, List<Map<String, dynamic>>.from(value));
    });

    setState(() {
      isLoading = false;
    });
  }

  List<int> getDynamicTimeRange() {
    Set<int> hours = {};

    timetable.forEach((_, sessions) {
      for (var session in sessions) {
        if (session['class'] != 'Break' && session['class'] != 'YIPPEE') {
          final start = int.tryParse(session['start'].split(':')[0]) ?? 0;
          final end = int.tryParse(session['end'].split(':')[0]) ?? 0;
          for (int i = start; i < end; i++) {
            hours.add(i);
          }
        }
      }
    });

    if (hours.isEmpty) return [7, 16];

    final sorted = hours.toList()..sort();
    return [sorted.first, sorted.last + 1];
  }

  String formatHour(int hour) {
    final time = TimeOfDay(hour: hour, minute: 0);
    return time.format(context);
  }

  @override
  Widget build(BuildContext context) {
    final timeRange = getDynamicTimeRange();

    return Scaffold(
      appBar: AppBar(
        title: Text('Optimized Timetable'),
        backgroundColor: Color(0xFFb3e5fc),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Timetable',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditSessionPage()),
              );
            },
          ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeFromDate != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          "📝 Using schedule from: $activeFromDate",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),

                    ...daysOfWeek.map((day) {
                      final sessions = (timetable[day] ?? []);
                      return Card(
                        margin: EdgeInsets.all(10),
                        elevation: 4,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              ...sessions.map((session) {
                                final className =
                                    session['class'] ?? session['subject'];
                                final start = session['start'];
                                final end = session['end'];
                                final professor = session['professor'] ?? '';
                                final isBreakOrYippee =
                                    className == 'Break' ||
                                    className == 'YIPPEE';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          isBreakOrYippee
                                              ? Color(0xFFFFFDD0)
                                              : Colors.blue[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            className,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  isBreakOrYippee
                                                      ? FontStyle.italic
                                                      : FontStyle.normal,
                                            ),
                                          ),
                                        ),
                                        Text('$start - $end'),
                                        if (professor.isNotEmpty &&
                                            !isBreakOrYippee)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 10,
                                            ),
                                            child: Text('($professor)'),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      );
                    }),

                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Weekly Schedule',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 500,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 100,
                                height: 50,
                                color: Colors.grey[300],
                                alignment: Alignment.center,
                                child: Text(
                                  'Day',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...daysOfWeek.map((day) {
                                return Container(
                                  width: 100,
                                  height: 60,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    border: Border.all(color: Colors.black),
                                  ),
                                  child: Text(
                                    day,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),

                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Column(
                                children: [
                                  Row(
                                    children: List.generate(
                                      timeRange[1] - timeRange[0],
                                      (index) {
                                        final hour = timeRange[0] + index;
                                        return Container(
                                          width: 120,
                                          height: 50,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            border: Border.all(
                                              color: Colors.black,
                                            ),
                                          ),
                                          child: Text(
                                            '${formatHour(hour)} - ${formatHour(hour + 1)}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  ...daysOfWeek.map((day) {
                                    final row = <Widget>[];
                                    int hour = timeRange[0];
                                    while (hour < timeRange[1]) {
                                      final sessions = timetable[day] ?? [];
                                      final session = sessions.firstWhere((s) {
                                        final start =
                                            int.tryParse(
                                              s['start'].split(':')[0],
                                            ) ??
                                            -1;
                                        final end =
                                            int.tryParse(
                                              s['end'].split(':')[0],
                                            ) ??
                                            -1;
                                        return hour >= start && hour < end;
                                      }, orElse: () => {});

                                      if (session.isEmpty) {
                                        row.add(
                                          Container(
                                            width: 120,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        );
                                        hour += 1;
                                        continue;
                                      }

                                      final start =
                                          int.tryParse(
                                            session['start'].split(':')[0],
                                          ) ??
                                          hour;
                                      final end =
                                          int.tryParse(
                                            session['end'].split(':')[0],
                                          ) ??
                                          hour + 1;
                                      final span = end - start;
                                      final className = session['class'] ?? '';
                                      final professor =
                                          session['professor'] ?? '';
                                      final bgColor = getClassColor(className);

                                      if (hour != start) {
                                        hour += 1;
                                        continue;
                                      }

                                      row.add(
                                        Container(
                                          width: 120.0 * span,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            border: Border.all(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          padding: EdgeInsets.all(4),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                className,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      (className == 'Break' ||
                                                              className ==
                                                                  'YIPPEE')
                                                          ? FontStyle.italic
                                                          : FontStyle.normal,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              if (professor.isNotEmpty &&
                                                  className != 'Break' &&
                                                  className != 'YIPPEE')
                                                Text(
                                                  professor,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                            ],
                                          ),
                                        ),
                                      );

                                      hour += span;
                                    }

                                    return Row(children: row);
                                  }).toList(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}