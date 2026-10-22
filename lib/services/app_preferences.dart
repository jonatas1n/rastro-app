import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const _persistentSummaryKey = 'persistent_spending_summary_enabled';
  static const _historySwipeHintSeenKey = 'history_swipe_hint_seen';
  static const _transactionAlertKey = 'transaction_alert_enabled';
  static const _appLockKey = 'app_lock_enabled';

  static Future<bool> get appLockEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appLockKey) ?? false;
  }

  static Future<void> setAppLockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockKey, value);
  }

  static Future<bool> get transactionAlertEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_transactionAlertKey) ?? true;
  }

  static Future<void> setTransactionAlertEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_transactionAlertKey, value);
  }

  static Future<bool> get historySwipeHintSeen async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_historySwipeHintSeenKey) ?? false;
  }

  static Future<void> setHistorySwipeHintSeen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_historySwipeHintSeenKey, value);
  }

  static Future<bool> get persistentSpendingSummaryEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_persistentSummaryKey) ?? true;
  }

  static Future<void> setPersistentSpendingSummaryEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_persistentSummaryKey, value);
  }
}
