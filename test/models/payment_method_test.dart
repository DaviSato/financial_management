import 'package:financial_management/models/expense.dart';
import 'package:financial_management/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromString faz round-trip com o que toJson grava', () {
    for (final method in PaymentMethod.values) {
      final expense = Expense(
        title: 'x',
        amount: 1,
        category: 'c',
        dueDate: DateTime(2026, 1, 1),
        paymentMethod: method,
      );
      final restored = Expense.fromJson(expense.toJson());
      expect(restored.paymentMethod, method, reason: 'método $method');
    }
  });
}
