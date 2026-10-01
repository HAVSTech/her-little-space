import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/period_cycle.dart';

class PeriodNotificationService {
  PeriodNotificationService._();

  static final instance = PeriodNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'period_care';
  static const _channelName = 'Period care';
  static const _channelDescription =
      'Cute daily care reminders during the first five period days.';

  static const _messages = <List<String>>[
    [
      'Good morning en thangameee ❤️ Nalla thoonguniya ma? Inniku flow epdi iruku?',
      'Saptiya ma? 🥺❤️ Water nalla kudichuko, flow la okay-va?',
      'Dinner saptiya thangame? ❤️ Konjam rest eduthuko ma.',
    ],
    [
      'Good morning ma ❤️ Nalla thoonguniya? Flow epdi iruku?',
      'Saptiya ma? 🥺 Lunch skip pannadha. Water kudichuko ❤️',
      'Thangame, flow la okay-va? ❤️ Seekiram thoongi rest eduthuko ma.',
    ],
    [
      'Morning thangame ❤️ Inniku konjam better ah feel panriya?',
      'Saaptiya ma? 🤍 Body tired ah irundha konjam rest eduthuko.',
      'Dinner saptiya? ❤️ Inniku nalla rest eduthuko thangame.',
    ],
    [
      'Good morning thangame ❤️ Flow epdi iruku ma? Better ah iruka?',
      'Saptiya ma? 🌸 Water kudichiya? Take care of yourself.',
      'Thangame ❤️ Konjam konjama cycle mudinjitu iruku. Nalla rest eduthuko ma.',
    ],
    [
      'Good morning thangame ❤️ Inniku flow epdi iruku? Almost there ma.',
      'Saaptiya ma? 🥰 Water kudichuko, konjam more care today.',
      'Last day ah irukalam thangame ❤️ Take care ma, soon this cycle will be over. 🫂',
    ],
  ];

  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> syncWithLatestCycle(List<PeriodCycle> cycles) async {
    await _plugin.cancelAll();

    if (cycles.isEmpty) return;

    final startDate = _dateOnly(cycles.first.startDate);
    final today = _dateOnly(DateTime.now());
    final elapsed = today.difference(startDate).inDays;

    if (elapsed < 0 || elapsed > 4) return;

    for (var dayIndex = elapsed; dayIndex < 5; dayIndex++) {
      final day = startDate.add(Duration(days: dayIndex));

      for (var slot = 0; slot < 3; slot++) {
        final scheduled = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          _hours[slot],
        );

        if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) continue;

        await _plugin.zonedSchedule(
          _notificationId(dayIndex, slot),
          "Harini's Little Space ❤️",
          _messages[dayIndex][slot],
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  static const _hours = [9, 13, 21];

  int _notificationId(int day, int slot) => day * 10 + slot + 1;

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
