import 'package:flutter/material.dart';

class SubjectWiseDetailPage extends StatelessWidget {
  final String subjectName;

  const SubjectWiseDetailPage({super.key, required this.subjectName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFb3e5fc),
        title: Text(subjectName),
      ),
      body: Center(
        child: Text(
          'Details for $subjectName will appear here.',
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}