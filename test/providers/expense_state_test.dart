import 'package:financial_management/models/expense.dart';
import 'package:financial_management/models/recurrence.dart';
import 'package:financial_management/providers/expense_state.dart';
import 'package:financial_management/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ExpenseState> stateWith(List<Expense> expenses) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  await storage.saveAllExpenses(expenses);
  final state = ExpenseState();
  await state.load();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('gasto mensal no dia 31', () {
    test('cai no último dia de fevereiro, sem vazar para março', () async {
      final state = await stateWith([
        Expense(
          title: 'Aluguel',
          amount: 1200,
          category: 'Moradia',
          recurrenceType: RecurrenceType.monthly,
          dueDate: DateTime(2026, 1, 31),
        ),
      ]);

      final fevereiro = state.getExpensesListForMonth(DateTime(2026, 2));
      expect(fevereiro.length, 1, reason: 'fevereiro não pode ficar vazio');
      expect(fevereiro.single.dueDate, DateTime(2026, 2, 28));

      final marco = state.getExpensesListForMonth(DateTime(2026, 3));
      expect(marco.length, 1, reason: 'março não pode receber duas ocorrências');
      expect(marco.single.dueDate, DateTime(2026, 3, 31));
    });

    test('não pula meses ao longo do ano', () async {
      final state = await stateWith([
        Expense(
          title: 'Aluguel',
          amount: 1200,
          category: 'Moradia',
          recurrenceType: RecurrenceType.monthly,
          dueDate: DateTime(2026, 1, 31),
        ),
      ]);

      for (var month = 1; month <= 12; month++) {
        expect(
          state.getExpensesListForMonth(DateTime(2026, month)).length,
          1,
          reason: 'mês $month',
        );
      }
    });
  });

  group('gasto parcelado', () {
    test('divide o valor e mantém uma parcela por mês', () async {
      final state = await stateWith([
        Expense(
          title: 'Notebook',
          amount: 6000,
          category: 'Eletrônicos',
          recurrenceType: RecurrenceType.installment,
          durationMonths: 6,
          dueDate: DateTime(2026, 1, 31),
        ),
      ]);

      expect(state.getExpensesForMonth(DateTime(2026, 1)), 1000);
      expect(state.getExpensesForMonth(DateTime(2026, 2)), 1000);
      expect(state.getExpensesForMonth(DateTime(2026, 6)), 1000);
      expect(state.getExpensesForMonth(DateTime(2026, 7)), 0);

      final fevereiro = state.getExpensesListForMonth(DateTime(2026, 2));
      expect(fevereiro.single.dueDate, DateTime(2026, 2, 28));
    });
  });

  group('gasto por período', () {
    test('cobre exatamente durationMonths meses', () async {
      final state = await stateWith([
        Expense(
          title: 'Curso',
          amount: 300,
          category: 'Educação',
          recurrenceType: RecurrenceType.period,
          durationMonths: 3,
          dueDate: DateTime(2026, 3, 31),
        ),
      ]);

      expect(state.getExpensesForMonth(DateTime(2026, 3)), 300);
      expect(state.getExpensesForMonth(DateTime(2026, 4)), 300);
      expect(state.getExpensesForMonth(DateTime(2026, 5)), 300);
      expect(state.getExpensesForMonth(DateTime(2026, 6)), 0);

      final abril = state.getExpensesListForMonth(DateTime(2026, 4));
      expect(abril.single.dueDate, DateTime(2026, 4, 30));
    });
  });

  group('marcação de pago por mês', () {
    test('independe do dia ajustado pelo clamp', () async {
      final state = await stateWith([
        Expense(
          id: 'fixo',
          title: 'Aluguel',
          amount: 1200,
          category: 'Moradia',
          recurrenceType: RecurrenceType.monthly,
          dueDate: DateTime(2026, 1, 31),
        ),
      ]);

      await state.toggleExpensePaid('fixo', DateTime(2026, 2));

      final fevereiro = state.getExpensesListForMonth(DateTime(2026, 2));
      expect(fevereiro.single.isPaidForMonth(DateTime(2026, 2)), isTrue);
      expect(
        state
            .getExpensesListForMonth(DateTime(2026, 3))
            .single
            .isPaidForMonth(DateTime(2026, 3)),
        isFalse,
      );
    });
  });
}
