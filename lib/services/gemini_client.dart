import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_suggestion.dart';
import '../models/bank_transaction.dart';
import 'gemini_config.dart';

/// Falha numa chamada ao Gemini. [statusCode] é null quando nem houve
/// resposta (sem rede, timeout) ou quando a resposta veio num formato
/// inesperado.
class GeminiException implements Exception {
  final int? statusCode;
  final String message;

  const GeminiException(this.message, {this.statusCode});

  /// Cota gratuita esgotada (por minuto ou por dia).
  bool get isQuota => statusCode == 429;
  bool get isUnauthorized =>
      statusCode == 400 && message.contains('API key') ||
      statusCode == 401 ||
      statusCode == 403;

  @override
  String toString() => 'GeminiException($statusCode): $message';
}

/// Algo já cadastrado no app que uma movimentação pode estar pagando
/// (gasto) ou recebendo (rendimento): ocorrência num mês específico.
class AiKnownEntry {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final bool paid;

  const AiKnownEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.paid = false,
  });
}

/// Cliente mínimo da API do Gemini para classificar movimentações do banco.
///
/// Uma chamada por lote, com resposta em JSON estruturado e raciocínio no
/// nível baixo — a tarefa é simples e o raciocínio é o que mais gasta token.
/// Vai só o necessário: as movimentações novas, os nomes das categorias e o
/// que já está cadastrado para o período (para não lançar de novo um
/// recorrente).
class GeminiClient {
  GeminiClient({
    required this.apiKey,
    this.model = GeminiConfig.model,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  static const _timeout = Duration(seconds: 60);

  static const _instructions = '''
Você classifica movimentações bancárias de uma pessoa no Brasil para o app de finanças dela.
Para CADA movimentação, devolva exatamente um item com o mesmo id e uma ação:
- "expense": gasto novo. "category" deve ser EXATAMENTE um dos nomes da lista de categorias.
- "income": rendimento novo (salário, venda, reembolso de terceiros...).
- "payExpense": é o pagamento de um gasto já cadastrado (lista "Gastos cadastrados"). Use quando nome e valor batem (valor até ~5% diferente; data próxima do vencimento). "matchId" = id do gasto. Só para gastos não pagos.
- "matchIncome": é o recebimento de um rendimento já cadastrado (lista "Rendimentos cadastrados"). "matchId" = id.
- "ignore": não é gasto nem rendimento: transferência entre contas da própria pessoa, aplicação/resgate de investimento, estorno que anula outra movimentação da lista.
Regras:
- Parcela 2 ou maior de compra parcelada: só "payExpense" se houver o parcelamento cadastrado; senão "expense" com confiança no máximo 0.5.
- Pagamento de fatura de cartão de crédito: "ignore" com confiança no máximo 0.6.
- Pix/transferência para pessoa física sem contexto: confiança no máximo 0.6.
- Se nenhuma categoria serve bem, confiança no máximo 0.6.
- "title": nome curto e limpo do estabelecimento ou pessoa (ex.: "Uber", "iFood", "Mercado Extra"), sem códigos.
- "confidence": 0 a 1, o quanto tem certeza da ação E da categoria/matchId.
- "reason": até 60 caracteres, em português, explicando a decisão.''';

  static const _schema = {
    'type': 'ARRAY',
    'items': {
      'type': 'OBJECT',
      'properties': {
        'id': {'type': 'STRING'},
        'action': {
          'type': 'STRING',
          'enum': ['expense', 'income', 'payExpense', 'matchIncome', 'ignore'],
        },
        'category': {'type': 'STRING'},
        'title': {'type': 'STRING'},
        'matchId': {'type': 'STRING'},
        'confidence': {'type': 'NUMBER'},
        'reason': {'type': 'STRING'},
      },
      'required': ['id', 'action', 'confidence'],
    },
  };

  /// Classifica [transactions]. Ids que a IA não devolver (ou devolver
  /// inválidos) simplesmente não aparecem no resultado.
  Future<List<AiSuggestion>> classify({
    required List<BankTransaction> transactions,
    required List<String> categories,
    required List<AiKnownEntry> expenses,
    required List<AiKnownEntry> incomes,
    required DateTime now,
  }) async {
    if (transactions.isEmpty) return const [];

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': _instructions},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': buildPrompt(
                transactions: transactions,
                categories: categories,
                expenses: expenses,
                incomes: incomes,
              ),
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _schema,
        'temperature': 0,
        'thinkingConfig': {'thinkingLevel': 'low'},
      },
    };

    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/'
              '$model:generateContent',
            ),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw GeminiException('Falha de conexão com o Gemini: $e');
    }

    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map ? decoded['error'] : null;
      throw GeminiException(
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return parseSuggestions(
      decoded,
      sentIds: {for (final t in transactions) t.id},
      now: now,
    );
  }

  static Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// Texto enviado à IA, uma linha por item com campos separados por `|`
  /// (bem mais curto que JSON).
  static String buildPrompt({
    required List<BankTransaction> transactions,
    required List<String> categories,
    required List<AiKnownEntry> expenses,
    required List<AiKnownEntry> incomes,
  }) {
    final b = StringBuffer()
      ..writeln('Categorias: ${categories.join(', ')}')
      ..writeln()
      ..writeln('Gastos cadastrados (id|nome|valor|vencimento|situação):');
    if (expenses.isEmpty) b.writeln('(nenhum)');
    for (final e in expenses) {
      b.writeln(
        '${e.id}|${e.title}|${_money(e.amount)}|${_date(e.date)}|'
        '${e.paid ? 'pago' : 'em aberto'}',
      );
    }
    b
      ..writeln()
      ..writeln('Rendimentos cadastrados (id|nome|valor|data):');
    if (incomes.isEmpty) b.writeln('(nenhum)');
    for (final i in incomes) {
      b.writeln('${i.id}|${i.title}|${_money(i.amount)}|${_date(i.date)}');
    }
    b
      ..writeln()
      ..writeln(
        'Movimentações (id|data|tipo|valor|descrição|forma|parcela|conta):',
      );
    for (final t in transactions) {
      b.writeln([
        t.id,
        _date(t.date),
        t.type == TransactionType.income ? 'entrada' : 'saída',
        _money(t.amount),
        t.description,
        t.paymentMethod?.label ?? '',
        t.isInstallment ? '${t.installmentNumber}/${t.totalInstallments}' : '',
        [t.institution, t.accountLabel].where((p) => p.isNotEmpty).join(' '),
      ].join('|'));
    }
    return b.toString();
  }

  /// Lê a resposta do `generateContent`. Itens com id desconhecido, ação
  /// inválida ou repetidos são descartados.
  static List<AiSuggestion> parseSuggestions(
    Object? response, {
    required Set<String> sentIds,
    required DateTime now,
  }) {
    final text = _text(response);
    if (text == null) {
      throw const GeminiException('Resposta do Gemini sem conteúdo');
    }
    final Object? items;
    try {
      items = jsonDecode(text);
    } catch (_) {
      throw const GeminiException('Resposta do Gemini não é JSON');
    }
    if (items is! List) {
      throw const GeminiException('Resposta do Gemini fora do formato');
    }

    final result = <String, AiSuggestion>{};
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['id'];
      final action = AiAction.fromName(item['action']);
      if (id is! String || !sentIds.contains(id) || action == null) continue;
      if (result.containsKey(id)) continue;
      result[id] = AiSuggestion(
        transactionId: id,
        action: action,
        confidence: ((item['confidence'] as num?)?.toDouble() ?? 0)
            .clamp(0.0, 1.0),
        createdAt: now,
        category: _str(item['category']),
        title: _str(item['title']),
        matchId: _str(item['matchId']),
        reason: _str(item['reason']),
      );
    }
    return result.values.toList();
  }

  static String? _text(Object? response) {
    if (response is! Map) return null;
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final content = (candidates.first as Map?)?['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return null;
    final text = parts
        .whereType<Map>()
        .map((p) => p['text'])
        .whereType<String>()
        .join();
    return text.isEmpty ? null : text;
  }

  static String? _str(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  static String _money(double v) => v.toStringAsFixed(2);

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void close() => _http.close();
}
