import 'package:flutter_test/flutter_test.dart';
import 'package:rastro/models/finance_profile.dart';
import 'package:rastro/services/persistent_notification_content.dart';
import 'package:rastro/services/spending_snapshot.dart';

void main() {
  const snapshot = SpendingSnapshot(
    weekTotal: 200,
    weekCount: 4,
    monthTotal: 800,
    monthCount: 12,
    previousWeekTotal: 100,
    previousWeekCount: 2,
    previousMonthSamePeriodTotal: 700,
    previousMonthSamePeriodCount: 10,
  );

  test('prioriza teto semanal nas metas', () {
    const profile = FinanceProfile(
      weeklyLimitEnabled: true,
      weeklySpendingLimit: 500,
    );
    final content = buildPersistentNotificationContent(
      snapshot: snapshot,
      profile: profile,
      periodSpend: 300,
    );
    expect(content.summary, contains('Semana'));
    expect(content.detail, contains('Teto semanal'));
    expect(content.detail, isNot(contains('IFOOD')));
  });

  test('sem metas mostra totais de semana e mês', () {
    final content = buildPersistentNotificationContent(
      snapshot: snapshot,
      profile: const FinanceProfile(),
      periodSpend: 0,
    );
    expect(content.detail, contains('Semana:'));
    expect(content.detail, contains('Mês:'));
  });
}
