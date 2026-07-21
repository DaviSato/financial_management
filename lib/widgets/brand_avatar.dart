import 'dart:io';

import 'package:flutter/material.dart';

import '../services/logo_service.dart';

/// Quadrado com o logo da marca lido do cache local ([LogoService]) ou, na
/// falta dele, um fallback (bolinha na cor da categoria).
///
/// Nunca toca a rede: se o arquivo não está em disco, mostra o fallback. O
/// download é feito só no seletor (com confirmação), não aqui — assim a lista
/// e o dashboard não disparam chamadas externas ao rolar.
class BrandAvatar extends StatelessWidget {
  final String? logoDomain;
  final Color color;
  final double size;

  /// Opacidade do fundo tingido (menor quando o gasto está pago, para esmaecer).
  final double backgroundAlpha;

  const BrandAvatar({
    super.key,
    required this.logoDomain,
    required this.color,
    this.size = 44,
    this.backgroundAlpha = 0.12,
  });

  @override
  Widget build(BuildContext context) {
    final domain = logoDomain;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(12),
      ),
      child: (domain == null || domain.isEmpty)
          ? _fallback()
          : FutureBuilder<File?>(
              future: LogoService().localIfExists(domain),
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file == null) return _fallback();
                // Preenche o quadrado inteiro (o logo.dev entrega ícones
                // quadrados, então cover ocupa tudo sem cortar).
                return Image.file(
                  file,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _fallback(),
                );
              },
            ),
    );
  }

  Widget _fallback() {
    return Center(
      child: Container(
        width: size * 0.4,
        height: size * 0.4,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
