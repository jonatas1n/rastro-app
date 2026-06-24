import 'package:intl/intl.dart';

import '../models/finance_profile.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'local_notification_service.dart';
import 'spending_insight_config.dart';
import 'spending_insight_prefs.dart';
import 'spending_snapshot.dart';

class _InsightCandidate {
  final int notificationId;
  final String title;
  final String body;
  final bool usesVariationCooldown;
  final int priority;

  const _InsightCandidate({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.usesVariationCooldown,
    required this.priority,
  });
}

/// Avalia regras de variação e dispara notificações locais (com cooldown).
class SpendingInsightService {
  SpendingInsightService._();
  static final _db = DatabaseService();
  static final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  static Future<void> evaluate({
    Transaction? newTransaction,
    bool rescheduleDailySummary = false,
  }) async {
    if (rescheduleDailySummary && await SpendingInsightPrefs.dailySummaryAt22Enabled) {
      await _scheduleDailySummary();
    }

    if (!await SpendingInsightPrefs.insightsEnabled) return;

    await LocalNotificationService.ensureAndroidPostPermission();

    final candidates = <_InsightCandidate>[];
    candidates.addAll(await _limitInsights());
    if (newTransaction != null) {
      final atypical = await _atypicalPurchaseInsight(newTransaction);
      if (atypical != null) candidates.add(atypical);
    }
    candidates.addAll(await _variationInsights());
    candidates.addAll(await _categoryInsights());
    final streak = await _limitStreakInsight(await _db.getFinanceProfile());
    if (streak != null) candidates.add(streak);

    if (candidates.isEmpty) return;

    candidates.sort((a, b) => b.priority.compareTo(a.priority));
    final top = candidates.first;

    if (top.usesVariationCooldown &&
        !await SpendingInsightPrefs.canSendVariationInsightToday()) {
      final limitOnly = candidates.where((c) => !c.usesVariationCooldown);
      if (limitOnly.isEmpty) return;
      await _show(limitOnly.first);
      return;
    }

    await _show(top);
    if (top.usesVariationCooldown) {
      await SpendingInsightPrefs.markVariationInsightToday();
    }
  }

  static Future<void> _show(_InsightCandidate c) async {
    await LocalNotificationService.showSpendingInsight(
      id: c.notificationId,
      title: c.title,
      body: c.body,
    );
  }

  static Future<List<_InsightCandidate>> _limitInsights() async {
    final profile = await _db.getFinanceProfile();
    final snapshot = await loadSpendingSnapshot(_db);
    final out = <_InsightCandidate>[];

    if (profile.weeklyLimitEnabled && (profile.weeklySpendingLimit ?? 0) > 0) {
      final limit = profile.weeklySpendingLimit!;
      final pct = snapshot.weekTotal / limit * 100;
      final band = _bandForPct(pct);
      final prev = await SpendingInsightPrefs.weeklyLimitBand;
      if (band > prev && band >= SpendingInsightConfig.limitBand80) {
        await SpendingInsightPrefs.setWeeklyLimitBand(band);
        out.add(_limitCandidate(
          id: 2010,
          label: 'Teto semanal',
          spent: snapshot.weekTotal,
          limit: limit,
          band: band,
          priority: band >= 100 ? 100 : 90,
        ));
      } else if (band < prev) {
        await SpendingInsightPrefs.setWeeklyLimitBand(band);
      }
    }

    if (profile.monthlyLimitEnabled && (profile.monthlySpendingLimit ?? 0) > 0) {
      final period = financePeriodFor(DateTime.now(), profile);
      final periodSpend = await _db.sumBetween(
        period.start.millisecondsSinceEpoch,
        period.end.millisecondsSinceEpoch,
      );
      final limit = profile.monthlySpendingLimit!;
      final pct = periodSpend / limit * 100;
      final band = _bandForPct(pct);
      final prev = await SpendingInsightPrefs.cycleLimitBand;
      if (band > prev && band >= SpendingInsightConfig.limitBand80) {
        await SpendingInsightPrefs.setCycleLimitBand(band);
        out.add(_limitCandidate(
          id: 2011,
          label: 'Teto do ciclo',
          spent: periodSpend,
          limit: limit,
          band: band,
          priority: band >= 100 ? 99 : 89,
        ));
      } else if (band < prev) {
        await SpendingInsightPrefs.setCycleLimitBand(band);
      }
    }

    return out;
  }

  static _InsightCandidate _limitCandidate({
    required int id,
    required String label,
    required double spent,
    required double limit,
    required int band,
    required int priority,
  }) {
    final pct = (spent / limit * 100).round();
    String title;
    String body;
    if (band >= SpendingInsightConfig.limitBand120) {
      title = '$label estourado';
      body =
          '${_currency.format(spent)} de ${_currency.format(limit)} ($pct%)';
    } else if (band >= SpendingInsightConfig.limitBand100) {
      title = '$label no limite';
      body =
          'Você atingiu o teto · ${_currency.format(spent)} / ${_currency.format(limit)}';
    } else {
      title = '$label quase no limite';
      body =
          '$pct% do teto · faltam ${_currency.format(limit - spent)}';
    }
    return _InsightCandidate(
      notificationId: id,
      title: title,
      body: body,
      usesVariationCooldown: false,
      priority: priority,
    );
  }

  static int _bandForPct(double pct) {
    if (pct >= SpendingInsightConfig.limitBand120) {
      return SpendingInsightConfig.limitBand120;
    }
    if (pct >= SpendingInsightConfig.limitBand100) {
      return SpendingInsightConfig.limitBand100;
    }
    if (pct >= SpendingInsightConfig.limitBand80) {
      return SpendingInsightConfig.limitBand80;
    }
    return 0;
  }

  static Future<_InsightCandidate?> _atypicalPurchaseInsight(
    Transaction tx,
  ) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final median = await _db.medianAmountBetween(
      start.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
      excludeLocalId: tx.localId,
    );
    final threshold = median == null
        ? SpendingInsightConfig.atypicalFloorAmount
        : [
            median * SpendingInsightConfig.atypicalMedianMultiplier,
            SpendingInsightConfig.atypicalFloorAmount,
          ].reduce((a, b) => a > b ? a : b);

    if (tx.amount < threshold) return null;

    return _InsightCandidate(
      notificationId: 2020,
      title: 'Compra acima do usual',
      body:
          '${tx.place} · ${_currency.format(tx.amount)} · bem acima da sua mediana recente',
      usesVariationCooldown: true,
      priority: 70,
    );
  }

  static Future<List<_InsightCandidate>> _variationInsights() async {
    final snapshot = await loadSpendingSnapshot(_db);
    final out = <_InsightCandidate>[];

    final dayAvg = await _recentDailyAverageExcludingToday();
    final todayTotal = await _todayTotal();
    if (dayAvg >= SpendingInsightConfig.minPreviousWeekTotal && todayTotal > 0) {
      final pct = ((todayTotal - dayAvg) / dayAvg * 100).round();
      if (pct >= SpendingInsightConfig.moderatePct) {
        out.add(_InsightCandidate(
          notificationId: 2001,
          title: 'Ritmo alto hoje',
          body:
              '${_currency.format(todayTotal)} hoje · $pct% acima da sua média recente',
          usesVariationCooldown: true,
          priority: pct >= SpendingInsightConfig.strongPct ? 60 : 50,
        ));
      } else if (pct <= -SpendingInsightConfig.moderatePct) {
        out.add(_InsightCandidate(
          notificationId: 2001,
          title: 'Dia mais calmo',
          body:
              '${_currency.format(todayTotal)} hoje · ${pct.abs()}% abaixo da média recente',
          usesVariationCooldown: true,
          priority: 40,
        ));
      }
    }

    final weekPct = snapshot.percentVsPreviousWeek;
    if (weekPct != null &&
        snapshot.previousWeekTotal >= SpendingInsightConfig.minPreviousWeekTotal &&
        snapshot.weekTotal >= SpendingInsightConfig.minPreviousWeekTotal) {
      if (weekPct >= SpendingInsightConfig.moderatePct) {
        out.add(_InsightCandidate(
          notificationId: 2002,
          title: 'Semana mais pesada',
          body:
              '+$weekPct% vs semana passada · '
              '${_currency.format(snapshot.weekTotal)} vs '
              '${_currency.format(snapshot.previousWeekTotal)}',
          usesVariationCooldown: true,
          priority: weekPct >= SpendingInsightConfig.strongPct ? 55 : 45,
        ));
      } else if (weekPct <= -SpendingInsightConfig.moderatePct) {
        out.add(_InsightCandidate(
          notificationId: 2002,
          title: 'Boa semana',
          body:
              '${weekPct.abs()}% a menos que a semana passada · continue assim',
          usesVariationCooldown: true,
          priority: 35,
        ));
      }
    }

    final monthPct = snapshot.percentVsPreviousMonth;
    if (monthPct != null &&
        snapshot.previousMonthSamePeriodTotal >=
            SpendingInsightConfig.minMonthTotalForCompare &&
        snapshot.monthTotal >= SpendingInsightConfig.minMonthTotalForCompare) {
      if (monthPct >= SpendingInsightConfig.moderatePct) {
        out.add(_InsightCandidate(
          notificationId: 2003,
          title: 'Ritmo do mês',
          body:
              'Até hoje no mês: $monthPct% a mais que no mesmo período do mês passado',
          usesVariationCooldown: true,
          priority: 48,
        ));
      } else if (monthPct <= -SpendingInsightConfig.monthDownPct) {
        out.add(_InsightCandidate(
          notificationId: 2003,
          title: 'Mês mais leve',
          body:
              'Até hoje: ${monthPct.abs()}% a menos que no mesmo período do mês passado',
          usesVariationCooldown: true,
          priority: 38,
        ));
      }
    }

    final projection = await _monthProjectionInsight(snapshot);
    if (projection != null) out.add(projection);

    return out;
  }

  static Future<List<_InsightCandidate>> _categoryInsights() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final monthStartMs = monthStart.millisecondsSinceEpoch;
    final monthEndMs = monthEnd.millisecondsSinceEpoch;

    _InsightCandidate? best;
    var bestPct = 0;

    for (final cat in TransactionCategory.values) {
      final mtd = await _db.sumBetweenCategory(monthStartMs, monthEndMs, cat);
      if (mtd < SpendingInsightConfig.minMonthTotalForCompare) continue;

      var fourWeekTotal = 0.0;
      for (var w = 1; w <= 4; w++) {
        final weekEnd = now.subtract(Duration(days: (w - 1) * 7));
        final weekStart = weekEnd.subtract(const Duration(days: 6));
        final start = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day,
        ).millisecondsSinceEpoch;
        final end = DateTime(
          weekEnd.year,
          weekEnd.month,
          weekEnd.day,
          23,
          59,
          59,
          999,
        ).millisecondsSinceEpoch;
        fourWeekTotal += await _db.sumBetweenCategory(start, end, cat);
      }
      final avgWeekly = fourWeekTotal / 4;
      if (avgWeekly < SpendingInsightConfig.minPreviousWeekTotal) continue;

      final expectedMtd = avgWeekly * (now.day / 7);
      if (expectedMtd <= 0) continue;
      final pct = ((mtd - expectedMtd) / expectedMtd * 100).round();
      if (pct >= SpendingInsightConfig.categoryUpPct && pct > bestPct) {
        bestPct = pct;
        best = _InsightCandidate(
          notificationId: 2030 + cat.index,
          title: '${cat.label} em alta',
          body:
              '${cat.emoji} ${cat.label} está $pct% acima do seu usual este mês',
          usesVariationCooldown: true,
          priority: 36,
        );
      }
    }

    if (best == null) return [];
    return [best];
  }

  static Future<_InsightCandidate?> _limitStreakInsight(
    FinanceProfile profile,
  ) async {
    if (!profile.weeklyLimitEnabled || (profile.weeklySpendingLimit ?? 0) <= 0) {
      await SpendingInsightPrefs.resetLimitStreak();
      return null;
    }

    final snapshot = await loadSpendingSnapshot(_db);
    final limit = profile.weeklySpendingLimit!;
    final under =
        snapshot.weekTotal < limit * SpendingInsightConfig.streakLimitFraction;

    final today = SpendingInsightPrefs.isoDate(DateTime.now());
    if (!under) {
      await SpendingInsightPrefs.resetLimitStreak();
      return null;
    }

    final last = await SpendingInsightPrefs.limitStreakLastDate;
    var days = await SpendingInsightPrefs.limitStreakDays;
    if (last != today) {
      days += 1;
      await SpendingInsightPrefs.setLimitStreak(days: days, isoDate: today);
    }

    if (days < SpendingInsightConfig.streakUnderLimitDays) return null;
    final notified = await SpendingInsightPrefs.limitStreakNotifiedAt;
    if (notified >= days) return null;

    await SpendingInsightPrefs.setLimitStreakNotifiedAt(days);
    return _InsightCandidate(
      notificationId: 2040,
      title: 'Dentro do teto',
      body:
          '$days dias seguidos abaixo de 90% do teto semanal — continue assim',
      usesVariationCooldown: true,
      priority: 32,
    );
  }

  static Future<_InsightCandidate?> _monthProjectionInsight(
    SpendingSnapshot snapshot,
  ) async {
    final now = DateTime.now();
    if (now.day < 5) return null;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final projected = snapshot.monthTotal / now.day * daysInMonth;
    final prev = snapshot.previousMonthSamePeriodTotal;
    if (prev < SpendingInsightConfig.minMonthTotalForCompare) return null;
    final prevProjected = prev / now.day * daysInMonth;
    final pct = ((projected - prevProjected) / prevProjected * 100).round();
    if (pct < SpendingInsightConfig.moderatePct) return null;

    return _InsightCandidate(
      notificationId: 2021,
      title: 'Projeção do mês',
      body:
          'No ritmo atual, o mês fecharia ~${_currency.format(projected)} (+$pct% vs mês passado)',
      usesVariationCooldown: true,
      priority: 42,
    );
  }

  static Future<double> _recentDailyAverageExcludingToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var total = 0.0;
    var daysWithSpend = 0;
    for (var i = 1; i <= 7; i++) {
      final d = today.subtract(Duration(days: i));
      final start = d.millisecondsSinceEpoch;
      final end = DateTime(d.year, d.month, d.day, 23, 59, 59, 999)
          .millisecondsSinceEpoch;
      final sum = await _db.sumBetween(start, end);
      if (sum > 0) {
        total += sum;
        daysWithSpend++;
      }
    }
    if (daysWithSpend < SpendingInsightConfig.minPastDaysForDayAverage) {
      return 0;
    }
    return total / daysWithSpend;
  }

  static Future<double> _todayTotal() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;
    return _db.sumBetween(start, end);
  }

  static Future<void> _scheduleDailySummary() async {
    final todayTotal = await _todayTotal();
    final dayAvg = await _recentDailyAverageExcludingToday();
    final txs = await _db.getByDay(DateTime.now());
    final topCat = _topCategoryLabel(txs);
    await LocalNotificationService.scheduleDailySummary(
      totalToday: todayTotal,
      avgWeek: dayAvg > 0 ? dayAvg : todayTotal,
      topCategory: topCat,
    );
  }

  static String _topCategoryLabel(List<Transaction> txs) {
    if (txs.isEmpty) return 'Sem gastos';
    final map = <TransactionCategory, double>{};
    for (final t in txs) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    final top = map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return '${top.emoji} ${top.label}';
  }
}
