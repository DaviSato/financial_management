import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'cloud_config.dart';

class FirebaseConfig {
  FirebaseConfig._();

  /// Firebase realmente inicializado NESTA sessão. Diferente de [isConfigured]:
  /// o usuário pode ter salvo uma config nova que só passa a valer no próximo
  /// boot. Tocar no Auth/Firestore antes disso lançaria exceção — este flag é o
  /// que a UI consulta para saber se a nuvem está de fato utilizável agora.
  static bool initialized = false;

  /// Mapeamento campo do app → chave do `.env`.
  static const _envKeys = {
    'apiKey': 'FIREBASE_API_KEY',
    'appId': 'FIREBASE_APP_ID',
    'messagingSenderId': 'FIREBASE_MESSAGING_SENDER_ID',
    'projectId': 'FIREBASE_PROJECT_ID',
    'storageBucket': 'FIREBASE_STORAGE_BUCKET',
  };

  /// Precedência: valor do app se houver, senão o do `.env`, senão vazio.
  static String _effective(String field) {
    final fromApp = CloudConfig().get(field);
    if (fromApp != null && fromApp.isNotEmpty) return fromApp;
    return dotenv.maybeGet(_envKeys[field]!) ?? '';
  }

  /// Config efetiva de cada campo — usada para pré-preencher o formulário.
  static Map<String, String> effectiveValues() => {
    for (final field in CloudConfig.fields) field: _effective(field),
  };

  /// Se a config efetiva (app ou `.env`) é suficiente para inicializar.
  static bool get isConfigured => _effective('apiKey').isNotEmpty;

  /// Origem da config efetiva, para mostrar na UI.
  static bool get isFromApp =>
      (CloudConfig().get('apiKey') ?? '').isNotEmpty;

  static FirebaseOptions get options {
    final bucket = _effective('storageBucket');
    return FirebaseOptions(
      apiKey: _effective('apiKey'),
      appId: _effective('appId'),
      messagingSenderId: _effective('messagingSenderId'),
      projectId: _effective('projectId'),
      storageBucket: bucket.isEmpty ? null : bucket,
    );
  }
}
