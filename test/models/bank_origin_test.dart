import 'package:financial_management/models/bank_origin.dart';
import 'package:financial_management/models/expense.dart';
import 'package:financial_management/models/income.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const origin = BankOrigin(name: 'Bradesco', logoDomain: 'bradesco.com.br');

  test('gasto guarda o banco de origem no round-trip', () {
    final e = Expense(
      amount: 10,
      title: 'Padaria',
      category: 'Mercado',
      dueDate: DateTime(2026, 10, 14),
      bankOrigin: origin,
    );

    final restored = Expense.fromJson(e.toJson());

    expect(restored.bankOrigin?.name, 'Bradesco');
    expect(restored.bankOrigin?.logoDomain, 'bradesco.com.br');
  });

  test('rendimento guarda o banco de origem no round-trip', () {
    final i = Income(amount: 100, title: 'Pix', bankOrigin: origin);

    final restored = Income.fromJson(i.toJson());

    expect(restored.bankOrigin?.name, 'Bradesco');
  });

  test('lançamento manual e JSON antigo ficam sem origem', () {
    final e = Expense(
      amount: 10,
      title: 'X',
      category: 'Y',
      dueDate: DateTime(2026, 10, 14),
    );
    final json = e.toJson()..remove('bankOrigin');

    expect(Expense.fromJson(json).bankOrigin, isNull);
    expect(Income.fromJson(Income(amount: 1, title: 'X').toJson()).bankOrigin,
        isNull);
  });

  test('copyWith preserva a origem (ocorrências de recorrentes/parcelas)', () {
    final e = Expense(
      amount: 10,
      title: 'X',
      category: 'Y',
      dueDate: DateTime(2026, 10, 14),
      bankOrigin: origin,
    );

    expect(e.copyWith(amount: 5).bankOrigin?.name, 'Bradesco');
    expect(
      Income(amount: 1, title: 'X', bankOrigin: origin)
          .copyWith(amount: 2)
          .bankOrigin
          ?.name,
      'Bradesco',
    );
  });
}
