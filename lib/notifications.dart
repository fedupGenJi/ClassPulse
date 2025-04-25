import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

Future<void> scheduleDailyNotificationTask() async {
  final now = DateTime.now();
  final fiveAM = DateTime(now.year, now.month, now.day, 5);

  final firstTrigger =
      now.isAfter(fiveAM) ? fiveAM.add(const Duration(days: 1)) : fiveAM;

  await AndroidAlarmManager.periodic(
    const Duration(days: 1),
    1001,
    backgroundNotificationCallback,
    startAt: firstTrigger,
    exact: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
}

void backgroundNotificationCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final attendanceSummary = prefs.getString('attendanceSummary') ?? '{}';
  final todayClassesJson = prefs.getString('todayClasses') ?? '[]';
  final assignmentsJson = prefs.getString('assignments') ?? '[]';
  final examsJson = prefs.getString('exams') ?? '[]';

  await NotificationService.scheduleNotificationsIfNeeded(
    assignments: List<Map<String, dynamic>>.from(jsonDecode(assignmentsJson)),
    exams: List<Map<String, dynamic>>.from(jsonDecode(examsJson)),
    todayClasses: List<Map<String, dynamic>>.from(jsonDecode(todayClassesJson)),
    attendanceSummary: jsonDecode(attendanceSummary),
  );
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static late SharedPreferences _prefs;
  static const _key = 'scheduled_notifications';

  static Future<void> init() async {
    tz.initializeTimeZones();
    _prefs = await SharedPreferences.getInstance();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> requestNotificationPermissions() async {
    final status = await Permission.notification.request();

    if (status.isGranted) {
      debugPrint("✅ Notification permission granted.");
    } else {
      debugPrint("❌ Notification permission denied.");
    }
  }

  static Future<void> requestBackgroundExecutionPermission() async {
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      final result = await Permission.ignoreBatteryOptimizations.request();
      if (result.isGranted) {
        debugPrint("✅ Background execution allowed.");
      } else {
        debugPrint("❌ Background execution denied.");
      }
    } else {
      debugPrint("✅ Already allowed to run in background.");
    }
  }

  static Set<String> _getScheduledIds() {
    return _prefs.getStringList(_key)?.toSet() ?? {};
  }

  static Future<void> _markAsScheduled(String id) async {
    final ids = _getScheduledIds();
    ids.add(id);
    await _prefs.setStringList(_key, ids.toList());
  }

  static Future<void> notifyLowAttendanceClassToday(
    List<Map<String, dynamic>> todayClasses,
  ) async {
    for (var cls in todayClasses) {
      if ((cls['attendancePercent'] ?? 100) < 80) {
        final formattedSubject = formatSubjectName(cls['subject']);

        final id =
            'low_attendance_${formattedSubject}_${DateTime.now().toIso8601String().substring(0, 10)}';
        if (_getScheduledIds().contains(id)) continue;

        await _notificationsPlugin.show(
          id.hashCode,
          "Can't Miss This One ☠️",
          "$formattedSubject has less than 80% attendance. Skip today and you're on thin ice!",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'attendance_channel',
              'Attendance Warnings',
              importance: Importance.max,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(''),
            ),
          ),
        );

        await _markAsScheduled(id);
      }
    }
  }

  static Future<void> scheduleNotificationsIfNeeded({
    required List<Map<String, dynamic>> assignments,
    required List<Map<String, dynamic>> exams,
    required List<Map<String, dynamic>> todayClasses,
    required Map<String, dynamic> attendanceSummary,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var assignment in assignments) {
      if ((assignment['submitted'] ?? false) == false) {
        final deadlineStr = assignment['deadline'];
        final deadline = DateTime.tryParse(_parseDate(deadlineStr));
        if (deadline == null) continue;

        final diff = deadline.difference(today).inDays;
        final formattedSubject = formatSubjectName(assignment['subject']);
        final title = assignment['title'];

        final messages = {
          3: "Hey, remember that '$title' of $formattedSubject? 3 days left. Procrastinate later.",
          0: "'$title' of $formattedSubject is due *today*. Good luck pulling a miracle. 🫠",
        };

        if (messages.containsKey(diff)) {
          final id = 'assignment_${title}_${formattedSubject}_$diff';
          if (_getScheduledIds().contains(id)) continue;

          await _notificationsPlugin.show(
            id.hashCode,
            'Assignment Reminder 📚',
            messages[diff],
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'assignments_channel',
                'Assignment Notifications',
                importance: Importance.max,
                priority: Priority.high,
                styleInformation: BigTextStyleInformation(''),
              ),
            ),
          );

          await _markAsScheduled(id);
        }
      }
    }

    for (var exam in exams) {
      final dateStr = exam['examDate'];
      final examDate = DateTime.tryParse(_parseDate(dateStr));
      if (examDate == null) continue;

      final diff = examDate.difference(today).inDays;
      final formattedSubject = formatSubjectName(exam['subject']);
      final title = exam['title'];

      final messages = {
        7: "'$title' of $formattedSubject is in 7 days. You might want to open your notes.",
        3: "'$title' of $formattedSubject is in 3 days. Time to *start* freaking out.",
        0: "'$title' of $formattedSubject is *today*. May the odds be ever in your favor. 🧠 Good luck mate!",
      };

      if (messages.containsKey(diff)) {
        final id = 'exam_${title}_${formattedSubject}_$diff';
        if (_getScheduledIds().contains(id)) continue;

        await _notificationsPlugin.show(
          id.hashCode,
          'Exam Incoming 🚨',
          messages[diff],
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'exams_channel',
              'Exam Notifications',
              importance: Importance.max,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(''),
            ),
          ),
        );

        await _markAsScheduled(id);
      }
    }

    final List<Map<String, dynamic>> lowAttendanceToday = [];
    for (var cls in todayClasses) {
      final subject = cls['class'];
      final stats =
          attendanceSummary.entries
              .firstWhere(
                (e) => (e.value['originalName'] ?? e.key) == subject,
                orElse: () => MapEntry('', {}),
              )
              .value;

      final present = stats['present'] ?? 0;
      final total = stats['total'] ?? 0;
      double percent = total > 0 ? (present / total) * 100 : 100;

      lowAttendanceToday.add({
        'subject': subject,
        'attendancePercent': percent,
      });
    }

    await notifyLowAttendanceClassToday(lowAttendanceToday);
  }

  static String _parseDate(String input) {
    final parts = input.split('/');
    return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
  }
}

String formatSubjectName(String subject) {
  final cleaned = subject.replaceAll(RegExp(r'\s+'), '');
  final uppercased = cleaned.toUpperCase();
  final withSpace = uppercased.replaceAllMapped(
    RegExp(r'([A-Z]+)(\d+)'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return withSpace;
}