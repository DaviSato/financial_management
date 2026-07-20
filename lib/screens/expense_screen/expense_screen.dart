import 'package:financial_management/screens/expense_screen/widgets/empty_state.dart';
import 'package:financial_management/screens/expense_screen/widgets/expense_card.dart';
import 'package:financial_management/screens/expense_screen/widgets/filter_bar.dart';
import 'package:financial_management/screens/expense_screen/widgets/sort_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recurrence.dart';
import '../../providers/category_state.dart';
import '../../providers/expense_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/expense_form.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/month_selector.dart';
import '../category_management/category_management_screen.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  late DateTime _selectedMonth;
  String? _selectedCategory;
  SortOption sortOption = SortOption.dateAsc;

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

  void _openForm(BuildContext context, {dynamic expense}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormDialog(
          expense: expense,
          onSave: (e) => expense == null
              ? context.read<ExpenseState>().addExpense(e)
              : context.read<ExpenseState>().updateExpense(e),
        ),
      ),
    );
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
        title: const Text('Excluir gasto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tem certeza que deseja excluir este gasto?',
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
                    context.read<ExpenseState>().deleteExpense(id);
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
        title: const Text('Gastos'),
        actions: [const LogoutAction()],
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
        label: const Text('Novo Gasto'),
      ),
      body: Consumer2<ExpenseState, CategoryState>(
        builder: (context, expenseState, categoryState, _) {
          final monthExpenses = expenseState.getExpensesListForMonth(
            _selectedMonth,
          );
          final filtered =
              monthExpenses.where((expense) {
                return _selectedCategory == null ||
                    expense.category == _selectedCategory;
              }).toList()..sort((a, b) {
                switch (sortOption) {
                  case SortOption.dateDesc:
                    return b.dueDate.compareTo(a.dueDate);
                  case SortOption.dateAsc:
                    return a.dueDate.compareTo(b.dueDate);
                  case SortOption.amountDesc:
                    return b.amount.compareTo(a.amount);
                  case SortOption.amountAsc:
                    return a.amount.compareTo(b.amount);
                  case SortOption.paidLast:
                    final aPaid = a.isPaidForMonth(_selectedMonth) ? 1 : 0;
                    final bPaid = b.isPaidForMonth(_selectedMonth) ? 1 : 0;
                    if (aPaid != bPaid) return aPaid - bPaid;
                    return a.dueDate.compareTo(b.dueDate);
                  case SortOption.categoryAz:
                    final cmp = a.category.compareTo(b.category);
                    if (cmp != 0) return cmp;
                    return a.dueDate.compareTo(b.dueDate);
                }
              });

          return Column(
            children: [
              // ── Filters ──────────────────────────────────────
              FilterBar(
                categories: categoryState.categories,
                selectedCategory: _selectedCategory,
                onCategorySelected: (name) =>
                    setState(() => _selectedCategory = name),
                onManageCategories: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CategoryManagementScreen(),
                  ),
                ),
              ),

              // ── Sort + List ──────────────────────────────────
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SortButton(
                      selected: sortOption,
                      onSelected: (opt) => setState(() => sortOption = opt),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        hasFilter: _selectedCategory != null,
                        onAdd: () => _openForm(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final expense = filtered[index];
                          final category = categoryState.categories
                              .where((c) => c.name == expense.category)
                              .firstOrNull;
                          final color =
                              category?.color ?? AppTheme.expenseColor;

                          final isPaid = expense.isPaidForMonth(_selectedMonth);
                          final paidDate = expense.paidDateForMonth(
                            _selectedMonth,
                          );

                          // Period badge: find original to compute index
                          int? periodIndex;
                          int? totalPeriods;
                          if (expense.durationMonths != null && expense.durationMonths! > 1) {
                            final original = expenseState.expenses
                                .where((e) => e.id == expense.id)
                                .firstOrNull;
                            if (original != null) {
                              final monthDiff =
                                  (expense.dueDate.year - original.dueDate.year) * 12 +
                                  (expense.dueDate.month - original.dueDate.month);
                              periodIndex = monthDiff + 1;
                              totalPeriods = expense.durationMonths;
                            }
                          }

                          return ExpenseCard(
                            title: expense.title,
                            amount: expense.amount,
                            category: expense.category,
                            dueDate: expense.dueDate,
                            color: color,
                            isPaid: isPaid,
                            paidDate: paidDate,
                            notifyOnDue: expense.notifyOnDue,
                            periodIndex: periodIndex,
                            totalPeriods: totalPeriods,
                            isInstallment: expense.recurrenceType == RecurrenceType.installment,
                            isAutomatic: expense.origin.isAutomatic,
                            onTogglePaid: () => context
                                .read<ExpenseState>()
                                .toggleExpensePaid(expense.id, _selectedMonth),
                            onToggleNotify: () => context
                                .read<ExpenseState>()
                                .toggleNotifyOnDue(expense.id),
                            onEdit: () {
                              final original = expenseState.expenses
                                  .where((e) => e.id == expense.id)
                                  .firstOrNull;
                              _openForm(context, expense: original ?? expense);
                            },
                            onDelete: () => _confirmDelete(
                              context,
                              expense.id,
                              expense.title,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
