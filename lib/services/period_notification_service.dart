import 'package:flutter/foundation.dart';
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

  // The tone progresses across the five period days:
  // caring -> comforting -> gentle encouragement -> encouraging -> almost done.
  // Each time slot has five variations, and the deterministic rotation avoids
  // sending the same variation on consecutive period days.
  static const _messages = <List<List<String>>>[
    // Day 1 - caring
    [
      [
        'Good morning en thangameee ❤️ Nalla thoonguniya ma? Inniku flow epdi iruku?',
        'Ezhundhutiya chellame? 🥺❤️ First saptiya? Body ah konjam paathuko ma.',
        'Good morning kuttyyy ❤️ Inniku konjam slow-va po ma, un body-ku rest venum.',
        'Morning diii thangame 🌸 Nalla irukiya? Flow la okay-va? 🫂',
        'Ezhundhacha en azhagiye? 🥰 Breakfast skip pannadha ma.',
      ],
      [
        'Saptiya en thangame? 🥺❤️ Lunch skip panna koodadhu ma.',
        'Chellameee, water kudichiya? 💗 Konjam konjam ah kudichuko ma.',
        'En kutty ponnu saptiya? 🥰 Flow okay-va? Konjam rest eduthuko.',
        'Thangame ❤️ Body tired ah iruka? Konjam relax pannitu sapdu ma.',
        'Saaptiya ma? 🫶 Unakku pidicha edhavadhu nalla sapdu… energy venum chellam.',
      ],
      [
        'Dinner saptiya en thangame? ❤️ Seekiram thoongu ma, nalla rest eduthuko.',
        'Good night en chellameee 🥺🫂 Inniku romba tired ah irundha, ellame vittutu rest edu.',
        'Thangame ❤️ Flow la okay-va? Bed-ku po ma, unakku konjam extra care venum.',
        'En azhagiyeee 🌙❤️ Water kudichitu comfortable ah thoongu ma.',
        'Good night kutty ❤️ Naan iruken… nee nalla rest eduthuko. 🫂',
      ],
    ],
    // Day 2 - comforting
    [
      [
        'Good morning en thangameee ❤️ Inniku konjam comfortable ah irukiya ma?',
        'Ezhundhutiya chellame? 🥺❤️ Slow-va start pannu ma, body-ku time kudu.',
        'Morning kuttyyy 🌸 Flow epdi iruku? Nalla rest eduthuko ma.',
        'Good morning azhagiye ❤️ Inniku unakku konjam extra care venum ma.',
        'Morning diii thangame 🫂 Breakfast saptiya? Unna nalla paathuko ma.',
      ],
      [
        'Saptiya thangame? ❤️ Konjam warm ah nalla sapdu ma.',
        'Chellameee 💗 Water kudichitu konjam relax panniko ma.',
        'En kutty ponnu 🥰 Lunch saptiya? Body tired ah irundha rest edu.',
        'Thangame ❤️ Inniku konjam slow-va po ma, rush panna vendam.',
        'Saaptiya ma? 🫶 Unakku comfort ah irukra food konjam sapdu chellam.',
      ],
      [
        'Dinner saptiya en thangame? ❤️ Inniku nalla rest eduthuko ma.',
        'Good night chellameee 🥺🫂 Body tired ah irundha seekiram thoongu ma.',
        'Thangame ❤️ Flow okay-va? Comfortable ah irundha podhum ma.',
        'En azhagiyeee 🌙❤️ Water kudichitu cozy ah thoongu ma.',
        'Good night kutty ❤️ Naan iruken, nee worry pannama rest edu. 🫂',
      ],
    ],
    // Day 3 - gentle encouragement
    [
      [
        'Good morning thangame ❤️ Inniku konjam better ah feel panriya?',
        'Ezhundhutiya chellame? 🥰 Konjam energy save pannitu po ma.',
        'Morning kuttyyy 🌸 Day by day konjam better ah irukum ma.',
        'Good morning azhagiye 🫂 Un body solradha listen pannu ma.',
        'Morning diii ❤️ Breakfast skip pannadha, take care ma.',
      ],
      [
        'Saptiya en thangame? 🥺❤️ Water nalla kudichuko ma.',
        'Chellameee 💗 Konjam rest eduthuko, nee romba tired ah irundha.',
        'En kutty ponnu 🥰 Lunch saptiya? Slowly take care of yourself ma.',
        'Thangame ❤️ Inniku body epdi feel aagudhu? Konjam relax panniko.',
        'Saaptiya ma? 🫶 Nalla sapdu, energy venum chellam.',
      ],
      [
        'Dinner saptiya thangame? ❤️ Inniku nalla rest eduthuko.',
        'Good night en chellameee 🥺🫂 Today konjam better ah irundha happy ma.',
        'Thangame ❤️ Flow okay-va? Bed-ku po ma, tomorrow fresh ah ezhundhiralam.',
        'En azhagiyeee 🌙❤️ Water kudichitu comfortable ah thoongu ma.',
        'Good night kutty ❤️ Naan iruken… nalla rest eduthuko. 🫂',
      ],
    ],
    // Day 4 - encouraging
    [
      [
        'Good morning thangame ❤️ Konjam konjama cycle mudinjitu iruku ma.',
        'Ezhundhutiya chellame? 🥰 Almost there ma, but still take care.',
        'Morning kuttyyy 🌸 Inniku konjam light ah feel panriya?',
        'Good morning azhagiye ❤️ Nalla saptiya? Un body-ku innum konjam care kudu ma.',
        'Morning diii thangame 🫂 One more gentle day, take it slow ma.',
      ],
      [
        'Saptiya en thangame? ❤️ Water kudichuko, almost there ma.',
        'Chellameee 💗 Lunch skip pannadha, konjam energy venum.',
        'En kutty ponnu 🥰 Flow okay-va? Konjam more rest eduthuko ma.',
        'Thangame ❤️ Body tired ah irundha relax pannitu sapdu ma.',
        'Saaptiya ma? 🫶 Nalla sapdu chellam, you are doing okay.',
      ],
      [
        'Dinner saptiya en thangame? ❤️ Innum konjam care, then good rest ma.',
        'Good night chellameee 🥺🫂 Almost through, seekiram thoongu ma.',
        'Thangame ❤️ Flow okay-va? Comfortable ah bed-ku po ma.',
        'En azhagiyeee 🌙❤️ Water kudichitu cozy ah rest edu ma.',
        'Good night kutty ❤️ Naan iruken… nalla rest eduthuko. 🫂',
      ],
    ],
    // Day 5 - almost done
    [
      [
        'Good morning thangame ❤️ Inniku flow epdi iruku? Almost there ma.',
        'Ezhundhacha en azhagiye? 🥰 Last day ah irukalam, but still take care ma.',
        'Good morning kuttyyy 🌸 Konjam better ah feel panriya? Take it easy ma.',
        'Morning diii thangame 🫂 Cycle mudiyara stage ma, nalla paathuko.',
        'Ezhundhutiya chellame? ❤️ Breakfast saptiya? One more caring day ma.',
      ],
      [
        'Saptiya en thangame? 🥺❤️ Water kudichuko, almost done ma.',
        'Chellameee 💗 Lunch nalla sapdu ma, body-ku energy venum.',
        'En kutty ponnu 🥰 Flow okay-va? Konjam more care today.',
        'Thangame ❤️ Rest eduthuko ma, soon this cycle will be over.',
        'Saaptiya ma? 🫶 Unakku pidicha nalla food sapdu chellam.',
      ],
      [
        'Dinner saptiya en thangame? ❤️ Nalla rest eduthuko ma.',
        'Good night en chellameee 🥺🫂 Soon this cycle will be over, sleep well.',
        'Thangame ❤️ Flow la okay-va? Bed-ku po ma, extra care today.',
        'En azhagiyeee 🌙❤️ Water kudichitu comfortable ah thoongu ma.',
        'Good night kutty ❤️ Naan iruken… nee nalla rest eduthuko. 🫂',
      ],
    ],
  ];

  Future<void> initialize() async {
    // Local scheduled notifications are for Android/iOS builds. The 19.x
    // notification plugin does not provide a web implementation, so skip it
    // on Flutter Web instead of allowing the notification plugin to break app
    // startup with a LateInitializationError.
    if (kIsWeb) return;

    try {
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
    } catch (_) {
      // Notification setup must never prevent the cycle tracker from loading.
    }
  }

  Future<void> syncWithLatestCycle(List<PeriodCycle> cycles) async {
    if (kIsWeb) return;

    try {
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
          _messageFor(dayIndex, slot),
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
    } catch (_) {
      // Notifications are optional; a platform/plugin issue must not surface
      // as an application error banner.
    }
  }

  String _messageFor(int dayIndex, int slot) {
    final options = _messages[dayIndex][slot];
    // Move through the five variations as the period progresses. The offset
    // differs by time slot so morning, afternoon, and night do not mirror each
    // other, and consecutive days never use the same variation.
    final index = (dayIndex + (slot * 2)) % options.length;
    return options[index];
  }

  static const _hours = [9, 13, 21];

  int _notificationId(int day, int slot) => day * 10 + slot + 1;

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
