import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/spending_summary_notification.dart';
import '../services/database_service.dart';
import '../services/sync_queue.dart';
import '../services/api_client.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseService _db;
  final SyncQueue       _sync;

  List<Transaction> _todayList  = [];
  List<Transaction> _monthList  = [];
  bool _loading = false;

  List<Transaction> get todayList  => _todayList;
  List<Transaction> get monthList  => _monthList;
  bool              get loading    => _loading;

  TransactionProvider({required ApiClient api})
      : _db   = DatabaseService(),
        _sync  = SyncQueue(api: api, db: DatabaseService());

  // ── Computed ──────────────────────────────────────────────────────────────

  double get totalToday =>
      _todayList.fold(0, (s, t) => s + t.amount);

  double get nonEssentialToday =>
      _todayList.where((t) => !t.isEssential).fold(0, (s, t) => s + t.amount);

  double get essentialToday => totalToday - nonEssentialToday;

  Transaction? get biggestToday => _todayList.isEmpty
      ? null
      : _todayList.reduce((a, b) => a.amount > b.amount ? a : b);

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

  TransactionCategory? get topCategoryToday {
    if (_todayList.isEmpty) return null;
    final map = <TransactionCategory, double>{};
    for (final t in _todayList) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double get savingsProjectionWeek {
    if (totalToday == 0) return 0;
    return nonEssentialToday / totalToday * weekAvg * 7;
  }

  double get savingsProjectionMonth {
    if (totalToday == 0) return 0;
    final ratio      = nonEssentialToday / totalToday;
    final monthTotal = _monthList.fold<double>(0, (s, t) => s + t.amount);
    return monthTotal * ratio;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final now = DateTime.now();
    _todayList = await _db.getByDay(now);
    _monthList = await _db.getByMonth(now);
    _loading   = false;
    notifyListeners();

    await SpendingSummaryNotification.refresh();

    // Tenta sincronizar pendentes em background
    _sync.triggerSync();
  }

  /// Inserção otimista: salva local → notifica UI → enfileira sync
  Future<void> addTransaction(Transaction tx) async {
    await _db.insert(tx);
    await load();          // UI atualiza imediatamente
    _sync.enqueue();       // sync em background
  }

  /// Toggle essencial — otimista: UI muda na hora, backend segue depois
  Future<void> toggleEssential(Transaction tx) async {
    final updated = tx.copyWith(isEssential: !tx.isEssential);

    // Atualiza local imediatamente
    await _db.updateEssential(tx.localId, updated.isEssential);
    _todayList = _todayList.map((t) => t.localId == tx.localId ? updated : t).toList();
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
