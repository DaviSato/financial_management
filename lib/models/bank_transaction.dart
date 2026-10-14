import 'payment_method.dart';

enum TransactionType { expense, income }

/// Conta de um banco conectado, como a Pluggy devolve em `GET /accounts`.
class BankAccount {
  final String id;
  final String name;

  /// Número externo da conta/cartão; só os últimos dígitos são mostrados.
  final String number;

  /// `true` para cartão de crédito (`type: CREDIT`), `false` para conta
  /// corrente/poupança (`type: BANK`).
  final bool isCreditCard;

  const BankAccount({
    required this.id,
    required this.name,
    required this.isCreditCard,
    this.number = '',
  });

  /// Rótulo curto para a UI: nome da conta e final do número
  /// (ex.: "Conta Corrente ••1234"). Um item do Meu Pluggy pode trazer contas
  /// e cartões, e o nome é o que os distingue.
  String get label {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final suffix =
        digits.length >= 4 ? '••${digits.substring(digits.length - 4)}' : '';
    return [name.trim(), suffix].where((p) => p.isNotEmpty).join(' ');
  }

  factory BankAccount.fromPluggy(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String,
      name: (json['marketingName'] ?? json['name'] ?? '') as String,
      isCreditCard: json['type'] == 'CREDIT',
      number: (json['number'] ?? '') as String,
    );
  }
}

/// Uma movimentação lida da Pluggy, já traduzida para o vocabulário do app.
///
/// Ainda não é um Expense/Income — é o rascunho que alimenta a caixa de
/// entrada, onde o usuário confirma a categoria antes de virar lançamento.
class BankTransaction {
  final String id;
  final String accountId;
  final String institution;

  /// Logo do banco (domínio no logo.dev), quando o usuário escolheu um.
  final String? institutionLogo;

  /// Conta ou cartão de origem ([BankAccount.label]).
  final String accountLabel;

  /// Sempre positivo; o sentido está em [type].
  final double amount;
  final TransactionType type;
  final String description;
  final DateTime date;
  final PaymentMethod? paymentMethod;

  /// Autorizada mas ainda não liquidada — típico de compra no cartão antes de
  /// a fatura fechar. A Pluggy pode trocar o id quando ela é liquidada, por
  /// isso a deduplicação também usa [fingerprint].
  final bool pending;

  /// Parcela atual / total, quando a compra no cartão é parcelada.
  final int? installmentNumber;
  final int? totalInstallments;

  const BankTransaction({
    required this.id,
    required this.accountId,
    required this.institution,
    this.institutionLogo,
    this.accountLabel = '',
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
    this.paymentMethod,
    this.pending = false,
    this.installmentNumber,
    this.totalInstallments,
  });

  bool get isInstallment => (totalInstallments ?? 0) > 1;

  /// Chave de deduplicação secundária, para quando a mesma movimentação volta
  /// com outro id (pendente → liquidada).
  String get fingerprint {
    final day =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '$accountId|${type.name}|${amount.toStringAsFixed(2)}|$day';
  }

  /// Traduz um item de `GET /v2/transactions`. Devolve `null` para o que não
  /// deve virar lançamento (ver [_ignored]).
  static BankTransaction? fromPluggy(
    Map<String, dynamic> json, {
    required BankAccount account,
    required String institution,
    String? institutionLogo,
  }) {
    if (_ignored(json, account)) return null;

    final type =
        json['type'] == 'CREDIT' ? TransactionType.income : TransactionType.expense;
    // Compra em moeda estrangeira: o que pesa no bolso é o valor convertido.
    final rawAmount =
        (json['amountInAccountCurrency'] ?? json['amount']) as num;
    final card = json['creditCardMetadata'] as Map<String, dynamic>?;

    return BankTransaction(
      id: json['id'] as String,
      accountId: account.id,
      institution: institution,
      institutionLogo: institutionLogo,
      accountLabel: account.label,
      amount: rawAmount.abs().toDouble(),
      type: type,
      description: _description(json, type),
      date: _day(json['date'] as String),
      paymentMethod: _paymentMethod(json, account),
      pending: json['status'] == 'PENDING',
      installmentNumber: (card?['installmentNumber'] as num?)?.toInt(),
      totalInstallments: (card?['totalInstallments'] as num?)?.toInt(),
    );
  }

  /// A Pluggy manda a data como meia-noite UTC (`2026-10-15T00:00:00.000Z`).
  /// Converter para o fuso local jogaria para a noite do dia anterior no
  /// Brasil, então vale o dia como veio.
  static DateTime _day(String iso) {
    final utc = DateTime.parse(iso).toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// O pagamento da fatura aparece duas vezes: como saída na conta corrente
  /// (dinheiro que de fato saiu) e como entrada no cartão. A entrada no cartão
  /// é só contabilidade interna — lançá-la viraria um rendimento fantasma.
  static bool _ignored(Map<String, dynamic> json, BankAccount account) {
    return account.isCreditCard &&
        json['type'] == 'CREDIT' &&
        json['operationType'] == 'PAGAMENTO_FATURA';
  }

  /// Nome legível da contraparte: o estabelecimento no gasto, quem pagou no
  /// rendimento. Cai para a descrição limpa da Pluggy quando não há.
  static String _description(Map<String, dynamic> json, TransactionType type) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    final payment = json['paymentData'] as Map<String, dynamic>?;
    final side = type == TransactionType.income ? 'payer' : 'receiver';
    final counterpart = payment?[side] as Map<String, dynamic>?;

    // "merchant" descreve onde a compra foi feita; no rendimento quem importa
    // é quem pagou.
    final merchantName = merchant == null || type == TransactionType.income
        ? null
        : merchant['name'];
    for (final candidate in [
      merchantName,
      counterpart?['name'],
      json['description'],
    ]) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return '';
  }

  static PaymentMethod? _paymentMethod(
    Map<String, dynamic> json,
    BankAccount account,
  ) {
    if (account.isCreditCard) return PaymentMethod.creditCard;

    final payment = json['paymentData'] as Map<String, dynamic>?;
    final rail = payment?['paymentMethod'] ?? json['operationType'];
    return switch (rail) {
      'PIX' => PaymentMethod.pix,
      'BOLETO' => PaymentMethod.bankSlip,
      'TED' || 'DOC' || 'TEV' => PaymentMethod.bankTransfer,
      _ => null,
    };
  }
}
