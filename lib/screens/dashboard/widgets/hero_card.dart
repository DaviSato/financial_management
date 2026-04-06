import 'package:financial_management/screens/dashboard/widgets/hero_metric.dart';
import 'package:financial_management/theme/app_theme.dart';
import 'package:financial_management/utils/currency_formatter.dart';
import 'package:flutter/material.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
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
                child: HeroMetric(
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
                child: HeroMetric(
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
