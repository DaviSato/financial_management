import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:financial_management/models/recurrence.dart';
import 'package:financial_management/services/data_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta um xlsx no layout da planilha do usuário: aba "Julho", Receitas em
/// B/C, Débitos em E/F.
Uint8List buildSheet(List<List<dynamic>> cells) {
  final excel = Excel.createExcel();
  final sheet = excel['Julho'];
  for (final c in cells) {
    final col = c[0] as int, rowIdx = c[1] as int;
    final value = c[2];
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx),
    );
    cell.value = value is num
        ? DoubleCellValue(value.toDouble())
        : TextCellValue(value as String);
  }
  excel.delete('Sheet1'); // deixa "Julho" como primeira (e única) aba
  return Uint8List.fromList(excel.encode()!);
}

void main() {
  final service = DataImportService();

  test('extrai rendimentos (B/C) e gastos (E/F) com valores', () {
    final bytes = buildSheet([
      // headers
      [1, 2, 'Receitas'], [4, 2, 'Débitos'],
      [1, 3, 'João'], [4, 3, 'Descrição'], [5, 3, 'Valor'],
      // dados
      [1, 4, 'João'], [2, 4, 5000], [4, 4, 'Aluguel'], [5, 4, 1200],
      [1, 5, 'Jessika'], [2, 5, 3000], [4, 5, 'Energia'], [5, 5, 250.50],
    ]);

    final p = service.parse(bytes);

    expect(p.incomes.length, 2);
    expect(p.expenses.length, 2);
    expect(p.incomes.map((i) => i.title), containsAll(['João', 'Jessika']));
    expect(p.expenses.firstWhere((e) => e.title == 'Aluguel').amount, 1200);
    expect(p.expenses.firstWhere((e) => e.title == 'Energia').amount, 250.50);
  });

  test('ignora rótulos de cabeçalho', () {
    final bytes = buildSheet([
      [1, 1, 'Receitas'], [2, 1, 0],
      [1, 2, 'Saldo'], [2, 2, 999],
      [4, 1, 'Descrição'], [5, 1, 0],
      [4, 2, 'Valor'], [5, 2, 888],
    ]);

    final p = service.parse(bytes);
    expect(p.incomes, isEmpty);
    expect(p.expenses, isEmpty);
  });

  test('planilha em branco (sem valores) não importa nada', () {
    final bytes = buildSheet([
      [1, 4, 'João'], // sem valor em C
      [4, 4, 'Aluguel'], // sem valor em F
    ]);

    final p = service.parse(bytes);
    expect(p.isEmpty, isTrue);
  });

  test('gasto vira também categoria, com recorrência mensal', () {
    final bytes = buildSheet([
      [4, 4, 'Aluguel'], [5, 4, 1200],
    ]);

    final p = service.parse(bytes);
    expect(p.categories.map((c) => c.name), contains('Aluguel'));
    expect(p.expenses.single.category, 'Aluguel');
    expect(p.expenses.single.recurrenceType, RecurrenceType.monthly);
    // Aba "Julho" → mês 7.
    expect(p.expenses.single.dueDate.month, 7);
  });

  test('categorias repetidas não duplicam', () {
    final bytes = buildSheet([
      [4, 4, 'Energia'], [5, 4, 100],
      [4, 5, 'Energia'], [5, 5, 110],
    ]);

    final p = service.parse(bytes);
    expect(p.expenses.length, 2);
    expect(p.categories.length, 1);
  });
}
