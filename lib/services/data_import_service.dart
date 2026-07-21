import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/recurrence.dart';
import '../utils/currency_formatter.dart';

/// Dados extraídos da planilha, prontos para revisão e importação.
class ImportPayload {
  final List<Category> categories;
  final List<Income> incomes;
  final List<Expense> expenses;

  const ImportPayload({
    required this.categories,
    required this.incomes,
    required this.expenses,
  });

  bool get isEmpty => incomes.isEmpty && expenses.isEmpty;
}

/// Lê a planilha de orçamento do usuário (mesmo layout do modelo enviado) e a
/// converte em rendimentos, gastos e categorias.
///
/// Layout da aba mensal (ex.: "Julho"):
///   - Receitas: coluna B = nome, coluna C = valor
///   - Débitos:  coluna E = descrição, coluna F = valor
///
/// Linhas sem valor numérico são ignoradas — então o modelo em branco não
/// importa nada, e a versão preenchida importa as entradas.
class DataImportService {
  final _uuid = const Uuid();

  // Índices de coluna (0-based): B=1, C=2, E=4, F=5.
  static const _incomeNameCol = 1;
  static const _incomeValueCol = 2;
  static const _expenseDescCol = 4;
  static const _expenseValueCol = 5;

  // Rótulos que não são dados.
  static const _skip = {
    'receitas',
    'debitos',
    'débitos',
    'descrição',
    'descricao',
    'valor',
    'saldo',
    'total',
  };

  static const _palette = [
    '0xFF5C6BC0', '0xFF26A69A', '0xFFAB47BC', '0xFFFFA726',
    '0xFF42A5F5', '0xFF66BB6A', '0xFFEF5350', '0xFFFF7043',
    '0xFFEC407A', '0xFF8D6E63', '0xFF29B6F6', '0xFF9CCC65',
  ];

  ImportPayload parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);

    // A primeira aba é a mensal (Receitas/Débitos). Faturas e Parcelas têm
    // layout por mês e ficam para um segundo passo, com dados reais em mãos.
    final firstSheet = excel.tables.keys.isEmpty ? null : excel.tables.keys.first;
    final sheet = firstSheet != null ? excel.tables[firstSheet] : null;

    final incomes = <Income>[];
    final expenses = <Expense>[];
    final categoryColors = <String, String>{};

    // Mês/ano de referência a partir do nome da aba (ex.: "Julho").
    final refDate = _monthFromName(firstSheet);

    if (sheet != null) {
      for (final row in sheet.rows) {
        // Rendimento: nome em B, valor em C.
        final incomeName = _text(row, _incomeNameCol);
        final incomeValue = _number(row, _incomeValueCol);
        if (_isData(incomeName) && incomeValue != null && incomeValue > 0) {
          incomes.add(
            Income(
              amount: incomeValue,
              title: incomeName!,
              recurrenceType: RecurrenceType.monthly,
              intervalMonths: 1,
              receiveDate: refDate,
            ),
          );
        }

        // Gasto: descrição em E, valor em F. A descrição também vira categoria.
        final expenseDesc = _text(row, _expenseDescCol);
        final expenseValue = _number(row, _expenseValueCol);
        if (_isData(expenseDesc) && expenseValue != null && expenseValue > 0) {
          categoryColors.putIfAbsent(
            expenseDesc!,
            () => _palette[categoryColors.length % _palette.length],
          );
          expenses.add(
            Expense(
              amount: expenseValue,
              title: expenseDesc,
              category: expenseDesc,
              recurrenceType: RecurrenceType.monthly,
              dueDate: refDate,
            ),
          );
        }
      }
    }

    final categories = [
      for (final entry in categoryColors.entries)
        Category(id: _uuid.v4(), name: entry.key, colorHex: entry.value),
    ];

    return ImportPayload(
      categories: categories,
      incomes: incomes,
      expenses: expenses,
    );
  }

  bool _isData(String? value) {
    if (value == null) return false;
    final t = value.trim();
    return t.isNotEmpty && !_skip.contains(t.toLowerCase());
  }

  String? _text(List<Data?> row, int col) {
    if (col >= row.length) return null;
    final v = row[col]?.value;
    if (v is TextCellValue) return v.value.text?.trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    return null;
  }

  double? _number(List<Data?> row, int col) {
    if (col >= row.length) return null;
    final v = row[col]?.value;
    if (v is IntCellValue) return v.value.toDouble();
    if (v is DoubleCellValue) return v.value;
    if (v is TextCellValue) return CurrencyFormatter.parse(v.value.text ?? '');
    return null;
  }

  DateTime _monthFromName(String? name) {
    final now = DateTime.now();
    if (name == null) return DateTime(now.year, now.month, 1);
    const months = {
      'janeiro': 1, 'fevereiro': 2, 'março': 3, 'marco': 3, 'abril': 4,
      'maio': 5, 'junho': 6, 'julho': 7, 'agosto': 8, 'setembro': 9,
      'outubro': 10, 'novembro': 11, 'dezembro': 12,
    };
    final month = months[name.trim().toLowerCase()];
    return month != null ? DateTime(now.year, month, 1) : DateTime(now.year, now.month, 1);
  }
}
