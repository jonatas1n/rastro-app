import 'package:flutter/foundation.dart';
import '../models/finance_profile.dart';
import '../services/database_service.dart';
import '../services/spending_summary_notification.dart';

class FinanceProfileProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  FinanceProfile _profile = const FinanceProfile();
  double _weekSpend = 0;
  double _periodSpend = 0;
  bool _loading = true;

  FinanceProfile get profile => _profile;
  double get weekSpend => _weekSpend;
  double get periodSpend => _periodSpend;
  bool get loading => _loading;

  FinancePeriod get currentPeriod => financePeriodFor(DateTime.now(), _profile);

  double? get projectedPeriodBalance =>
      _profile.hasIncome ? _profile.monthlyIncome - _periodSpend : null;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _profile = await _db.getFinanceProfile();
    await _refreshSpending();
    _loading = false;
    notifyListeners();
  }

  Future<void> save(FinanceProfile profile) async {
    await _db.saveFinanceProfile(profile);
    _profile = profile;
    await _refreshSpending();
    notifyListeners();
    await SpendingSummaryNotification.refresh();
  }

  Future<void> refreshSpending() async {
    await _refreshSpending();
    notifyListeners();
  }

  Future<void> _refreshSpending() async {
    final now = DateTime.now();
    final period = financePeriodFor(now, _profile);
    _periodSpend = await _db.sumBetween(
      period.start.millisecondsSinceEpoch,
      period.end.millisecondsSinceEpoch,
    );
    _weekSpend = await _db.sumBetween(
      weekStart(now).millisecondsSinceEpoch,
      weekEnd(now).millisecondsSinceEpoch,
    );
  }
}
