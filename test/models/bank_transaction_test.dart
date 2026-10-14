import 'package:financial_management/models/bank_transaction.dart';
import 'package:financial_management/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

const checking = BankAccount(id: 'acc-1', name: 'Conta', isCreditCard: false);
const card = BankAccount(id: 'acc-2', name: 'Cartão', isCreditCard: true);

Map<String, dynamic> tx({
  String id = 't1',
  String type = 'DEBIT',
  num amount = -50.0,
  String date = '2026-10-15T00:00:00.000Z',
  String description = 'COMPRA',
  String status = 'POSTED',
  Map<String, dynamic>? merchant,
  Map<String, dynamic>? paymentData,
  Map<String, dynamic>? creditCardMetadata,
  String? operationType,
  num? amountInAccountCurrency,
}) {
  return {
    'id': id,
    'type': type,
    'amount': amount,
    'date': date,
    'description': description,
    'status': status,
    'merchant': ?merchant,
    'paymentData': ?paymentData,
    'creditCardMetadata': ?creditCardMetadata,
    'operationType': ?operationType,
    'amountInAccountCurrency': ?amountInAccountCurrency,
  };
}

BankTransaction? parse(Map<String, dynamic> json, {BankAccount account = checking}) =>
    BankTransaction.fromPluggy(json, account: account, institution: 'Nubank');

void main() {
  test('DEBIT vira gasto com valor positivo', () {
    final t = parse(tx(amount: -212.45))!;
    expect(t.type, TransactionType.expense);
    expect(t.amount, 212.45);
    expect(t.institution, 'Nubank');
    expect(t.accountId, 'acc-1');
  });

  test('CREDIT vira rendimento', () {
    final t = parse(tx(type: 'CREDIT', amount: 2482.26))!;
    expect(t.type, TransactionType.income);
    expect(t.amount, 2482.26);
  });

  test('data à meia-noite UTC não volta para o dia anterior', () {
    final t = parse(tx(date: '2026-10-15T00:00:00.000Z'))!;
    expect(t.date, DateTime(2026, 10, 15));
  });

  test('gasto usa o nome do estabelecimento', () {
    final t = parse(tx(merchant: {'name': 'Padaria Real'}))!;
    expect(t.description, 'Padaria Real');
  });

  test('pix recebido usa o nome de quem pagou', () {
    final t = parse(tx(
      type: 'CREDIT',
      amount: 100,
      description: 'PIX RECEBIDO',
      paymentData: {
        'paymentMethod': 'PIX',
        'payer': {'name': 'Maria Souza'},
        'receiver': {'name': 'Eu Mesmo'},
      },
    ))!;
    expect(t.description, 'Maria Souza');
    expect(t.paymentMethod, PaymentMethod.pix);
  });

  test('sem contraparte cai na descrição da Pluggy', () {
    final t = parse(tx(description: 'TARIFA MENSAL'))!;
    expect(t.description, 'TARIFA MENSAL');
  });

  test('forma de pagamento pelo trilho', () {
    expect(parse(tx(operationType: 'PIX'))!.paymentMethod, PaymentMethod.pix);
    expect(
      parse(tx(paymentData: {'paymentMethod': 'BOLETO'}))!.paymentMethod,
      PaymentMethod.bankSlip,
    );
    expect(
      parse(tx(paymentData: {'paymentMethod': 'TED'}))!.paymentMethod,
      PaymentMethod.bankTransfer,
    );
    expect(parse(tx())!.paymentMethod, isNull);
  });

  test('compra no cartão: crédito, pendente e parcelada', () {
    final t = parse(
      tx(
        amount: 159.2,
        status: 'PENDING',
        creditCardMetadata: {'installmentNumber': 1, 'totalInstallments': 3},
      ),
      account: card,
    )!;
    expect(t.type, TransactionType.expense);
    expect(t.paymentMethod, PaymentMethod.creditCard);
    expect(t.pending, true);
    expect(t.isInstallment, true);
    expect(t.installmentNumber, 1);
    expect(t.totalInstallments, 3);
  });

  test('pagamento da fatura do lado do cartão é ignorado', () {
    final json = tx(
      type: 'CREDIT',
      amount: 1200,
      operationType: 'PAGAMENTO_FATURA',
    );
    expect(parse(json, account: card), isNull);
    // Na conta corrente o mesmo pagamento é dinheiro saindo de verdade.
    expect(parse(tx(operationType: 'PAGAMENTO_FATURA')), isNotNull);
  });

  test('compra em moeda estrangeira usa o valor convertido', () {
    final t = parse(tx(amount: -50, amountInAccountCurrency: -298.19))!;
    expect(t.amount, 298.19);
  });

  test('fingerprint ignora o id', () {
    final pending = parse(tx(id: 'a', status: 'PENDING'))!;
    final posted = parse(tx(id: 'b'))!;
    expect(pending.fingerprint, posted.fingerprint);
  });

  test('rótulo da conta: nome e final do número', () {
    final account = BankAccount.fromPluggy({
      'id': 'acc-9',
      'type': 'BANK',
      'name': 'Conta Corrente',
      'number': '1234/56789-0',
    });
    expect(account.label, 'Conta Corrente ••7890');
    expect(parse(tx(), account: account)!.accountLabel, 'Conta Corrente ••7890');
  });

  test('rótulo da conta sem número fica só com o nome', () {
    expect(checking.label, 'Conta');
  });
}
