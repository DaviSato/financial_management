import '../models/captured_notification.dart';
import '../models/parsed_transaction.dart';
import 'transaction_parser.dart';

/// O que a importação automática decidiu fazer com a fila.
class AutoImportPlan {
  /// Transações a criar sozinhas (origem automática).
  final List<ParsedTransaction> toCreate;

  /// Notificações a remover da fila — apenas as que viraram lançamento.
  /// Provisórias e não reconhecidas permanecem para revisão manual.
  final List<CapturedNotification> toConsume;

  const AutoImportPlan({required this.toCreate, required this.toConsume});

  bool get isEmpty => toCreate.isEmpty;
}

/// Decide, sem efeitos colaterais, o que importar automaticamente da fila.
///
/// Conservador de propósito: só cria a partir de regra **confirmada**. Palpite
/// provisório (crédito, pix ainda não vistos) e texto não reconhecido nunca
/// viram lançamento silencioso — ficam esperando o usuário revisar.
class AutoImportService {
  final TransactionParser parser;
  const AutoImportService({this.parser = const TransactionParser()});

  AutoImportPlan plan(List<CapturedNotification> queue) {
    final toCreate = <ParsedTransaction>[];
    final toConsume = <CapturedNotification>[];
    final seen = <String>{};

    for (final notification in queue) {
      final parsed = parser.parse(notification);

      // Só o confirmado entra sozinho. O resto espera revisão manual.
      if (parsed == null || parsed.provisional) continue;

      // A notificação sai da fila mesmo se for duplicata — senão a duplicata
      // ficaria presa para sempre.
      toConsume.add(notification);
      if (seen.add(parsed.dedupeKey)) toCreate.add(parsed);
    }

    return AutoImportPlan(toCreate: toCreate, toConsume: toConsume);
  }
}
