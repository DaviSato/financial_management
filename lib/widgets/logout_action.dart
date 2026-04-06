import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});

  @override
  Widget build(BuildContext context) {
    if (AuthService().currentUser == null) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.logout_rounded),
      tooltip: 'Sair',
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.expenseColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.expenseColor,
                size: 24,
              ),
            ),
            title: const Text('Encerrar sessão'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tem certeza que deseja sair?',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AuthService().currentUser?.email ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.expenseColor,
                        minimumSize: const Size(0, 42),
                      ),
                      child: const Text('Sair'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await StorageService().clearAll();
          await AuthService().signOut();
        }
      },
    );
  }
}
