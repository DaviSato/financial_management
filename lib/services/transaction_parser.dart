import '../models/captured_notification.dart';
import '../models/parsed_transaction.dart';
import '../models/payment_method.dart';
import '../utils/currency_formatter.dart';

/// Uma palavra-chave que identifica o tipo de transação, independente do app
/// que enviou a notificação.
///
/// A allowlist de apps já decide o que é capturado; aqui decidimos apenas o que
/// a transação *é*. Isso funciona em qualquer banco porque "débito", "pix" e
/// "R$" são praticamente universais no Brasil — muito mais estáveis que o texto
/// completo de cada instituição.
class KeywordRule {
  final String label;

  /// Todas precisam aparecer (já normalizadas: minúsculas, sem acento).
  final List<String> must;

  /// Ao menos uma precisa aparecer. Vazio = sem essa exigência.
  final List<String> any;

  /// Nenhuma pode aparecer.
  final List<String> none;

  final TransactionType type;
  final PaymentMethod? paymentMethod;

  /// Contraparte: prefixos tentados, em ordem, para extrair estabelecimento ou
  /// nome ("em PADARIA", "para Fulano", "de Fulano").
  final List<String> counterpartyPrefixes;

  /// Confirmada contra texto real do banco. As demais são palpites que a UI
  /// marca como provisórios — corrigidos quando o formato real aparecer.
  final bool confirmed;

  const KeywordRule({
    required this.label,
    required this.type,
    this.must = const [],
    this.any = const [],
    this.none = const [],
    this.paymentMethod,
    this.counterpartyPrefixes = const ['em'],
    this.confirmed = false,
  });

  bool matches(String normalized) {
    bool has(String kw) => normalized.contains(kw);
    if (!must.every(has)) return false;
    if (any.isNotEmpty && !any.any(has)) return false;
    if (none.any(has)) return false;
    return true;
  }
}

class TransactionParser {
  /// Palavras que indicam que a notificação NÃO é uma transação a lançar:
  /// compra negada, estorno, cobrança futura. Reconhecida, mas ignorada.
  static const _rejectKeywords = [
    'negada',
    'nao aprovada',
    'recusada',
    'nao autorizada',
    'estorno',
    'estornad',
    'cancelad',
    'falha',
  ];

  /// Regras em ordem de prioridade — a primeira que casar vence. As mais
  /// específicas (pix com direção) vêm antes das genéricas.
  ///
  /// Só o débito está confirmado; veio de uma captura real:
  ///   "Compra no débito aprovada · Compra de R$ 32,22 em BistroRestaurante"
  /// O resto são palpites com base em formatos comuns, a confirmar no aparelho.
  static const List<KeywordRule> defaultRules = [
    KeywordRule(
      label: 'Pix recebido',
      must: ['pix'],
      any: ['recebido', 'recebeu', 'recebimento'],
      type: TransactionType.income,
      paymentMethod: PaymentMethod.pix,
      counterpartyPrefixes: ['de'],
    ),
    KeywordRule(
      label: 'Pix enviado',
      must: ['pix'],
      any: ['enviado', 'enviou', 'pagamento', 'pago'],
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.pix,
      counterpartyPrefixes: ['para', 'pra'],
    ),
    KeywordRule(
      // Pix sem direção explícita: assume saída, o caso mais comum.
      label: 'Pix',
      must: ['pix'],
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.pix,
      counterpartyPrefixes: ['para', 'pra', 'de'],
    ),
    KeywordRule(
      label: 'Débito',
      any: ['debito'],
      none: ['pix'],
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.debitCard,
      counterpartyPrefixes: ['em'],
      confirmed: true,
    ),
    KeywordRule(
      label: 'Crédito',
      any: ['credito'],
      none: ['pix'],
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.creditCard,
      counterpartyPrefixes: ['em'],
    ),
    KeywordRule(
      label: 'Recebimento',
      any: ['recebimento', 'deposito', 'ted recebida', 'salario'],
      type: TransactionType.income,
      counterpartyPrefixes: ['de'],
    ),
  ];

  final List<KeywordRule> rules;
  const TransactionParser({this.rules = defaultRules});

  static final _amountPattern = RegExp(r'R\$\s*([\d.]+,\d{2})');

  /// Interpreta uma notificação capturada. Retorna null quando não reconhece um
  /// lançamento — texto desconhecido ou explicitamente rejeitado (compra negada
  /// etc.). O usuário sempre confirma antes de virar Expense/Income.
  ParsedTransaction? parse(CapturedNotification notification) {
    final raw = notification.fullText;
    final normalized = _normalize(raw);

    if (_rejectKeywords.any(normalized.contains)) return null;

    final amount = _extractAmount(raw);
    if (amount == null) return null; // palavra de tipo sem valor não é lançamento

    for (final rule in rules) {
      if (!rule.matches(normalized)) continue;
      return ParsedTransaction(
        amount: amount,
        type: rule.type,
        description: _extractCounterparty(raw, rule.counterpartyPrefixes),
        paymentMethod: rule.paymentMethod,
        postedAt: notification.postedAt,
        sourcePackage: notification.packageName,
        rawText: raw,
        ruleLabel: rule.label,
        provisional: !rule.confirmed,
      );
    }
    return null;
  }

  double? _extractAmount(String raw) {
    final match = _amountPattern.firstMatch(raw);
    if (match == null) return null;
    return CurrencyFormatter.parse(match.group(1)!);
  }

  /// Tenta cada prefixo em ordem e devolve o texto após ele, até o fim.
  /// Descarta capturas que começam com valor ("de R$ 32,22"), que seriam falso
  /// positivo do prefixo "de".
  String _extractCounterparty(String raw, List<String> prefixes) {
    for (final prefix in prefixes) {
      final pattern = RegExp(
        '\\b$prefix\\s+(.+?)\\s*\$',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(raw);
      final captured = match?.group(1)?.trim();
      if (captured == null || captured.isEmpty) continue;
      final lower = captured.toLowerCase();
      if (lower.startsWith('r\$') || RegExp(r'^\d').hasMatch(lower)) continue;
      return captured;
    }
    return '';
  }

  static String _normalize(String s) {
    s = s.toLowerCase();
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final buffer = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      buffer.write(i == -1 ? ch : to[i]);
    }
    return buffer.toString();
  }
}
