import '../models/transaction.dart';
import 'bank_notification_sources.dart';
import 'notification_debug_log.dart';

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

  List<NotificationDebugCheck> buildChecks({
    required String title,
    required String body,
    required String? packageName,
    required bool handlerRegistered,
    bool? handlerSucceeded,
    String? handlerError,
  }) {
    final bank = sourceMatch;
    final hasContent = title.trim().isNotEmpty || body.trim().isNotEmpty;
    final hasPackage = packageName != null && packageName.isNotEmpty;

    return [
      const NotificationDebugCheck(
        id: 'received',
        label: 'Notificação recebida',
        ok: true,
      ),
      NotificationDebugCheck(
        id: 'content',
        label: 'Título ou texto presente',
        ok: hasContent,
        detail: hasContent ? null : 'Vazio',
      ),
      NotificationDebugCheck(
        id: 'package',
        label: 'Pacote Android informado',
        ok: hasPackage,
        detail: packageName ?? '(null)',
      ),
      NotificationDebugCheck(
        id: 'bank',
        label: 'Banco no catálogo',
        ok: bank != null,
        detail: bank != null
            ? '${bank.source.label} (${bank.kind.name})'
            : 'Pacote/título não bate com banks.md',
      ),
      NotificationDebugCheck(
        id: 'regex',
        label: 'Valor bate com regex R\$',
        ok: amountRaw != null,
        detail: amountRaw ?? 'Nenhum padrão R\$ / 1.234,56 encontrado',
      ),
      NotificationDebugCheck(
        id: 'amount',
        label: 'Valor numérico válido (> 0)',
        ok: amount != null && amount! > 0,
        detail: amount?.toStringAsFixed(2),
      ),
      NotificationDebugCheck(
        id: 'parsed',
        label: 'Parser montou gasto',
        ok: parsed != null,
      ),
      NotificationDebugCheck(
        id: 'handler',
        label: 'App pronto para salvar (handler)',
        ok: handlerRegistered,
        detail: handlerRegistered ? null : 'Faça login e abra a home',
      ),
      NotificationDebugCheck(
        id: 'saved',
        label: 'Salvo no SQLite + lista',
        ok: handlerSucceeded == true,
        detail: parsed == null
            ? 'Parser não concluiu'
            : handlerError,
      ),
    ];
  }
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
