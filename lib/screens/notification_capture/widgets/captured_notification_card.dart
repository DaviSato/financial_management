import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../models/captured_notification.dart';
import '../../../models/parsed_transaction.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';

/// Mostra a notificação como o banco a enviou e, abaixo, o que o parser
/// entendeu dela — com um atalho para lançar.
///
/// Os campos crus continuam à mostra de propósito: enquanto os formatos não
/// estiverem todos confirmados, ver o texto original é o que permite ajustar as
/// palavras-chave.
class CapturedNotificationCard extends StatelessWidget {
  const CapturedNotificationCard({
    super.key,
    required this.notification,
    this.parsed,
    this.onLaunch,
  });

  final CapturedNotification notification;

  /// Resultado do parser; null quando não foi reconhecida como lançamento.
  final ParsedTransaction? parsed;

  /// Abre o formulário pré-preenchido (ou vazio, se [parsed] for null).
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context) {
    final n = notification;

    return Card(
      // Quadrado e sem borda própria: o arredondamento e a borda vêm da moldura
      // externa (SwipeableCardFrame), para o card deslizar com borda de fuga
      // reta e não vazar o fundo do swipe nos cantos.
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    n.packageName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM HH:mm:ss', 'pt_BR').format(n.postedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6E6E78),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: n.fullText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Texto copiado'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: Color(0xFF6E6E78),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (n.title.isNotEmpty) _Field(label: 'title', value: n.title),
            if (n.text.isNotEmpty) _Field(label: 'text', value: n.text),
            if (n.bigText.isNotEmpty && n.bigText != n.text)
              _Field(label: 'bigText', value: n.bigText),
            if (n.subText.isNotEmpty) _Field(label: 'subText', value: n.subText),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _ParsePreview(parsed: parsed, onLaunch: onLaunch),
          ],
        ),
      ),
    );
  }
}

/// Faixa inferior: o que o parser extraiu, e o botão de lançar.
class _ParsePreview extends StatelessWidget {
  const _ParsePreview({required this.parsed, required this.onLaunch});

  final ParsedTransaction? parsed;
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context) {
    final p = parsed;

    if (p == null) {
      return Row(
        children: [
          const Expanded(
            child: Text(
              'Não reconhecida automaticamente',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ),
          if (onLaunch != null)
            TextButton(
              onPressed: onLaunch,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Lançar manual', style: TextStyle(fontSize: 12)),
            ),
        ],
      );
    }

    final isExpense = p.type == TransactionType.expense;
    final color = isExpense ? AppTheme.expenseColor : AppTheme.incomColor;

    return Row(
      children: [
        Icon(
          isExpense ? Icons.south_west_rounded : Icons.north_east_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    CurrencyFormatter.format(p.amount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Tag(text: p.ruleLabel, color: color),
                  if (p.provisional) ...[
                    const SizedBox(width: 6),
                    const _Tag(text: 'provisório', color: Color(0xFFB0883B)),
                  ],
                ],
              ),
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  p.description,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onLaunch,
          style: FilledButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            backgroundColor: color,
          ),
          child: Text(isExpense ? 'Lançar gasto' : 'Lançar renda'),
        ),
      ],
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF6E6E78),
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
