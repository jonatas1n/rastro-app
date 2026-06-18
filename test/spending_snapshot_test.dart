import 'package:flutter_test/flutter_test.dart';
import 'package:rastro/services/spending_snapshot.dart';

void main() {
  group('previousMonthSamePeriodRange', () {
    test('limita o dia ao último dia do mês anterior', () {
      final now = DateTime(2026, 3, 31);
      final range = previousMonthSamePeriodRange(now);
      expect(range.start, DateTime(2026, 2, 1));
      expect(range.end.day, 28);
      expect(range.end.month, 2);
    });

    test('usa o mesmo dia quando cabe no mês anterior', () {
      final now = DateTime(2026, 6, 17);
      final range = previousMonthSamePeriodRange(now);
      expect(range.start, DateTime(2026, 5, 1));
      expect(range.end.day, 17);
      expect(range.end.month, 5);
    });
  });

  group('previousWeekRange', () {
    test('cobre a semana imediatamente anterior', () {
      final now = DateTime(2026, 6, 18); // quinta
      final range = previousWeekRange(now);
      expect(range.start, DateTime(2026, 6, 8));
      expect(range.end.day, 14);
      expect(range.end.month, 6);
    });
  });

  group('formatComparisonLine', () {
    test('mais gasto no mês', () {
      final line = formatComparisonLine(const SpendingSnapshot(
        weekTotal: 0,
        weekCount: 0,
        monthTotal: 110,
        monthCount: 2,
        previousWeekTotal: 0,
        previousWeekCount: 0,
        previousMonthSamePeriodTotal: 100,
        previousMonthSamePeriodCount: 1,
      ));
      expect(line, 'Até hoje no mês: 10% a mais no mesmo período do mês passado');
    });

    test('menos gasto no mês', () {
      final line = formatComparisonLine(const SpendingSnapshot(
        weekTotal: 0,
        weekCount: 0,
        monthTotal: 90,
        monthCount: 1,
        previousWeekTotal: 0,
        previousWeekCount: 0,
        previousMonthSamePeriodTotal: 100,
        previousMonthSamePeriodCount: 2,
      ));
      expect(line, 'Até hoje no mês: 10% a menos no mesmo período do mês passado');
    });
  });

  group('formatWeekComparisonLine', () {
    test('mais gasto na semana', () {
      final line = formatWeekComparisonLine(const SpendingSnapshot(
        weekTotal: 200,
        weekCount: 3,
        monthTotal: 0,
        monthCount: 0,
        previousWeekTotal: 100,
        previousWeekCount: 2,
        previousMonthSamePeriodTotal: 0,
        previousMonthSamePeriodCount: 0,
      ));
      expect(line, 'Esta semana: 100% a mais na semana anterior');
    });
  });
}
