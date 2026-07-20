import 'package:financial_management/models/entry_origin.dart';
import 'package:financial_management/models/expense.dart';
import 'package:financial_management/models/income.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntryOrigin.fromString', () {
    test('valores conhecidos', () {
      expect(EntryOrigin.fromString('manual'), EntryOrigin.manual);
      expect(EntryOrigin.fromString('automatic'), EntryOrigin.automatic);
    });

    test('ausente ou desconhecido cai em manual (dados antigos)', () {
      expect(EntryOrigin.fromString(null), EntryOrigin.manual);
      expect(EntryOrigin.fromString(''), EntryOrigin.manual);
      expect(EntryOrigin.fromString('sei la'), EntryOrigin.manual);
    });
  });

  group('Expense', () {
    test('padrão é manual', () {
      final e = Expense(
        title: 'x',
        amount: 1,
        category: 'c',
        dueDate: DateTime(2026, 1, 1),
      );
      expect(e.origin, EntryOrigin.manual);
    });

    test('origin faz round-trip no JSON', () {
      final e = Expense(
        title: 'x',
        amount: 1,
        category: 'c',
        dueDate: DateTime(2026, 1, 1),
        origin: EntryOrigin.automatic,
      );
      expect(Expense.fromJson(e.toJson()).origin, EntryOrigin.automatic);
    });

    test('lançamento salvo sem o campo é lido como manual', () {
      final legacy = {
        'id': 'a',
        'title': 'Antigo',
        'amount': 10.0,
        'category': 'c',
        'dueDate': DateTime(2025, 1, 1).toIso8601String(),
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      };
      expect(Expense.fromJson(legacy).origin, EntryOrigin.manual);
    });

    test('copyWith preserva e altera a origem', () {
      final e = Expense(
        title: 'x',
        amount: 1,
        category: 'c',
        dueDate: DateTime(2026, 1, 1),
      );
      expect(e.copyWith(amount: 2).origin, EntryOrigin.manual);
      expect(e.copyWith(origin: EntryOrigin.automatic).origin,
          EntryOrigin.automatic);
    });
  });

  group('Income', () {
    test('padrão é manual', () {
      final i = Income(title: 'x', amount: 1);
      expect(i.origin, EntryOrigin.manual);
    });

    test('origin faz round-trip no JSON', () {
      final i = Income(
        title: 'x',
        amount: 1,
        origin: EntryOrigin.automatic,
      );
      expect(Income.fromJson(i.toJson()).origin, EntryOrigin.automatic);
    });

    test('lançamento salvo sem o campo é lido como manual', () {
      final legacy = {
        'id': 'a',
        'title': 'Antigo',
        'amount': 10.0,
        'recurrenceType': 'once',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      };
      expect(Income.fromJson(legacy).origin, EntryOrigin.manual);
    });
  });
}
