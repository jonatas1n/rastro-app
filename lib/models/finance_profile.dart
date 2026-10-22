/// Perfil financeiro local (renda, ciclo de pagamento e metas).
class FinanceProfile {
  final double monthlyIncome;
  /// Dia do mês em que a renda cai (1–31).
  final int payDay;
  /// Último dia do ciclo (ex.: recebe dia 5, ciclo fecha dia 4 do mês seguinte).
  final int cycleEndDay;

  final bool weeklyLimitEnabled;
  final double? weeklySpendingLimit;

  final bool monthlyLimitEnabled;
  final double? monthlySpendingLimit;

  final bool monthEndBalanceEnabled;
  final double? monthEndTargetBalance;

  const FinanceProfile({
    this.monthlyIncome = 0,
    this.payDay = 1,
    this.cycleEndDay = 31,
    this.weeklyLimitEnabled = false,
    this.weeklySpendingLimit,
    this.monthlyLimitEnabled = false,
    this.monthlySpendingLimit,
    this.monthEndBalanceEnabled = false,
    this.monthEndTargetBalance,
  });

  bool get hasIncome => monthlyIncome > 0;

  bool get hasAnyGoal =>
      (weeklyLimitEnabled && (weeklySpendingLimit ?? 0) > 0) ||
      (monthlyLimitEnabled && (monthlySpendingLimit ?? 0) > 0) ||
      (monthEndBalanceEnabled && monthEndTargetBalance != null);

  /// Perfil ainda no padrão de fábrica (ex.: após reinstall antes do restore).
  bool get isDefaultConfiguration =>
      monthlyIncome == 0 &&
      payDay == 1 &&
      cycleEndDay == 31 &&
      !weeklyLimitEnabled &&
      weeklySpendingLimit == null &&
      !monthlyLimitEnabled &&
      monthlySpendingLimit == null &&
      !monthEndBalanceEnabled &&
      monthEndTargetBalance == null;

  FinanceProfile copyWith({
    double? monthlyIncome,
    int? payDay,
    int? cycleEndDay,
    bool? weeklyLimitEnabled,
    double? weeklySpendingLimit,
    bool? monthlyLimitEnabled,
    double? monthlySpendingLimit,
    bool? monthEndBalanceEnabled,
    double? monthEndTargetBalance,
  }) =>
      FinanceProfile(
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
        payDay: payDay ?? this.payDay,
        cycleEndDay: cycleEndDay ?? this.cycleEndDay,
        weeklyLimitEnabled: weeklyLimitEnabled ?? this.weeklyLimitEnabled,
        weeklySpendingLimit: weeklySpendingLimit ?? this.weeklySpendingLimit,
        monthlyLimitEnabled: monthlyLimitEnabled ?? this.monthlyLimitEnabled,
        monthlySpendingLimit: monthlySpendingLimit ?? this.monthlySpendingLimit,
        monthEndBalanceEnabled:
            monthEndBalanceEnabled ?? this.monthEndBalanceEnabled,
        monthEndTargetBalance:
            monthEndTargetBalance ?? this.monthEndTargetBalance,
      );

  Map<String, dynamic> toMap() => {
        'monthly_income': monthlyIncome,
        'pay_day': payDay,
        'cycle_end_day': cycleEndDay,
        'weekly_limit_enabled': weeklyLimitEnabled ? 1 : 0,
        'weekly_spending_limit': weeklySpendingLimit,
        'monthly_limit_enabled': monthlyLimitEnabled ? 1 : 0,
        'monthly_spending_limit': monthlySpendingLimit,
        'month_end_balance_enabled': monthEndBalanceEnabled ? 1 : 0,
        'month_end_target_balance': monthEndTargetBalance,
      };

  factory FinanceProfile.fromMap(Map<String, dynamic> m) => FinanceProfile(
        monthlyIncome: (m['monthly_income'] as num?)?.toDouble() ?? 0,
        payDay: (m['pay_day'] as int?) ?? 1,
        cycleEndDay: (m['cycle_end_day'] as int?) ?? 31,
        weeklyLimitEnabled: (m['weekly_limit_enabled'] as int? ?? 0) == 1,
        weeklySpendingLimit: (m['weekly_spending_limit'] as num?)?.toDouble(),
        monthlyLimitEnabled: (m['monthly_limit_enabled'] as int? ?? 0) == 1,
        monthlySpendingLimit: (m['monthly_spending_limit'] as num?)?.toDouble(),
        monthEndBalanceEnabled:
            (m['month_end_balance_enabled'] as int? ?? 0) == 1,
        monthEndTargetBalance:
            (m['month_end_target_balance'] as num?)?.toDouble(),
      );
}

/// Intervalo do ciclo financeiro baseado no dia de pagamento.
class FinancePeriod {
  final DateTime start;
  final DateTime end;

  const FinancePeriod({required this.start, required this.end});
}

FinancePeriod financePeriodFor(DateTime now, FinanceProfile profile) {
  final pay = profile.payDay.clamp(1, 31);
  final endDay = profile.cycleEndDay.clamp(1, 31);

  DateTime clampDay(int year, int month, int day) {
    final last = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, last));
  }

  if (pay <= endDay) {
    final start = clampDay(now.year, now.month, pay);
    final end = clampDay(now.year, now.month, endDay)
        .add(const Duration(hours: 23, minutes: 59, seconds: 59));
    if (now.isBefore(start)) {
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      return FinancePeriod(
        start: clampDay(prevMonth.year, prevMonth.month, pay),
        end: clampDay(prevMonth.year, prevMonth.month, endDay)
            .add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      );
    }
    return FinancePeriod(start: start, end: end);
  }

  // Ciclo cruza o mês (ex.: paga dia 25, fecha dia 10).
  final startThisMonth = clampDay(now.year, now.month, pay);
  if (!now.isBefore(startThisMonth)) {
    final next = DateTime(now.year, now.month + 1, 1);
    return FinancePeriod(
      start: startThisMonth,
      end: clampDay(next.year, next.month, endDay)
          .add(const Duration(hours: 23, minutes: 59, seconds: 59)),
    );
  }
  final prev = DateTime(now.year, now.month - 1, 1);
  return FinancePeriod(
    start: clampDay(prev.year, prev.month, pay),
    end: clampDay(now.year, now.month, endDay)
        .add(const Duration(hours: 23, minutes: 59, seconds: 59)),
  );
}

DateTime weekStart(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

DateTime weekEnd(DateTime now) =>
    weekStart(now).add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
