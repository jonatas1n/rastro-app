import 'dart:convert';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/finance_profile.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'rastro.db');
    return openDatabase(path, version: 3, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id         TEXT    NOT NULL UNIQUE,
        server_id        INTEGER,
        place            TEXT    NOT NULL,
        amount           REAL    NOT NULL,
        category         TEXT    NOT NULL,
        timestamp        INTEGER NOT NULL,
        is_essential     INTEGER NOT NULL DEFAULT 1,
        raw_notification TEXT,
        synced           INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_updates (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id  TEXT    NOT NULL,
        payload   TEXT    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE finance_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        monthly_income REAL NOT NULL DEFAULT 0,
        pay_day INTEGER NOT NULL DEFAULT 1,
        cycle_end_day INTEGER NOT NULL DEFAULT 31,
        weekly_limit_enabled INTEGER NOT NULL DEFAULT 0,
        weekly_spending_limit REAL,
        monthly_limit_enabled INTEGER NOT NULL DEFAULT 0,
        monthly_spending_limit REAL,
        month_end_balance_enabled INTEGER NOT NULL DEFAULT 0,
        month_end_target_balance REAL
      )
    ''');
    await db.insert('finance_profile', {'id': 1, ...FinanceProfile().toMap()});
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN local_id TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN server_id INTEGER');
      await db.execute('ALTER TABLE transactions ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_updates (
          id        INTEGER PRIMARY KEY AUTOINCREMENT,
          local_id  TEXT    NOT NULL,
          payload   TEXT    NOT NULL
        )
      ''');
    }
    if (oldV < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS finance_profile (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          monthly_income REAL NOT NULL DEFAULT 0,
          pay_day INTEGER NOT NULL DEFAULT 1,
          cycle_end_day INTEGER NOT NULL DEFAULT 31,
          weekly_limit_enabled INTEGER NOT NULL DEFAULT 0,
          weekly_spending_limit REAL,
          monthly_limit_enabled INTEGER NOT NULL DEFAULT 0,
          monthly_spending_limit REAL,
          month_end_balance_enabled INTEGER NOT NULL DEFAULT 0,
          month_end_target_balance REAL
        )
      ''');
      final rows = await db.query('finance_profile', where: 'id = 1');
      if (rows.isEmpty) {
        await db.insert('finance_profile', {'id': 1, ...FinanceProfile().toMap()});
      }
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<Transaction> insert(Transaction t) async {
    final database = await db;
    await database.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return t.copyWith();
  }

  Future<void> updateEssential(String localId, bool essential) async {
    final database = await db;
    await database.update(
      'transactions',
      {'is_essential': essential ? 1 : 0},
      where: 'local_id = ?', whereArgs: [localId],
    );
  }

  Future<void> updateCategory(String localId, TransactionCategory category) async {
    final database = await db;
    await database.update(
      'transactions',
      {'category': category.dbValue},
      where: 'local_id = ?', whereArgs: [localId],
    );
  }

  Future<void> updateTransaction(
    String localId, {
    String? place,
    double? amount,
    TransactionCategory? category,
    bool? isEssential,
    int? timestampMs,
  }) async {
    final database = await db;
    final data = <String, dynamic>{};
    if (place != null) data['place'] = place;
    if (amount != null) data['amount'] = amount;
    if (category != null) data['category'] = category.dbValue;
    if (isEssential != null) data['is_essential'] = isEssential ? 1 : 0;
    if (timestampMs != null) data['timestamp'] = timestampMs;
    if (data.isEmpty) return;
    await database.update(
      'transactions',
      data,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<double> sumBetween(int startMs, int endMs) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions '
      'WHERE timestamp >= ? AND timestamp <= ?',
      [startMs, endMs],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> countBetween(int startMs, int endMs) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as c FROM transactions '
      'WHERE timestamp >= ? AND timestamp <= ?',
      [startMs, endMs],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<FinanceProfile> getFinanceProfile() async {
    final database = await db;
    final rows = await database.query('finance_profile', where: 'id = 1');
    if (rows.isEmpty) return const FinanceProfile();
    return FinanceProfile.fromMap(rows.first);
  }

  Future<void> saveFinanceProfile(FinanceProfile profile) async {
    final database = await db;
    await database.insert(
      'finance_profile',
      {'id': 1, ...profile.toMap()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markSynced(String localId, int serverId) async {
    final database = await db;
    await database.update(
      'transactions',
      {'synced': 1, 'server_id': serverId},
      where: 'local_id = ?', whereArgs: [localId],
    );
  }

  Future<void> delete(String localId) async {
    final database = await db;
    await database.delete('transactions', where: 'local_id = ?', whereArgs: [localId]);
  }

  Future<void> deleteMany(Iterable<String> localIds) async {
    final ids = localIds.toList();
    if (ids.isEmpty) return;
    final database = await db;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await database.delete(
      'transactions',
      where: 'local_id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  // ── Sync queue ────────────────────────────────────────────────────────────

  Future<List<Transaction>> getPendingSync() async {
    final database = await db;
    final rows = await database.query(
      'transactions', where: 'synced = 0', orderBy: 'timestamp ASC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<void> addPendingUpdate(String localId, Map<String, dynamic> payload) async {
    final database = await db;
    await database.insert('pending_updates', {
      'local_id': localId,
      'payload':  jsonEncode(payload),
    });
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<Transaction>> getByDay(DateTime day) async {
    final database = await db;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end   = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;
    final rows  = await database.query(
      'transactions',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'timestamp DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getByMonth(DateTime month) async {
    final database = await db;
    final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    final end   = DateTime(month.year, month.month + 1, 0, 23, 59, 59).millisecondsSinceEpoch;
    final rows  = await database.query(
      'transactions',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'timestamp DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// Busca com filtros combinados para a tela de histórico.
  /// Todos os parâmetros são opcionais — sem nenhum retorna tudo.
  Future<List<Transaction>> search({
    String?               query,
    DateTime?             from,
    DateTime?             to,
    TransactionCategory?  category,
    bool?                 essentialOnly,
    int                   limit  = 200,
    int                   offset = 0,
  }) async {
    final database = await db;

    final conditions = <String>[];
    final args       = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      conditions.add('LOWER(place) LIKE ?');
      args.add('%${query.trim().toLowerCase()}%');
    }
    if (from != null) {
      conditions.add('timestamp >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      conditions.add('timestamp <= ?');
      args.add(DateTime(to.year, to.month, to.day, 23, 59, 59).millisecondsSinceEpoch);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category.dbValue);
    }
    if (essentialOnly != null) {
      conditions.add('is_essential = ?');
      args.add(essentialOnly ? 1 : 0);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');

    final rows = await database.query(
      'transactions',
      where:   where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit:   limit,
      offset:  offset,
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// Total de registros para um mesmo filtro (paginação).
  Future<int> count({
    String?              query,
    DateTime?            from,
    DateTime?            to,
    TransactionCategory? category,
    bool?                essentialOnly,
  }) async {
    final database = await db;
    final conditions = <String>[];
    final args       = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      conditions.add('LOWER(place) LIKE ?');
      args.add('%${query.trim().toLowerCase()}%');
    }
    if (from     != null) { conditions.add('timestamp >= ?');   args.add(from.millisecondsSinceEpoch); }
    if (to       != null) { conditions.add('timestamp <= ?');   args.add(DateTime(to.year, to.month, to.day, 23, 59, 59).millisecondsSinceEpoch); }
    if (category != null) { conditions.add('category = ?');     args.add(category.dbValue); }
    if (essentialOnly != null) { conditions.add('is_essential = ?'); args.add(essentialOnly ? 1 : 0); }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final result = await database.rawQuery(
      'SELECT COUNT(*) as c FROM transactions${where != null ? ' WHERE $where' : ''}',
      args.isEmpty ? null : args,
    );
    return (result.first['c'] as int?) ?? 0;
  }
}
