import 'package:financial_management/screens/income_screen/widgets/empty_state.dart';
import 'package:financial_management/screens/income_screen/widgets/income_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/income.dart';
import '../../models/recurrence.dart';
import '../../providers/income_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../widgets/income_form.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/month_selector.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _prevMonth() => setState(() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
  });

  void _nextMonth() => setState(() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
  });

  void _goToToday() {
    final now = DateTime.now();
    setState(() => _selectedMonth = DateTime(now.year, now.month, 1));
  }

  void _pickMonth(BuildContext context) async {
    final picked = await MonthSelector.showPicker(context, _selectedMonth);
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
    }
  }

  void _openForm(BuildContext context, {Income? income}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomeFormDialog(
          income: income,
          onSave: (i) => income == null
              ? context.read<IncomeState>().addIncome(i)
              : context.read<IncomeState>().updateIncome(i),
        ),
      ),
    );
  }

  /// Selo curto descrevendo a recorrência do rendimento.
  String? _recurrenceLabel(Income income) {
    switch (income.recurrenceType) {
      case RecurrenceType.monthly:
        final n = income.effectiveIntervalMonths;
        if (n == 1) return 'mensal';
        if (n == 6) return 'semestral';
        if (n == 12) return 'anual';
        return 'a cada $n meses';
      case RecurrenceType.period:
        return 'por período';
      default:
        return null;
    }
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.expenseColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.expenseColor,
            size: 24,
          ),
        ),
        title: const Text('Excluir rendimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tem certeza que deseja excluir este rendimento?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.expenseColor,
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: () {
                    context.read<IncomeState>().deleteIncome(id);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Excluir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rendimentos'),
        actions: const [LogoutAction()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                MonthSelector(
                  selectedMonth: _selectedMonth,
                  onPrevious: _prevMonth,
                  onNext: _nextMonth,
                  onGoToToday: _goToToday,
                  onMonthTap: () => _pickMonth(context),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Novo Rendimento'),
      ),
      body: Consumer<IncomeState>(
        builder: (context, incomeState, _) {
          final monthIncomes = incomeState.getIncomesListForMonth(
            _selectedMonth,
          )..sort((a, b) => a.receiveDate.compareTo(b.receiveDate));

          if (monthIncomes.isEmpty) return const EmptyState();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            itemCount: monthIncomes.length,
            itemBuilder: (context, index) {
              final income = monthIncomes[index];
              // A lista contém ocorrências expandidas; o original é a fonte de
              // verdade para editar e para calcular o número da parcela.
              final original = incomeState.incomes
                  .where((i) => i.id == income.id)
                  .firstOrNull;

              int? periodIndex;
              int? totalPeriods;
              if (income.recurrenceType == RecurrenceType.period &&
                  original != null &&
                  (original.durationMonths ?? 0) > 1) {
                periodIndex =
                    monthsBetween(original.receiveDate, income.receiveDate) + 1;
                totalPeriods = original.durationMonths;
              }

              return IncomeCard(
                title: income.title,
                amount: income.amount,
                receiveDate: income.receiveDate,
                recurrenceLabel: _recurrenceLabel(income),
                periodIndex: periodIndex,
                totalPeriods: totalPeriods,
                onEdit: () => _openForm(context, income: original ?? income),
                onDelete: () =>
                    _confirmDelete(context, income.id, income.title),
              );
            },
          );
        },
      ),
    );
  }
}
