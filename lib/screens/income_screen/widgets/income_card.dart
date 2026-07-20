import 'package:financial_management/theme/app_theme.dart';
import 'package:financial_management/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class IncomeCard extends StatelessWidget {
  const IncomeCard({
    super.key,
    required this.title,
    required this.amount,
    required this.receiveDate,
    required this.onEdit,
    required this.onDelete,
    this.recurrenceLabel,
    this.periodIndex,
    this.totalPeriods,
    this.isAutomatic = false,
  });

  final String title;
  final double amount;
  final DateTime receiveDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Ex: "a cada 6 meses". Nulo para rendimento único.
  final String? recurrenceLabel;
  final int? periodIndex;
  final int? totalPeriods;
  final bool isAutomatic;

  @override
  Widget build(BuildContext context) {
    final showPeriodBadge = periodIndex != null && totalPeriods != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.incomColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: AppTheme.incomColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Título + selos de recorrência
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
                  if (recurrenceLabel != null || showPeriodBadge || isAutomatic) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (recurrenceLabel != null)
                          _Badge(
                            text: recurrenceLabel!,
                            color: AppTheme.incomColor,
                          ),
                        if (recurrenceLabel != null && showPeriodBadge)
                          const SizedBox(width: 6),
                        if (showPeriodBadge)
                          _Badge(
                            text: '$periodIndex/$totalPeriods',
                            color: Colors.white,
                          ),
                        if (isAutomatic) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.bolt_rounded,
                            size: 13,
                            color: AppTheme.primaryColor.withValues(alpha: 0.75),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Valor + data
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.incomColor,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('dd/MM/yy', 'pt_BR').format(receiveDate),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color.withValues(alpha: 0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
