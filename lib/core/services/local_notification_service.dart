import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'jagabersama_schedules';
  static const String _channelName = 'Pengingat Jadwal Kesehatan';
  static const String _channelDesc =
      'Notifikasi pengingat kontrol dokter, lab, dan minum obat keluarga';

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {
      // Fallback ke zona default sistem jika lokasi tidak ditemukan
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  int _notificationIdFromSchedule(String scheduleId) {
    return scheduleId.hashCode & 0x7fffffff;
  }

  Future<void> scheduleReminder({
    required String scheduleId,
    required String memberName,
    required String title,
    required DateTime scheduledAt,
    required int reminderMinutesBefore,
    String? location,
  }) async {
    try {
      await initialize();

      final triggerTime = scheduledAt
          .toLocal()
          .subtract(Duration(minutes: reminderMinutesBefore));
      if (triggerTime.isBefore(DateTime.now())) {
        return;
      }

      final tzDateTime = tz.TZDateTime.from(triggerTime, tz.local);
      final body = location != null && location.isNotEmpty
          ? '$memberName • $title di $location'
          : '$memberName • $title';

      await _plugin.zonedSchedule(
        _notificationIdFromSchedule(scheduleId),
        'Pengingat Jadwal Kesehatan',
        body,
        tzDateTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi lokal: $e');
    }
  }

  Future<void> cancelReminder(String scheduleId) async {
    try {
      await initialize();
      await _plugin.cancel(_notificationIdFromSchedule(scheduleId));
    } catch (e) {
      debugPrint('Gagal membatalkan notifikasi: $e');
    }
  }
}
