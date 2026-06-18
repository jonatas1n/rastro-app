import '../models/finance_profile.dart';
import 'database_service.dart';

/// Totais e registros recentes para a notificação persistente de resumo.
class SpendingSnapshot {
  final double weekTotal;
  final int weekCount;
  final double monthTotal;
  final int monthCount;
  final double previousWeekTotal;
  final int previousWeekCount;
  final double previousMonthSamePeriodTotal;
  final int previousMonthSamePeriodCount;

  const SpendingSnapshot({
    required this.weekTotal,
    required this.weekCount,
    required this.monthTotal,
    required this.monthCount,
    required this.previousWeekTotal,
    required this.previousWeekCount,
    required this.previousMonthSamePeriodTotal,
    required this.previousMonthSamePeriodCount,
  });

  int? get percentVsPreviousMonth =>
      _percentDelta(monthTotal, previousMonthSamePeriodTotal);

  int? get percentVsPreviousWeek =>
      _percentDelta(weekTotal, previousWeekTotal);
}

int? _percentDelta(double current, double previous) {
  if (previous <= 0) {
    if (current <= 0) return 0;
    return null;
  }
  return ((current - previous) / previous * 100).round();
}

DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// Mês corrente: dia 1 até hoje (fim do dia).
({DateTime start, DateTime end}) monthToDateRange(DateTime now) {
  final start = DateTime(now.year, now.month, 1);
  return (start: start, end: _endOfDay(now));
}

/// Semana anterior (segunda a domingo imediatamente antes da semana atual).
({DateTime start, DateTime end}) previousWeekRange(DateTime now) {
  final thisWeekStart = weekStart(now);
  final prevStart = thisWeekStart.subtract(const Duration(days: 7));
  final prevEnd = thisWeekStart.subtract(const Duration(milliseconds: 1));
  return (start: prevStart, end: prevEnd);
}

/// Mesmo número de dias no mês anterior (ex.: 1–17 deste mês vs 1–17 do mês passado).
({DateTime start, DateTime end}) previousMonthSamePeriodRange(DateTime now) {
  final prevMonthAnchor = DateTime(now.year, now.month - 1, 1);
  final lastDayPrevMonth =
      DateTime(prevMonthAnchor.year, prevMonthAnchor.month + 1, 0).day;
  final day = now.day.clamp(1, lastDayPrevMonth);
  final start = DateTime(prevMonthAnchor.year, prevMonthAnchor.month, 1);
  final end =
      _endOfDay(DateTime(prevMonthAnchor.year, prevMonthAnchor.month, day));
  return (start: start, end: end);
}

Future<SpendingSnapshot> loadSpendingSnapshot(DatabaseService db) async {
  final now = DateTime.now();
  final month = monthToDateRange(now);
  final prevMonth = previousMonthSamePeriodRange(now);
  final prevWeek = previousWeekRange(now);
  final weekStartMs = weekStart(now).millisecondsSinceEpoch;
  final weekEndMs = weekEnd(now).millisecondsSinceEpoch;

  final weekTotal = await db.sumBetween(weekStartMs, weekEndMs);
  final weekCount = await db.countBetween(weekStartMs, weekEndMs);
  final monthTotal = await db.sumBetween(
    month.start.millisecondsSinceEpoch,
    month.end.millisecondsSinceEpoch,
  );
  final monthCount = await db.countBetween(
    month.start.millisecondsSinceEpoch,
    month.end.millisecondsSinceEpoch,
  );
  final previousWeekTotal = await db.sumBetween(
    prevWeek.start.millisecondsSinceEpoch,
    prevWeek.end.millisecondsSinceEpoch,
  );
  final previousWeekCount = await db.countBetween(
    prevWeek.start.millisecondsSinceEpoch,
    prevWeek.end.millisecondsSinceEpoch,
  );
  final previousMonthSamePeriodTotal = await db.sumBetween(
    prevMonth.start.millisecondsSinceEpoch,
    prevMonth.end.millisecondsSinceEpoch,
  );
  final previousMonthSamePeriodCount = await db.countBetween(
    prevMonth.start.millisecondsSinceEpoch,
    prevMonth.end.millisecondsSinceEpoch,
  );

  return SpendingSnapshot(
    weekTotal: weekTotal,
    weekCount: weekCount,
    monthTotal: monthTotal,
    monthCount: monthCount,
    previousWeekTotal: previousWeekTotal,
    previousWeekCount: previousWeekCount,
    previousMonthSamePeriodTotal: previousMonthSamePeriodTotal,
    previousMonthSamePeriodCount: previousMonthSamePeriodCount,
  );
}

String formatComparisonLine(SpendingSnapshot snapshot) {
  return _formatPeriodComparison(
    scope: 'Até hoje no mês',
    reference: 'no mesmo período do mês passado',
    emptyCurrent: 'Ainda sem gastos neste mês',
    emptyPrevious: 'Sem referência no mês passado para comparar',
    equal: 'Mesmo ritmo de gasto do mês passado neste período',
    currentTotal: snapshot.monthTotal,
    percent: snapshot.percentVsPreviousMonth,
  );
}

String formatWeekComparisonLine(SpendingSnapshot snapshot) {
  return _formatPeriodComparison(
    scope: 'Esta semana',
    reference: 'na semana anterior',
    emptyCurrent: 'Ainda sem gastos nesta semana',
    emptyPrevious: 'Sem referência na semana anterior para comparar',
    equal: 'Mesmo ritmo de gasto da semana anterior',
    currentTotal: snapshot.weekTotal,
    percent: snapshot.percentVsPreviousWeek,
  );
}

String _formatPeriodComparison({
  required String scope,
  required String reference,
  required String emptyCurrent,
  required String emptyPrevious,
  required String equal,
  required double currentTotal,
  required int? percent,
}) {
  if (percent == null) {
    if (currentTotal <= 0) return emptyCurrent;
    return emptyPrevious;
  }
  if (percent == 0) return equal;
  if (percent > 0) {
    return '$scope: $percent% a mais $reference';
  }
  return '$scope: ${percent.abs()}% a menos $reference';
}
