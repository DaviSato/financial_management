import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/bank_transaction.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/brand_avatar.dart';

/// Uma movimentação do banco aguardando ser lançada.
class BankTransactionCard extends StatelessWidget {
  const BankTransactionCard({
    super.key,
    required this.transaction,
    required this.onLaunch,
  });

  final BankTransaction transaction;

  /// Abre o formulário pré-preenchido.
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isExpense = t.type == TransactionType.expense;
    final color = isExpense ? AppTheme.expenseColor : AppTheme.incomColor;

    return Card(
      // Quadrado e sem borda própria: o arredondamento e a borda vêm da moldura
      // externa (SwipeableCardFrame), para o card deslizar com borda de fuga
      // reta e não vazar o fundo do swipe nos cantos.
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _Flag(transaction: t, color: color, isExpense: isExpense),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.description.isEmpty ? 'Sem descrição' : t.description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      t.institution,
                      t.accountLabel,
                      DateFormat('dd/MM', 'pt_BR').format(t.date),
                    ].where((p) => p.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6E6E78),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        CurrencyFormatter.format(t.amount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      if (t.paymentMethod != null)
                        _Tag(text: t.paymentMethod!.label, color: color),
                      if (t.isInstallment)
                        _Tag(
                          text:
                              'parcela ${t.installmentNumber}/${t.totalInstallments}',
                          color: color,
                        ),
                      if (t.pending)
                        const _Tag(text: 'pendente', color: Color(0xFFB0883B)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onLaunch,
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                backgroundColor: color,
              ),
              child: Text(isExpense ? 'Lançar gasto' : 'Lançar renda'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeira do banco: o logo escolhido para a conexão, com o sentido da
/// movimentação num selo no canto. Sem logo, fica só a seta.
class _Flag extends StatelessWidget {
  const _Flag({
    required this.transaction,
    required this.color,
    required this.isExpense,
  });

  final BankTransaction transaction;
  final Color color;
  final bool isExpense;

  IconData get _arrow =>
      isExpense ? Icons.south_west_rounded : Icons.north_east_rounded;

  @override
  Widget build(BuildContext context) {
    final logo = transaction.institutionLogo;
    if (logo == null || logo.isEmpty) {
      return Icon(_arrow, size: 18, color: color);
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          BrandAvatar(logoDomain: logo, color: color, size: 40),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 2,
                ),
              ),
              child: Icon(_arrow, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
