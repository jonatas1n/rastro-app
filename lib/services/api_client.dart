import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/finance_profile.dart';
import 'database_service.dart';

class ApiClient {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://rastro-api.vercel.app',
  );

  static const _baseUrl = baseUrl;

  String? _token;

  Future<void> _loadToken() async {
    if (_token != null) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthResult> register(String email, String password, String name) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'name': name}),
    );
    return _handleAuth(resp);
  }

  Future<AuthResult> login(String email, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleAuth(resp);
  }

  AuthResult _handleAuth(http.Response resp) {
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      _token = token;
      return AuthResult(
        token:  token,
        userId: data['user_id'] as int,
        name:   data['name'] as String,
      );
    }
    throw ApiException(_errorMessage(resp), resp.statusCode);
  }

  void clearSession() {
    _token = null;
  }

  static String _errorMessage(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
        }
        return detail.toString();
      }
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // corpo não-JSON (ex.: "Internal Server Error")
    }
    final body = resp.body.trim();
    if (body.isNotEmpty) return body;
    return 'Erro desconhecido';
  }

  // ── Transactions ─────────────────────────────────────────────────────────

  static Transaction transactionFromServerJson(Map<String, dynamic> j) {
    final tsRaw = j['timestamp'];
    final DateTime timestamp = tsRaw is String
        ? DateTime.parse(tsRaw)
        : DateTime.fromMillisecondsSinceEpoch(0);
    return Transaction(
      localId: j['local_id'] as String,
      serverId: j['id'] as int,
      place: j['place'] as String,
      amount: (j['amount'] as num).toDouble(),
      category: TransactionCategoryX.fromDb(j['category'] as String),
      timestamp: timestamp,
      isEssential: j['is_essential'] as bool? ?? true,
      rawNotification: j['raw_notification'] as String?,
      synced: true,
    );
  }

  /// Baixa todas as transações do usuário (paginação automática).
  static const _fetchPageSize = 100;
  static const _fetchMaxRows = 10000;

  Future<List<Transaction>> fetchAllTransactions() async {
    await _loadToken();
    final all = <Transaction>[];
    var offset = 0;

    while (all.length < _fetchMaxRows) {
      final uri = Uri.parse(
        '$_baseUrl/transactions?limit=$_fetchPageSize&offset=$offset',
      );
      final resp = await http.get(uri, headers: _headers);

      if (resp.statusCode != 200) {
        throw ApiException(
          'Falha ao buscar transações: ${_errorMessage(resp)}',
          resp.statusCode,
        );
      }

      final list = jsonDecode(resp.body) as List;
      if (list.isEmpty) break;

      for (final item in list) {
        all.add(transactionFromServerJson(item as Map<String, dynamic>));
      }

      if (list.length < _fetchPageSize) break;
      offset += _fetchPageSize;
    }

    return all;
  }

  /// Sincronização em lote — idempotente, pode chamar quantas vezes quiser
  Future<List<SyncedTransaction>> syncBatch(List<Transaction> txs) async {
    await _loadToken();
    final payload = txs.map((t) => {
      'local_id':         t.localId,
      'place':            t.place,
      'amount':           t.amount,
      'category':         t.category.name,
      'is_essential':     t.isEssential,
      'timestamp':        t.timestamp.toUtc().toIso8601String(),
      'raw_notification': t.rawNotification,
    }).toList();

    final resp = await http.post(
      Uri.parse('$_baseUrl/transactions/sync'),
      headers: _headers,
      body: jsonEncode({'transactions': payload}),
    );

    if (resp.statusCode != 200) throw ApiException('Sync falhou', resp.statusCode);

    final list = jsonDecode(resp.body) as List;
    return list.map((e) => SyncedTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateTransaction(
    String localId, {
    bool? isEssential,
    String? category,
    String? place,
    double? amount,
    DateTime? timestamp,
  }) async {
    await _loadToken();
    final body = <String, dynamic>{};
    if (isEssential != null) body['is_essential'] = isEssential;
    if (category    != null) body['category']     = category;
    if (place       != null) body['place']        = place;
    if (amount      != null) body['amount']       = amount;
    if (timestamp   != null) {
      body['timestamp'] = timestamp.toUtc().toIso8601String();
    }

    await http.patch(
      Uri.parse('$_baseUrl/transactions/$localId'),
      headers: _headers,
      body: jsonEncode(body),
    );
  }

  /// Envia feedback de categoria corrigida pelo usuário
  Future<void> categoryFeedback(String localId, TransactionCategory category) async {
    await _loadToken();
    await http.post(
      Uri.parse('$_baseUrl/transactions/feedback'),
      headers: _headers,
      body: jsonEncode({'local_id': localId, 'category': category.name}),
    );
  }

  /// Pede recategorização aprimorada para uma lista de transações
  Future<List<CategorySuggestion>> bulkCategorize(
    List<Transaction> txs,
  ) async {
    await _loadToken();
    final resp = await http.post(
      Uri.parse('$_baseUrl/transactions/categorize'),
      headers: _headers,
      body: jsonEncode(txs.map((t) => {
        'local_id': t.localId,
        'place':    t.place,
      }).toList()),
    );
    if (resp.statusCode != 200) throw ApiException('Categorize falhou', resp.statusCode);
    final list = jsonDecode(resp.body) as List;
    return list.map((e) => CategorySuggestion.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Finance profile ───────────────────────────────────────────────────────

  static FinanceProfile financeProfileFromJson(Map<String, dynamic> j) =>
      FinanceProfile.fromMap(j);

  /// Retorna `null` se o usuário ainda não tem perfil no servidor (404).
  Future<FinanceProfile?> fetchFinanceProfile() async {
    await _loadToken();
    final resp = await http.get(
      Uri.parse('$_baseUrl/finance/profile'),
      headers: _headers,
    );
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw ApiException(
        'Falha ao buscar perfil financeiro: ${_errorMessage(resp)}',
        resp.statusCode,
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return financeProfileFromJson(data);
  }

  Future<void> putFinanceProfile(FinanceProfile profile) async {
    await _loadToken();
    final resp = await http.put(
      Uri.parse('$_baseUrl/finance/profile'),
      headers: _headers,
      body: jsonEncode(profile.toMap()),
    );
    if (resp.statusCode != 200) {
      throw ApiException(
        'Falha ao salvar perfil financeiro: ${_errorMessage(resp)}',
        resp.statusCode,
      );
    }
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<ContextMessage>> fetchMessages() async {
    await _loadToken();
    final resp = await http.get(
      Uri.parse('$_baseUrl/messages/?unread_only=true'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return [];
    final list = jsonDecode(resp.body) as List;
    return list.map((e) => ContextMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> ackMessage(int messageId) async {
    await _loadToken();
    await http.post(
      Uri.parse('$_baseUrl/messages/ack'),
      headers: _headers,
      body: jsonEncode({'message_id': messageId}),
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<NotificationProcessResult?> processNotification({
    required String packageName,
    required String title,
    required String text,
  }) async {
    await _loadToken();
    if (_token == null || _token!.isEmpty) return null;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/notifications/process'),
        headers: _headers,
        body: jsonEncode({
          'package_name': packageName,
          'title': title,
          'text': text,
        }),
      );
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return null;
      return NotificationProcessResult.fromJson(decoded);
    } catch (e, st) {
      debugPrint('Falha ao processar notificação: $e\n$st');
      return null;
    }
  }

  /// Null quando não há sessão ou a rede falha — o espelho local permanece.
  Future<List<AppWhitelistEntry>?> fetchAppWhitelist() async {
    await _loadToken();
    if (_token == null || _token!.isEmpty) return null;
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/notifications/whitelist'),
        headers: _headers,
      );
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AppWhitelistEntry.fromJson)
          .toList();
    } catch (e, st) {
      debugPrint('Falha ao buscar whitelist de apps: $e\n$st');
      return null;
    }
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

class AuthResult {
  final String token;
  final int    userId;
  final String name;
  const AuthResult({required this.token, required this.userId, required this.name});
}

class SyncedTransaction {
  final String localId;
  final int    serverId;
  final bool   suppressedDuplicate;
  const SyncedTransaction({
    required this.localId,
    required this.serverId,
    this.suppressedDuplicate = false,
  });
  factory SyncedTransaction.fromJson(Map<String, dynamic> j) => SyncedTransaction(
        localId: j['local_id'] as String,
        serverId: j['id'] as int,
        suppressedDuplicate: j['suppressed_duplicate'] as bool? ?? false,
      );
}

class NotificationProcessResult {
  final bool accepted;
  final String reason;
  final bool cacheHit;
  final double? amount;
  final String? place;
  final String? category;
  final String? templateHash;
  final String? templateMask;
  final bool isCost;
  final String? extractionRules;

  const NotificationProcessResult({
    required this.accepted,
    required this.reason,
    required this.cacheHit,
    required this.amount,
    required this.place,
    required this.category,
    required this.templateHash,
    required this.templateMask,
    required this.isCost,
    required this.extractionRules,
  });

  factory NotificationProcessResult.fromJson(Map<String, dynamic> j) {
    return NotificationProcessResult(
      accepted: j['accepted'] as bool? ?? false,
      reason: j['reason'] as String? ?? '',
      cacheHit: j['cache_hit'] as bool? ?? false,
      amount: (j['amount'] as num?)?.toDouble(),
      place: j['place'] as String?,
      category: j['category'] as String?,
      templateHash: j['template_hash'] as String?,
      templateMask: j['template_mask'] as String?,
      isCost: j['is_cost'] as bool? ?? false,
      extractionRules: j['extraction_rules'] as String?,
    );
  }
}

class CategorySuggestion {
  final String localId;
  final TransactionCategory category;
  final double confidence;
  final String source;

  const CategorySuggestion({
    required this.localId,
    required this.category,
    required this.confidence,
    required this.source,
  });

  factory CategorySuggestion.fromJson(Map<String, dynamic> j) => CategorySuggestion(
    localId:    j['local_id'] as String,
    category:   TransactionCategoryX.fromDb(j['category'] as String),
    confidence: (j['confidence'] as num).toDouble(),
    source:     j['source'] as String,
  );
}

class ContextMessage {
  final int    id;
  final String trigger;
  final String message;
  final DateTime sentAt;
  bool opened;

  ContextMessage({
    required this.id,
    required this.trigger,
    required this.message,
    required this.sentAt,
    this.opened = false,
  });

  factory ContextMessage.fromJson(Map<String, dynamic> j) => ContextMessage(
    id:      j['id'] as int,
    trigger: j['trigger'] as String,
    message: j['message'] as String,
    sentAt:  DateTime.parse(j['sent_at'] as String),
    opened:  j['opened'] as bool,
  );
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
