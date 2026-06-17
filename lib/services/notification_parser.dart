import '../models/transaction.dart';

/// Resultado do parse de uma notificação
class ParsedNotification {
  final double amount;
  final String place;
  final TransactionCategory category;

  const ParsedNotification({
    required this.amount,
    required this.place,
    required this.category,
  });
}

/// Parser de notificações de bancos brasileiros.
///
/// Suporta padrões comuns de:
/// Nubank, Inter, Bradesco, Itaú, Santander, C6, PicPay, PagBank
class NotificationParser {
  // ── Padrões de valor ──────────────────────────────────────────────────────

  // "R$ 47,90" | "R$47.90" | "47,90" após palavras-chave
  static final _amountRe = RegExp(
    r'R\$\s*(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})'
    r'|(\d{1,3}(?:\.\d{3})*,\d{2})',
    caseSensitive: false,
  );

  // ── Padrões de estabelecimento ────────────────────────────────────────────

  // "em <Nome>" | "no <Nome>" | "na <Nome>"
  static final _placePrep = RegExp(
    r'\b(?:em|no|na|para|de)\s+([A-Za-zÀ-ú0-9 &.\-]{2,40})',
    caseSensitive: false,
  );

  // "Compra aprovada: <Nome>" | "Compra realizada em <Nome>"
  static final _placeColon = RegExp(
    r'(?:compra|pagamento|débito)[^:]*:\s*([A-Za-zÀ-ú0-9 &.\-]{2,40})',
    caseSensitive: false,
  );

  // ── Mapa de palavras-chave → categoria ───────────────────────────────────
  static final _categoryMap = <RegExp, TransactionCategory>{
    // Alimentação
    RegExp(r'ifood|rappi|uber.?eat|james|mcdonalds|burger|subway|pizza|padaria|lanchonete|restaurante|cafe|açaí', caseSensitive: false):
        TransactionCategory.alimentacao,

    // Mercado
    RegExp(r'pão de açúcar|extra|carrefour|atacadão|assaí|mercado|hortifruti|supermercado|sacolão', caseSensitive: false):
        TransactionCategory.mercado,

    // Transporte
    RegExp(r'\b99\b|uber|cabify|taxi|posto|shell|ipiranga|petrobras|br.?distribuidora|combustível|gasolina|estacionamento|onibus|metrô', caseSensitive: false):
        TransactionCategory.transporte,

    // Saúde
    RegExp(r'farmácia|drogaria|droga|panvel|ultrafarma|pacheco|hospital|clínica|laboratorio|exame|dentista|médico', caseSensitive: false):
        TransactionCategory.saude,

    // Compras
    RegExp(r'amazon|shopee|americanas|magazineluiza|magalu|renner|riachuelo|lojas|shopping|mercado.?livre', caseSensitive: false):
        TransactionCategory.compras,

    // Lazer
    RegExp(r'netflix|spotify|amazon.?prime|hbo|disney|cinema|teatro|show|steam|playstation|xbox|bar|balada|clube', caseSensitive: false):
        TransactionCategory.lazer,
  };

  // ── Pacotes que devem ser ignorados (não são gastos) ─────────────────────
  static final _ignore = RegExp(
    r'pix\s+recebido|crédito\s+em|transferência\s+recebida|saldo\s+disponível|limite\s+disponível|extrato',
    caseSensitive: false,
  );

  /// Tenta extrair valor, estabelecimento e categoria de um texto de notificação.
  /// Retorna null se não parecer um gasto.
  static ParsedNotification? parse(String title, String body) {
    final text = '$title $body';

    // Filtra notificações que não são gastos
    if (_ignore.hasMatch(text)) return null;

    // Deve conter palavra que indique gasto
    final isExpense = RegExp(
      r'compra|pagamento|débito|debitado|gasto|aprovad|realizado|pix\s+enviado',
      caseSensitive: false,
    ).hasMatch(text);
    if (!isExpense) return null;

    // Extrai valor
    final amountMatch = _amountRe.firstMatch(text);
    if (amountMatch == null) return null;

    final rawAmount = (amountMatch.group(1) ?? amountMatch.group(2))!
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final amount = double.tryParse(rawAmount);
    if (amount == null || amount <= 0) return null;

    // Extrai estabelecimento
    final placeMatch = _placeColon.firstMatch(text) ?? _placePrep.firstMatch(text);
    final rawPlace   = placeMatch?.group(1)?.trim() ?? _extractAppName(title);
    final place      = _cleanPlace(rawPlace);

    // Detecta categoria
    final category = _detectCategory(text);

    return ParsedNotification(amount: amount, place: place, category: category);
  }

  static String _extractAppName(String title) {
    // "Nubank", "Inter", "Bradesco" costumam ser o título da notificação
    final clean = title.split(RegExp(r'[-:|]')).first.trim();
    return clean.isEmpty ? 'Desconhecido' : clean;
  }

  static String _cleanPlace(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[*#@]'), '')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static TransactionCategory _detectCategory(String text) {
    for (final entry in _categoryMap.entries) {
      if (entry.key.hasMatch(text)) return entry.value;
    }
    return TransactionCategory.outros;
  }
}
