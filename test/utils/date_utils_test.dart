import 'package:financial_management/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('addMonths', () {
    test('soma meses preservando o dia', () {
      expect(addMonths(DateTime(2026, 1, 15), 1), DateTime(2026, 2, 15));
      expect(addMonths(DateTime(2026, 1, 15), 6), DateTime(2026, 7, 15));
      expect(addMonths(DateTime(2026, 1, 15), 12), DateTime(2027, 1, 15));
    });

    test('limita o dia ao último dia do mês de destino', () {
      // Sem clamp, DateTime(2026, 2, 31) estouraria para 03/03.
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 3, 31), 1), DateTime(2026, 4, 30));
    });

    test('respeita ano bissexto', () {
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('não acumula erro ao somar sempre a partir da data original', () {
      final origem = DateTime(2026, 1, 31);
      expect(addMonths(origem, 1), DateTime(2026, 2, 28));
      expect(addMonths(origem, 2), DateTime(2026, 3, 31)); // volta para o dia 31
    });

    test('aceita meses negativos', () {
      expect(addMonths(DateTime(2026, 1, 10), -1), DateTime(2025, 12, 10));
    });
  });

  group('monthsBetween', () {
    test('conta meses ignorando o dia', () {
      expect(monthsBetween(DateTime(2026, 1, 31), DateTime(2026, 2, 1)), 1);
      expect(monthsBetween(DateTime(2026, 1, 1), DateTime(2027, 1, 1)), 12);
      expect(monthsBetween(DateTime(2026, 6, 1), DateTime(2026, 1, 1)), -5);
    });
  });
}
