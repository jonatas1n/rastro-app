import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance_profile.dart';
import '../services/api_client.dart';
import '../services/database_service.dart';
import '../services/spending_summary_notification.dart';
import '../services/sync_queue.dart';

const _kIncomeSetupPromptDismissed = 'income_setup_prompt_dismissed';

class FinanceProfileProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final ApiClient _api;

  FinanceProfile _profile = const FinanceProfile();
  double _weekSpend = 0;
  double _periodSpend = 0;
  bool _loading = true;
  bool _restoring = false;
  bool _incomeSetupDismissed = false;
  String? _restoreError;

  FinanceProfileProvider({required ApiClient api}) : _api = api;

  FinanceProfile get profile => _profile;
  double get weekSpend => _weekSpend;
  double get periodSpend => _periodSpend;
  bool get loading => _loading;
  bool get restoring => _restoring;
  bool get incomeSetupDismissed => _incomeSetupDismissed;
  String? get restoreError => _restoreError;

  FinancePeriod get currentPeriod => financePeriodFor(DateTime.now(), _profile);

  double? get projectedPeriodBalance =>
      _profile.hasIncome ? _profile.monthlyIncome - _periodSpend : null;

  /// Restaura perfil do servidor quando o SQLite ainda está no padrão de fábrica
  /// (reinstall). Se o usuário já configurou localmente, não sobrescreve.
  Future<void> restoreFromServer() async {
    final stored = await AuthStorage.load();
    if (stored == null) return;

    final local = await _db.getFinanceProfile();
    if (!local.isDefaultConfiguration) return;

    _restoring = true;
    _restoreError = null;
    notifyListeners();

    try {
      final remote = await _api.fetchFinanceProfile();
      if (remote == null) return;

      await _db.saveFinanceProfile(remote);
      _profile = remote;
      await _refreshSpending();
    } on ApiException catch (e, st) {
      debugPrint(
        'Restore perfil financeiro falhou (API ${e.statusCode}): ${e.message}\n$st',
      );
      _restoreError =
          'Não foi possível restaurar o perfil financeiro do servidor.';
    } catch (e, st) {
      debugPrint('Restore perfil financeiro falhou: $e\n$st');
      _restoreError =
          'Não foi possível restaurar o perfil financeiro do servidor.';
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _incomeSetupDismissed =
        prefs.getBool(_kIncomeSetupPromptDismissed) ?? false;

    await restoreFromServer();

    _profile = await _db.getFinanceProfile();
    await _refreshSpending();
    _loading = false;
    notifyListeners();
  }

  Future<void> dismissIncomeSetupPrompt() async {
    if (_incomeSetupDismissed) return;
    _incomeSetupDismissed = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIncomeSetupPromptDismissed, true);
  }

  /// Grava localmente e envia ao backend (PUT sobrescreve o perfil remoto).
  /// Retorna mensagem pt_BR em falha de sync, ou `null` se OK.
  Future<String?> save(FinanceProfile profile) async {
    await _db.saveFinanceProfile(profile);
    _profile = profile;
    await _refreshSpending();
    notifyListeners();
    await SpendingSummaryNotification.refresh();

    try {
      await _api.putFinanceProfile(profile);
      return null;
    } on ApiException catch (e, st) {
      debugPrint(
        'Sync perfil financeiro falhou (API ${e.statusCode}): ${e.message}\n$st',
      );
      return 'Não foi possível sincronizar o perfil financeiro.';
    } catch (e, st) {
      debugPrint('Sync perfil financeiro falhou: $e\n$st');
      return 'Não foi possível sincronizar o perfil financeiro.';
    }
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
