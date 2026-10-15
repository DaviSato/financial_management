import 'dart:convert';

import 'package:financial_management/models/bank_history_entry.dart';
import 'package:financial_management/models/bank_transaction.dart';
import 'package:financial_management/models/payment_method.dart';
import 'package:financial_management/services/bank_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

BankTransaction transaction(String id, DateTime date) => BankTransaction(
      id: id,
      accountId: 'acc-1',
      institution: 'Nubank',
      institutionLogo: 'nubank.com.br',
      accountLabel: 'Cartão ••1234',
      amount: 42.5,
      type: TransactionType.expense,
      description: 'MERCADO',
      date: date,
      paymentMethod: PaymentMethod.creditCard,
      pending: true,
      installmentNumber: 1,
      totalInstallments: 3,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 15, 12);
  late PrefsFirestoreHistoryStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = PrefsFirestoreHistoryStore(now: () => now);
  });

  test('salva e lê de volta o retrato completo', () async {
    final t = transaction('t-1', DateTime(2026, 10, 12));
    await store.save([
      BankHistoryEntry.of(t, BankOutcome.launched, at: now, launchedId: 'e-1'),
    ]);

    final entry = (await store.load())['t-1']!;
    final back = entry.transaction!;
    expect(entry.outcome, BankOutcome.launched);
    expect(entry.launchedId, 'e-1');
    expect(entry.handledAt, now);
    expect(entry.fingerprint, t.fingerprint);
    expect(back.toJson(), t.toJson());
    expect(back.paymentMethod, PaymentMethod.creditCard);
    expect(back.isInstallment, true);
  });

  test('lê o formato antigo (id → fingerprint)', () async {
    SharedPreferences.setMockInitialValues({
      'bank_handled': jsonEncode({'velho': 'acc|expense|10.00|2026-10-01', 'x': null}),
    });

    final all = await store.load();

    expect(all['velho']!.outcome, BankOutcome.handled);
    expect(all['velho']!.fingerprint, 'acc|expense|10.00|2026-10-01');
    expect(all['velho']!.transaction, isNull);
    expect(all['x']!.fingerprint, isNull);
  });

  test('apaga o que passou de 12 meses e mantém o resto', () async {
    await store.save([
      BankHistoryEntry.of(
        transaction('velha', DateTime(2025, 9, 1)),
        BankOutcome.discarded,
        at: DateTime(2025, 9, 2),
      ),
      BankHistoryEntry.of(
        transaction('nova', DateTime(2026, 9, 1)),
        BankOutcome.discarded,
        at: DateTime(2026, 9, 2),
      ),
    ]);

    expect((await store.load()).keys, ['nova']);
    final raw = (await SharedPreferences.getInstance()).getString('bank_handled')!;
    expect((jsonDecode(raw) as Map).keys, ['nova']);
  });

  test('remove tira do armazenamento', () async {
    await store.save([
      BankHistoryEntry.of(
        transaction('t-1', DateTime(2026, 10, 12)),
        BankOutcome.discarded,
        at: now,
      ),
    ]);

    await store.remove(['t-1']);

    expect(await store.load(), isEmpty);
  });
}
