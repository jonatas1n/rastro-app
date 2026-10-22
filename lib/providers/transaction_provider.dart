import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/spending_summary_notification.dart';
import '../services/database_service.dart';
import '../services/sync_queue.dart';
import '../services/api_client.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseService _db;
  final ApiClient       _api;
  final SyncQueue       _sync;

  List<Transaction> _todayList  = [];
  List<Transaction> _monthList  = [];
  List<Transaction> _recentRangeList = [];
  List<Transaction> _historyWindowTransactions = [];
  int _loadedHistoryWindows = 1;
  bool _hasMoreHistory = false;
  bool _loading = false;
  bool _restoring = false;
  String? _restoreError;

  List<Transaction> get todayList  => _todayList;
  List<Transaction> get monthList  => _monthList;
  bool              get loading    => _loading;
  bool              get restoring  => _restoring;
  String?           get restoreError => _restoreError;

  static const int historyWindowDays = 7;

  int get loadedHistoryWindows => _loadedHistoryWindows;
  bool get hasMoreHistory => _hasMoreHistory;
  List<Transaction> get historyWindowTransactions =>
      List.unmodifiable(_historyWindowTransactions);

  /// Início do intervalo carregado: hoje − (7 × janelas − 1) dias.
  DateTime get historyWindowStart {
    final today = calendarDay(DateTime.now());
    return today.subtract(
      Duration(days: historyWindowDays * _loadedHistoryWindows - 1),
    );
  }

  Map<DateTime, List<Transaction>> get historyByDay {
    final map = <DateTime, List<Transaction>>{};
    for (final tx in _historyWindowTransactions) {
      final day = calendarDay(tx.timestamp);
      map.putIfAbsent(day, () => []).add(tx);
    }
    for (final list in map.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return map;
  }

  /// Dias visíveis na lista (desc): hoje sempre; demais só com gastos no intervalo.
  List<DateTime> get historyVisibleDays {
    final today = calendarDay(DateTime.now());
    final start = historyWindowStart;
    final byDay = historyByDay;
    final days = <DateTime>[today];
    var d = today.subtract(const Duration(days: 1));
    while (!d.isBefore(start)) {
      if (byDay.containsKey(d)) days.add(d);
      d = d.subtract(const Duration(days: 1));
    }
    return days;
  }

  double get historyWindowTotal =>
      _historyWindowTransactions.fold(0.0, (s, t) => s + t.amount);

  double get historyWindowNonEssential => _historyWindowTransactions
      .where((t) => !t.isEssential)
      .fold(0.0, (s, t) => s + t.amount);

  TransactionProvider({required ApiClient api})
      : _db   = DatabaseService(),
        _api  = api,
        _sync  = SyncQueue(api: api, db: DatabaseService());

  // ── Computed ──────────────────────────────────────────────────────────────

  static DateTime calendarDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static const int carouselPastDays = 7;
  static const int carouselDayCount = carouselPastDays + 1;
  static int get carouselTodayPageIndex => carouselDayCount - 1;

  /// Hoje + os 7 dias calendário anteriores (8 cards), do mais antigo ao mais recente.
  List<DateTime> get carouselDays {
    final today = calendarDay(DateTime.now());
    return List.generate(
      carouselDayCount,
      (i) => calendarDay(today.subtract(Duration(days: carouselPastDays - i))),
    );
  }

  List<DateTime> get availableDays => carouselDays;

  List<Transaction> transactionsForDay(DateTime day) {
    final d = calendarDay(day);
    final today = calendarDay(DateTime.now());
    if (d == today) {
      return List.unmodifiable(_todayList);
    }
    final oldest = today.subtract(const Duration(days: carouselPastDays));
    if (!d.isBefore(oldest) && !d.isAfter(today)) {
      return _recentRangeList
          .where((t) => calendarDay(t.timestamp) == d)
          .toList();
    }
    return _monthList
        .where((t) => calendarDay(t.timestamp) == d)
        .toList();
  }

  double totalForDay(DateTime day) =>
      transactionsForDay(day).fold(0.0, (s, t) => s + t.amount);

  double nonEssentialForDay(DateTime day) => transactionsForDay(day)
      .where((t) => !t.isEssential)
      .fold(0.0, (s, t) => s + t.amount);

  double essentialForDay(DateTime day) =>
      totalForDay(day) - nonEssentialForDay(day);

  Transaction? biggestForDay(DateTime day) {
    final list = transactionsForDay(day);
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a.amount > b.amount ? a : b);
  }

  Map<TransactionCategory, double> categoryTotalsForDay(DateTime day) {
    final map = <TransactionCategory, double>{};
    for (final t in transactionsForDay(day)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  TransactionCategory? topCategoryForDay(DateTime day) {
    final map = categoryTotalsForDay(day);
    if (map.isEmpty) return null;
    return map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double get totalToday => totalForDay(DateTime.now());

  double get nonEssentialToday => nonEssentialForDay(DateTime.now());

  double get essentialToday => essentialForDay(DateTime.now());

  Transaction? get biggestToday => biggestForDay(DateTime.now());

  double get weekAvg {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week  = _monthList.where((t) {
      final d = DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day);
      return d.isBefore(today) && today.difference(d).inDays <= 7;
    });
    if (week.isEmpty) return 0;
    final days  = week.map((t) =>
        DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day)).toSet().length;
    final total = week.fold<double>(0, (s, t) => s + t.amount);
    return days > 0 ? total / days : 0;
  }

  Map<TransactionCategory, double> get monthByCategory {
    final map = <TransactionCategory, double>{};
    for (final t in _monthList) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  TransactionCategory? get topCategoryToday => topCategoryForDay(DateTime.now());

  double savingsProjectionWeekForDay(DateTime day) {
    final total = totalForDay(day);
    if (total == 0) return 0;
    return nonEssentialForDay(day) / total * weekAvg * 7;
  }

  double savingsProjectionMonthForDay(DateTime day) {
    final total = totalForDay(day);
    if (total == 0) return 0;
    final ratio = nonEssentialForDay(day) / total;
    final monthTotal = _monthList.fold<double>(0, (s, t) => s + t.amount);
    return monthTotal * ratio;
  }

  double get savingsProjectionWeek => savingsProjectionWeekForDay(DateTime.now());

  double get savingsProjectionMonth =>
      savingsProjectionMonthForDay(DateTime.now());

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Restaura transações do servidor (merge). [onlyIfEmpty] evita chamadas
  /// desnecessárias quando já há dados locais (ex.: retorno ao app).
  Future<void> restoreFromServer({bool onlyIfEmpty = false}) async {
    if (onlyIfEmpty) {
      final count = await _db.countAll();
      if (count > 0) return;
    }

    _restoring = true;
    _restoreError = null;
    notifyListeners();

    try {
      final remote = await _api.fetchAllTransactions();
      await _db.upsertFromServer(remote);
    } on ApiException catch (e, st) {
      debugPrint('Restore falhou (API ${e.statusCode}): ${e.message}\n$st');
      _restoreError = 'Não foi possível restaurar os gastos do servidor.';
    } catch (e, st) {
      debugPrint('Restore falhou: $e\n$st');
      _restoreError = 'Não foi possível restaurar os gastos do servidor.';
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> load({bool rescheduleDailySummary = true}) async {
    _loading = true;
    notifyListeners();

    await restoreFromServer(onlyIfEmpty: true);

    _loadedHistoryWindows = 1;

    final now = DateTime.now();
    final today = calendarDay(now);
    _todayList = await _db.getByDay(now);
    _monthList = await _db.getByMonth(now);
    _recentRangeList = await _db.getByDateRange(
      today.subtract(const Duration(days: carouselPastDays)),
      today,
    );
    await _refreshHistoryWindows();
    _loading   = false;
    notifyListeners();

    await SpendingSummaryNotification.refresh(
      rescheduleDailySummary: rescheduleDailySummary,
    );

    // Tenta sincronizar pendentes em background
    _sync.triggerSync();
  }

  Future<void> loadMoreHistory() async {
    if (!_hasMoreHistory) return;
    _loadedHistoryWindows++;
    await _refreshHistoryWindows();
    notifyListeners();
  }

  Future<void> _refreshHistoryWindows() async {
    final today = calendarDay(DateTime.now());
    final start = historyWindowStart;
    _historyWindowTransactions = await _db.getByDateRange(start, today);
    _hasMoreHistory = await _db.hasTransactionBefore(start);
  }

  /// Inserção otimista: salva local → notifica UI → enfileira sync
  Future<void> addTransaction(Transaction tx) async {
    await _db.insert(tx);
    _loading = true;
    notifyListeners();
    final now = DateTime.now();
    final today = calendarDay(now);
    _todayList = await _db.getByDay(now);
    _monthList = await _db.getByMonth(now);
    _recentRangeList = await _db.getByDateRange(
      today.subtract(const Duration(days: carouselPastDays)),
      today,
    );
    await _refreshHistoryWindows();
    _loading = false;
    notifyListeners();

    await SpendingSummaryNotification.refresh(
      newTransaction: tx,
      rescheduleDailySummary: true,
    );
    _sync.enqueue();
  }

  /// Toggle essencial — otimista: UI muda na hora, backend segue depois
  Future<void> toggleEssential(Transaction tx) async {
    final updated = tx.copyWith(isEssential: !tx.isEssential);

    // Atualiza local imediatamente
    await _db.updateEssential(tx.localId, updated.isEssential);
    _todayList = _todayList.map((t) => t.localId == tx.localId ? updated : t).toList();
    _historyWindowTransactions = _historyWindowTransactions
        .map((t) => t.localId == tx.localId ? updated : t)
        .toList();
    notifyListeners();

    // Propaga ao backend em background
    _sync.pushEssentialToggle(updated);
  }

  /// Correção de categoria pelo usuário — ensina o backend
  Future<void> correctCategory(Transaction tx, TransactionCategory newCat) async {
    final updated = tx.copyWith(category: newCat);
    await _db.updateCategory(tx.localId, newCat);
    _todayList = _todayList.map((t) => t.localId == tx.localId ? updated : t).toList();
    _monthList = _monthList.map((t) => t.localId == tx.localId ? updated : t).toList();
    _historyWindowTransactions = _historyWindowTransactions
        .map((t) => t.localId == tx.localId ? updated : t)
        .toList();
    notifyListeners();

    _sync.pushCategoryFeedback(updated);
  }

  Future<void> remove(String localId) async {
    await _db.delete(localId);
    await load();
  }

  Future<void> removeMany(Iterable<String> localIds) async {
    await _db.deleteMany(localIds);
    await load();
  }

  /// Marca vários gastos como essencial ou não-essencial (local primeiro, sync depois).
  Future<void> setEssentialMany(Iterable<String> localIds, bool essential) async {
    final ids = localIds.toSet();
    if (ids.isEmpty) return;

    final toSync = <Transaction>[];
    final syncedIds = <String>{};
    for (final t in [..._todayList, ..._monthList, ..._recentRangeList]) {
      if (!ids.contains(t.localId) || t.isEssential == essential) continue;
      if (!syncedIds.add(t.localId)) continue;
      toSync.add(t.copyWith(isEssential: essential));
    }

    await _db.updateEssentialMany(ids, essential);

    Transaction mapEssential(Transaction t) =>
        ids.contains(t.localId) ? t.copyWith(isEssential: essential) : t;

    _todayList = _todayList.map(mapEssential).toList();
    _monthList = _monthList.map(mapEssential).toList();
    _recentRangeList = _recentRangeList.map(mapEssential).toList();
    notifyListeners();

    for (final tx in toSync) {
      _sync.pushEssentialToggle(tx);
    }
  }

  Future<void> editTransaction(
    Transaction tx, {
    required String place,
    required double amount,
    required TransactionCategory category,
    required bool isEssential,
    required DateTime timestamp,
  }) async {
    await _db.updateTransaction(
      tx.localId,
      place: place,
      amount: amount,
      category: category,
      isEssential: isEssential,
      timestampMs: timestamp.millisecondsSinceEpoch,
    );
    final updated = tx.copyWith(
      place: place,
      amount: amount,
      category: category,
      isEssential: isEssential,
      timestamp: timestamp,
    );
    await load();
    _sync.pushTransactionEdit(updated);
  }

  @override
  void dispose() {
    _sync.dispose();
    super.dispose();
  }
}
