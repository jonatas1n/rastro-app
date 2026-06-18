import 'package:flutter/services.dart';

/// Formata centavos como moeda pt_BR (ex.: 123456 → "1.234,56").
String formatBrMoneyInput(double amount) {
  final cents = (amount * 100).round();
  return _formatCents(cents);
}

/// Interpreta texto mascarado ou parcial como valor em reais.
double? parseBrMoney(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return int.parse(digits) / 100;
}

/// Máscara de digitação: só dígitos, vírgula decimal e separador de milhar.
class BrMoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final cents = int.parse(digits);
    final formatted = _formatCents(cents);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatCents(int cents) {
  final reais = cents ~/ 100;
  final centPart = (cents % 100).toString().padLeft(2, '0');
  return '${_formatIntGroup(reais.toString())},$centPart';
}

String _formatIntGroup(String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}
