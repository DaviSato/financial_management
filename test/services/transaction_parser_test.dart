import 'package:financial_management/models/captured_notification.dart';
import 'package:financial_management/models/parsed_transaction.dart';
import 'package:financial_management/models/payment_method.dart';
import 'package:financial_management/services/transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

CapturedNotification cap(String title, String body, {String pkg = 'com.nu.production'}) {
  return CapturedNotification(
    packageName: pkg,
    title: title,
    text: body,
    bigText: '',
    subText: '',
    postedAt: DateTime(2026, 7, 20, 14, 30),
    filePath: '/tmp/x.json',
  );
}

void main() {
  const parser = TransactionParser();

  group('débito (formato real confirmado)', () {
    test('extrai valor, tipo, método e estabelecimento', () {
      final result = parser.parse(cap(
        'Compra no débito aprovada',
        'Compra de R\$ 32,22 em BistroRestaurante',
      ));

      expect(result, isNotNull);
      expect(result!.type, TransactionType.expense);
      expect(result.amount, 32.22);
      expect(result.paymentMethod, PaymentMethod.debitCard);
      expect(result.description, 'BistroRestaurante');
      expect(result.ruleLabel, 'Débito');
      expect(result.provisional, isFalse);
    });

    test('o "de R\$" antes do valor não vira contraparte', () {
      final result = parser.parse(cap(
        'Compra no débito aprovada',
        'Compra de R\$ 32,22 em BistroRestaurante',
      ));
      // Se o prefixo "de" tivesse vencido, a descrição viria "R\$ 32,22 em...".
      expect(result!.description, 'BistroRestaurante');
    });

    test('valor com milhar', () {
      final result = parser.parse(cap(
        'Compra no débito aprovada',
        'Compra de R\$ 1.234,56 em SUPERMERCADO',
      ));
      expect(result!.amount, 1234.56);
    });
  });

  group('rejeição', () {
    test('compra negada não vira lançamento', () {
      final result = parser.parse(cap(
        'Compra negada',
        'Compra de R\$ 32,22 em BistroRestaurante negada por saldo',
      ));
      expect(result, isNull);
    });

    test('estorno é ignorado', () {
      final result = parser.parse(cap(
        'Estorno',
        'Estorno de R\$ 50,00 em LOJA',
      ));
      expect(result, isNull);
    });
  });

  group('não reconhecido', () {
    test('texto sem valor retorna null', () {
      final result = parser.parse(cap(
        'Novidade no app',
        'Confira as novidades do seu cartão',
      ));
      expect(result, isNull);
    });

    test('valor sem palavra-chave de tipo retorna null', () {
      final result = parser.parse(cap(
        'Aviso',
        'Seu limite é de R\$ 500,00',
      ));
      expect(result, isNull);
    });
  });

  group('regras provisórias (a confirmar com texto real)', () {
    test('crédito é marcado como provisório', () {
      final result = parser.parse(cap(
        'Compra aprovada',
        'Compra no crédito de R\$ 89,90 em POSTO',
      ));
      expect(result, isNotNull);
      expect(result!.paymentMethod, PaymentMethod.creditCard);
      expect(result.type, TransactionType.expense);
      expect(result.provisional, isTrue);
    });

    test('pix recebido é classificado como rendimento', () {
      final result = parser.parse(cap(
        'Pix recebido',
        'Você recebeu um Pix de R\$ 200,00 de Fulano',
      ));
      expect(result, isNotNull);
      expect(result!.type, TransactionType.income);
      expect(result.provisional, isTrue);
    });
  });

  group('deduplicação', () {
    test('mesma compra gera a mesma chave', () {
      final a = parser.parse(cap('Compra no débito aprovada', 'Compra de R\$ 32,22 em X'));
      final b = parser.parse(cap('Compra no débito aprovada', 'Compra de R\$ 32,22 em X'));
      expect(a!.dedupeKey, b!.dedupeKey);
    });

    test('valores diferentes geram chaves diferentes', () {
      final a = parser.parse(cap('Compra no débito aprovada', 'Compra de R\$ 32,22 em X'));
      final b = parser.parse(cap('Compra no débito aprovada', 'Compra de R\$ 33,00 em X'));
      expect(a!.dedupeKey, isNot(b!.dedupeKey));
    });
  });
}
