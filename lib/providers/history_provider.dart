import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class HistoryFilter {
  final String?              query;
  final DateTime?            from;
  final DateTime?            to;
  final TransactionCategory? category;
  final bool?                essentialOnly;

  const HistoryFilter({
    this.query,
    this.from,
    this.to,
    this.category,
    this.essentialOnly,
  });

  HistoryFilter copyWith({
    Object? query        = _sentinel,
    Object? from         = _sentinel,
    Object? to           = _sentinel,
    Object? category     = _sentinel,
    Object? essentialOnly = _sentinel,
  }) =>
      HistoryFilter(
        query:        query        == _sentinel ? this.query        : query as String?,
        from:         from         == _sentinel ? this.from         : from as DateTime?,
        to:           to           == _sentinel ? this.to           : to as DateTime?,
        category:     category     == _sentinel ? this.category     : category as TransactionCategory?,
        essentialOnly: essentialOnly == _sentinel ? this.essentialOnly : essentialOnly as bool?,
      );

  bool get isEmpty =>
      query == null &&
      from == null &&
      to == null &&
      category == null &&
      essentialOnly == null;

  static const _sentinel = Object();
}

class HistoryProvider extends ChangeNotifier {
  final _db = DatabaseService();

  static const _pageSize = 50;

  List<Transaction> _results = [];
  HistoryFilter     _filter  = const HistoryFilter();
  bool   _loading     = false;
  bool   _hasMore     = false;
  int    _total       = 0;
  int    _page        = 0;

  // Debounce para a busca por texto
  Timer? _debounce;

  List<Transaction> get results  => _results;
  HistoryFilter     get filter   => _filter;
  bool              get loading  => _loading;
  bool              get hasMore  => _hasMore;
  int               get total    => _total;

  // Gastos agrupados por dia para a listagem
  Map<DateTime, List<Transaction>> get byDay {
    final map = <DateTime, List<Transaction>>{};
    for (final tx in _results) {
      final day = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day);
      map.putIfAbsent(day, () => []).add(tx);
    }
    return map;
  }

  List<DateTime> get sortedDays =>
      byDay.keys.toList()..sort((a, b) => b.compareTo(a));

  double get filteredTotal =>
      _results.fold(0.0, (s, t) => s + t.amount);

  double get filteredNonEssential =>
      _results.where((t) => !t.isEssential).fold(0.0, (s, t) => s + t.amount);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Primeira carga / reset
  Future<void> load() => _fetch(reset: true);

  /// Busca por texto com debounce de 300ms
  void setQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filter = _filter.copyWith(query: q.isEmpty ? null : q);
      _fetch(reset: true);
    });
  }

  void setCategory(TransactionCategory? cat) {
    _filter = _filter.copyWith(category: cat);
    _fetch(reset: true);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _filter = _filter.copyWith(from: from, to: to);
    _fetch(reset: true);
  }

  void setEssentialOnly(bool? v) {
    _filter = _filter.copyWith(essentialOnly: v);
    _fetch(reset: true);
  }

  void clearFilters() {
    _filter = const HistoryFilter();
    _fetch(reset: true);
  }

  /// Carrega próxima página
  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _page++;
    await _fetch(reset: false);
  }

  Future<void> refreshItem(String localId) async {
    final idx = _results.indexWhere((t) => t.localId == localId);
    if (idx == -1) return;
    final fresh = await _db.search(query: localId, limit: 1);
    if (fresh.isNotEmpty) {
      _results[idx] = fresh.first;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _fetch({required bool reset}) async {
    if (reset) _page = 0;

    _loading = true;
    if (reset) notifyListeners();

    final rows = await _db.search(
      query:        _filter.query,
      from:         _filter.from,
      to:           _filter.to,
      category:     _filter.category,
      essentialOnly: _filter.essentialOnly,
      limit:        _pageSize,
      offset:       _page * _pageSize,
    );

    if (reset) {
      _total = await _db.count(
        query:        _filter.query,
        from:         _filter.from,
        to:           _filter.to,
        category:     _filter.category,
        essentialOnly: _filter.essentialOnly,
      );
      _results = rows;
    } else {
      _results = [..._results, ...rows];
    }

    _hasMore = _results.length < _total;
    _loading = false;
    notifyListeners();
  }
}
