import 'package:financial_management/models/category.dart';
import 'package:financial_management/theme/app_theme.dart';
import 'package:financial_management/utils/currency_formatter.dart';
import 'package:flutter/material.dart';

class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({
    super.key,
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
