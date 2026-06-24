import 'package:shared_preferences/shared_preferences.dart';

/// Estado persistido para cooldown e faixas de teto.
class SpendingInsightPrefs {
  static const _insightsEnabledKey = 'spending_insights_enabled';
  static const _dailySummaryEnabledKey = 'spending_insights_daily_22h_enabled';
  static const _lastVariationDateKey = 'spending_insight_last_variation_date';
  static const _weeklyLimitBandKey = 'spending_insight_weekly_limit_band';
  static const _cycleLimitBandKey = 'spending_insight_cycle_limit_band';
  static const _limitStreakDaysKey = 'spending_insight_limit_streak_days';
  static const _limitStreakLastDateKey = 'spending_insight_limit_streak_last_date';
  static const _limitStreakNotifiedKey = 'spending_insight_limit_streak_notified';

  static Future<bool> get insightsEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_insightsEnabledKey) ?? true;
  }

  static Future<void> setInsightsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_insightsEnabledKey, value);
  }

  static Future<bool> get dailySummaryAt22Enabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dailySummaryEnabledKey) ?? true;
  }

  static Future<void> setDailySummaryAt22Enabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailySummaryEnabledKey, value);
  }

  static Future<String?> get lastVariationInsightDate async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastVariationDateKey);
  }

  static Future<void> markVariationInsightToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = isoDate(DateTime.now());
    await prefs.setString(_lastVariationDateKey, today);
  }

  static String isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<bool> canSendVariationInsightToday() async {
    final last = await lastVariationInsightDate;
    return last != isoDate(DateTime.now());
  }

  static Future<int> get weeklyLimitBand async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_weeklyLimitBandKey) ?? 0;
  }

  static Future<void> setWeeklyLimitBand(int band) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weeklyLimitBandKey, band);
  }

  static Future<int> get cycleLimitBand async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cycleLimitBandKey) ?? 0;
  }

  static Future<void> setCycleLimitBand(int band) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cycleLimitBandKey, band);
  }

  static Future<int> get limitStreakDays async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_limitStreakDaysKey) ?? 0;
  }

  static Future<String?> get limitStreakLastDate async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_limitStreakLastDateKey);
  }

  static Future<int> get limitStreakNotifiedAt async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_limitStreakNotifiedKey) ?? 0;
  }

  static Future<void> setLimitStreak({
    required int days,
    required String isoDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_limitStreakDaysKey, days);
    await prefs.setString(_limitStreakLastDateKey, isoDate);
  }

  static Future<void> setLimitStreakNotifiedAt(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_limitStreakNotifiedKey, days);
  }

  static Future<void> resetLimitStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_limitStreakDaysKey, 0);
    await prefs.remove(_limitStreakLastDateKey);
  }
}
