import '../models/finance_profile.dart';
import 'app_preferences.dart';
import 'database_service.dart';
import 'local_notification_service.dart';
import 'persistent_notification_content.dart';
import 'spending_snapshot.dart';

/// Notificação fixa (ongoing): valores e metas do usuário.
class SpendingSummaryNotification {
  static final _db = DatabaseService();
  static bool _running = false;

  static Future<void> startIfEnabled() async {
    final enabled = await AppPreferences.persistentSpendingSummaryEnabled;
    if (!enabled) {
      _running = false;
      return;
    }
    await start();
  }

  static Future<void> start() async {
    final enabled = await AppPreferences.persistentSpendingSummaryEnabled;
    if (!enabled) {
      _running = false;
      await LocalNotificationService.cancelPersistentSpendingSummary();
      return;
    }
    _running = true;
    await LocalNotificationService.ensureAndroidPostPermission();
    await refresh();
  }

  static Future<void> refresh() async {
    if (!await AppPreferences.persistentSpendingSummaryEnabled) {
      _running = false;
      await LocalNotificationService.cancelPersistentSpendingSummary();
      return;
    }
    if (!_running) {
      _running = true;
    }

    final snapshot = await loadSpendingSnapshot(_db);
    final profile = await _db.getFinanceProfile();
    final period = financePeriodFor(DateTime.now(), profile);
    final periodSpend = await _db.sumBetween(
      period.start.millisecondsSinceEpoch,
      period.end.millisecondsSinceEpoch,
    );

    final content = buildPersistentNotificationContent(
      snapshot: snapshot,
      profile: profile,
      periodSpend: periodSpend,
    );

    await LocalNotificationService.showPersistentSpendingSummary(
      title: content.title,
      summary: content.summary,
      detail: content.detail,
    );
  }

  static Future<void> stop() async {
    _running = false;
    await LocalNotificationService.cancelPersistentSpendingSummary();
  }

  static Future<void> setEnabled(bool enabled) async {
    await AppPreferences.setPersistentSpendingSummaryEnabled(enabled);
    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }
}
