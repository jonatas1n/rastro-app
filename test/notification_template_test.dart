import 'package:flutter_test/flutter_test.dart';
import 'package:rastro/models/transaction.dart';
import 'package:rastro/services/notification_mask.dart';
import 'package:rastro/services/notification_rules.dart';

void main() {
  group('máscara de notificação', () {
    test('valores diferentes geram a mesma máscara', () {
      const first = 'Compra aprovada de R\$ 47,90 em IFOOD';
      const second = 'Compra aprovada de R\$ 1.234,56 em IFOOD';
      final firstMask = notificationTemplateMask(first);
      final secondMask = notificationTemplateMask(second);
      expect(firstMask, 'compra aprovada de [VALOR] em ifood');
      expect(secondMask, firstMask);
      expect(notificationTemplateHash(firstMask), notificationTemplateHash(secondMask));
      expect(notificationTemplateHash(firstMask).length, 64);
    });

    test('troca data, hora e número', () {
      const first = 'Debito de R\$ 10,00 em 21/10/2026 as 14:30 final 4321';
      const second = 'Debito de R\$ 99,99 em 01/01/2024 as 08:05 final 9999';
      const expected = 'debito de [VALOR] em [DATA] as [HORA] final [NUM]';
      expect(notificationTemplateMask(first), expected);
      expect(notificationTemplateMask(second), expected);
    });

    test('aplica a regra salva no texto atual', () {
      final extracted = applyExtractionRules(
        'Compra aprovada de R\$ 47,90 em IFOOD',
        {
          'amount_regex': r'R\$\s*(\d{1,3}(?:\.\d{3})*,\d{2}|\d+,\d{2})',
          'place_regex': r'em\s+([A-Za-z0-9]+)',
          'category': 'alimentacao',
        },
      );
      expect(extracted, isNotNull);
      expect(extracted!.amount, closeTo(47.90, 0.001));
      expect(extracted.place, 'IFOOD');
      expect(extracted.category, TransactionCategory.alimentacao);
    });
  });

  group('whitelist e duplicata', () {
    test('autoriza pacote pelo fragmento e rejeita app fora da lista', () {
      expect(packageAllowedByNames('br.com.bradesco', ['bradesco']), isTrue);
      expect(
        packageAllowedByNames('com.example.shop', ['bradesco', 'com.nu.production']),
        isFalse,
      );
      expect(packageAllowedByNames(null, ['bradesco']), isFalse);
    });

    test('detecta gasto repetido na janela de 6 horas', () {
      final now = DateTime(2026, 10, 21, 15);
      final existing = [
        SpendSnapshot(
          amount: 10,
          place: 'ifood',
          timestamp: now.subtract(const Duration(hours: 1)),
        ),
      ];
      expect(
        isRecentDuplicate(
          amount: 10,
          place: ' IFOOD ',
          moment: now,
          existing: existing,
        ),
        isTrue,
      );
      expect(
        isRecentDuplicate(
          amount: 10,
          place: 'IFOOD',
          moment: now,
          existing: [
            SpendSnapshot(
              amount: 10,
              place: 'IFOOD',
              timestamp: now.subtract(const Duration(hours: 7)),
            ),
          ],
        ),
        isFalse,
      );
      expect(
        isRecentDuplicate(
          amount: 11,
          place: 'IFOOD',
          moment: now,
          existing: existing,
        ),
        isFalse,
      );
    });
  });
}
