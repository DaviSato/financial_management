import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../screens/category_management_screen.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/expense_form.dart';
import '../widgets/month_selector.dart';

enum _SortOption { dateDesc, dateAsc, amountDesc, amountAsc }

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  late DateTime _selectedMonth;
  String? _selectedCategory;
  _SortOption _sortOption = _SortOption.dateDesc;

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

  void _openForm(BuildContext context, {dynamic expense}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormDialog(
          expense: expense,
          onSave: (e) => expense == null
              ? context.read<AppState>().addExpense(e)
              : context.read<AppState>().updateExpense(e),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Gasto'),
        content: Text('Tem certeza que deseja excluir "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.expenseColor,
            ),
            onPressed: () {
              context.read<AppState>().deleteExpense(id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Excluir'),
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
        actions: [
          _SortButton(
            selected: _sortOption,
            onSelected: (opt) => setState(() => _sortOption = opt),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Novo Gasto'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final monthExpenses = appState.getExpensesListForMonth(
            _selectedMonth,
          );
          final filtered =
              monthExpenses.where((expense) {
                return _selectedCategory == null ||
                    expense.category == _selectedCategory;
              }).toList()..sort((a, b) {
                switch (_sortOption) {
                  case _SortOption.dateDesc:
                    return b.dueDate.compareTo(a.dueDate);
                  case _SortOption.dateAsc:
                    return a.dueDate.compareTo(b.dueDate);
                  case _SortOption.amountDesc:
                    return b.amount.compareTo(a.amount);
                  case _SortOption.amountAsc:
                    return a.amount.compareTo(b.amount);
                }
              });

          return Column(
            children: [
              // ── Filters ──────────────────────────────────────
              _FilterBar(
                selectedMonth: _selectedMonth,
                onPreviousMonth: _prevMonth,
                onNextMonth: _nextMonth,
                categories: appState.categories,
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

              // ── List ─────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        hasFilter: _selectedCategory != null,
                        onAdd: () => _openForm(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final expense = filtered[index];
                          final category = appState.categories
                              .where((c) => c.name == expense.category)
                              .firstOrNull;
                          final color =
                              category?.color ?? AppTheme.expenseColor;

                          return _ExpenseCard(
                            title: expense.title,
                            amount: expense.amount,
                            category: expense.category,
                            dueDate: expense.dueDate,
                            color: color,
                            onEdit: () => _openForm(context, expense: expense),
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

// ─── Filter Bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onManageCategories,
  });

  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final List categories;
  final String? selectedCategory;
  final void Function(String?) onCategorySelected;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonthSelector(
                selectedMonth: selectedMonth,
                onPrevious: onPreviousMonth,
                onNext: onNextMonth,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onManageCategories,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.category,
                          size: 16,
                          color: Color(0xFF6E6E78),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CategoryChip(
                      label: 'Todos',
                      color: AppTheme.primaryColor,
                      selected: selectedCategory == null,
                      onTap: () => onCategorySelected(null),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryChip(
                          label: category.name,
                          color: category.color,
                          selected: selectedCategory == category.name,
                          onTap: () => onCategorySelected(category.name),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != 'Todos') ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : const Color(0xFF8E8E98),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Expense Card ─────────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.title,
    required this.amount,
    required this.category,
    required this.dueDate,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final double amount;
  final String category;
  final DateTime dueDate;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Title + category pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Amount + date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('dd/MM/yy', 'pt_BR').format(dueDate),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6E6E78),
                  ),
                ),
              ],
            ),

            // Menu
            SizedBox(
              width: 32,
              child: PopupMenuButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: Color(0xFF4E4E58),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: onEdit,
                    child: const Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 10),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    onTap: onDelete,
                    child: const Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppTheme.expenseColor,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Excluir',
                          style: TextStyle(color: AppTheme.expenseColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sort Button ──────────────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  const _SortButton({required this.selected, required this.onSelected});
  final _SortOption selected;
  final void Function(_SortOption) onSelected;

  static const _items = [
    (_SortOption.dateDesc, Icons.history_rounded, 'Mais recente primeiro'),
    (_SortOption.dateAsc, Icons.update_rounded, 'Mais antigo primeiro'),
    (
      _SortOption.amountDesc,
      Icons.trending_down_rounded,
      'Maior valor primeiro',
    ),
    (_SortOption.amountAsc, Icons.trending_up_rounded, 'Menor valor primeiro'),
  ];

  bool get _isDefault => selected == _SortOption.dateDesc;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortOption>(
      tooltip: 'Ordenar',
      onSelected: onSelected,
      offset: const Offset(0, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: 18,
              color: _isDefault ? Colors.white54 : AppTheme.primaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              'Ordenar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _isDefault ? Colors.white38 : AppTheme.primaryColor,
              ),
            ),
            if (!_isDefault) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
      itemBuilder: (_) => _items.map((item) {
        final (option, icon, label) = item;
        final isSelected = selected == option;
        return PopupMenuItem<_SortOption>(
          value: option,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFF6E6E78),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter, required this.onAdd});
  final bool hasFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.expenseColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 32,
              color: AppTheme.expenseColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'Nenhum gasto nessa categoria'
                : 'Nenhum gasto encontrado',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter ? 'Tente outro filtro' : 'Registre seu primeiro gasto',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
