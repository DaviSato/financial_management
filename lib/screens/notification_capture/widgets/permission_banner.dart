import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Aviso de que o acesso a notificações ainda não foi concedido.
///
/// A permissão não pode ser pedida por dialog: o usuário precisa habilitar
/// manualmente em Ajustes > Acesso a notificações. O botão só abre a tela.
class PermissionBanner extends StatelessWidget {
  const PermissionBanner({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AppTheme.expenseColor.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  'Acesso a notificações desligado',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Sem essa permissão nada é capturado. Ela precisa ser '
              'habilitada à mão nos ajustes do Android — nenhum app consegue '
              'concedê-la por conta própria.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Abrir ajustes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
