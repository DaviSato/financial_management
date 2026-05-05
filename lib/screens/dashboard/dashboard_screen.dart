import 'package:financial_management/screens/dashboard/widgets/category_breakdown.dart';
import 'package:financial_management/screens/dashboard/widgets/empty_chart.dart';
import 'package:financial_management/screens/dashboard/widgets/hero_card.dart';
import 'package:financial_management/screens/dashboard/widgets/income_expense_chart.dart';
import 'package:financial_management/screens/dashboard/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../providers/category_state.dart';
import '../../providers/expense_state.dart';
import '../../providers/income_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/month_selector.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  Color _colorForCategory(String name, List<Category> categories, int index) {
    final match = categories.where((c) => c.name == name).firstOrNull;
    return match?.color ?? AppTheme.chartColors()[index % 8];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel'),
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
      body: Consumer2<ExpenseState, IncomeState>(
        builder: (context, expenseState, incomeState, _) {
          final categories = context.watch<CategoryState>().categories;
          final income = incomeState.getIncomeForMonth(_selectedMonth);
          final expenses = expenseState.getExpensesForMonth(_selectedMonth);
          final balance = income - expenses;
          final expensesByCategory = expenseState.getExpensesByCategoryForMonth(
            _selectedMonth,
          );
          final raw = DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonth);
          final monthLabel = raw[0].toUpperCase() + raw.substring(1);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Balance Card ──────────────────────────
                HeroCard(
                  income: income,
                  expenses: expenses,
                  balance: balance,
                  monthLabel: monthLabel,
                ),
                const SizedBox(height: 24),

                // ── Income vs Expenses Chart ──────────────────
                if (income > 0 || expenses > 0) ...[
                  const SectionHeader(title: 'Visão do Mês'),
                  const SizedBox(height: 16),
                  IncomeExpenseChart(
                    income: income,
                    expenses: expenses,
                    balance: balance,
                    expensesByCategory: expensesByCategory,
                    categories: categories,
                    colorForCategory: _colorForCategory,
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Expenses by Category ──────────────────────
                if (expensesByCategory.isNotEmpty) ...[
                  SectionHeader(title: 'Gastos por Categoria'),
                  const SizedBox(height: 16),
                  CategoryBreakdown(
                    expensesByCategory: expensesByCategory,
                    categories: categories,
                    colorForCategory: _colorForCategory,
                  ),
                ] else if (income == 0 && expenses == 0)
                  const EmptyChart(),
              ],
            ),
          );
        },
      ),
    );
  }
}
