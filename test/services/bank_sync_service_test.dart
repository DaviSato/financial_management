import 'dart:convert';

import 'package:financial_management/models/bank_history_entry.dart';
import 'package:financial_management/services/bank_history_store.dart';
import 'package:financial_management/services/bank_sync_service.dart';
import 'package:financial_management/services/pluggy_client.dart';
import 'package:financial_management/services/pluggy_config.dart';
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

Map<String, dynamic> tx(
  String id,
  String date, {
  num amount = -10,
  String status = 'POSTED',
}) =>
    {
      'id': id,
      'type': 'DEBIT',
      'amount': amount,
      'date': '${date}T00:00:00.000Z',
      'description': 'COMPRA $id',
      'status': status,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryHistoryStore handled;
  late List<Map<String, dynamic>> transactions;
  late int transactionCalls;
  late DateTime now;

  Future<void> configure({List<Map<String, dynamic>>? connections}) async {
    SharedPreferences.setMockInitialValues({
      'pluggy_client_id': 'id',
      'pluggy_connections': jsonEncode(connections ??
          [
            {
              'itemId': 'item-1',
              'institution': 'Nubank',
              'connectedAt': '2026-10-10T15:30:00.000',
            },
          ]),
    });
    FlutterSecureStorage.setMockInitialValues({
      'pluggy_client_secret': 'secret',
    });
    await PluggyConfig().load();
  }

  setUp(() async {
    dotenv.loadFromString(envString: '', isOptional: true);
    handled = MemoryHistoryStore();
    transactions = [];
    transactionCalls = 0;
    now = DateTime(2026, 10, 15, 12);
    await configure();

    BankSyncService.overrideForTesting(
      history: handled,
      now: () => now,
      clientFactory: (id, secret) => PluggyClient(
        clientId: id,
        clientSecret: secret,
        now: () => now,
        httpClient: MockClient((request) async {
          final body = switch (request.url.path) {
            '/auth' => {'apiKey': 'key'},
            '/items/item-1' => {
                'id': 'item-1',
                'status': 'UPDATED',
                'lastUpdatedAt': '2026-10-15T09:12:00.000Z',
                'nextAutoSyncAt': '2026-10-16T09:12:00.000Z',
              },
            '/accounts' => {
                'page': 1,
                'totalPages': 1,
                'results': [
                  {'id': 'acc-1', 'name': 'Conta', 'type': 'BANK'},
                ],
              },
            '/v2/transactions' => () {
                transactionCalls++;
                return {'results': transactions, 'next': null};
              }(),
            _ => throw StateError('rota inesperada ${request.url}'),
          };
          return http.Response(jsonEncode(body), 200);
        }),
      ),
    );
  });

  test('sÃ³ entra o que Ã© do dia da conexÃ£o em diante, mais recente primeiro',
      () async {
    transactions = [
      tx('antes', '2026-10-09'),
      tx('mesmo-dia', '2026-10-10'),
      tx('depois', '2026-10-14'),
    ];

    await BankSyncService().sync();

    expect(BankSyncService().pending.map((t) => t.id), ['depois', 'mesmo-dia']);
    expect(BankSyncService().lastError, isNull);
  });

  test('guarda a ultima atualizacao de cada item', () async {
    await BankSyncService().sync();

    final item = BankSyncService().items['item-1']!;
    expect(item.status, 'UPDATED');
    expect(item.lastUpdatedAt, DateTime.utc(2026, 10, 15, 9, 12).toLocal());
    expect(item.nextAutoSyncAt, DateTime.utc(2026, 10, 16, 9, 12).toLocal());
    expect(item.hasProblem, false);
  });

  test('o que foi tratado nÃ£o volta', () async {
    transactions = [tx('a', '2026-10-12'), tx('b', '2026-10-13')];
    await BankSyncService().sync();

    await BankSyncService().discard([BankSyncService().pending.first]);
    expect(BankSyncService().pending.map((t) => t.id), ['a']);

    await BankSyncService().sync(force: true);
    expect(BankSyncService().pending.map((t) => t.id), ['a']);
  });

  test('pendente tratado nÃ£o volta quando liquida com outro id', () async {
    transactions = [tx('pend', '2026-10-12', status: 'PENDING')];
    await BankSyncService().sync();
    await BankSyncService().discard(BankSyncService().pending);

    transactions = [tx('liquidada', '2026-10-12')];
    await BankSyncService().sync(force: true);

    expect(BankSyncService().pending, isEmpty);
  });

  test('duas compras iguais liquidadas nÃ£o se escondem', () async {
    transactions = [tx('x', '2026-10-12'), tx('y', '2026-10-12')];
    await BankSyncService().sync();
    await BankSyncService().discard([BankSyncService().pending.first]);

    await BankSyncService().sync(force: true);

    expect(BankSyncService().pending, hasLength(1));
  });

  test('nÃ£o sincroniza de novo antes do intervalo mÃ­nimo', () async {
    await BankSyncService().sync();
    now = now.add(const Duration(minutes: 5));
    await BankSyncService().sync();
    expect(transactionCalls, 1);

    now = now.add(BankSyncService.minInterval);
    await BankSyncService().sync();
    expect(transactionCalls, 2);
  });

  test('sem banco conectado nÃ£o chama a API', () async {
    await configure(connections: []);
    await BankSyncService().sync();

    expect(BankSyncService().isConfigured, false);
    expect(transactionCalls, 0);
  });

  group('histórico', () {
    test('lançada guarda o retrato e o id do lançamento', () async {
      transactions = [tx('a', '2026-10-12'), tx('b', '2026-10-13')];
      await BankSyncService().sync();

      final b = BankSyncService().pending.first;
      await BankSyncService().launch(b, launchedId: 'expense-1');
      await BankSyncService().discard(BankSyncService().pending);

      final history = BankSyncService().history;
      expect(history.map((e) => e.transactionId), ['b', 'a']);
      expect(history.first.outcome, BankOutcome.launched);
      expect(history.first.launchedId, 'expense-1');
      expect(history.first.handledAt, now);
      expect(history.last.outcome, BankOutcome.discarded);
      expect(handled.entries['b']!.transaction!.description, 'COMPRA b');
    });

    test('restaurar devolve às pendentes e some do histórico', () async {
      transactions = [tx('a', '2026-10-12')];
      await BankSyncService().sync();
      await BankSyncService().discard(BankSyncService().pending);

      await BankSyncService().restore(BankSyncService().history.single);

      expect(BankSyncService().pending.map((t) => t.id), ['a']);
      expect(BankSyncService().history, isEmpty);
      expect(handled.entries, isEmpty);

      await BankSyncService().sync(force: true);
      expect(BankSyncService().pending.map((t) => t.id), ['a']);
    });

    test('registro antigo ganha o retrato quando a Pluggy devolve', () async {
      handled.entries['a'] = const BankHistoryEntry(
        transactionId: 'a',
        outcome: BankOutcome.handled,
      );
      transactions = [tx('a', '2026-10-12')];

      await BankSyncService().sync();

      expect(BankSyncService().pending, isEmpty);
      final entry = BankSyncService().history.single;
      expect(entry.outcome, BankOutcome.handled);
      expect(entry.transaction!.amount, 10);
      expect(handled.entries['a']!.transaction, isNotNull);
    });

    test('histórico carrega sem banco configurado', () async {
      transactions = [tx('a', '2026-10-12')];
      await BankSyncService().sync();
      await BankSyncService().discard(BankSyncService().pending);

      await configure(connections: []);
      await BankSyncService().sync(force: true);

      expect(BankSyncService().history.map((e) => e.transactionId), ['a']);
    });
  });
}
