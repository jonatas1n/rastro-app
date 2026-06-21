import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/transaction.dart';

final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _tzReady = false;

  static const persistentSpendingSummaryId = 1001;
  static const debugTestNotificationId = 9998;

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
    await ensureAndroidPostPermission();
  }

  static Future<void> ensureAndroidPostPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Resumo fixo na barra de status (não dismissível; desligar em Configurações).
  static Future<void> showPersistentSpendingSummary({
    required String title,
    required String summary,
    required String detail,
  }) async {
    await _plugin.show(
      persistentSpendingSummaryId,
      title,
      summary,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'spending_summary',
          'Resumo de gastos',
          channelDescription:
              'Acompanha gastos e metas. Desative em Renda e metas.',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.status,
          styleInformation: BigTextStyleInformation(
            detail,
            contentTitle: summary,
            summaryText: title,
            htmlFormatBigText: false,
          ),
        ),
      ),
    );
  }

  static Future<void> cancelPersistentSpendingSummary() async {
    await _plugin.cancel(persistentSpendingSummaryId);
  }

  /// Notificação visível na barra para testar o listener (tela de debug).
  static Future<void> showDebugTestNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      debugTestNotificationId,
      '[Debug] $title',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'debug_test',
          'Testes de debug',
          channelDescription:
              'Notificações geradas pela tela de debug do Rastro.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
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

    await _plugin.zonedSchedule(
      999,
      'Resumo do dia · ${_fmt.format(totalToday)}',
      '$topCategory · ${diffPct.abs()}% ${diff > 0 ? 'acima' : 'abaixo'} da média diária recente',
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
