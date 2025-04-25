import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

Future<void> generateAndViewPDF(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();

  final studentName = prefs.getString('userName') ?? 'Unknown';
  final email = prefs.getString('userGmail') ?? 'Unknown';
  final course = prefs.getString('userCourse') ?? 'Unknown';
  final semesterName = prefs.getString('semesterName') ?? 'Unknown';
  final rawStart = prefs.getString('semesterStartDate');
  final semesterStartDate =
      rawStart != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(rawStart))
          : 'Unknown';
  final semesterEndDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

  final summaryRaw = prefs.getString('attendanceSummary') ?? '{}';
  final assignmentsRaw = prefs.getString('assignments') ?? '[]';
  final examsRaw = prefs.getString('exams') ?? '[]';

  final attendanceSummary = Map<String, dynamic>.from(jsonDecode(summaryRaw));
  final assignments = List<Map<String, dynamic>>.from(
    jsonDecode(assignmentsRaw),
  );
  final exams = List<Map<String, dynamic>>.from(jsonDecode(examsRaw));

  final Map<String, Map<String, dynamic>> subjectMap = {};

  attendanceSummary.forEach((key, value) {
    final name = value['originalName'] ?? key;
    final norm = _normalize(name);
    subjectMap[norm] = {
      'name': name,
      'attendedClasses': value['present'] ?? 0,
      'totalClasses': value['total'] ?? 0,
      'assignments': <Map<String, dynamic>>[],
      'exams': <Map<String, dynamic>>[],
    };
  });

  for (final a in assignments) {
    final sub = a['subject'];
    if (sub == null) continue;
    final norm = _normalize(sub);
    subjectMap.putIfAbsent(
      norm,
      () => {
        'name': sub,
        'attendedClasses': 0,
        'totalClasses': 0,
        'assignments': <Map<String, dynamic>>[],
        'exams': <Map<String, dynamic>>[],
      },
    );
    subjectMap[norm]!['assignments'].add(a);
  }

  for (final e in exams) {
    final sub = e['subject'];
    if (sub == null) continue;
    final norm = _normalize(sub);
    subjectMap.putIfAbsent(
      norm,
      () => {
        'name': sub,
        'attendedClasses': 0,
        'totalClasses': 0,
        'assignments': <Map<String, dynamic>>[],
        'exams': <Map<String, dynamic>>[],
      },
    );
    subjectMap[norm]!['exams'].add(e);
  }

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      build:
          (context) => [
            pw.Text(
              'Semester Summary',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Student Information:',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Name: $studentName'),
            pw.Text('Email: $email'),
            pw.Text('Course: $course'),
            pw.Text('Semester: $semesterName'),
            pw.Text('Start Date: $semesterStartDate'),
            pw.Text('End Date: $semesterEndDate'),
            pw.SizedBox(height: 20),
            ...subjectMap.values.map((subject) {
              final name = subject['name'];
              final attended = subject['attendedClasses'];
              final total = subject['totalClasses'];
              final subjectAssignments =
                  subject['assignments'] as List<dynamic>;
              final subjectExams = subject['exams'] as List<dynamic>;

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 14),
                  pw.Text(
                    name,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 6),
                  pw.Text(
                    "Attendance",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Total Classes: $total'),
                        pw.Text('Classes Attended: $attended'),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 8),
                  pw.Text(
                    "Assignments",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 12),
                    child:
                        subjectAssignments.isEmpty
                            ? pw.Text("No assignments.")
                            : pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children:
                                  subjectAssignments.map((a) {
                                    final title = a['title'];
                                    final missedRescheduled =
                                        a['missedThenRescheduled'] == true;
                                    final tag =
                                        missedRescheduled
                                            ? "Missed and Rescheduled"
                                            : getAssignmentTag(a);
                                    return pw.Text('$title - $tag');
                                  }).toList(),
                            ),
                  ),

                  pw.SizedBox(height: 8),
                  pw.Text(
                    "Exams",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 12),
                    child:
                        subjectExams.isEmpty
                            ? pw.Text("No exams.")
                            : pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children:
                                  subjectExams.map((e) {
                                    final title = e['title'];
                                    final tag = getExamTag(e);
                                    return pw.Text('$title - $tag');
                                  }).toList(),
                            ),
                  ),

                  pw.Divider(),
                ],
              );
            }),
          ],
    ),
  );

  final Uint8List bytes = await pdf.save();
  final fileName =
      'Semester_Summary_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
  String? path;

  if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    path = '${dir.path}/$fileName';
  } else {
    final save = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (save == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❌ No folder selected.")));
      return;
    }
    path = save.path;
  }

  try {
    final file = File(path);
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
    //await prefs.clear();
    await Future.delayed(const Duration(seconds: 2));
    Phoenix.rebirth(context);
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("❌ Failed to save/open PDF: $e")));
  }
}

String _normalize(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

String getAssignmentTag(Map<String, dynamic> assignment) {
  final deadlineStr = assignment['deadline'];
  final submitted = assignment['submitted'] ?? false;
  if (deadlineStr == null || deadlineStr.isEmpty) return "Missed";

  final deadline = DateFormat('dd/MM/yyyy').parse(deadlineStr);
  final now = DateTime.now();

  if (submitted) return "Submitted";
  if (_isSameDay(now, deadline)) return "Missed";
  if (now.isAfter(deadline)) return "Missed";
  if (deadline.difference(now).inDays < 7) return "Missed";
  return "Missed";
}

String getExamTag(Map<String, dynamic> exam) {
  if (exam['appeared'] == true) return "Appeared";
  return "Not Appeared";
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
