import 'package:flutter/material.dart';

/// Moldura para uma linha de lista com swipe: aplica o espaçamento externo, o
/// arredondamento e a borda — tudo parado — enquanto o card interno (que deve
/// ser quadrado, sem raio/borda próprios) desliza dentro dela.
///
/// Como o card desliza com borda de fuga reta e a moldura recorta o conteúdo
/// (clip), o fundo do swipe nunca vaza pelos cantos arredondados.
class SwipeableCardFrame extends StatelessWidget {
  const SwipeableCardFrame({super.key, required this.child});

  /// Normalmente o `Dismissible` com o card quadrado.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: child,
      ),
    );
  }
}
