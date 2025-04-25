import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class SubjectWiseDetailPage extends StatefulWidget {
  final String subjectName;

  const SubjectWiseDetailPage({super.key, required this.subjectName});

  @override
  State<SubjectWiseDetailPage> createState() => _SubjectWiseDetailPageState();
}

class _SubjectWiseDetailPageState extends State<SubjectWiseDetailPage> {
  List<Map<String, dynamic>> subjectAssignments = [];
  List<Map<String, dynamic>> subjectExams = [];

  String normalizeSubject(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final assignmentData = prefs.getString('assignments');
    final examData = prefs.getString('exams');

    final normalizedTarget = normalizeSubject(widget.subjectName);

    if (assignmentData != null) {
      final allAssignments = List<Map<String, dynamic>>.from(
        jsonDecode(assignmentData),
      );
      subjectAssignments =
          allAssignments
              .where((a) => normalizeSubject(a['subject']) == normalizedTarget)
              .toList();
    }

    if (examData != null) {
      final allExams = List<Map<String, dynamic>>.from(jsonDecode(examData));
      subjectExams =
          allExams
              .where((e) => normalizeSubject(e['subject']) == normalizedTarget)
              .toList();
    }

    setState(() {});
  }

  String? _getAssignmentTag(Map<String, dynamic> assignment) {
    final deadline = DateFormat('dd/MM/yyyy').parse(assignment['deadline']);
    final now = DateTime.now();
    final isSubmitted = assignment['submitted'] ?? false;

    if (isSubmitted) return "Submitted";
    if (_isSameDay(deadline, now)) return "Due Today";
    if (now.isAfter(deadline)) return "Missed";
    if (deadline.difference(now).inDays < 7) return "Due Soon";
    return null;
  }

  String? _getExamTag(Map<String, dynamic> exam) {
  final examDate = DateFormat('dd/MM/yyyy').parse(exam['examDate']);
  final now = DateTime.now();

  if (exam['appeared'] == true) {
    return "Appeared";
  } else if (exam['appeared'] == false) {
    return "Not Appeared";
  } else if (now.isBefore(examDate)) {
    final daysLeft = examDate.difference(now).inDays;
    if (daysLeft < 14) return "Coming Soon";
    return null;
  } else if (now.isAfter(examDate) || _isSameDay(now, examDate)) {
    return "Undefined";
  }

  return null;
}

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _infoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text("$label: $value", style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildCard({
    required String title,
    required List<Widget> subtitleWidgets,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...subtitleWidgets,
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, {Color? color}) {
    final tagColor =
        color ??
        {
          "Submitted": Colors.green,
          "Due Today": Colors.orange,
          "Missed": Colors.red,
          "Due Soon": Colors.deepOrangeAccent,
          "Coming Soon": Colors.deepOrangeAccent,
          "Undefined": Colors.grey,
          "Appeared": Colors.green,
          "Not Appeared": Colors.red,
        }[tag] ??
        Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Chip(
        label: Text(tag, style: const TextStyle(color: Colors.white)),
        backgroundColor: tagColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        backgroundColor: const Color(0xFFb3e5fc),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader("Assignments"),
            const SizedBox(height: 8),
            if (subjectAssignments.isEmpty)
              const Text("No assignments mentioned yet.")
            else
              ...subjectAssignments.map((assignment) {
                final tag = _getAssignmentTag(assignment);
                return _buildCard(
                  title: assignment['title'],
                  subtitleWidgets: [
                    _infoText("Deadline", assignment['deadline']),
                    _infoText("Submission Type", assignment['type']),
                    if (tag != null) _buildTagChip(tag),
                    if (assignment['missedThenRescheduled'] == true)
                      _buildTagChip(
                        "Missed and Rescheduled",
                        color: Colors.brown,
                      ),
                  ],
                );
              }),

            const SizedBox(height: 20),
            _sectionHeader("Exams"),
            const SizedBox(height: 8),
            if (subjectExams.isEmpty)
              const Text("No exams mentioned yet.")
            else
              ...subjectExams.map((exam) {
                final tag = _getExamTag(exam);
                return _buildCard(
                  title: exam['title'],
                  subtitleWidgets: [
                    _infoText("Exam Date", exam['examDate']),
                    if (tag != null) _buildTagChip(tag),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}