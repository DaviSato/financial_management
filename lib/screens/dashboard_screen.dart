import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/logout_action.dart';
import '../widgets/month_selector.dart';

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
                ),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final income = appState.getIncomeForMonth(_selectedMonth);
          final expenses = appState.getExpensesForMonth(_selectedMonth);
          final balance = income - expenses;
          final expensesByCategory = appState.getExpensesByCategoryForMonth(
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
                _HeroCard(
                  income: income,
                  expenses: expenses,
                  balance: balance,
                  monthLabel: monthLabel,
                ),
                const SizedBox(height: 24),

                // ── Income vs Expenses Chart ──────────────────
                if (income > 0 || expenses > 0) ...[
                  const _SectionHeader(title: 'Visão do Mês'),
                  const SizedBox(height: 16),
                  _IncomeExpenseChart(
                    income: income,
                    expenses: expenses,
                    balance: balance,
                    expensesByCategory: expensesByCategory,
                    categories: appState.categories,
                    colorForCategory: _colorForCategory,
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Expenses by Category ──────────────────────
                if (expensesByCategory.isNotEmpty) ...[
                  _SectionHeader(title: 'Gastos por Categoria'),
                  const SizedBox(height: 16),
                  _CategoryBreakdown(
                    expensesByCategory: expensesByCategory,
                    categories: appState.categories,
                    colorForCategory: _colorForCategory,
                  ),
                ] else if (income == 0 && expenses == 0)
                  const _EmptyChart(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Hero Card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.income,
    required this.expenses,
    required this.balance,
    required this.monthLabel,
  });

  final double income;
  final double expenses;
  final double balance;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    final spendRatio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final progressColor = spendRatio > 0.9
        ? AppTheme.expenseColor
        : AppTheme.incomColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPositive
              ? const [Color(0xFF0D2137), Color(0xFF0A1628)]
              : const [Color(0xFF270D0D), Color(0xFF1A0808)],
        ),
        border: Border.all(
          color: (isPositive ? AppTheme.primaryColor : AppTheme.expenseColor)
              .withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month label
          Row(
            children: [
              Text(
                'Saldo do Mês',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  monthLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Balance amount
          Text(
            CurrencyFormatter.format(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
          const SizedBox(height: 20),

          // Progress bar
          if (income > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uso do orçamento',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${(spendRatio * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: progressColor.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: spendRatio,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(progressColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Income vs Expense row
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Rendimentos',
                  value: income,
                  color: AppTheme.incomColor,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _HeroMetric(
                  label: 'Gastos',
                  value: expenses,
                  color: AppTheme.expenseColor,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(value),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [Text(title, style: Theme.of(context).textTheme.titleLarge)],
    );
  }
}

// ─── Pie Chart Card ───────────────────────────────────────────────────────────

// ─── Income vs Expense Chart ──────────────────────────────────────────────────

class _IncomeExpenseChart extends StatelessWidget {
  const _IncomeExpenseChart({
    required this.income,
    required this.expenses,
    required this.balance,
    required this.expensesByCategory,
    required this.categories,
    required this.colorForCategory,
  });

  final double income;
  final double expenses;
  final double balance;
  final Map<String, double> expensesByCategory;
  final List<Category> categories;
  final Color Function(String, List<Category>, int) colorForCategory;

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    final categoryEntries = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // One green section for income + one section per expense category
    final sections = <PieChartSectionData>[
      if (income > 0)
        PieChartSectionData(
          color: AppTheme.incomColor.withValues(alpha: 0.2),
          value: income,
          title: '',
          radius: 36,
        ),
      ...List.generate(categoryEntries.length, (i) {
        final color = colorForCategory(categoryEntries[i].key, categories, i);
        return PieChartSectionData(
          color: color,
          value: categoryEntries[i].value,
          title: '',
          radius: 36,
        );
      }),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Donut with balance in center
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 52,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'saldo',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(balance),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isPositive
                            ? AppTheme.incomColor
                            : AppTheme.expenseColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Legends
          if (income > 0)
            _ChartLegendRow(
              color: AppTheme.incomColor,
              label: 'Rendimentos',
              value: income,
            ),
          if (income > 0 && categoryEntries.isNotEmpty)
            const SizedBox(height: 10),

          ...List.generate(categoryEntries.length, (i) {
            final color = colorForCategory(
              categoryEntries[i].key,
              categories,
              i,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChartLegendRow(
                color: color,
                label: categoryEntries[i].key,
                value: categoryEntries[i].value,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ChartLegendRow extends StatelessWidget {
  const _ChartLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Category Breakdown ───────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.expensesByCategory,
    required this.categories,
    required this.colorForCategory,
  });

  final Map<String, double> expensesByCategory;
  final List<Category> categories;
  final Color Function(String, List<Category>, int) colorForCategory;

  @override
  Widget build(BuildContext context) {
    final entries = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = expensesByCategory.values.reduce((a, b) => a + b);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalhamento',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E6E78),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(entries.length, (i) {
            final color = colorForCategory(entries[i].key, categories, i);
            final pct = entries[i].value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entries[i].key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(entries[i].value),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 44,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Text(
            'Sem dados neste mês',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
