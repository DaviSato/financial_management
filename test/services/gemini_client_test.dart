import 'dart:convert';

import 'package:financial_management/models/ai_suggestion.dart';
import 'package:financial_management/models/bank_transaction.dart';
import 'package:financial_management/models/payment_method.dart';
import 'package:financial_management/services/gemini_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final now = DateTime(2026, 10, 15, 12);

BankTransaction tx(String id, {int? parcela, int? total}) => BankTransaction(
      id: id,
      accountId: 'acc-1',
      institution: 'Nubank',
      accountLabel: 'Cartão ••1234',
      amount: 23.5,
      type: TransactionType.expense,
      description: 'UBER *TRIP',
      date: DateTime(2026, 10, 12),
      paymentMethod: PaymentMethod.creditCard,
      installmentNumber: parcela,
      totalInstallments: total,
    );

Map<String, dynamic> geminiResponse(Object items) => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(items)},
            ],
          },
        },
      ],
    };

void main() {
  test('prompt leva categorias, cadastrados e movimentações em linhas', () {
    final prompt = GeminiClient.buildPrompt(
      transactions: [tx('t-1', parcela: 2, total: 3)],
      categories: ['Transporte', 'Lazer'],
      expenses: [
        AiKnownEntry(
          id: 'e-1',
          title: 'Netflix',
          amount: 55.9,
          date: DateTime(2026, 10, 10),
        ),
      ],
      incomes: const [],
    );

    expect(prompt, contains('Categorias: Transporte, Lazer'));
    expect(prompt, contains('e-1|Netflix|55.90|2026-10-10|em aberto'));
    expect(prompt, contains('(nenhum)'));
    expect(
      prompt,
      contains(
        't-1|2026-10-12|saída|23.50|UBER *TRIP|Cartão de Crédito|2/3|'
        'Nubank Cartão ••1234',
      ),
    );
  });

  test('descarta id desconhecido, ação inválida e repetido', () {
    final result = GeminiClient.parseSuggestions(
      geminiResponse([
        {
          'id': 't-1',
          'action': 'expense',
          'category': 'Transporte',
          'title': 'Uber',
          'confidence': 1.4,
        },
        {'id': 't-1', 'action': 'ignore', 'confidence': 0.9},
        {'id': 'x', 'action': 'expense', 'confidence': 0.9},
        {'id': 't-2', 'action': 'voar', 'confidence': 0.9},
        {'id': 't-3', 'action': 'payExpense', 'matchId': 'e-1', 'confidence': 0.7, 'title': ' '},
      ]),
      sentIds: {'t-1', 't-2', 't-3'},
      now: now,
    );

    expect(result.map((s) => s.transactionId), ['t-1', 't-3']);
    expect(result.first.action, AiAction.expense);
    expect(result.first.confidence, 1.0);
    expect(result.first.title, 'Uber');
    expect(result.last.matchId, 'e-1');
    expect(result.last.title, isNull);
  });

  test('classify manda a chave no header e lê a resposta', () async {
    late http.Request sent;
    final client = GeminiClient(
      apiKey: 'chave',
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode(geminiResponse([
            {'id': 't-1', 'action': 'expense', 'category': 'Transporte', 'confidence': 0.95},
          ])),
          200,
        );
      }),
    );

    final result = await client.classify(
      transactions: [tx('t-1')],
      categories: ['Transporte'],
      expenses: const [],
      incomes: const [],
      now: now,
    );

    expect(sent.headers['x-goog-api-key'], 'chave');
    expect(sent.url.path, endsWith('gemini-3.5-flash:generateContent'));
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['generationConfig']['responseMimeType'], 'application/json');
    expect(result.single.category, 'Transporte');
  });

  test('429 vira erro de cota', () async {
    final client = GeminiClient(
      apiKey: 'chave',
      httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'error': {'code': 429, 'message': 'Resource exhausted'},
            }),
            429,
          )),
    );

    await expectLater(
      client.classify(
        transactions: [tx('t-1')],
        categories: const [],
        expenses: const [],
        incomes: const [],
        now: now,
      ),
      throwsA(isA<GeminiException>()
          .having((e) => e.isQuota, 'isQuota', true)
          .having((e) => e.message, 'message', 'Resource exhausted')),
    );
  });
}
