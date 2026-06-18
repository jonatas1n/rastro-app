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

/// Parser de notificações — só processa origens do catálogo [bankNotificationSources].
class NotificationParser {
  static final _amountRe = RegExp(
    r'R\$\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)'
    r'|R\$\s*(\d+(?:,\d{2})?)'
    r'|(\d{1,3}(?:\.\d{3})*,\d{2})',
    caseSensitive: false,
  );

  static final _placePrep = RegExp(
    r'\b(?:em|no|na|para|de|@)\s+([A-Za-zÀ-ú0-9 &.\-]{2,45})',
    caseSensitive: false,
  );

  static final _placeColon = RegExp(
    r'(?:compra|pagamento|d[eé]bito|transa[cç][aã]o)[^:]*:\s*([A-Za-zÀ-ú0-9 &.\-]{2,45})',
    caseSensitive: false,
  );

  static final _categoryMap = <RegExp, TransactionCategory>{
    RegExp(r'ifood|rappi|uber.?eat|mcdonalds|burger|subway|pizza|padaria|lanchonete|restaurante|cafe|açaí', caseSensitive: false):
        TransactionCategory.alimentacao,
    RegExp(r'pão de açúcar|extra|carrefour|atacadão|assaí|mercado|hortifruti|supermercado|sacolão', caseSensitive: false):
        TransactionCategory.mercado,
    RegExp(r'\b99\b|uber|cabify|taxi|posto|shell|ipiranga|petrobras|combustível|gasolina|estacionamento|metrô', caseSensitive: false):
        TransactionCategory.transporte,
    RegExp(r'farmácia|drogaria|droga|panvel|ultrafarma|hospital|clínica|laboratorio|dentista|médico', caseSensitive: false):
        TransactionCategory.saude,
    RegExp(r'amazon|shopee|americanas|magazineluiza|magalu|renner|riachuelo|shopping|mercado.?livre', caseSensitive: false):
        TransactionCategory.compras,
    RegExp(r'netflix|spotify|amazon.?prime|hbo|disney|cinema|steam|playstation|xbox|bar|balada', caseSensitive: false):
        TransactionCategory.lazer,
  };

  static final _ignore = RegExp(
    r'pix\s+recebido|cr[eé]dito\s+em|transfer[eê]ncia\s+recebida|saldo\s+dispon[ií]vel|'
    r'limite\s+dispon[ií]vel|extrato|fatura\s+fechada|pagamento\s+recebido|'
    r'entrada\s+de\s+pix|voc[eê]\s+recebeu',
    caseSensitive: false,
  );

  static final _expenseRe = RegExp(
    r'compra|pagamento|d[eé]bito|debitado|gasto|aprovad|realizad|pix\s+enviado|'
    r'transa[cç][aã]o\s+aprovada|cart[aã]o\s+final|sa[ií]da\s+de\s+pix|compras\s+no',
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

  static ParsedNotification? parse(
    String title,
    String body, {
    String? packageName,
  }) {
    final text = '$title $body'.replaceAll('\n', ' ');
    if (_ignore.hasMatch(text)) return null;

    final sourceMatch = matchBankNotificationSource(
      packageName: packageName,
      title: title,
      body: body,
    );
    if (sourceMatch == null) return null;

    if (_needsExpenseSignal(sourceMatch.kind) && !_expenseRe.hasMatch(text)) {
      return null;
    }

    final amount = _parseAmount(text);
    if (amount == null || amount <= 0) return null;

    final bankLabel = sourceMatch.source.label;
    final placeMatch = _placeColon.firstMatch(text) ?? _placePrep.firstMatch(text);
    final rawPlace = placeMatch?.group(1)?.trim() ??
        bankLabel ??
        _extractAppName(title);
    final place = _cleanPlace(rawPlace);
    final category = _detectCategory(text);

    return ParsedNotification(
      amount: amount,
      place: place,
      category: category,
      bankLabel: bankLabel,
    );
  }

  static bool _needsExpenseSignal(BankSourceMatchKind kind) {
    return kind == BankSourceMatchKind.notificationTitle ||
        kind == BankSourceMatchKind.caixaSms;
  }

  static double? _parseAmount(String text) {
    final match = _amountRe.firstMatch(text);
    if (match == null) return null;
    final raw = (match.group(1) ?? match.group(2) ?? match.group(3))!;
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  static String _extractAppName(String title) {
    final clean = title.split(RegExp(r'[-:|]')).first.trim();
    return clean.isEmpty ? 'Desconhecido' : clean;
  }

  static String _cleanPlace(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[*#@]'), '')
        .trim()
        .split(' ')
        .map((w) =>
            w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static TransactionCategory _detectCategory(String text) {
    for (final entry in _categoryMap.entries) {
      if (entry.key.hasMatch(text)) return entry.value;
    }
    return TransactionCategory.outros;
  }
}
