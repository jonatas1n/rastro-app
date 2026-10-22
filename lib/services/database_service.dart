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
    return openDatabase(path, version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
    await _createNotificationTables(db);
  }

  static Future<void> _createNotificationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications_cache (
        template_hash    TEXT PRIMARY KEY,
        template_mask    TEXT NOT NULL,
        is_cost          INTEGER NOT NULL,
        extraction_rules TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_whitelist (
        package_name TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        allowed      INTEGER NOT NULL DEFAULT 1
      )
    ''');
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
    if (oldV < 4) {
      await _createNotificationTables(db);
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<Transaction> insert(Transaction t) async {
    final database = await db;
    await database.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return t.copyWith();
  }

  Future<int> countAll() async {
    final database = await db;
    final result = await database.rawQuery('SELECT COUNT(*) AS c FROM transactions');
    return (result.first['c'] as int?) ?? 0;
  }

  /// True se existe alguma transação antes do início deste dia (00:00 local).
  Future<bool> hasTransactionBefore(DateTime startDay) async {
    final database = await db;
    final startMs = DateTime(startDay.year, startDay.month, startDay.day)
        .millisecondsSinceEpoch;
    final result = await database.rawQuery(
      'SELECT 1 FROM transactions WHERE timestamp < ? LIMIT 1',
      [startMs],
    );
    return result.isNotEmpty;
  }

  /// Mescla transações vindas do servidor (restore pós-login/reinstall).
  ///
  /// Conflito: se já existir linha com o mesmo [local_id] e `synced = 0`, ou
  /// houver registro em `pending_updates`, a linha local não é alterada (edits
  /// offline pendentes têm prioridade). Caso contrário, insere ou atualiza com
  /// `synced = 1` e `server_id` do servidor.
  Future<int> upsertFromServer(Iterable<Transaction> remote) async {
    final database = await db;
    var applied = 0;

    for (final t in remote) {
      final pending = await database.query(
        'pending_updates',
        where: 'local_id = ?',
        whereArgs: [t.localId],
        limit: 1,
      );
      final existing = await database.query(
        'transactions',
        where: 'local_id = ?',
        whereArgs: [t.localId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final localSynced = (existing.first['synced'] as int? ?? 0) == 1;
        if (!localSynced || pending.isNotEmpty) continue;

        await database.update(
          'transactions',
          {
            'server_id': t.serverId,
            'place': t.place,
            'amount': t.amount,
            'category': t.category.dbValue,
            'timestamp': t.timestamp.millisecondsSinceEpoch,
            'is_essential': t.isEssential ? 1 : 0,
            'raw_notification': t.rawNotification,
            'synced': 1,
          },
          where: 'local_id = ?',
          whereArgs: [t.localId],
        );
        applied++;
        continue;
      }

      await database.insert(
        'transactions',
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      applied++;
    }

    return applied;
  }

  Future<void> updateEssential(String localId, bool essential) async {
    final database = await db;
    await database.update(
      'transactions',
      {'is_essential': essential ? 1 : 0},
      where: 'local_id = ?', whereArgs: [localId],
    );
  }

  Future<void> updateEssentialMany(Iterable<String> localIds, bool essential) async {
    final ids = localIds.toList();
    if (ids.isEmpty) return;
    final database = await db;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await database.update(
      'transactions',
      {'is_essential': essential ? 1 : 0},
      where: 'local_id IN ($placeholders)',
      whereArgs: ids,
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

  Future<double> sumBetweenCategory(
    int startMs,
    int endMs,
    TransactionCategory category,
  ) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions '
      'WHERE timestamp >= ? AND timestamp <= ? AND category = ?',
      [startMs, endMs, category.dbValue],
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

  /// Mediana dos valores de transação no intervalo (para compra atípica).
  Future<double?> medianAmountBetween(
    int startMs,
    int endMs, {
    String? excludeLocalId,
  }) async {
    final database = await db;
    final rows = await database.rawQuery(
      excludeLocalId == null
          ? 'SELECT amount FROM transactions '
              'WHERE timestamp >= ? AND timestamp <= ? ORDER BY amount ASC'
          : 'SELECT amount FROM transactions '
              'WHERE timestamp >= ? AND timestamp <= ? AND local_id != ? '
              'ORDER BY amount ASC',
      excludeLocalId == null
          ? [startMs, endMs]
          : [startMs, endMs, excludeLocalId],
    );
    if (rows.isEmpty) return null;
    final amounts = rows
        .map((r) => (r['amount'] as num?)?.toDouble() ?? 0)
        .where((a) => a > 0)
        .toList();
    if (amounts.isEmpty) return null;
    amounts.sort();
    final mid = amounts.length ~/ 2;
    if (amounts.length.isOdd) return amounts[mid];
    return (amounts[mid - 1] + amounts[mid]) / 2;
  }

  /// Dias distintos com pelo menos um gasto no intervalo.
  Future<int> countDistinctDaysWithSpend(int startMs, int endMs) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(DISTINCT date(timestamp / 1000, "unixepoch", "localtime")) as c '
      'FROM transactions WHERE timestamp >= ? AND timestamp <= ?',
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

  /// Inclusive calendar-day range (start 00:00 → end 23:59:59).
  Future<List<Transaction>> getByDateRange(
    DateTime startDay,
    DateTime endDay,
  ) async {
    final database = await db;
    final start = DateTime(startDay.year, startDay.month, startDay.day)
        .millisecondsSinceEpoch;
    final end = DateTime(
      endDay.year,
      endDay.month,
      endDay.day,
      23,
      59,
      59,
    ).millisecondsSinceEpoch;
    final rows = await database.query(
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

  Future<List<Transaction>> getSince(DateTime since) async {
    final database = await db;
    final rows = await database.query(
      'transactions',
      where: 'timestamp >= ?',
      whereArgs: [since.millisecondsSinceEpoch],
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<void> saveNotificationTemplate({
    required String templateHash,
    required String templateMask,
    required bool isCost,
    required String extractionRules,
  }) async {
    final database = await db;
    await database.insert(
      'notifications_cache',
      {
        'template_hash': templateHash,
        'template_mask': templateMask,
        'is_cost': isCost ? 1 : 0,
        'extraction_rules': extractionRules,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> findNotificationTemplate(String templateHash) async {
    final database = await db;
    final rows = await database.query(
      'notifications_cache',
      where: 'template_hash = ?',
      whereArgs: [templateHash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<String>> allowedPackageNames() async {
    final database = await db;
    final rows = await database.query(
      'app_whitelist',
      columns: ['package_name'],
      where: 'allowed = 1',
    );
    return [
      for (final row in rows)
        if (row['package_name'] is String) row['package_name'] as String,
    ];
  }

  Future<void> replaceAppWhitelist(List<AppWhitelistEntry> entries) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('app_whitelist');
      for (final entry in entries) {
        await txn.insert('app_whitelist', {
          'package_name': entry.packageName,
          'display_name': entry.displayName,
          'allowed': entry.allowed ? 1 : 0,
        });
      }
    });
  }
}

class AppWhitelistEntry {
  final String packageName;
  final String displayName;
  final bool allowed;

  const AppWhitelistEntry({
    required this.packageName,
    required this.displayName,
    required this.allowed,
  });

  factory AppWhitelistEntry.fromJson(Map<String, dynamic> json) {
    return AppWhitelistEntry(
      packageName: json['package_name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      allowed: json['allowed'] as bool? ?? true,
    );
  }
}
