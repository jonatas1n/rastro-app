/// Limiares e regras para alertas de variação de consumo.
class SpendingInsightConfig {
  SpendingInsightConfig._();

  static const moderatePct = 25;
  static const strongPct = 40;
  static const monthDownPct = 20;

  /// Dias com gasto nos últimos 7 (excluindo hoje) para comparar dia vs média.
  static const minPastDaysForDayAverage = 3;

  static const minPreviousWeekTotal = 10.0;
  static const minMonthTotalForCompare = 30.0;

  static const atypicalMedianMultiplier = 2.0;
  static const atypicalFloorAmount = 80.0;

  static const limitBand80 = 80;
  static const limitBand100 = 100;
  static const limitBand120 = 120;

  static const categoryUpPct = 40;
  static const streakUnderLimitDays = 5;
  static const streakLimitFraction = 0.9;

  static const dailySummaryHour = 22;
}
