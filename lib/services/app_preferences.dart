import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const _persistentSummaryKey = 'persistent_spending_summary_enabled';

  static Future<bool> get persistentSpendingSummaryEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_persistentSummaryKey) ?? true;
  }

  static Future<void> setPersistentSpendingSummaryEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_persistentSummaryKey, value);
  }
}
