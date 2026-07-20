import 'package:financial_management/models/income.dart';
import 'package:financial_management/models/recurrence.dart';
import 'package:financial_management/providers/income_state.dart';
import 'package:financial_management/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cria um IncomeState com os rendimentos informados já persistidos.
Future<IncomeState> stateWith(List<Income> incomes) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  await storage.saveAllIncomes(incomes);
  final state = IncomeState();
  await state.load();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rendimento único', () {
    test('aparece só no mês da data de recebimento', () async {
      final state = await stateWith([
        Income(
          title: 'Abono salarial',
          amount: 1518,
          receiveDate: DateTime(2026, 8, 12),
        ),
      ]);

      expect(state.getIncomeForMonth(DateTime(2026, 7)), 0);
      expect(state.getIncomeForMonth(DateTime(2026, 8)), 1518);
      expect(state.getIncomeForMonth(DateTime(2026, 9)), 0);
    });

    test('pode ser cadastrado no futuro', () async {
      final state = await stateWith([
        Income(
          title: 'Restituição IR',
          amount: 900,
          receiveDate: DateTime(2027, 5, 30),
        ),
      ]);

      expect(state.getIncomesListForMonth(DateTime(2027, 5)).length, 1);
    });
  });

  group('rendimento recorrente', () {
    test('intervalo 1 cai todo mês', () async {
      final state = await stateWith([
        Income(
          title: 'Salário',
          amount: 5000,
          recurrenceType: RecurrenceType.monthly,
          intervalMonths: 1,
          receiveDate: DateTime(2026, 1, 5),
        ),
      ]);

      for (final month in [1, 2, 3, 11, 12]) {
        expect(
          state.getIncomeForMonth(DateTime(2026, month)),
          5000,
          reason: 'mês $month',
        );
      }
    });

    test('intervalo 12 só cai no mês do primeiro recebimento (13º)', () async {
      final state = await stateWith([
        Income(
          title: '13º salário',
          amount: 5000,
          recurrenceType: RecurrenceType.monthly,
          intervalMonths: 12,
          receiveDate: DateTime(2026, 12, 20),
        ),
      ]);

      expect(state.getIncomeForMonth(DateTime(2026, 11)), 0);
      expect(state.getIncomeForMonth(DateTime(2026, 12)), 5000);
      expect(state.getIncomeForMonth(DateTime(2027, 6)), 0);
      expect(state.getIncomeForMonth(DateTime(2027, 12)), 5000);
      expect(state.getIncomeForMonth(DateTime(2030, 12)), 5000);
    });

    test('intervalo 6 alterna semestralmente', () async {
      final state = await stateWith([
        Income(
          title: 'Bônus semestral',
          amount: 3000,
          recurrenceType: RecurrenceType.monthly,
          intervalMonths: 6,
          receiveDate: DateTime(2026, 3, 10),
        ),
      ]);

      expect(state.getIncomeForMonth(DateTime(2026, 3)), 3000);
      expect(state.getIncomeForMonth(DateTime(2026, 4)), 0);
      expect(state.getIncomeForMonth(DateTime(2026, 9)), 3000);
      expect(state.getIncomeForMonth(DateTime(2027, 3)), 3000);
    });

    test('não aparece antes do primeiro recebimento', () async {
      final state = await stateWith([
        Income(
          title: 'Salário novo emprego',
          amount: 4000,
          recurrenceType: RecurrenceType.monthly,
          intervalMonths: 1,
          receiveDate: DateTime(2026, 6, 5),
        ),
      ]);

      expect(state.getIncomeForMonth(DateTime(2026, 5)), 0);
      expect(state.getIncomeForMonth(DateTime(2026, 6)), 4000);
    });

    test('dia 31 não vaza para o mês seguinte', () async {
      final state = await stateWith([
        Income(
          title: 'Salário',
          amount: 100,
          recurrenceType: RecurrenceType.monthly,
          intervalMonths: 1,
          receiveDate: DateTime(2026, 1, 31),
        ),
      ]);

      final fevereiro = state.getIncomesListForMonth(DateTime(2026, 2));
      expect(fevereiro.length, 1);
      expect(fevereiro.single.receiveDate, DateTime(2026, 2, 28));
      expect(state.getIncomesListForMonth(DateTime(2026, 3)).length, 1);
    });
  });

  group('rendimento por período', () {
    test('cobre exatamente durationMonths meses', () async {
      final state = await stateWith([
        Income(
          title: 'Freela 6 meses',
          amount: 2000,
          recurrenceType: RecurrenceType.period,
          durationMonths: 6,
          receiveDate: DateTime(2026, 2, 15),
        ),
      ]);

      expect(state.getIncomeForMonth(DateTime(2026, 1)), 0);
      expect(state.getIncomeForMonth(DateTime(2026, 2)), 2000);
      expect(state.getIncomeForMonth(DateTime(2026, 7)), 2000);
      expect(state.getIncomeForMonth(DateTime(2026, 8)), 0);
    });
  });

  group('compatibilidade com dados antigos', () {
    test('rendimento sem receiveDate usa createdAt', () {
      final income = Income.fromJson({
        'id': 'abc',
        'title': 'Salário antigo',
        'amount': 3000,
        'recurrenceType': 'monthly',
        'createdAt': DateTime(2025, 4, 9).toIso8601String(),
      });

      expect(income.receiveDate, DateTime(2025, 4, 9));
      expect(income.effectiveIntervalMonths, 1);
    });
  });
}
