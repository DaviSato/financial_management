import 'dart:convert';

import 'package:financial_management/models/bank_history_entry.dart';
import 'package:financial_management/models/category.dart';
import 'package:financial_management/models/expense.dart';
import 'package:financial_management/models/recurrence.dart';
import 'package:financial_management/providers/category_state.dart';
import 'package:financial_management/providers/expense_state.dart';
import 'package:financial_management/providers/income_state.dart';
import 'package:financial_management/services/bank_auto_launcher.dart';
import 'package:financial_management/services/bank_history_store.dart';
import 'package:financial_management/services/bank_sync_service.dart';
import 'package:financial_management/services/gemini_client.dart';
import 'package:financial_management/services/gemini_config.dart';
import 'package:financial_management/services/pluggy_client.dart';
import 'package:financial_management/services/pluggy_config.dart';
import 'package:financial_management/services/storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryHistoryStore implements BankHistoryStore {
  final Map<String, BankHistoryEntry> entries = {};

  @override
  Future<Map<String, BankHistoryEntry>> load() async => Map.of(entries);

  @override
  Future<void> save(Iterable<BankHistoryEntry> list) async {
    for (final e in list) {
      entries[e.transactionId] = e;
    }
  }

  @override
  Future<void> remove(Iterable<String> ids) async {
    ids.forEach(entries.remove);
  }
}

Map<String, dynamic> tx(String id, String description, num amount) => {
      'id': id,
      'type': amount < 0 ? 'DEBIT' : 'CREDIT',
      'amount': amount,
      'date': '2026-10-12T00:00:00.000Z',
      'description': description,
      'status': 'POSTED',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 15, 12);
  late List<Map<String, dynamic>> transactions;
  late List<Map<String, dynamic>> aiAnswer;
  late List<String> prompts;
  late int geminiStatus;
  late ExpenseState expenses;
  late IncomeState incomes;
  late MemoryHistoryStore history;
  late Expense netflix;

  setUp(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    netflix = Expense(
      title: 'Netflix',
      amount: 55.9,
      category: 'Lazer',
      recurrenceType: RecurrenceType.monthly,
      dueDate: DateTime(2026, 9, 10),
    );
    SharedPreferences.setMockInitialValues({
      'pluggy_client_id': 'id',
      'pluggy_connections': jsonEncode([
        {
          'itemId': 'item-1',
          'institution': 'Nubank',
          'connectedAt': '2026-10-01T00:00:00.000',
        },
      ]),
    });
    FlutterSecureStorage.setMockInitialValues({
      'pluggy_client_secret': 'secret',
      'gemini_api_key': 'chave',
    });
    await PluggyConfig().load();
    await GeminiConfig().load();

    final storage = StorageService();
    await storage.init();
    await storage.saveAllExpenses([netflix]);
    await storage.saveAllCategories([
      Category(id: 'c-1', name: 'Transporte'),
      Category(id: 'c-2', name: 'Lazer'),
    ]);
    expenses = ExpenseState();
    await expenses.load();
    incomes = IncomeState();
    await incomes.load();
    final categories = CategoryState(expenses);
    await categories.load();

    transactions = [];
    aiAnswer = [];
    prompts = [];
    geminiStatus = 200;
    history = MemoryHistoryStore();

    BankSyncService.overrideForTesting(
      history: history,
      now: () => now,
      clientFactory: (id, secret) => PluggyClient(
        clientId: id,
        clientSecret: secret,
        now: () => now,
        httpClient: MockClient((request) async {
          final body = switch (request.url.path) {
            '/auth' => {'apiKey': 'key'},
            '/items/item-1' => {'id': 'item-1', 'status': 'UPDATED'},
            '/accounts' => {
                'totalPages': 1,
                'results': [
                  {'id': 'acc-1', 'name': 'Conta', 'type': 'BANK'},
                ],
              },
            '/v2/transactions' => {'results': transactions, 'next': null},
            _ => throw StateError('rota inesperada ${request.url}'),
          };
          return http.Response(jsonEncode(body), 200);
        }),
      ),
    );
    BankSyncService().autoLauncher = BankAutoLauncher(
      expenses: expenses,
      incomes: incomes,
      categories: categories,
      now: () => now,
      clientFactory: (key) => GeminiClient(
        apiKey: key,
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          prompts.add(body['contents'][0]['parts'][0]['text'] as String);
          if (geminiStatus != 200) {
            return http.Response('{"error":{"message":"cota"}}', geminiStatus);
          }
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': jsonEncode(aiAnswer)},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      ),
    );
  });

  test('aplica o que tem confiança alta e deixa o resto pendente', () async {
    transactions = [
      tx('uber', 'UBER *TRIP', -23.5),
      tx('netflix', 'NETFLIX.COM', -55.9),
      tx('pix', 'PIX JOAO', -300),
      tx('transf', 'TRANSF MESMA TITULARIDADE', -1000),
    ];
    aiAnswer = [
      {
        'id': 'uber',
        'action': 'expense',
        'category': 'transporte',
        'title': 'Uber',
        'confidence': 0.95,
      },
      {
        'id': 'netflix',
        'action': 'payExpense',
        'matchId': netflix.id,
        'confidence': 0.97,
      },
      {'id': 'pix', 'action': 'expense', 'confidence': 0.4},
      {'id': 'transf', 'action': 'ignore', 'confidence': 0.9},
    ];

    await BankSyncService().sync();

    expect(BankSyncService().pending.map((t) => t.id), ['pix']);
    expect(BankSyncService().autoError, isNull);

    final uber = expenses.expenses.singleWhere((e) => e.title == 'Uber');
    expect(uber.category, 'Transporte');
    expect(uber.amount, 23.5);
    expect(uber.isPaidForMonth(DateTime(2026, 10)), true);

    final paid = expenses.expenses.singleWhere((e) => e.id == netflix.id);
    expect(paid.paidByMonth['2026-10'], DateTime(2026, 10, 12));

    expect(history.entries['uber']!.outcome, BankOutcome.launched);
    expect(history.entries['uber']!.launchedId, uber.id);
    expect(history.entries['netflix']!.outcome, BankOutcome.matched);
    expect(history.entries['transf']!.outcome, BankOutcome.discarded);
    expect(history.entries.values.every((e) => e.auto), true);

    // O recorrente vai no contexto para a IA poder reconhecer o pagamento.
    expect(prompts.single, contains('${netflix.id}|Netflix|55.90'));
    expect(
      BankSyncService().autoLauncher!.suggestionFor('pix')!.confidence,
      0.4,
    );
  });

  test('cada movimentação vai para a IA uma vez só', () async {
    transactions = [tx('pix', 'PIX JOAO', -300)];
    aiAnswer = [
      {'id': 'pix', 'action': 'expense', 'confidence': 0.4},
    ];

    await BankSyncService().sync();
    await BankSyncService().sync(force: true);

    expect(prompts, hasLength(1));
    expect(BankSyncService().pending, hasLength(1));
  });

  test('categoria inexistente não lança, mesmo com confiança alta', () async {
    transactions = [tx('uber', 'UBER', -23.5)];
    aiAnswer = [
      {'id': 'uber', 'action': 'expense', 'category': 'Viagem', 'confidence': 0.99},
    ];

    await BankSyncService().sync();

    expect(BankSyncService().pending.map((t) => t.id), ['uber']);
    expect(expenses.expenses, hasLength(1));
  });

  test('cota esgotada vira aviso e tenta de novo depois', () async {
    transactions = [tx('uber', 'UBER', -23.5)];
    geminiStatus = 429;

    await BankSyncService().sync();
    expect(BankSyncService().autoError, contains('Limite gratuito'));
    expect(BankSyncService().pending, hasLength(1));

    geminiStatus = 200;
    aiAnswer = [
      {'id': 'uber', 'action': 'expense', 'category': 'Transporte', 'confidence': 0.9},
    ];
    await BankSyncService().sync(force: true);

    expect(BankSyncService().pending, isEmpty);
    expect(BankSyncService().autoError, isNull);
  });

  test('desfazer o vínculo tira o pago e não reenvia para a IA', () async {
    transactions = [tx('netflix', 'NETFLIX.COM', -55.9)];
    aiAnswer = [
      {'id': 'netflix', 'action': 'payExpense', 'matchId': netflix.id, 'confidence': 0.97},
    ];
    await BankSyncService().sync();

    final entry = BankSyncService().history.single;
    await BankSyncService().autoLauncher!.unmatch(entry);
    await BankSyncService().restore(entry);
    await BankSyncService().sync(force: true);

    final back = expenses.expenses.singleWhere((e) => e.id == netflix.id);
    expect(back.isPaidForMonth(DateTime(2026, 10)), false);
    expect(BankSyncService().pending.map((t) => t.id), ['netflix']);
    expect(prompts, hasLength(1));
  });

  test('desligado, nada vai para a IA', () async {
    await GeminiConfig().setAutoLaunch(false);
    transactions = [tx('uber', 'UBER', -23.5)];

    await BankSyncService().sync();

    expect(prompts, isEmpty);
    expect(BankSyncService().pending, hasLength(1));
    await GeminiConfig().setAutoLaunch(true);
  });
}
