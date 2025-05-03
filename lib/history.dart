import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final List<Color> distinctColors = [
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

final Map<String, Color> subjectColors = {};
int _colorIndex = 0;

String normalizeSubject(String subject) {
  return subject.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

Color getColorForSubject(String subject) {
  String normalized = normalizeSubject(subject);
  if (!subjectColors.containsKey(normalized)) {
    subjectColors[normalized] =
        distinctColors[_colorIndex % distinctColors.length];
    _colorIndex++;
  }
  return subjectColors[normalized]!;
}

class TimetableHistoryPage extends StatelessWidget {
  const TimetableHistoryPage({super.key});

  Color getColorForClass(String className) {
    return getColorForSubject(className);
  }

  Future<void> _deleteVersion(BuildContext context, String fromDate) async {
    final prefs = await SharedPreferences.getInstance();
    final versionStr = prefs.getString('timetableVersions');
    if (versionStr == null) return;

    List<dynamic> versions = jsonDecode(versionStr);
    versions.removeWhere((v) => v['from'] == fromDate);

    await prefs.setString('timetableVersions', jsonEncode(versions));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🗑 Schedule from $fromDate deleted')),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TimetableHistoryPage()),
    );
  }

  Future<List<Map<String, dynamic>>> _loadVersions() async {
    final prefs = await SharedPreferences.getInstance();
    final versionStr = prefs.getString('timetableVersions');
    if (versionStr == null) return [];

    List<dynamic> raw = jsonDecode(versionStr);
    raw.sort((a, b) => a['from'].compareTo(b['from']));
    return List<Map<String, dynamic>>.from(raw);
  }

  List<int> getTimeRange(Map<String, dynamic> timetable) {
    Set<int> hours = {};
    timetable.forEach((_, sessions) {
      for (var s in sessions) {
        if (s['class'] != 'Break' && s['class'] != 'YIPPEE') {
          final start = int.tryParse(s['start'].split(':')[0]) ?? 0;
          final end = int.tryParse(s['end'].split(':')[0]) ?? 0;
          for (int h = start; h < end; h++) hours.add(h);
        }
      }
    });
    if (hours.isEmpty) return [7, 16];
    final sorted = hours.toList()..sort();
    return [sorted.first, sorted.last + 1];
  }

  Widget buildGrid(
    BuildContext context,
    Map<String, dynamic> timetable,
    String fromDate,
  ) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final timeRange = getTimeRange(timetable);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "📝 Schedule from: $fromDate",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (DateTime.parse(fromDate).isAfter(DateTime.now()))
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: "Delete this reschedule",
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Delete Reschedule'),
                            content: Text(
                              'Are you sure you want to delete schedule from $fromDate?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );

                    if (confirm == true) {
                      await _deleteVersion(context, fromDate);
                    }
                  },
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 80),
                  ...List.generate(
                    timeRange[1] - timeRange[0],
                    (index) => Container(
                      width: 80,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        border: Border.all(color: Colors.black),
                      ),
                      child: Text(
                        "${(timeRange[0] + index).toString().padLeft(2, '0')}:00 - ${(timeRange[0] + index + 1).toString().padLeft(2, '0')}:00",
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              ...days.map((day) {
                final row = <Widget>[
                  Container(
                    width: 80,
                    height: 45,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.black),
                    ),
                    child: Text(day, textAlign: TextAlign.center),
                  ),
                ];

                int hour = timeRange[0];
                while (hour < timeRange[1]) {
                  final sessions = List<Map<String, dynamic>>.from(
                    timetable[day] ?? [],
                  );
                  final match = sessions.firstWhere((s) {
                    final start = int.tryParse(s['start'].split(':')[0]) ?? -1;
                    final end = int.tryParse(s['end'].split(':')[0]) ?? -1;
                    return hour >= start && hour < end;
                  }, orElse: () => {});

                  if (match.isEmpty) {
                    row.add(
                      Container(
                        width: 80,
                        height: 45,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                    );
                    hour += 1;
                    continue;
                  }

                  final start = int.parse(match['start'].split(':')[0]);
                  final end = int.parse(match['end'].split(':')[0]);
                  final span = end - start;
                  final name = match['class'] ?? '';
                  final prof = match['professor'] ?? '';
                  final isBreak = name == 'Break' || name == 'YIPPEE';

                  row.add(
                    Container(
                      width: 80.0 * span,
                      height: 45,
                      decoration: BoxDecoration(
                        color:
                            isBreak
                                ? const Color.fromARGB(179, 203, 182, 182)
                                : getColorForClass(name),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontStyle:
                                  isBreak ? FontStyle.italic : FontStyle.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (!isBreak && prof.isNotEmpty)
                            Text(prof, style: const TextStyle(fontSize: 11)),
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
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reschedule History'),
        backgroundColor: const Color(0xFFb3e5fc),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadVersions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final versions = snapshot.data!;
          if (versions.isEmpty)
            return const Center(child: Text("No reschedules yet."));

          return ListView.builder(
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final version = versions[index];
              return buildGrid(
                context,
                Map<String, dynamic>.from(version['data']),
                version['from'],
              );
            },
          );
        },
      ),
    );
  }
}