import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/bank_transaction.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';
import 'bank_history_tile.dart' show BankLogo, aiColor;

const _pendingColor = Color(0xFFB0883B);
const _mutedColor = Color(0xFF6E6E78);

/// Uma movimentação do banco aguardando ser lançada: linha compacta, no
/// mesmo formato do histórico, dentro do bloco de pendentes.
class BankTransactionCard extends StatelessWidget {
  const BankTransactionCard({
    super.key,
    required this.transaction,
    required this.onLaunch,
    this.aiHint,
    this.actionLabel,
    this.secondaryLabel,
    this.onSecondary,
  });

  final BankTransaction transaction;

  /// Ação principal: abre o formulário pré-preenchido ou aplica a sugestão
  /// da IA.
  final VoidCallback onLaunch;

  /// Sugestão da IA que ficou para o usuário decidir (confiança baixa).
  final String? aiHint;

  /// Texto do botão principal; null = "Lançar".
  final String? actionLabel;

  /// Ação alternativa, quando a principal é a sugestão da IA (ex.: lançar
  /// como gasto novo em vez de marcar um existente como pago).
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isExpense = t.type == TransactionType.expense;
    final color = isExpense ? AppTheme.expenseColor : AppTheme.incomColor;

    final meta = [
      DateFormat('dd/MM', 'pt_BR').format(t.date),
      if (t.institution.isNotEmpty) t.institution,
      if (t.paymentMethod != null) t.paymentMethod!.label,
      if (t.isInstallment) '${t.installmentNumber}/${t.totalInstallments}',
    ].join(' · ');

    // Fundo opaco: a linha desliza sobre o fundo do swipe.
    return Material(
      color: Theme.of(context).cardColor,
      child: InkWell(
        // Tocar na linha sempre abre o formulário (a alternativa, quando a
        // principal é a sugestão da IA) — aplicar a sugestão fica no botão.
        onTap: onSecondary ?? onLaunch,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Logo(transaction: t, color: color, isExpense: isExpense),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.description.isEmpty
                              ? 'Sem descrição'
                              : t.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: meta),
                              if (t.pending)
                                const TextSpan(
                                  text: ' · pendente',
                                  style: TextStyle(color: _pendingColor),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isExpense ? '−' : '+'} '
                        '${CurrencyFormatter.format(t.amount)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _ActionPill(
                        label: actionLabel ?? 'Lançar',
                        color: aiHint != null && onSecondary != null
                            ? aiColor
                            : color,
                        onTap: onLaunch,
                      ),
                    ],
                  ),
                ],
              ),
              if (aiHint != null)
                Padding(
                  padding: const EdgeInsets.only(left: 48, top: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 11,
                        color: aiColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          aiHint!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: aiColor),
                        ),
                      ),
                      if (secondaryLabel != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onSecondary,
                          child: Text(
                            secondaryLabel!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white24,
                            ),
                          ),
                        ),
                      ],
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

/// Logo do banco com o sentido da movimentação num selo no canto.
class _Logo extends StatelessWidget {
  const _Logo({
    required this.transaction,
    required this.color,
    required this.isExpense,
  });

  final BankTransaction transaction;
  final Color color;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          BankLogo(logoDomain: transaction.institutionLogo, size: 36),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isExpense ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão pequeno e tonal, para não pesar a lista.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
