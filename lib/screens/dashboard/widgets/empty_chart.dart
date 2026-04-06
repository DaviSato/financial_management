import 'package:financial_management/theme/app_theme.dart';
import 'package:flutter/material.dart';

class EmptyChart extends StatelessWidget {
  const EmptyChart({super.key});

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
