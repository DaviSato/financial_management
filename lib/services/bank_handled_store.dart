import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bank_transaction.dart';
import 'auth_service.dart';
import 'firebase_config.dart';
import 'firestore_service.dart';

/// Lembra quais movimentações do banco já foram lançadas ou descartadas, para
/// não reaparecerem na caixa de entrada.
///
/// Chave: id da transação na Pluggy. Valor: [BankTransaction.fingerprint], só
/// para as que estavam pendentes — a Pluggy pode trocar o id quando a compra é
/// liquidada, e o fingerprint é o que a reconhece de volta. Para as já
/// liquidadas o valor fica null: duas compras iguais no mesmo dia são legítimas
/// e não podem se esconder uma à outra.
abstract class BankHandledStore {
  Future<Map<String, String?>> load();
  Future<void> add(Iterable<BankTransaction> transactions);
}

/// Grava local (sempre) e no Firestore (quando conectado), para que o que foi
/// tratado num aparelho suma da caixa de entrada nos outros.
class PrefsFirestoreHandledStore implements BankHandledStore {
  static const _key = 'bank_handled';

  FirestoreService? get _cloud =>
      FirebaseConfig.initialized && AuthService().uid != null
          ? FirestoreService()
          : null;

  @override
  Future<Map<String, String?>> load() async {
    final local = await _loadLocal();
    final cloud = _cloud;
    if (cloud == null) return local;
    try {
      return {...local, ...await cloud.getBankHandled()};
    } catch (e) {
      // Sem rede: o que já está local basta para não duplicar neste aparelho.
      debugPrint('Falha ao ler bank_handled do Firestore: $e');
      return local;
    }
  }

  @override
  Future<void> add(Iterable<BankTransaction> transactions) async {
    final entries = {
      for (final t in transactions) t.id: t.pending ? t.fingerprint : null,
    };
    final local = await _loadLocal()
      ..addAll(entries);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(local));

    try {
      await _cloud?.saveBankHandled(entries);
    } catch (e) {
      debugPrint('Falha ao gravar bank_handled no Firestore: $e');
    }
  }

  Future<Map<String, String?>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String?>();
    } catch (_) {
      return {};
    }
  }
}
