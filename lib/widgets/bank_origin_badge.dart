import 'dart:io';

import 'package:flutter/material.dart';

import '../models/bank_origin.dart';
import '../services/logo_service.dart';
import '../theme/app_theme.dart';

/// Selo pequeno com o logo do banco de onde o lançamento veio (Pluggy).
/// Vai no canto do ícone dos cards de gasto e rendimento.
///
/// Baixa o logo se ainda não estiver no aparelho — o lançamento pode ter sido
/// feito em outro aparelho. Sem logo, mostra um ícone de banco.
class BankOriginBadge extends StatelessWidget {
  const BankOriginBadge({super.key, required this.origin, this.size = 18});

  final BankOrigin origin;
  final double size;

  /// Um download por domínio por sessão. O FutureBuilder roda a cada rebuild
  /// da lista; sem o cache, offline cada rolagem tentaria baixar de novo.
  static final _logos = <String, Future<File?>>{};

  static Future<File?> _logo(String domain) => _logos.putIfAbsent(
        domain,
        () => LogoService().ensureLocal(domain).catchError((_) => null),
      );

  @override
  Widget build(BuildContext context) {
    final domain = origin.logoDomain;
    final message = origin.name.isEmpty
        ? 'Lançado do banco'
        : 'Lançado do ${origin.name}';

    return Tooltip(
      message: message,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.surfaceColor, width: 1.5),
        ),
        child: (domain == null || domain.isEmpty)
            ? _fallback()
            : FutureBuilder<File?>(
                future: _logo(domain),
                builder: (context, snapshot) {
                  final file = snapshot.data;
                  if (file == null) return _fallback();
                  return ClipOval(
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallback(),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _fallback() => Icon(
        Icons.account_balance_rounded,
        size: size * 0.6,
        color: Colors.white70,
      );
}
