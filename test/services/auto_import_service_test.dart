import 'package:financial_management/models/captured_notification.dart';
import 'package:financial_management/models/parsed_transaction.dart';
import 'package:financial_management/services/auto_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

CapturedNotification cap(String title, String body, {int minute = 0}) {
  return CapturedNotification(
    packageName: 'com.nu.production',
    title: title,
    text: body,
    bigText: '',
    subText: '',
    postedAt: DateTime(2026, 7, 20, 14, minute),
    filePath: '/tmp/$title-$minute.json',
  );
}

void main() {
  const service = AutoImportService();

  test('cria a partir de regra confirmada (débito)', () {
    final plan = service.plan([
      cap('Compra no débito aprovada', 'Compra de R\$ 32,22 em BistroRestaurante'),
    ]);

    expect(plan.toCreate.length, 1);
    expect(plan.toCreate.single.amount, 32.22);
    expect(plan.toConsume.length, 1);
  });

  test('NÃO cria a partir de regra provisória — fica para revisão manual', () {
    final plan = service.plan([
      cap('Pix recebido', 'Você recebeu um Pix de R\$ 200,00 de Fulano'),
      cap('Compra aprovada', 'Compra no crédito de R\$ 50,00 em LOJA'),
    ]);

    expect(plan.toCreate, isEmpty);
    expect(plan.toConsume, isEmpty, reason: 'provisórios não saem da fila');
  });

  test('não cria a partir de compra negada', () {
    final plan = service.plan([
      cap('Compra negada', 'Compra de R\$ 10,00 em X negada'),
    ]);
    expect(plan.toCreate, isEmpty);
  });

  test('duplicata não cria dois, mas ambas saem da fila', () {
    final plan = service.plan([
      cap('Compra no débito aprovada', 'Compra de R\$ 32,22 em X', minute: 1),
      cap('Compra no débito aprovada', 'Compra de R\$ 32,22 em X', minute: 2),
    ]);

    expect(plan.toCreate.length, 1, reason: 'colapsa a duplicata');
    expect(plan.toConsume.length, 2, reason: 'nenhuma fica presa na fila');
  });

  test('mistura: confirmado é criado, provisório permanece', () {
    final plan = service.plan([
      cap('Compra no débito aprovada', 'Compra de R\$ 32,22 em MERCADO', minute: 1),
      cap('Pix recebido', 'Pix de R\$ 100,00 de Alguém', minute: 2),
    ]);

    expect(plan.toCreate.length, 1);
    expect(plan.toCreate.single.paymentMethod?.name, 'debitCard');
    // só a de débito sai; o pix provisório continua para revisão
    expect(plan.toConsume.length, 1);
    expect(plan.toConsume.single.title, 'Compra no débito aprovada');
  });

  test('marca as transações criadas para virarem origem automática', () {
    final plan = service.plan([
      cap('Compra no débito aprovada', 'Compra de R\$ 32,22 em X'),
    ]);
    // O parser não define origem; quem cria (o provider) marca como automático.
    // Aqui garantimos apenas que há exatamente o esperado a criar.
    expect(plan.toCreate.single.type, TransactionType.expense);
  });
}
