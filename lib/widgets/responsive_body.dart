import 'package:flutter/material.dart';

/// Centraliza e limita a largura do conteúdo em telas largas (desktop), para
/// listas, cards e formulários não esticarem de ponta a ponta num monitor.
///
/// Em telas estreitas (celular) é praticamente transparente: o conteúdo já é
/// mais estreito que [maxWidth], então ocupa tudo. Alinha ao topo para não
/// centralizar verticalmente listas que rolam.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 680});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
