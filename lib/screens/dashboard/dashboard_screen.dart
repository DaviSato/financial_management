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
import '../../providers/privacy_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/capture_bell_button.dart';
import '../../widgets/collapsing_header_sliver.dart';
import '../../widgets/month_selector.dart';
import '../../widgets/responsive_body.dart';

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

  /// Faixa com o seletor de mês, ancorada abaixo da toolbar fixa.
  Widget _monthHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveBody(
        // Mais largo que as demais telas: comporta o card de saldo e o gráfico
        // lado a lado em janelas de desktop (ver _HeroAndChart).
        maxWidth: 1040,
        child: Consumer2<ExpenseState, IncomeState>(
        builder: (context, expenseState, incomeState, _) {
          final categories = context.watch<CategoryState>().categories;
          final hidePrivate = context.watch<PrivacyState>().hideIncome;
          final income = incomeState.getIncomeForMonth(_selectedMonth);
          final expenses = expenseState.getExpensesForMonth(_selectedMonth);
          final balance = income - expenses;
          final expensesByCategory = expenseState.getExpensesByCategoryForMonth(
            _selectedMonth,
          );
          final raw = DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonth);
          final monthLabel = raw[0].toUpperCase() + raw.substring(1);

          return CustomScrollView(
            slivers: [
              // Toolbar fixa (Painel + ações) + seletor de mês colapsável
              // que volta com snap ao rolar de volta.
              CollapsingHeaderSliver(
                title: const Text('Painel'),
                actions: [
                  const CaptureBellButton(),
                  Consumer<PrivacyState>(
                    builder: (context, privacy, _) => IconButton(
                      tooltip: privacy.hideIncome
                          ? 'Mostrar valores'
                          : 'Ocultar valores',
                      icon: Icon(
                        privacy.hideIncome
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          context.read<PrivacyState>().toggleHideIncome(),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                headerHeight: 58,
                header: _monthHeader(),
              ),

              // ── Conteúdo ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Saldo + gráfico (lado a lado no desktop) ─
                      _HeroAndChart(
                        income: income,
                        expenses: expenses,
                        balance: balance,
                        monthLabel: monthLabel,
                        hidePrivate: hidePrivate,
                        expensesByCategory: expensesByCategory,
                        categories: categories,
                        colorForCategory: _colorForCategory,
                      ),
                      const SizedBox(height: 24),

                      // ── Expenses by Category ────────────────────
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
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}

/// Card de saldo e gráfico do mês. Em janelas largas (desktop) ficam lado a
/// lado; em telas estreitas (celular) empilham. Quando não há dados no mês só
/// o card aparece — o gráfico não faz sentido sem valores.
class _HeroAndChart extends StatelessWidget {
  const _HeroAndChart({
    required this.income,
    required this.expenses,
    required this.balance,
    required this.monthLabel,
    required this.hidePrivate,
    required this.expensesByCategory,
    required this.categories,
    required this.colorForCategory,
  });

  final double income;
  final double expenses;
  final double balance;
  final String monthLabel;
  final bool hidePrivate;
  final Map<String, double> expensesByCategory;
  final List<Category> categories;
  final Color Function(String, List<Category>, int) colorForCategory;

  /// Acima desta largura o card e o gráfico ficam lado a lado.
  static const _sideBySideBreakpoint = 820.0;

  @override
  Widget build(BuildContext context) {
    final hero = HeroCard(
      income: income,
      expenses: expenses,
      balance: balance,
      monthLabel: monthLabel,
      hidePrivate: hidePrivate,
    );

    // Sem movimento no mês, o gráfico não tem o que mostrar.
    if (income <= 0 && expenses <= 0) return hero;

    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Visão do Mês'),
        const SizedBox(height: 16),
        IncomeExpenseChart(
          income: income,
          expenses: expenses,
          balance: balance,
          expensesByCategory: expensesByCategory,
          categories: categories,
          colorForCategory: colorForCategory,
          hidePrivate: hidePrivate,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _sideBySideBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: hero),
              const SizedBox(width: 24),
              Expanded(child: chart),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            hero,
            const SizedBox(height: 24),
            chart,
          ],
        );
      },
    );
  }
}
