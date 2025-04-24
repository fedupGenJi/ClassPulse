import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'detailedsubject.dart';
import 'assignment.dart';
import 'exams.dart';

class SubjectWiseOverviewPage extends StatefulWidget {
  const SubjectWiseOverviewPage({super.key});

  @override
  State<SubjectWiseOverviewPage> createState() =>
      _SubjectWiseOverviewPageState();
}

class _SubjectWiseOverviewPageState extends State<SubjectWiseOverviewPage> {
  Map<String, Map<String, dynamic>> subjectMap = {};

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  String normalize(String name) {
    return name.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  Future<void> _loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final rawAssignments = prefs.getString('assignments');
    final rawExams = prefs.getString('exams');

    final assignments =
        rawAssignments != null
            ? List<Map<String, dynamic>>.from(jsonDecode(rawAssignments))
            : [];

    final exams =
        rawExams != null
            ? List<Map<String, dynamic>>.from(jsonDecode(rawExams))
            : [];

    final tempMap = <String, Map<String, dynamic>>{};

    for (var a in assignments) {
      final rawSub = a['subject'];
      if (rawSub == null) continue;
      final normSub = normalize(rawSub);
      tempMap.putIfAbsent(
        normSub,
        () => {'displayName': rawSub, 'assignmentCount': 0, 'examCount': 0},
      );
      final entry = tempMap[normSub]!;
      entry['assignmentCount'] = (entry['assignmentCount'] ?? 0) + 1;
    }

    for (var e in exams) {
      final rawSub = e['subject'];
      if (rawSub == null) continue;
      final normSub = normalize(rawSub);
      tempMap.putIfAbsent(
        normSub,
        () => {'displayName': rawSub, 'assignmentCount': 0, 'examCount': 0},
      );
      final entry = tempMap[normSub]!;
      entry['examCount'] = (entry['examCount'] ?? 0) + 1;
    }

    setState(() {
      subjectMap = tempMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFb3e5fc),
        title: const Text("Subjects Overview"),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment),
            tooltip: 'View Assignments',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssignmentPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'View Exams',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExamPage()),
              );
            },
          ),
        ],
      ),
      body:
          subjectMap.isEmpty
              ? const Center(child: Text("No subjects found yet."))
              : ListView.builder(
                itemCount: subjectMap.length,
                itemBuilder: (context, index) {
                  final key = subjectMap.keys.elementAt(index);
                  final data = subjectMap[key]!;
                  final display = data['displayName'];
                  final assignments = data['assignmentCount'];
                  final exams = data['examCount'];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(display),
                      subtitle: Text(
                        "$assignments Assignment(s), $exams Exam(s)",
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) =>
                                    SubjectWiseDetailPage(subjectName: display),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }
}