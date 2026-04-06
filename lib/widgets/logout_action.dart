import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';

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
            title: const Text('Sair'),
            content: const Text('Deseja encerrar a sessão?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sair'),
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
