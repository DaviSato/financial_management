import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';

import '../utils/currency_formatter.dart';

/// Valor em reais que o botão de olho (ocultar valores) esconde com blur.
///
/// Oculto, desfoca um valor fictício — não o real: blur do valor verdadeiro
/// ainda entregaria a ordem de grandeza pelo comprimento do número, e um blur
/// leve dá para ler de perto.
class PrivateAmount extends StatelessWidget {
  const PrivateAmount(
    this.value, {
    super.key,
    required this.hidden,
    this.style,
  });

  final double value;
  final bool hidden;
  final TextStyle? style;

  static const _placeholder = 'R\$ 0.000,00';

  @override
  Widget build(BuildContext context) {
    if (!hidden) return Text(CurrencyFormatter.format(value), style: style);

    // Proporcional à fonte: o mesmo sigma que apaga um valor de 12px deixaria
    // o saldo de 34px legível.
    final sigma = (style?.fontSize ?? 14) * 0.3;
    return Semantics(
      label: 'Valor oculto',
      child: ExcludeSemantics(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          ),
          child: Text(_placeholder, style: style),
        ),
      ),
    );
  }
}
