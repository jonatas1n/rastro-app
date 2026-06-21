import 'package:flutter_test/flutter_test.dart';
import 'package:rastro/models/finance_profile.dart';
import 'package:rastro/models/transaction.dart';
import 'package:rastro/services/bank_notification_sources.dart';
import 'package:rastro/services/notification_parser.dart';

void main() {
  group('NotificationParser', () {
    test('extrai valor de notificação bancária', () {
      final parsed = NotificationParser.parse(
        'Nubank',
        'Compra aprovada de R\$ 47,90 em IFOOD',
        packageName: 'com.nu.production',
      );
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(47.90, 0.001));
      expect(parsed.place, 'Nubank');
      expect(parsed.bankLabel, 'Nubank');
      expect(parsed.category, TransactionCategory.outros);
    });

    test('ignora texto sem valor monetário', () {
      expect(
        NotificationParser.parse(
          'Nubank',
          'Seu cartão chegou',
          packageName: 'com.nu.production',
        ),
        isNull,
      );
    });

    test('detecta banco pelo título sem pacote', () {
      expect(
        NotificationParser.isBankSource(packageName: null, title: 'Bradesco'),
        isTrue,
      );
    });

    test('ignora app genérico fora do catálogo', () {
      expect(
        NotificationParser.parse(
          'Minha Loja',
          'Compra aprovada de R\$ 10,00 em TESTE',
          packageName: 'com.example.shop',
        ),
        isNull,
      );
    });

    test('detecta compra Caixa via SMS', () {
      final parsed = NotificationParser.parse(
        'CAIXA',
        'Compra debitada R\$ 32,15 cartao final 1234',
        packageName: 'com.google.android.apps.messaging',
      );
      expect(parsed, isNotNull);
      expect(parsed!.amount, closeTo(32.15, 0.001));
      expect(parsed.bankLabel, 'Caixa');
    });

    test('ignora SMS sem menção à Caixa', () {
      expect(
        NotificationParser.parse(
          'Nubank',
          'Compra R\$ 10,00',
          packageName: 'com.google.android.apps.messaging',
        ),
        isNull,
      );
    });
  });

  group('bankNotificationSources', () {
    test('cobre bancos listados em banks.md', () {
      const expectedIds = {
        'bb',
        'itau',
        'bradesco',
        'santander',
        'caixa',
        'nubank',
        'inter',
        'c6',
        'pagbank',
        'mercado_pago',
        'picpay',
        'neon',
        'iti',
        'next',
        'original',
        'bmg',
        'pan',
        'agibank',
        'btg',
        'bs2',
        'mercantil',
        'bv',
        'sicoob',
        'sicredi',
        '99pay',
        'digimais',
        'zro',
        'stark',
        's3',
        'ngcash',
        'n26',
        'digio',
      };
      final ids = bankNotificationSources.map((s) => s.id).toSet();
      expect(ids, expectedIds);
    });
  });

  group('FinanceProfile', () {
    test('calcula ciclo que cruza mês', () {
      const profile = FinanceProfile(payDay: 25, cycleEndDay: 10);
      final period = financePeriodFor(DateTime(2026, 6, 20), profile);
      expect(period.start.day, 25);
      expect(period.start.month, 5);
      expect(period.end.day, 10);
      expect(period.end.month, 6);
    });
  });
}
