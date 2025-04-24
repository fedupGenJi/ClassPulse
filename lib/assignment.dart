import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class AssignmentPage extends StatefulWidget {
  const AssignmentPage({super.key});

  @override
  State<AssignmentPage> createState() => _AssignmentPageState();
}

class _AssignmentPageState extends State<AssignmentPage> {
  final List<Map<String, dynamic>> assignments = [];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
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

  Future<void> _saveAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('assignments', jsonEncode(assignments));
  }

  Future<void> _loadAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('assignments');
    if (data != null) {
      setState(() {
        assignments.clear();
        assignments.addAll(List<Map<String, dynamic>>.from(jsonDecode(data)));
      });
    }
  }

  List<Map<String, dynamic>> _sortedAssignments() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Map<String, dynamic>> sorted = [...assignments];

    int getPriority(Map<String, dynamic> assignment, DateTime date) {
      final submitted = assignment['submitted'] ?? false;

      if (submitted) return 4;
      if (_isSameDay(date, today)) return 1;
      if (date.isAfter(today)) return 2;
      return 3;
    }

    sorted.sort((a, b) {
      final dateA = DateFormat('dd/MM/yyyy').parse(a['deadline']);
      final dateB = DateFormat('dd/MM/yyyy').parse(b['deadline']);

      final priorityA = getPriority(a, dateA);
      final priorityB = getPriority(b, dateB);

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      return dateA.compareTo(dateB);
    });

    return sorted;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String? _getAssignmentTag(Map<String, dynamic> assignment) {
    final deadline = DateFormat('dd/MM/yyyy').parse(assignment['deadline']);
    final now = DateTime.now();
    final isSubmitted = assignment['submitted'] ?? false;

    final isSameDay =
        now.year == deadline.year &&
        now.month == deadline.month &&
        now.day == deadline.day;

    if (isSubmitted && now.isBefore(deadline.add(const Duration(days: 1)))) {
      return "Submitted";
    }

    if (!isSubmitted && isSameDay) {
      return "Due Today";
    }

    if (!isSubmitted && now.isAfter(deadline)) {
      return "Missed";
    }

    if (!isSubmitted && deadline.difference(now).inDays < 7) {
      return "Due Soon";
    }

    return null;
  }

  Future<bool> _promptReschedule() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("Reschedule Assignment?"),
                content: const Text(
                  "This assignment was missed. Do you want to set a new deadline?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("No"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Yes"),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showAddOrEditAssignmentDialog({
    Map<String, dynamic>? existing,
    int? index,
    bool wasMissedAndRescheduled = false,
  }) {
    final _subjectController = TextEditingController(
      text: existing?['subject'] ?? '',
    );
    final _titleController = TextEditingController(
      text: existing?['title'] ?? '',
    );
    DateTime? _selectedDate =
        existing != null
            ? DateFormat('dd/MM/yyyy').parse(existing['deadline'])
            : null;
    String _submissionType = existing?['type'] ?? 'Soft-copy';

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Add Assignment' : 'Edit Assignment',
              ),
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
                        const Text('Deadline:'),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );

                            if (pickedDate != null) {
                              setState(() {
                                _selectedDate = pickedDate;
                              });
                            }
                          },
                          child: const Text('Pick a date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_selectedDate != null)
                      Text(
                        'Selected deadline: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _submissionType,
                      items:
                          ['Soft-copy', 'Hard-copy', 'Both']
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _submissionType = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Submission Type',
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
                    child: const Text('Delete'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_subjectController.text.isNotEmpty &&
                        _titleController.text.isNotEmpty &&
                        _selectedDate != null) {
                      bool confirmed = true;
                      if (existing != null) {
                        confirmed = await _confirmSaveOrUpdate();
                      }
                      if (!confirmed) return;

                      final newEntry = {
                        'subject': _subjectController.text,
                        'title': _titleController.text,
                        'deadline': DateFormat(
                          'dd/MM/yyyy',
                        ).format(_selectedDate!),
                        'type': _submissionType,
                        'submitted': existing?['submitted'] ?? false,
                        'missedThenRescheduled':
                            wasMissedAndRescheduled ||
                            (existing?['missedThenRescheduled'] ?? false),
                      };

                      setState(() {
                        if (existing != null && index != null) {
                          assignments[index] = newEntry;
                        } else {
                          assignments.add(newEntry);
                        }
                      });

                      await _saveAssignments();
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

  Future<bool> _confirmSaveOrUpdate() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Are you sure?'),
                content: const Text('Do you want to save the changes?'),
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
  }

  void _confirmDelete(int index) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Confirm Deletion'),
                content: const Text(
                  'Are you sure you want to delete this assignment?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (shouldDelete) {
      setState(() {
        assignments.removeAt(index);
      });
      await _saveAssignments();
    }
  }

  bool _isPastDeadline(String deadline) {
    final deadlineDate = DateFormat('dd/MM/yyyy').parse(deadline);
    final now = DateTime.now();
    return now.isAfter(
      DateTime(
        deadlineDate.year,
        deadlineDate.month,
        deadlineDate.day,
        23,
        59,
        59,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Assignment"),
        backgroundColor: const Color(0xFFb3e5fc),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAssignments,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddOrEditAssignmentDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text("Add an Assignment"),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Assignments",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    assignments.isEmpty
                        ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 150),
                            Center(child: Text("No exams added yet.")),
                          ],
                        )
                        : ListView.builder(
                          itemCount: _sortedAssignments().length,
                          itemBuilder: (context, index) {
                            final assignment = _sortedAssignments()[index];
                            final tag = _getAssignmentTag(assignment);

                            return GestureDetector(
                              onTap: () async {
                                final isMissed =
                                    _isPastDeadline(assignment['deadline']) &&
                                    !(assignment['submitted'] ?? false);
                                int idx = assignments.indexOf(assignment);

                                if (isMissed) {
                                  bool reschedule = await _promptReschedule();
                                  if (reschedule) {
                                    _showAddOrEditAssignmentDialog(
                                      existing: assignment,
                                      index: idx,
                                      wasMissedAndRescheduled: true,
                                    );
                                  }
                                } else {
                                  _showAddOrEditAssignmentDialog(
                                    existing: assignment,
                                    index: idx,
                                  );
                                }
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (assignment['missedThenRescheduled'] ==
                                                true)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  "Missed and Rescheduled",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.brown,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),

                                            Container(
                                              height: 5,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: _getColorForSubject(
                                                  assignment['subject'],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              margin: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                            ),

                                            Text(
                                              '${assignment['title']} (${assignment['subject']})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Deadline: ${assignment['deadline']}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'Submission: ${assignment['type']}',
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
                                                  color:
                                                      tag == "Missed"
                                                          ? Colors.red[100]
                                                          : tag == "Submitted"
                                                          ? Colors.green[100]
                                                          : Colors.orange[100],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        tag == "Missed"
                                                            ? Colors.red[900]
                                                            : tag == "Submitted"
                                                            ? Colors.green[900]
                                                            : Colors
                                                                .orange[900],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Checkbox(
                                            value:
                                                assignment['submitted'] ??
                                                false,
                                            onChanged:
                                                _isPastDeadline(
                                                      assignment['deadline'],
                                                    )
                                                    ? null
                                                    : (val) async {
                                                      final confirm = await showDialog<
                                                        bool
                                                      >(
                                                        context: context,
                                                        builder:
                                                            (_) => AlertDialog(
                                                              title: Text(
                                                                val == true
                                                                    ? 'Mark as Submitted?'
                                                                    : 'Unmark Submission?',
                                                              ),
                                                              content: Text(
                                                                val == true
                                                                    ? 'Do you want to mark this assignment as submitted?'
                                                                    : 'Do you want to unmark this assignment as submitted?',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        false,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Cancel',
                                                                      ),
                                                                ),
                                                                ElevatedButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        true,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Confirm',
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                      );

                                                      if (confirm == true) {
                                                        setState(() {
                                                          assignment['submitted'] =
                                                              val ?? false;
                                                        });
                                                        await _saveAssignments();
                                                      }
                                                    },
                                          ),
                                          const Text(
                                            "Submit",
                                            style: TextStyle(fontSize: 10),
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