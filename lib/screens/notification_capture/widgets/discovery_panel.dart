import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Painel do modo descoberta: lista os apps que notificaram e permite marcar
/// quais devem ser capturados.
///
/// Existe porque o package do banco precisa ser confirmado no aparelho — não
/// presumido. E ele registra só o NOME do app, nunca o conteúdo, para que
/// descobrir o package do Nubank não signifique logar o WhatsApp junto.
class DiscoveryPanel extends StatelessWidget {
  const DiscoveryPanel({
    super.key,
    required this.discoveryMode,
    required this.seenPackages,
    required this.watchedPackages,
    required this.onToggleDiscovery,
    required this.onToggleWatched,
    required this.onClearSeen,
  });

  final bool discoveryMode;
  final List<String> seenPackages;
  final List<String> watchedPackages;
  final ValueChanged<bool> onToggleDiscovery;
  final ValueChanged<String> onToggleWatched;
  final VoidCallback onClearSeen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: discoveryMode,
              onChanged: onToggleDiscovery,
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo descoberta'),
              subtitle: const Text(
                'Registra apenas quais apps notificam, sem nenhum conteúdo. '
                'Use para achar o package do banco e desligue depois.',
                style: TextStyle(fontSize: 11),
              ),
            ),
            if (seenPackages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  discoveryMode
                      ? 'Nenhum app notificou ainda. Deixe ligado e use o '
                            'celular normalmente.'
                      : 'Ligue o modo descoberta para listar os apps que '
                            'notificam neste aparelho.',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              )
            else ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'APPS VISTOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6E6E78),
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: onClearSeen,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Limpar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: seenPackages.map((package) {
                  final isWatched = watchedPackages.contains(package);
                  return FilterChip(
                    label: Text(
                      package,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: isWatched,
                    showCheckmark: true,
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                    onSelected: (_) => onToggleWatched(package),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
