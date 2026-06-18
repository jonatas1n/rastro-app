import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

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
      return AuthResult(
        token:  data['access_token'] as String,
        userId: data['user_id'] as int,
        name:   data['name'] as String,
      );
    }
    throw ApiException(_errorMessage(resp), resp.statusCode);
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
  const SyncedTransaction({required this.localId, required this.serverId});
  factory SyncedTransaction.fromJson(Map<String, dynamic> j) =>
      SyncedTransaction(localId: j['local_id'] as String, serverId: j['id'] as int);
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
