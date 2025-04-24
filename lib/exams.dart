import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final List<Map<String, dynamic>> exams = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  final List<Color> subjectColors = [
    Colors.lightBlueAccent,
    Colors.pinkAccent,
    Colors.deepOrangeAccent,
    Colors.lightGreen,
    Colors.amber,
    Colors.deepPurpleAccent,
    Colors.cyan,
    Colors.teal,
  ];

  final Map<String, Color> _subjectColorMap = {};

  Color _getColorForSubject(String subjectName) {
    final normalized = subjectName.trim().toLowerCase();
    if (_subjectColorMap.containsKey(normalized)) {
      return _subjectColorMap[normalized]!;
    }
    final color = subjectColors[_subjectColorMap.length % subjectColors.length];
    _subjectColorMap[normalized] = color;
    return color;
  }

  Future<void> _loadExams() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('exams');
    if (data != null) {
      setState(() {
        exams.clear();
        exams.addAll(List<Map<String, dynamic>>.from(jsonDecode(data)));
      });
    }
  }

  Future<void> _saveExams() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('exams', jsonEncode(exams));
  }

  Future<bool> _confirmToggle(bool value) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text(
                  value ? 'Mark as Appeared?' : 'Mark as Not Appeared?',
                ),
                content: Text(
                  value
                      ? 'Are you sure you want to mark this exam as appeared?'
                      : 'Are you sure you want to mark this exam as not appeared?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showExamDialog({Map<String, dynamic>? existing, int? index}) {
    final _subjectController = TextEditingController(
      text: existing?['subject'] ?? '',
    );
    final _titleController = TextEditingController(
      text: existing?['title'] ?? '',
    );
    DateTime? _examDate =
        existing != null
            ? DateFormat('dd/MM/yyyy').parse(existing['examDate'])
            : null;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Exam' : 'Edit Exam'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject Name',
                      ),
                    ),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Exam Date:'),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setState(() => _examDate = picked);
                            }
                          },
                          child: const Text('Pick a date'),
                        ),
                      ],
                    ),
                    if (_examDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Selected: ${DateFormat('dd MMM yyyy').format(_examDate!)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                if (existing != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(index!);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text("Delete"),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_subjectController.text.isNotEmpty &&
                        _titleController.text.isNotEmpty &&
                        _examDate != null) {
                      final newExam = {
                        'subject': _subjectController.text,
                        'title': _titleController.text,
                        'examDate': DateFormat('dd/MM/yyyy').format(_examDate!),
                      };

                      if (existing != null &&
                          existing.containsKey('appeared')) {
                        newExam['appeared'] = existing['appeared'];
                      }

                      setState(() {
                        if (existing != null && index != null) {
                          exams[index] = newExam;
                        } else {
                          exams.add(newExam);
                        }
                      });

                      await _saveExams();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(int index) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Delete Exam'),
                content: const Text(
                  'Are you sure you want to delete this exam?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirm) {
      setState(() => exams.removeAt(index));
      await _saveExams();
    }
  }

  List<Map<String, dynamic>> _sortedExams() {
    List<Map<String, dynamic>> sorted = [...exams];
    sorted.sort((a, b) {
      final dateA = DateFormat('dd/MM/yyyy').parse(a['examDate']);
      final dateB = DateFormat('dd/MM/yyyy').parse(b['examDate']);
      return dateA.compareTo(dateB);
    });
    return sorted;
  }

  String? _getTag(Map<String, dynamic> exam) {
    final examDate = DateFormat('dd/MM/yyyy').parse(exam['examDate']);
    final now = DateTime.now();

    if (exam['appeared'] == true) {
      return "Appeared";
    } else if (exam['appeared'] == false) {
      return "Not Appeared";
    } else if (now.isBefore(examDate)) {
      final daysLeft = examDate.difference(now).inDays;
      if (daysLeft < 14) return "Due Soon";
      return null;
    } else if (now.isAfter(examDate) || now.isAtSameMomentAs(examDate)) {
      return "Undefined";
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Exams"),
        backgroundColor: const Color(0xFFb3e5fc),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExams,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _showExamDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Exam"),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Upcoming Exams",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child:
                    exams.isEmpty
                        ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 150),
                            Center(child: Text("No exams added yet.")),
                          ],
                        )
                        : ListView.builder(
                          itemCount: _sortedExams().length,
                          itemBuilder: (context, index) {
                            final exam = _sortedExams()[index];
                            final tag = _getTag(exam);
                            final examDate = DateFormat(
                              'dd/MM/yyyy',
                            ).parse(exam['examDate']);
                            final isPast = examDate.isBefore(DateTime.now());

                            return GestureDetector(
                              onTap: () {
                                _showExamDialog(existing: exam, index: index);
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              height: 5,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: _getColorForSubject(
                                                  exam['subject'],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              margin: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                            ),
                                            Text(
                                              '${exam['title']} (${exam['subject']})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(height: 4),
                                            Text(
                                              'Exam Date: ${exam['examDate']}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (tag != null)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  top: 6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange[100],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.orange[900],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                height: 30,

                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        exam['appeared'] == true
                                                            ? Colors.green
                                                            : Colors.grey[300],
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                  ),
                                                  onPressed:
                                                      isPast
                                                          ? () async {
                                                            if (exam['appeared'] !=
                                                                true) {
                                                              final confirm =
                                                                  await _confirmToggle(
                                                                    true,
                                                                  );
                                                              if (confirm) {
                                                                setState(
                                                                  () =>
                                                                      exam['appeared'] =
                                                                          true,
                                                                );
                                                                await _saveExams();
                                                              }
                                                            }
                                                          }
                                                          : null,

                                                  child: const Text(
                                                    "Appeared",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                height: 30,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        exam['appeared'] ==
                                                                false
                                                            ? const Color.fromARGB(
                                                              255,
                                                              227,
                                                              86,
                                                              76,
                                                            )
                                                            : Colors.grey[300],
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                  ),
                                                  onPressed:
                                                      isPast
                                                          ? () async {
                                                            if (exam['appeared'] !=
                                                                false) {
                                                              final confirm =
                                                                  await _confirmToggle(
                                                                    false,
                                                                  );
                                                              if (confirm) {
                                                                setState(
                                                                  () =>
                                                                      exam['appeared'] =
                                                                          false,
                                                                );
                                                                await _saveExams();
                                                              }
                                                            }
                                                          }
                                                          : null,

                                                  child: const Text(
                                                    "Not Appeared",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}