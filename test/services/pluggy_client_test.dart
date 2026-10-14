import 'dart:convert';

import 'package:financial_management/services/pluggy_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late List<http.Request> requests;
  late DateTime now;

  PluggyClient client(Future<http.Response> Function(http.Request) handler) {
    return PluggyClient(
      clientId: 'id',
      clientSecret: 'secret',
      httpClient: MockClient((request) {
        requests.add(request);
        if (request.url.path == '/auth') {
          return Future.value(json({'apiKey': 'key-${requests.length}'}));
        }
        return handler(request);
      }),
      now: () => now,
    );
  }

  setUp(() {
    requests = [];
    now = DateTime(2026, 10, 15, 10);
  });

  test('autentica uma vez e reaproveita a key', () async {
    final c = client((_) async => json({
          'id': 'item-1',
          'connector': {'name': 'Nubank'},
        }));

    final item = await c.getItem('item-1');
    await c.getItem('item-1');

    expect(item.institution, 'Nubank');
    final auth = requests.where((r) => r.url.path == '/auth').toList();
    expect(auth, hasLength(1));
    expect(jsonDecode(auth.single.body), {
      'clientId': 'id',
      'clientSecret': 'secret',
    });
    expect(requests.last.headers['X-API-KEY'], 'key-1');
  });

  test('renova a key antes de completar 2h', () async {
    final c = client((_) async => json({'id': 'item-1'}));

    await c.getItem('item-1');
    now = now.add(const Duration(hours: 1, minutes: 55));
    await c.getItem('item-1');

    expect(requests.where((r) => r.url.path == '/auth'), hasLength(2));
  });

  test('percorre as páginas de transações pelo cursor', () async {
    final c = client((request) async {
      expect(request.url.path, '/v2/transactions');
      expect(request.url.queryParameters['accountId'], 'acc-1');
      expect(request.url.queryParameters['dateFrom'], '2026-10-01');
      return switch (request.url.queryParameters['after']) {
        null => json({
            'results': [
              {'id': 't1'},
            ],
            'next': '?accountId=acc-1&after=abc%3D%3D',
          }),
        'abc==' => json({
            'results': [
              {'id': 't2'},
            ],
            'next': null,
          }),
        final other => fail('cursor inesperado: $other'),
      };
    });

    final result = await c.getTransactions('acc-1', from: DateTime(2026, 10));

    expect(result.map((t) => t['id']), ['t1', 't2']);
  });

  test('percorre as páginas de contas', () async {
    final c = client((request) async {
      final page = request.url.queryParameters['page'];
      return json({
        'page': int.parse(page!),
        'totalPages': 2,
        'results': [
          {'id': 'acc-$page', 'name': 'Conta $page', 'type': 'BANK'},
        ],
      });
    });

    final accounts = await c.getAccounts('item-1');

    expect(accounts.map((a) => a.id), ['acc-1', 'acc-2']);
  });

  test('erro da API vira PluggyException com a mensagem', () async {
    final c = client(
      (_) async => json({'message': 'Item not found'}, 404),
    );

    await expectLater(
      c.getItem('x'),
      throwsA(
        isA<PluggyException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Item not found'),
      ),
    );
  });

  test('401 descarta a key e a próxima chamada autentica de novo', () async {
    var calls = 0;
    final c = client((_) async {
      calls++;
      return calls == 1
          ? json({'message': 'expired'}, 401)
          : json({'id': 'item-1'});
    });

    await expectLater(c.getItem('item-1'), throwsA(isA<PluggyException>()));
    await c.getItem('item-1');

    expect(requests.where((r) => r.url.path == '/auth'), hasLength(2));
  });
}
