import 'package:financial_management/theme/app_theme.dart';
import 'package:financial_management/utils/currency_formatter.dart';
import 'package:financial_management/widgets/brand_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.title,
    required this.amount,
    required this.category,
    required this.dueDate,
    required this.color,
    required this.isPaid,
    required this.notifyOnDue,
    required this.onTogglePaid,
    required this.onToggleNotify,
    required this.onEdit,
    required this.onDelete,
    this.paidDate,
    this.periodIndex,
    this.totalPeriods,
    this.isInstallment = false,
    this.logoDomain,
  });

  final String title;
  final double amount;
  final String category;
  final DateTime dueDate;
  final Color color;
  final String? logoDomain;
  final bool isPaid;
  final bool notifyOnDue;
  final DateTime? paidDate;
  final VoidCallback onTogglePaid;
  final VoidCallback onToggleNotify;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int? periodIndex;
  final int? totalPeriods;
  final bool isInstallment;

  bool get _isOverdue {
    if (isPaid) return false;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return !due.isAfter(todayDate);
  }

  /// Quadrado à esquerda. Com logo, ele aparece sempre e o estado
  /// (pago/vencido) vira um selo pequeno no canto — senão um gasto que vence
  /// hoje já contaria como vencido e esconderia o logo. Sem logo, mantém o
  /// selo de estado ou a bolinha da cor da categoria.
  Widget _buildLeading() {
    final hasLogo = (logoDomain ?? '').isNotEmpty;

    if (!hasLogo) {
      if (isPaid) {
        return _statusTile(
          Icons.check_circle_rounded,
          AppTheme.incomColor.withValues(alpha: 0.8),
        );
      }
      if (_isOverdue) {
        return _statusTile(
          Icons.warning_amber_rounded,
          AppTheme.expenseColor.withValues(alpha: 0.9),
        );
      }
      return BrandAvatar(logoDomain: null, color: color);
    }

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          BrandAvatar(logoDomain: logoDomain, color: color),
          if (isPaid || _isOverdue)
            Positioned(right: -3, bottom: -3, child: _statusBadge()),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    final paid = isPaid;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: paid ? AppTheme.incomColor : AppTheme.expenseColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.surfaceColor, width: 2),
      ),
      child: Icon(
        paid ? Icons.check_rounded : Icons.priority_high_rounded,
        size: 11,
        color: Colors.white,
      ),
    );
  }

  Widget _statusTile(IconData icon, Color iconColor) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isPaid ? 0.06 : 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, size: 20, color: iconColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = isPaid ? 0.4 : 1.0;

    return Opacity(
      opacity: isPaid ? 0.65 : 1.0,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              // Logo da marca / indicador de estado
              _buildLeading(),
              const SizedBox(width: 14),

              // Title + category pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: dimmed),
                        decoration: isPaid ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white.withValues(alpha: 0.4),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: isPaid ? 0.05 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                color: color.withValues(alpha: dimmed),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (periodIndex != null && totalPeriods != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: isPaid ? 0.04 : 0.07),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$periodIndex/$totalPeriods',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: isPaid ? 0.4 : 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (isPaid && paidDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pago em ${DateFormat('dd/MM/yy', 'pt_BR').format(paidDate!)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.incomColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Amount + due date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: dimmed),
                      letterSpacing: -0.3,
                      decoration: isPaid ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  if (isInstallment && totalPeriods != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${totalPeriods}x · ${CurrencyFormatter.format(amount * totalPeriods!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: isPaid ? 0.25 : 0.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (notifyOnDue) ...[
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 10,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        DateFormat('dd/MM/yy', 'pt_BR').format(dueDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(
                            0xFF6E6E78,
                          ).withValues(alpha: dimmed),
                        ),
                      ),
                    ],
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
                      onTap: onTogglePaid,
                      child: Row(
                        children: [
                          Icon(
                            isPaid
                                ? Icons.radio_button_unchecked
                                : Icons.check_circle_outline,
                            size: 16,
                            color: AppTheme.incomColor,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isPaid ? 'Desmarcar pagamento' : 'Marcar como pago',
                            style: const TextStyle(color: AppTheme.incomColor),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      onTap: onToggleNotify,
                      child: Row(
                        children: [
                          Icon(
                            notifyOnDue
                                ? Icons.notifications_off_outlined
                                : Icons.notifications_outlined,
                            size: 16,
                            color: notifyOnDue
                                ? Colors.white38
                                : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            notifyOnDue
                                ? 'Desativar notificação'
                                : 'Notificar vencimento',
                            style: TextStyle(
                              color: notifyOnDue
                                  ? Colors.white38
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
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
      ),
    );
  }
}
