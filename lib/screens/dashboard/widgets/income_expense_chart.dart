import 'package:financial_management/models/category.dart';
import 'package:financial_management/screens/dashboard/widgets/chart_legend_row.dart';
import 'package:financial_management/theme/app_theme.dart';
import 'package:financial_management/utils/currency_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class IncomeExpenseChart extends StatelessWidget {
  const IncomeExpenseChart({
    super.key,
    required this.income,
    required this.expenses,
    required this.balance,
    required this.expensesByCategory,
    required this.categories,
    required this.colorForCategory,
    this.hidePrivate = false,
  });

  final double income;
  final double expenses;
  final double balance;
  final Map<String, double> expensesByCategory;
  final List<Category> categories;
  final Color Function(String, List<Category>, int) colorForCategory;

  /// Oculta os valores de saldo e rendimento. Gastos permanecem visíveis.
  final bool hidePrivate;

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
                      hidePrivate
                          ? 'R\$ ••••'
                          : CurrencyFormatter.format(balance),
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
            ChartLegendRow(
              color: AppTheme.incomColor,
              label: 'Rendimentos',
              value: income,
              obscured: hidePrivate,
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
              child: ChartLegendRow(
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
