import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (_) {
      // Notification init failed — app still works, just no scheduled reminders
    }
  }

  /// Schedule local notifications for a post: one "time to post!" alert at
  /// the scheduled moment, plus an optional advance reminder.
  ///
  /// [reminderOffset] fires a second notification N minutes/hours before the
  /// scheduled time (e.g. Duration(minutes: 15)). Pass null or Duration.zero
  /// to skip the advance reminder.
  static Future<void> schedulePostReminder({
    required int id,
    required String postTitle,
    required String platform,
    required DateTime scheduledTime,
    Duration? reminderOffset,
  }) async {
    await init();
    if (!_initialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'post_reminders',
        'Post Reminders',
        channelDescription: 'Reminds you to post your scheduled content',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const details = NotificationDetails(android: androidDetails);

      // Main "time to post!" alert.
      await _plugin.zonedSchedule(
        id,
        'Time to post!',
        'Your $platform caption for "$postTitle" is ready to share!',
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // Advance reminder (e.g. 15 min before).
      if (reminderOffset != null && reminderOffset.inSeconds > 0) {
        final reminderAt = scheduledTime.subtract(reminderOffset);
        if (reminderAt.isAfter(DateTime.now())) {
          await _plugin.zonedSchedule(
            // Different id so both can coexist and be cancelled independently.
            id + 1,
            'Post reminder: ${_humanOffset(reminderOffset)} away',
            'Your $platform caption for "$postTitle" posts in ${_humanOffset(reminderOffset)}.',
            tz.TZDateTime.from(reminderAt, tz.local),
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    } catch (_) {
      // Scheduling failed — not critical
    }
  }

  /// Cancel both the main alert and its paired pre-reminder.
  static Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
      await _plugin.cancel(id + 1);
    } catch (_) {}
  }

  /// Generate an .ics calendar file for the scheduled post and hand it to
  /// the OS share sheet. The user opens it in Google Calendar / Outlook /
  /// Apple Calendar — the built-in reminder fires even if the app is closed.
  static Future<bool> shareCalendarEvent({
    required String postTitle,
    required String platform,
    required String captionText,
    required DateTime scheduledTime,
    Duration? reminderOffset,
  }) async {
    if (kIsWeb) return false;
    try {
      final ics = _buildIcs(
        title: 'Post: $postTitle ($platform)',
        description: captionText,
        start: scheduledTime,
        reminderOffset: reminderOffset,
      );

      final dir = await getTemporaryDirectory();
      final file = File(p.join(
          dir.path, 'postcraft_${DateTime.now().millisecondsSinceEpoch}.ics'));
      await file.writeAsString(ics);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/calendar')],
        subject: 'Add to calendar: $postTitle',
        text: 'Publishing on $platform at ${scheduledTime.toLocal()}',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _buildIcs({
    required String title,
    required String description,
    required DateTime start,
    Duration? reminderOffset,
  }) {
    String fmt(DateTime dt) {
      final u = dt.toUtc();
      String pad(int n) => n.toString().padLeft(2, '0');
      return '${u.year}${pad(u.month)}${pad(u.day)}T'
          '${pad(u.hour)}${pad(u.minute)}${pad(u.second)}Z';
    }

    // iCalendar escaping: newlines → \n, commas/semicolons → escaped
    String escape(String s) => s
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');

    final end = start.add(const Duration(minutes: 15));
    final uid = 'postcraft-${DateTime.now().millisecondsSinceEpoch}@postcraft';

    final alarm = (reminderOffset != null && reminderOffset.inSeconds > 0)
        ? '''BEGIN:VALARM
TRIGGER:-PT${reminderOffset.inMinutes}M
ACTION:DISPLAY
DESCRIPTION:${escape(title)}
END:VALARM
'''
        : '';

    return '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//PostCraft AI//Scheduled Post//EN
BEGIN:VEVENT
UID:$uid
DTSTAMP:${fmt(DateTime.now())}
DTSTART:${fmt(start)}
DTEND:${fmt(end)}
SUMMARY:${escape(title)}
DESCRIPTION:${escape(description)}
${alarm}END:VEVENT
END:VCALENDAR
''';
  }

  static String _humanOffset(Duration d) {
    if (d.inDays >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    if (d.inHours >= 1) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
    return '${d.inMinutes} min';
  }
}
