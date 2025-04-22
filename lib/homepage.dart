import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Map<String, List<Map<String, dynamic>>> optimizedTimetable = {};

  @override
  void initState() {
    super.initState();
    _loadOptimizedTimetable();
  }

  Future<void> _loadOptimizedTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('optimizedTimetable');
    if (data != null) {
      final Map<String, dynamic> decoded = jsonDecode(data);
      optimizedTimetable = decoded.map((key, value) {
        List<Map<String, dynamic>> slots = List<Map<String, dynamic>>.from(value);
        return MapEntry(key, slots);
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimized Timetable'),
      ),
      body: optimizedTimetable.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Optimized Timetable:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      jsonEncode(optimizedTimetable), // Displaying the timetable as a JSON string
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}