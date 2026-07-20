import 'package:financial_management/utils/currency_formatter.dart';
import 'package:flutter/material.dart';

class HeroMetric extends StatelessWidget {
  const HeroMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.obscured = false,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool obscured;

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
            obscured ? 'R\$ ••••' : CurrencyFormatter.format(value),
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
