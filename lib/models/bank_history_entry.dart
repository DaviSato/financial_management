import 'bank_transaction.dart';

/// O que aconteceu com uma movimentação que chegou do banco.
enum BankOutcome {
  /// Virou gasto ou rendimento ([BankHistoryEntry.launchedId]).
  launched,

  /// O usuário descartou: não era para lançar.
  discarded,

  /// Era o pagamento/recebimento de algo já cadastrado
  /// ([BankHistoryEntry.launchedId]); um gasto passa a constar pago no mês.
  matched,

  /// Tratada antes de o histórico existir — só se sabe que saiu da caixa de
  /// entrada, não se virou lançamento.
  handled;

  static BankOutcome fromName(Object? name) {
    for (final o in values) {
      if (o.name == name) return o;
    }
    return handled;
  }
}

/// Uma movimentação do banco que já saiu da caixa de entrada.
///
/// Serve a dois propósitos: impedir que ela volte numa próxima sincronização
/// (por [transactionId] e, se estava pendente, por [fingerprint]) e mostrar o
/// histórico do que chegou e do que foi feito com cada coisa.
class BankHistoryEntry {
  /// Id da transação na Pluggy.
  final String transactionId;

  /// [BankTransaction.fingerprint], só para as que estavam pendentes — a
  /// Pluggy pode trocar o id quando a compra é liquidada, e o fingerprint é o
  /// que a reconhece de volta. Para as já liquidadas fica null: duas compras
  /// iguais no mesmo dia são legítimas e não podem se esconder uma à outra.
  final String? fingerprint;

  final BankOutcome outcome;

  /// Quando foi tratada. Null em registros antigos guardados só com o id.
  final DateTime? handledAt;

  /// Retrato da movimentação. Null em registros antigos até a próxima
  /// sincronização trazê-la de novo da Pluggy (se ainda estiver na janela).
  final BankTransaction? transaction;

  /// Id do gasto ou rendimento criado, quando [outcome] é
  /// [BankOutcome.launched], ou do que já existia quando é
  /// [BankOutcome.matched]. O tipo é o da [transaction].
  final String? launchedId;

  /// Feito pela IA, sem o usuário confirmar.
  final bool auto;

  /// Quanto tempo o histórico guarda. Bem maior que a janela da Pluggy
  /// (BankSyncService.lookback), então nada expirado pode voltar à caixa de
  /// entrada.
  static const retention = Duration(days: 365);

  const BankHistoryEntry({
    required this.transactionId,
    required this.outcome,
    this.fingerprint,
    this.handledAt,
    this.transaction,
    this.launchedId,
    this.auto = false,
  });

  factory BankHistoryEntry.of(
    BankTransaction t,
    BankOutcome outcome, {
    required DateTime at,
    String? launchedId,
    bool auto = false,
  }) {
    return BankHistoryEntry(
      transactionId: t.id,
      fingerprint: t.pending ? t.fingerprint : null,
      outcome: outcome,
      handledAt: at,
      transaction: t,
      launchedId: launchedId,
      auto: auto,
    );
  }

  BankHistoryEntry withTransaction(BankTransaction t) => BankHistoryEntry(
        transactionId: transactionId,
        fingerprint: fingerprint,
        outcome: outcome,
        handledAt: handledAt,
        transaction: t,
        launchedId: launchedId,
        auto: auto,
      );

  /// Passou de [retention], contando da data da movimentação (ou de quando
  /// foi tratada, se não há retrato). Sem nenhuma das duas, fica.
  bool isExpired(DateTime now) {
    final reference = transaction?.date ?? handledAt;
    return reference != null && now.difference(reference) > retention;
  }

  Map<String, dynamic> toJson() => {
        'fingerprint': fingerprint,
        'outcome': outcome.name,
        if (handledAt != null) 'handledAt': handledAt!.toIso8601String(),
        if (transaction != null) 'transaction': transaction!.toJson(),
        if (launchedId != null) 'launchedId': launchedId,
        if (auto) 'auto': true,
      };

  /// Lê o que [toJson] grava e também o formato antigo, que tinha só
  /// `fingerprint` e `handledAt`.
  factory BankHistoryEntry.fromJson(String id, Map<String, dynamic> json) {
    final t = json['transaction'];
    final handledAt = json['handledAt'];
    return BankHistoryEntry(
      transactionId: id,
      fingerprint: json['fingerprint'] as String?,
      outcome: BankOutcome.fromName(json['outcome']),
      handledAt: handledAt is String ? DateTime.tryParse(handledAt) : null,
      transaction: t is Map
          ? BankTransaction.fromJson(Map<String, dynamic>.from(t))
          : null,
      launchedId: json['launchedId'] as String?,
      auto: json['auto'] == true,
    );
  }
}
