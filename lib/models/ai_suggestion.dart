/// O que a IA acha que deve ser feito com uma movimentação do banco.
enum AiAction {
  /// Gasto novo, na categoria [AiSuggestion.category].
  expense,

  /// Rendimento novo.
  income,

  /// Pagamento de um gasto que já existe (recorrente, parcela, conta avulsa
  /// em aberto): [AiSuggestion.matchId] é o gasto, que passa a constar pago.
  payExpense,

  /// Recebimento de um rendimento que já existe ([AiSuggestion.matchId]).
  /// Não muda nada — só não lança de novo.
  matchIncome,

  /// Não é gasto nem rendimento (transferência entre contas próprias,
  /// aplicação/resgate, pagamento de fatura).
  ignore;

  static AiAction? fromName(Object? name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }
}

/// Resposta da IA para uma movimentação. Guardada por id da transação para
/// que cada uma vá para a IA uma vez só.
class AiSuggestion {
  final String transactionId;
  final AiAction action;
  final String? category;

  /// Nome limpo para o lançamento ("Uber", "iFood"), no lugar da descrição
  /// crua do banco.
  final String? title;
  final String? matchId;

  /// 0 a 1. Só o que passa de BankAutoLauncher.threshold é aplicado sozinho.
  final double confidence;

  /// Motivo curto, mostrado quando a sugestão fica para o usuário decidir.
  final String? reason;

  final DateTime createdAt;

  const AiSuggestion({
    required this.transactionId,
    required this.action,
    required this.confidence,
    required this.createdAt,
    this.category,
    this.title,
    this.matchId,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'confidence': confidence,
        'createdAt': createdAt.toIso8601String(),
        if (category != null) 'category': category,
        if (title != null) 'title': title,
        if (matchId != null) 'matchId': matchId,
        if (reason != null) 'reason': reason,
      };

  static AiSuggestion? fromJson(String id, Map<String, dynamic> json) {
    final action = AiAction.fromName(json['action']);
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (action == null || createdAt == null) return null;
    return AiSuggestion(
      transactionId: id,
      action: action,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      createdAt: createdAt,
      category: json['category'] as String?,
      title: json['title'] as String?,
      matchId: json['matchId'] as String?,
      reason: json['reason'] as String?,
    );
  }
}
