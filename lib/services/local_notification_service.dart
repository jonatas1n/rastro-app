import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/transaction.dart';

final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _tzReady = false;

  static Future<void> init() async {
    if (!_tzReady) {
      tz_data.initializeTimeZones();
      _tzReady = true;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  /// Notificação imediata ao detectar um gasto
  static Future<void> showTransactionAlert(Transaction tx) async {
    final cat = tx.category;
    await _plugin.show(
      tx.hashCode,
      '${cat.emoji} ${cat.label} · ${tx.place}',
      _fmt.format(tx.amount),
      NotificationDetails(
        android: _androidDetails(
          channelId: 'transactions',
          channelName: 'Gastos',
        ),
      ),
    );
  }

  /// Resumo diário — agendado para 22h
  static Future<void> scheduleDailySummary({
    required double totalToday,
    required double avgWeek,
    required String topCategory,
  }) async {
    final diff = totalToday - avgWeek;
    final diffPct = avgWeek > 0 ? (diff / avgWeek * 100).round() : 0;
    final arrow = diff > 0 ? '↑' : '↓';

    await _plugin.zonedSchedule(
      999,
      'Resumo do dia · ${_fmt.format(totalToday)}',
      '$topCategory  ·  $arrow${diffPct.abs()}% vs média da semana',
      _todayAt22(),
      NotificationDetails(
        android: _androidDetails(
          channelId: 'daily_summary',
          channelName: 'Resumo diário',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static AndroidNotificationDetails _androidDetails({
    required String channelId,
    required String channelName,
  }) =>
      AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

  static tz.TZDateTime _todayAt22() {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22,
      0,
      0,
    );
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }
}
