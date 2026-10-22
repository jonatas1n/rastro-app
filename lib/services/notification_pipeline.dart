import 'package:flutter/foundation.dart';

import '../models/transaction.dart';
import 'api_client.dart';
import 'bank_notification_sources.dart';
import 'database_service.dart';
import 'notification_mask.dart';
import 'notification_parser.dart';
import 'notification_rules.dart';

/// Whitelist, cache local e, no miss, a API. Sem rede, cai no parser regex.
class NotificationPipeline {
  final DatabaseService _db;
  final ApiClient? _api;

  NotificationPipeline({DatabaseService? database, ApiClient? api})
      : _db = database ?? DatabaseService(),
        _api = api;

  Future<Transaction?> resolve({
    required String title,
    required String body,
    String? packageName,
  }) async {
    final source = matchBankNotificationSource(
      packageName: packageName,
      title: title,
      body: body,
    );
    final allowed = packageAllowedByNames(
      packageName,
      await _db.allowedPackageNames(),
    );
    if (source == null && !allowed) return null;

    if (source?.kind == BankSourceMatchKind.caixaSms) {
      return _fromParser(title, body, packageName);
    }

    final raw = '$title $body'.replaceAll('\n', ' ');
    final mask = notificationTemplateMask(raw);
    final hash = notificationTemplateHash(mask);
    final cached = await _db.findNotificationTemplate(hash);
    if (cached != null) {
      final isCost = (cached['is_cost'] as int? ?? 0) == 1;
      if (!isCost) return null;
      final rules = decodeExtractionRules(cached['extraction_rules'] as String? ?? '{}');
      final extracted = applyExtractionRules(raw, rules);
      if (extracted != null) {
        return _rejectIfDuplicate(
          _transaction(
            title: title,
            body: body,
            amount: extracted.amount,
            place: extracted.place ?? source?.source.label ?? 'Gasto',
            category: extracted.category,
          ),
        );
      }
    }

    final canAskApi = _canAskApi(packageName, source, allowed);
    if (canAskApi) {
      final remote = await _api!.processNotification(
        packageName: packageName!,
        title: title,
        text: body,
      );
      if (remote != null) {
        await _rememberRemote(remote);
        if (remote.reason != 'whitelist' && !remote.accepted) return null;
        if (remote.accepted && remote.amount != null && remote.place != null) {
          return _rejectIfDuplicate(
            _transaction(
              title: title,
              body: body,
              amount: remote.amount!,
              place: remote.place!,
              category: TransactionCategoryX.fromDb(remote.category ?? 'outros'),
            ),
          );
        }
      }
    }

    return _fromParser(title, body, packageName);
  }

  bool _canAskApi(String? packageName, BankSourceMatch? source, bool allowed) {
    if (_api == null) return false;
    if (packageName == null || packageName.isEmpty) return false;
    if (source?.kind == BankSourceMatchKind.caixaSms) return false;
    return allowed || source?.kind == BankSourceMatchKind.package;
  }

  Future<void> _rememberRemote(NotificationProcessResult remote) async {
    final hash = remote.templateHash;
    final rules = remote.extractionRules;
    final mask = remote.templateMask;
    if (hash == null || rules == null || mask == null) return;
    try {
      await _db.saveNotificationTemplate(
        templateHash: hash,
        templateMask: mask,
        isCost: remote.isCost,
        extractionRules: rules,
      );
    } catch (e, st) {
      debugPrint('Falha ao gravar cache de notificação: $e\n$st');
    }
  }

  Future<Transaction?> _fromParser(String title, String body, String? packageName) async {
    final parsed = NotificationParser.parse(title, body, packageName: packageName);
    if (parsed == null) return null;
    return _rejectIfDuplicate(
      _transaction(
        title: title,
        body: body,
        amount: parsed.amount,
        place: parsed.place,
        category: parsed.category,
      ),
    );
  }

  Future<Transaction?> _rejectIfDuplicate(Transaction tx) async {
    final since = tx.timestamp.subtract(duplicateWindow);
    final recent = await _db.getSince(since);
    final snapshots = recent.map(
      (item) => SpendSnapshot(
        amount: item.amount,
        place: item.place,
        timestamp: item.timestamp,
      ),
    );
    if (isRecentDuplicate(
      amount: tx.amount,
      place: tx.place,
      moment: tx.timestamp,
      existing: snapshots,
    )) {
      return null;
    }
    return tx;
  }

  Transaction _transaction({
    required String title,
    required String body,
    required double amount,
    required String place,
    required TransactionCategory category,
  }) {
    return Transaction(
      place: place,
      amount: amount,
      category: category,
      timestamp: DateTime.now(),
      isEssential: false,
      rawNotification: '$title | $body',
    );
  }
}

class NotificationWhitelistSync {
  static Future<void> refresh(ApiClient api) async {
    final entries = await api.fetchAppWhitelist();
    if (entries == null) return;
    await DatabaseService().replaceAppWhitelist(entries);
  }
}
