import 'payment_method.dart';

enum TransactionType { expense, income }

/// Resultado de interpretar uma [CapturedNotification]: o que o parser
/// conseguiu extrair de valor, tipo e contraparte.
///
/// Ainda não é um Expense/Income — é o rascunho que alimenta a caixa de
/// entrada, onde o usuário confirma a categoria antes de virar lançamento.
class ParsedTransaction {
  final double amount;
  final TransactionType type;

  /// Estabelecimento (gasto) ou quem enviou/pagou (rendimento).
  final String description;
  final PaymentMethod? paymentMethod;
  final DateTime postedAt;
  final String sourcePackage;
  final String rawText;

  /// Rótulo da regra que casou — mostrado na UI para dar rastreabilidade.
  final String ruleLabel;

  /// Regra ainda não confirmada contra texto real do banco. O palpite pode
  /// estar errado; serve para revelar o formato verdadeiro quando aparecer.
  final bool provisional;

  const ParsedTransaction({
    required this.amount,
    required this.type,
    required this.description,
    required this.postedAt,
    required this.sourcePackage,
    required this.rawText,
    required this.ruleLabel,
    this.paymentMethod,
    this.provisional = false,
  });

  /// Chave de deduplicação. A notificação não traz id de transação, então a
  /// dedup é heurística: mesmo app, tipo, valor, contraparte e dia. Duas
  /// compras idênticas no mesmo dia colapsam — raro e preferível a duplicar.
  String get dedupeKey {
    final day =
        '${postedAt.year}-${postedAt.month.toString().padLeft(2, '0')}-${postedAt.day.toString().padLeft(2, '0')}';
    return '$sourcePackage|${type.name}|${amount.toStringAsFixed(2)}|'
        '${description.toLowerCase()}|$day';
  }

  @override
  String toString() =>
      'ParsedTransaction(${type.name}, $amount, "$description", '
      'rule: $ruleLabel${provisional ? ' [provisório]' : ''})';
}
