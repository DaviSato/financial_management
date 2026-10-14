import 'dart:convert';

import 'package:financial_management/models/bank_connection.dart';
import 'package:financial_management/services/pluggy_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('PLUGGY_ITEMS vira bancos, com nome opcional', () async {
    dotenv.loadFromString(
      envString: 'PLUGGY_ITEMS=item-a:Bradesco, item-b ,',
    );
    await PluggyConfig().load();

    final c = PluggyConfig().connections;
    expect(c.map((c) => c.itemId), ['item-a', 'item-b']);
    expect(c.map((c) => c.institution), ['Bradesco', '']);
    expect(PluggyConfig().isFromEnv('item-a'), true);
  });

  test('a data de início do item do .env não anda a cada boot', () async {
    SharedPreferences.setMockInitialValues({
      'pluggy_env_items_seen': jsonEncode({'item-a': '2026-10-01T09:00:00.000'}),
    });
    dotenv.loadFromString(envString: 'PLUGGY_ITEMS=item-a:Bradesco');
    await PluggyConfig().load();

    expect(PluggyConfig().connections.single.connectedAt, DateTime(2026, 10, 1, 9));
  });

  test('item novo no .env grava o dia em que foi visto', () async {
    dotenv.loadFromString(envString: 'PLUGGY_ITEMS=item-a');
    await PluggyConfig().load();
    final first = PluggyConfig().connections.single.connectedAt;

    await PluggyConfig().load();

    expect(PluggyConfig().connections.single.connectedAt, first);
  });

  test('o mesmo item no app vale o do app', () async {
    dotenv.loadFromString(envString: 'PLUGGY_ITEMS=item-a:Do env');
    await PluggyConfig().load();
    await PluggyConfig().addConnection(BankConnection(
      itemId: 'item-a',
      institution: 'Do app',
      connectedAt: DateTime(2026, 10, 14),
    ));

    expect(PluggyConfig().connections.single.institution, 'Do app');
    expect(PluggyConfig().isFromEnv('item-a'), false);
  });

  test('sem PLUGGY_ITEMS, só os do app', () async {
    dotenv.loadFromString(envString: 'PLUGGY_CLIENT_ID=x');
    await PluggyConfig().load();

    expect(PluggyConfig().connections, isEmpty);
  });

  test('PLUGGY_ITEMS aceita o domínio do logo', () async {
    dotenv.loadFromString(
      envString: 'PLUGGY_ITEMS=item-a:Bradesco:bradesco.com.br,item-b:Nubank',
    );
    await PluggyConfig().load();

    final c = PluggyConfig().connections;
    expect(c.map((c) => c.logoDomain), ['bradesco.com.br', null]);
  });

  test('nome e logo editados no app persistem', () async {
    dotenv.loadFromString(envString: 'PLUGGY_CLIENT_ID=x');
    await PluggyConfig().load();
    await PluggyConfig().addConnection(BankConnection(
      itemId: 'item-a',
      institution: 'MeuPluggy',
      connectedAt: DateTime(2026, 10, 14),
    ));
    await PluggyConfig().updateConnection(
      'item-a',
      institution: 'Bradesco',
      logoDomain: 'bradesco.com.br',
    );

    await PluggyConfig().load();

    final c = PluggyConfig().connections.single;
    expect(c.institution, 'Bradesco');
    expect(c.logoDomain, 'bradesco.com.br');
    expect(c.connectedAt, DateTime(2026, 10, 14));
  });

  test('data gravada corrompida e item repetido não quebram o boot', () async {
    SharedPreferences.setMockInitialValues({
      'pluggy_env_items_seen': jsonEncode({'item-a': 'lixo'}),
    });
    dotenv.loadFromString(envString: 'PLUGGY_ITEMS=item-a:A,item-a:B');
    await PluggyConfig().load();

    final c = PluggyConfig().connections;
    expect(c, hasLength(1));
    expect(c.single.institution, 'A');
  });
}
