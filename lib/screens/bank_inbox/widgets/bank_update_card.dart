import 'package:flutter/material.dart';

import '../../../models/bank_connection.dart';
import '../../../services/pluggy_client.dart';
import '../../../theme/app_theme.dart';
import 'bank_history_tile.dart';

/// Situação dos bancos na Pluggy, uma linha por banco num card só: quando os
/// dados foram atualizados e quanto falta para a próxima atualização.
///
/// O Meu Pluggy atualiza uma vez por dia, então o que aconteceu no banco
/// depois de [PluggyItem.lastUpdatedAt] ainda não chegou — a barrinha mostra
/// em que ponto do ciclo estamos.
class BankUpdateCard extends StatelessWidget {
  const BankUpdateCard({super.key, required this.banks, this.now});

  final List<({BankConnection connection, PluggyItem item})> banks;

  /// Relógio injetável; null usa [DateTime.now].
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final now = this.now ?? DateTime.now();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final (i, b) in banks.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 52,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              _BankUpdateRow(connection: b.connection, item: b.item, now: now),
            ],
          ],
        ),
      ),
    );
  }
}

class _BankUpdateRow extends StatelessWidget {
  const _BankUpdateRow({
    required this.connection,
    required this.item,
    required this.now,
  });

  final BankConnection connection;
  final PluggyItem item;
  final DateTime now;

  static const _muted = Color(0xFF6E6E78);
  static const _warning = Color(0xFFB0883B);

  @override
  Widget build(BuildContext context) {
    final last = item.lastUpdatedAt;
    final next = item.nextAutoSyncAt;
    final status = _status();
    final name = connection.institution.isEmpty
        ? connection.itemId
        : connection.institution;

    final String detail;
    if (item.hasProblem) {
      detail = 'Reconecte em meu.pluggy.ai';
    } else if (item.isUpdating) {
      detail = 'Buscando dados novos…';
    } else if (last == null) {
      detail = 'Ainda sem dados';
    } else {
      detail = [
        '${_day(last)} ${_time(last)}',
        if (next != null && now.isBefore(next))
          'próxima em ${_span(next.difference(now))}',
      ].join(' · ');
    }

    final showBar = !item.hasProblem && last != null && next != null;

    return Tooltip(
      message: [
        if (last != null) 'Dados até ${_day(last)}, ${_time(last)}',
        if (next != null) 'Próxima atualização: ${_day(next)}, ${_time(next)}',
      ].join('\n'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            BankLogo(logoDomain: connection.logoDomain, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: item.hasProblem ? status.color : _muted,
                    ),
                  ),
                  if (showBar) ...[
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: item.isUpdating ? null : _progress(last, next),
                        minHeight: 3,
                        color: status.color,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: status.label,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String label, Color color}) _status() {
    if (item.hasProblem) {
      return (label: 'Reconectar', color: AppTheme.expenseColor);
    }
    if (item.isUpdating) {
      return (label: 'Atualizando', color: AppTheme.primaryColor);
    }
    final next = item.nextAutoSyncAt;
    // Folga de 1h: a Pluggy costuma rodar um pouco depois do horário previsto.
    if (next != null && now.isAfter(next.add(const Duration(hours: 1)))) {
      return (label: 'Atrasada', color: _warning);
    }
    if (item.lastUpdatedAt == null) {
      return (label: 'Aguardando', color: _muted);
    }
    return (label: 'Em dia', color: AppTheme.incomColor);
  }

  double _progress(DateTime last, DateTime next) {
    final total = next.difference(last).inSeconds;
    if (total <= 0) return 1;
    return (now.difference(last).inSeconds / total).clamp(0.0, 1.0);
  }

  /// "5 min", "6 h", "2 dias".
  static String _span(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)} min';
    if (d.inHours < 24) return '${d.inHours} h';
    final days = d.inDays;
    return days == 1 ? '1 dia' : '$days dias';
  }

  String _day(DateTime d) {
    final days = DateTime(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return switch (days) {
      0 => 'hoje',
      -1 => 'ontem',
      1 => 'amanhã',
      _ => '${_two(d.day)}/${_two(d.month)}',
    };
  }

  static String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
