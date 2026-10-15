import 'package:flutter/material.dart';

import '../../../models/bank_history_entry.dart';
import '../../../models/bank_transaction.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/brand_avatar.dart';

/// Cor do que foi feito pela IA (selo e destaques).
const aiColor = Color(0xFFA78BFA);

/// Rótulo e cor de cada resultado, compartilhados pela linha e pelo detalhe.
extension BankOutcomeStyle on BankOutcome {
  /// Rótulo genérico, usado no filtro.
  String get label => switch (this) {
        BankOutcome.launched => 'Lançada',
        BankOutcome.discarded => 'Descartada',
        BankOutcome.matched => 'Já cadastrada',
        BankOutcome.handled => 'Antiga',
      };

  /// Rótulo no plural, para o chip do filtro.
  String get filterLabel => switch (this) {
        BankOutcome.launched => 'Lançadas',
        BankOutcome.discarded => 'Descartadas',
        BankOutcome.matched => 'Já cadastradas',
        BankOutcome.handled => 'Antigas',
      };

  /// O que o resultado quer dizer, mostrado sob o filtro selecionado.
  String get description => switch (this) {
        BankOutcome.launched =>
          'Viraram um gasto ou rendimento novo — por você ou pela IA.',
        BankOutcome.discarded =>
          'Você dispensou: não eram para lançar (transferência entre contas, '
              'estorno, duplicada…).',
        BankOutcome.matched =>
          'Eram o pagamento de algo já cadastrado; o gasto passou a constar '
              'pago (ou o rendimento, recebido).',
        BankOutcome.handled =>
          'Saíram da caixa de entrada antes de o histórico existir; não se '
              'sabe se viraram lançamento.',
      };

  Color get color => switch (this) {
        BankOutcome.launched => AppTheme.primaryColor,
        BankOutcome.discarded => const Color(0xFF6E6E78),
        BankOutcome.matched => AppTheme.incomColor,
        BankOutcome.handled => const Color(0xFF8E8E98),
      };

  IconData get icon => switch (this) {
        BankOutcome.launched => Icons.check_circle_rounded,
        BankOutcome.discarded => Icons.remove_circle_outline_rounded,
        BankOutcome.matched => Icons.task_alt_rounded,
        BankOutcome.handled => Icons.history_rounded,
      };
}

/// Rótulo do resultado de uma entrada: "já cadastrada" vira "Paga" num gasto
/// e "Recebida" num rendimento.
String outcomeLabel(BankHistoryEntry entry) {
  if (entry.outcome != BankOutcome.matched) return entry.outcome.label;
  return entry.transaction?.type == TransactionType.income
      ? 'Recebida'
      : 'Paga';
}

/// Uma linha do histórico: movimentação que já saiu da caixa de entrada.
class BankHistoryTile extends StatelessWidget {
  const BankHistoryTile({super.key, required this.entry, required this.onTap});

  final BankHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = entry.transaction!;
    final isExpense = t.type == TransactionType.expense;
    final discarded = entry.outcome == BankOutcome.discarded;
    final amountColor = discarded
        ? const Color(0xFF6E6E78)
        : isExpense
            ? AppTheme.expenseColor
            : AppTheme.incomColor;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Opacity(
              opacity: discarded ? 0.45 : 1,
              child: BankLogo(logoDomain: t.institutionLogo, size: 36),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.description.isEmpty ? 'Sem descrição' : t.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: discarded ? Colors.white54 : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [t.institution, t.accountLabel]
                        .where((p) => p.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6E6E78),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '−' : '+'} ${CurrencyFormatter.format(t.amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                    decoration: discarded ? TextDecoration.lineThrough : null,
                    decorationColor: amountColor,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.auto) ...[
                      const Tooltip(
                        message: 'Feito pela IA',
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 11,
                          color: aiColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(
                      entry.outcome.icon,
                      size: 11,
                      color: entry.outcome.color,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      outcomeLabel(entry),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: entry.outcome.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo do banco ou, sem logo escolhido, um ícone genérico no mesmo formato.
class BankLogo extends StatelessWidget {
  const BankLogo({super.key, required this.logoDomain, this.size = 40});

  final String? logoDomain;
  final double size;

  @override
  Widget build(BuildContext context) {
    final domain = logoDomain;
    if (domain == null || domain.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.account_balance_outlined,
          size: size / 2,
          color: AppTheme.primaryColor,
        ),
      );
    }
    return BrandAvatar(
      logoDomain: domain,
      color: AppTheme.primaryColor,
      size: size,
    );
  }
}
