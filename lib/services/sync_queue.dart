import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';
import '../services/database_service.dart';

/// Gerencia a fila de sincronização offline-first.
///
/// Fluxo:
/// 1. Transação é salva localmente (SQLite) imediatamente — otimista
/// 2. SyncQueue tenta enviar ao backend quando há conexão
/// 3. Se falhar, fica na fila e tenta de novo (backoff exponencial)
/// 4. Backend retorna categorias aprimoradas → SQLite atualizado silenciosamente
class SyncQueue {
  final ApiClient _api;
  final DatabaseService _db;

  Timer? _retryTimer;
  bool _syncing = false;
  int _failCount = 0;

  SyncQueue({required ApiClient api, required DatabaseService db})
      : _api = api,
        _db = db;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Chame após inserir uma transação localmente.
  /// Dispara sync imediato; se falhar, agenda retry.
  void enqueue() {
    _scheduleSync(delay: Duration.zero);
  }

  /// Chame ao voltar de offline, ou ao abrir o app.
  void triggerSync() {
    _scheduleSync(delay: const Duration(seconds: 1));
  }

  void dispose() {
    _retryTimer?.cancel();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _scheduleSync({required Duration delay}) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _sync);
  }

  Future<void> _sync() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final pending = await _db.getPendingSync();
      if (pending.isEmpty) {
        _syncing = false;
        return;
      }

      final synced = await _api.syncBatch(pending);

      // Marca como sincronizadas no SQLite
      for (final s in synced) {
        await _db.markSynced(s.localId, s.serverId);
      }

      // Pede recategorização aprimorada para as recém-sincronizadas
      _recategorizeInBackground(pending);

      _failCount = 0;
    } catch (_) {
      _failCount++;
      // Backoff: 5s, 10s, 20s, 40s... máx 5min
      final delay = Duration(seconds: (5 * (1 << _failCount)).clamp(5, 300));
      _scheduleSync(delay: delay);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _recategorizeInBackground(List<Transaction> txs) async {
    try {
      final suggestions = await _api.bulkCategorize(txs);
      for (final s in suggestions) {
        // Só atualiza se a confiança do backend for maior que a local
        // e a fonte for "learned" ou "llm"
        if (s.confidence >= 0.75 && s.source != 'local_rule') {
          await _db.updateCategory(s.localId, s.category);
        }
      }
    } catch (_) {
      // Falha silenciosa — categorização local já está correta
    }
  }

  // ── Propagação de updates para o backend ─────────────────────────────────

  Future<void> pushEssentialToggle(Transaction tx) async {
    try {
      await _api.updateTransaction(tx.localId, isEssential: tx.isEssential);
    } catch (_) {
      // Armazena para retry na próxima sync
      await _db.addPendingUpdate(tx.localId, {'is_essential': tx.isEssential});
    }
  }

  Future<void> pushCategoryFeedback(Transaction tx) async {
    try {
      await _api.categoryFeedback(tx.localId, tx.category);
    } catch (_) {
      await _db.addPendingUpdate(tx.localId, {'category': tx.category.name});
    }
  }

  Future<void> pushTransactionEdit(Transaction tx) async {
    try {
      await _api.updateTransaction(
        tx.localId,
        isEssential: tx.isEssential,
        category: tx.category.name,
        place: tx.place,
        amount: tx.amount,
        timestamp: tx.timestamp,
      );
    } catch (_) {
      await _db.addPendingUpdate(tx.localId, {
        'is_essential': tx.isEssential,
        'category': tx.category.name,
        'place': tx.place,
        'amount': tx.amount,
        'timestamp': tx.timestamp.toUtc().toIso8601String(),
      });
    }
  }
}

// ── Auth state persistence ────────────────────────────────────────────────────

class AuthStorage {
  static const _tokenKey  = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _nameKey   = 'user_name';

  static Future<void> save(AuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey,  result.token);
    await prefs.setInt(_userIdKey,    result.userId);
    await prefs.setString(_nameKey,   result.name);
  }

  static Future<StoredAuth?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token  = prefs.getString(_tokenKey);
    final userId = prefs.getInt(_userIdKey);
    final name   = prefs.getString(_nameKey);
    if (token == null || userId == null) return null;
    return StoredAuth(token: token, userId: userId, name: name ?? '');
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nameKey);
  }
}

class StoredAuth {
  final String token;
  final int    userId;
  final String name;
  const StoredAuth({required this.token, required this.userId, required this.name});
}
