import 'package:financial_management/models/expense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logoDomain sobrevive ao roundtrip toJson/fromJson', () {
    final e = Expense(
      amount: 21.90,
      title: 'Spotify',
      category: 'Lazer',
      dueDate: DateTime(2026, 7, 5),
      logoDomain: 'spotify.com',
    );

    final back = Expense.fromJson(e.toJson());

    expect(back.logoDomain, 'spotify.com');
  });

  test('JSON antigo sem logoDomain vira null (retrocompatível)', () {
    final json = {
      'id': 'x',
      'amount': 10.0,
      'title': 'Aluguel',
      'category': 'Moradia',
      'dueDate': DateTime(2026, 7, 5).toIso8601String(),
    };

    final e = Expense.fromJson(json);

    expect(e.logoDomain, isNull);
  });

  test('copyWith preserva o logoDomain', () {
    final e = Expense(
      amount: 1,
      title: 't',
      category: 'c',
      dueDate: DateTime(2026, 1, 1),
      logoDomain: 'itau.com.br',
    );

    expect(e.copyWith(title: 'novo').logoDomain, 'itau.com.br');
  });
}
