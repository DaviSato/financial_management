import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fundo vermelho revelado ao arrastar um item da direita para a esquerda para
/// excluí-lo. Alinhado ao layout dos cards de gasto/rendimento.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Fundo sólido; o card quadrado desliza sobre ele dentro da moldura com
      // clip (SwipeableCardFrame), então nada vaza nos cantos.
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      color: AppTheme.expenseColor.withValues(alpha: 0.15),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Excluir',
            style: TextStyle(
              color: AppTheme.expenseColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.expenseColor,
            size: 20,
          ),
        ],
      ),
    );
  }
}
