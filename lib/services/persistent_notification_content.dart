import 'package:intl/intl.dart';

import '../models/finance_profile.dart';
import 'spending_insight_config.dart';
import 'spending_snapshot.dart';

class PersistentNotificationContent {
  const PersistentNotificationContent({
    required this.title,
    required this.summary,
    required this.detail,
  });

  final String title;
  final String summary;
  final String detail;
}

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

PersistentNotificationContent buildPersistentNotificationContent({
  required SpendingSnapshot snapshot,
  required FinanceProfile profile,
  required double periodSpend,
}) {
  final lines = <String>[];

  if (profile.weeklyLimitEnabled && (profile.weeklySpendingLimit ?? 0) > 0) {
    lines.add(_limitLine(
      'Teto semanal',
      snapshot.weekTotal,
      profile.weeklySpendingLimit!,
    ));
  }

  if (profile.monthlyLimitEnabled && (profile.monthlySpendingLimit ?? 0) > 0) {
    lines.add(_limitLine(
      'Teto do ciclo',
      periodSpend,
      profile.monthlySpendingLimit!,
    ));
  }

  if (profile.monthEndBalanceEnabled &&
      profile.monthEndTargetBalance != null &&
      profile.hasIncome) {
    final projected = profile.monthlyIncome - periodSpend;
    final target = profile.monthEndTargetBalance!;
    final gap = projected - target;
    final gapText = gap >= 0
        ? 'Acima da meta em ${_currency.format(gap)}'
        : 'Faltam ${_currency.format(-gap)} para a meta';
    lines.add(
      'Saldo previsto ${_currency.format(projected)} · '
      'meta ${_currency.format(target)} · $gapText',
    );
  }

  if (lines.isEmpty) {
    lines.add('Semana: ${_currency.format(snapshot.weekTotal)}');
    lines.add('Mês: ${_currency.format(snapshot.monthTotal)}');
  }

  lines.add(formatWeekComparisonLine(snapshot));
  lines.add(formatComparisonLine(snapshot));

  final headline = _headline(
    snapshot: snapshot,
    profile: profile,
    periodSpend: periodSpend,
  );

  return PersistentNotificationContent(
    title: 'Rastro',
    summary: headline,
    detail: lines.join('\n'),
  );
}

String _headline({
  required SpendingSnapshot snapshot,
  required FinanceProfile profile,
  required double periodSpend,
}) {
  if (profile.weeklyLimitEnabled && (profile.weeklySpendingLimit ?? 0) > 0) {
    final limit = profile.weeklySpendingLimit!;
    final pct = (snapshot.weekTotal / limit * 100).round();
    if (pct >= SpendingInsightConfig.limitBand100) {
      return 'Teto semanal no limite · ${_currency.format(snapshot.weekTotal)}';
    }
    if (pct >= SpendingInsightConfig.limitBand80) {
      return 'Teto semanal $pct% · ${_currency.format(snapshot.weekTotal)}';
    }
    return 'Semana ${_currency.format(snapshot.weekTotal)}';
  }
  if (profile.monthlyLimitEnabled && (profile.monthlySpendingLimit ?? 0) > 0) {
    final limit = profile.monthlySpendingLimit!;
    final pct = (periodSpend / limit * 100).round();
    if (pct >= SpendingInsightConfig.limitBand100) {
      return 'Teto do ciclo no limite · ${_currency.format(periodSpend)}';
    }
    if (pct >= SpendingInsightConfig.limitBand80) {
      return 'Ciclo $pct% · ${_currency.format(periodSpend)}';
    }
    return 'Ciclo ${_currency.format(periodSpend)}';
  }
  if (profile.monthEndBalanceEnabled &&
      profile.hasIncome &&
      profile.monthEndTargetBalance != null) {
    final projected = profile.monthlyIncome - periodSpend;
    return 'Saldo previsto ${_currency.format(projected)}';
  }
  return 'Semana ${_currency.format(snapshot.weekTotal)}';
}

String _limitLine(String label, double spent, double limit) {
  final pct = limit > 0 ? (spent / limit * 100).round().clamp(0, 999) : 0;
  final remaining = limit - spent;
  final status = remaining >= 0
      ? 'restam ${_currency.format(remaining)}'
      : 'excedeu ${_currency.format(-remaining)}';
  return '$label · ${_currency.format(spent)} / ${_currency.format(limit)} '
      '($pct%) · $status';
}
