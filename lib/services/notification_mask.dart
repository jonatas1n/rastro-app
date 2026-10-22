import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/transaction.dart';

final _whitespace = RegExp(r'\s+');
final _money = RegExp(
  r"r\$\s*\d{1,3}(?:\.\d{3})*(?:,\d{2})?"
  r"|r\$\s*\d+(?:,\d{2})?"
  r"|\d{1,3}(?:\.\d{3})+,\d{2}"
  r"|\d+,\d{2}",
);
final _date = RegExp(
  r'\b\d{4}-\d{2}-\d{2}\b'
  r'|\b\d{1,2}/\d{1,2}/\d{2,4}\b'
  r'|\b\d{1,2}/\d{1,2}\b',
);
final _time = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b');
final _number = RegExp(r'\d+');

const defaultAmountRegex =
    r"R\$\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)|R\$\s*(\d+(?:,\d{2})?)|(\d{1,3}(?:\.\d{3})*,\d{2})";
const defaultPlaceRegex =
    r"(?:em|no|na|estabelecimento)\s+([A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9 .&'*_-]{1,60})";

/// Mesma normalização do servidor: valor, data, hora e números viram placeholders.
String notificationTemplateMask(String text) {
  var masked = text.replaceAll(_whitespace, ' ').trim().toLowerCase();
  masked = masked.replaceAll(_money, '[VALOR]');
  masked = masked.replaceAll(_date, '[DATA]');
  masked = masked.replaceAll(_time, '[HORA]');
  masked = masked.replaceAll(_number, '[NUM]');
  return masked.replaceAll(_whitespace, ' ').trim();
}

String notificationTemplateHash(String mask) {
  return sha256.convert(utf8.encode(mask)).toString();
}

class TemplateExtraction {
  final double amount;
  final String? place;
  final TransactionCategory category;

  const TemplateExtraction({
    required this.amount,
    required this.place,
    required this.category,
  });
}

TemplateExtraction? applyExtractionRules(String text, Map<String, dynamic> rules) {
  final amountPattern = rules['amount_regex'] as String?;
  final amount = _extractAmount(text, amountPattern);
  if (amount == null) return null;

  final placePattern = rules['place_regex'] as String?;
  final categoryRaw = rules['category'] as String? ?? 'outros';
  return TemplateExtraction(
    amount: amount,
    place: _extractPlace(text, placePattern),
    category: TransactionCategoryX.fromDb(categoryRaw),
  );
}

Map<String, dynamic> decodeExtractionRules(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (e) {
    debugPrint('Regras de extração inválidas: $e');
  }
  return {};
}

double? parseBrlAmount(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'r\$', caseSensitive: false), '')
      .trim()
      .replaceAll('.', '')
      .replaceAll(',', '.');
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0) return null;
  return value;
}

double? _extractAmount(String text, String? pattern) {
  final patterns = <String>[
    if (pattern != null && pattern.isNotEmpty) pattern,
    defaultAmountRegex,
  ];
  final seen = <String>{};
  for (final candidate in patterns) {
    if (!seen.add(candidate)) continue;
    final group = _firstCapture(candidate, text);
    if (group == null) continue;
    final amount = parseBrlAmount(group);
    if (amount != null) return amount;
  }
  return null;
}

String? _extractPlace(String text, String? pattern) {
  final patterns = <String>[
    if (pattern != null && pattern.isNotEmpty) pattern,
    defaultPlaceRegex,
  ];
  final seen = <String>{};
  for (final candidate in patterns) {
    if (!seen.add(candidate)) continue;
    final group = _firstCapture(candidate, text);
    if (group == null) continue;
    final place = group.trim().replaceAll(RegExp(r'^[ ., -]+|[ ., -]+$'), '');
    if (place.isEmpty) continue;
    return place.length > 80 ? place.substring(0, 80) : place;
  }
  return null;
}

String? _firstCapture(String pattern, String text) {
  final RegExp expression;
  try {
    expression = RegExp(pattern, caseSensitive: false);
  } on FormatException catch (e) {
    debugPrint('Regex de extração inválida: $e');
    return null;
  }
  final match = expression.firstMatch(text);
  if (match == null) return null;
  for (var index = 1; index <= match.groupCount; index++) {
    final group = match.group(index);
    if (group != null && group.isNotEmpty) return group;
  }
  return null;
}
