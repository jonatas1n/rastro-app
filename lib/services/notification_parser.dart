import '../models/transaction.dart';
import 'bank_notification_sources.dart';

class ParsedNotification {
  final double amount;
  final String place;
  final TransactionCategory category;
  final String? bankLabel;

  const ParsedNotification({
    required this.amount,
    required this.place,
    required this.category,
    this.bankLabel,
  });
}

class NotificationAnalyzeResult {
  final BankSourceMatch? sourceMatch;
  final String? amountRaw;
  final double? amount;
  final ParsedNotification? parsed;

  const NotificationAnalyzeResult({
    this.sourceMatch,
    this.amountRaw,
    this.amount,
    this.parsed,
  });
}

/// Notificações de bancos do catálogo: extrai somente o valor (R$).
class NotificationParser {
  static final amountPattern = RegExp(
    r'R\$\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)'
    r'|R\$\s*(\d+(?:,\d{2})?)'
    r'|(\d{1,3}(?:\.\d{3})*,\d{2})',
    caseSensitive: false,
  );

  static bool isBankSource({
    String? packageName,
    required String title,
    String body = '',
  }) {
    return matchBankNotificationSource(
          packageName: packageName,
          title: title,
          body: body,
        ) !=
        null;
  }

  static NotificationAnalyzeResult analyze(
    String title,
    String body, {
    String? packageName,
  }) {
    final sourceMatch = matchBankNotificationSource(
      packageName: packageName,
      title: title,
      body: body,
    );
    final text = '$title $body'.replaceAll('\n', ' ');
    final amountRaw = _amountRaw(text);
    final amount = _parseAmount(text);
    ParsedNotification? parsed;
    if (sourceMatch != null && amount != null && amount > 0) {
      final bankLabel = sourceMatch.source.label;
      parsed = ParsedNotification(
        amount: amount,
        place: bankLabel,
        category: TransactionCategory.outros,
        bankLabel: bankLabel,
      );
    }
    return NotificationAnalyzeResult(
      sourceMatch: sourceMatch,
      amountRaw: amountRaw,
      amount: amount,
      parsed: parsed,
    );
  }

  static ParsedNotification? parse(
    String title,
    String body, {
    String? packageName,
  }) {
    return analyze(title, body, packageName: packageName).parsed;
  }

  static String? _amountRaw(String text) {
    final match = amountPattern.firstMatch(text);
    if (match == null) return null;
    return match.group(0);
  }

  static double? _parseAmount(String text) {
    final match = amountPattern.firstMatch(text);
    if (match == null) return null;
    final raw = (match.group(1) ?? match.group(2) ?? match.group(3))!;
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}
