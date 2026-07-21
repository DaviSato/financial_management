import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/category_state.dart';
import '../../providers/expense_state.dart';
import '../../providers/income_state.dart';
import '../../services/data_import_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';

/// Mostra o que o parser extraiu da planilha antes de criar de fato — o usuário
/// confere valores e só então confirma. Evita que um erro de leitura vire dado.
class ImportReviewScreen extends StatefulWidget {
  const ImportReviewScreen({super.key, required this.payload});

  final ImportPayload payload;

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  bool _importing = false;

  Future<void> _import() async {
    final categoryState = context.read<CategoryState>();
    final incomeState = context.read<IncomeState>();
    final expenseState = context.read<ExpenseState>();

    setState(() => _importing = true);

    final existing =
        categoryState.categories.map((c) => c.name.toLowerCase()).toSet();
    var cats = 0;
    for (final category in widget.payload.categories) {
      if (existing.contains(category.name.toLowerCase())) continue;
      await categoryState.addCustomCategory(category);
      cats++;
    }
    for (final income in widget.payload.incomes) {
      await incomeState.addIncome(income);
    }
    for (final expense in widget.payload.expenses) {
      await expenseState.addExpense(expense);
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline_rounded, size: 28),
        title: const Text('Importação concluída'),
        content: Text(
          '$cats categorias, ${widget.payload.incomes.length} rendimentos e '
          '${widget.payload.expenses.length} gastos importados.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    final total = p.incomes.length + p.expenses.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar importação')),
      body: p.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    'Assumi tudo como mensal recorrente, no 1º dia do mês da '
                    'aba. Confira e, se algo estiver errado, me avise.',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ),
                if (p.incomes.isNotEmpty) ...[
                  _Header('RENDIMENTOS · ${p.incomes.length}'),
                  for (final i in p.incomes)
                    _Row(
                      title: i.title,
                      subtitle: 'Mensal',
                      amount: i.amount,
                      color: AppTheme.incomColor,
                    ),
                ],
                if (p.expenses.isNotEmpty) ...[
                  _Header('GASTOS · ${p.expenses.length}'),
                  for (final e in p.expenses)
                    _Row(
                      title: e.title,
                      subtitle: e.category,
                      amount: e.amount,
                      color: AppTheme.expenseColor,
                    ),
                ],
              ],
            ),
      bottomNavigationBar: p.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _importing ? null : _import,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _importing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Importar $total itens'),
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6E6E78),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  final String title;
  final String subtitle;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Text(
        CurrencyFormatter.format(amount),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum valor encontrado',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'A planilha selecionada não tem valores nas colunas esperadas '
              '(Receitas em B/C, Débitos em E/F). Confira se é a versão '
              'preenchida.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
