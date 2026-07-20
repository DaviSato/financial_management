import 'package:financial_management/services/cloud_config.dart';
import 'package:financial_management/services/firebase_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CloudConfig().clear();
    await CloudConfig().load();
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  group('CloudConfig', () {
    test('save e load preservam os campos', () async {
      await CloudConfig().save({
        'apiKey': 'k',
        'appId': 'a',
        'projectId': 'p',
      });
      await CloudConfig().load();

      expect(CloudConfig().get('apiKey'), 'k');
      expect(CloudConfig().get('projectId'), 'p');
      expect(CloudConfig().hasConfig, isTrue);
    });

    test('campo vazio não é gravado', () async {
      await CloudConfig().save({'apiKey': 'k', 'appId': '   '});
      expect(CloudConfig().get('appId'), isNull);
    });

    test('clear remove tudo', () async {
      await CloudConfig().save({'apiKey': 'k'});
      await CloudConfig().clear();
      expect(CloudConfig().hasConfig, isFalse);
    });
  });

  group('precedência app → .env', () {
    test('sem nada, não está configurado', () {
      expect(FirebaseConfig.isConfigured, isFalse);
    });

    test('só o .env: usa o .env', () async {
      dotenv.loadFromString(envString: 'FIREBASE_API_KEY=envkey\nFIREBASE_PROJECT_ID=envproj');
      expect(FirebaseConfig.isConfigured, isTrue);
      expect(FirebaseConfig.isFromApp, isFalse);
      expect(FirebaseConfig.effectiveValues()['apiKey'], 'envkey');
      expect(FirebaseConfig.effectiveValues()['projectId'], 'envproj');
    });

    test('config do app sobrepõe o .env', () async {
      dotenv.loadFromString(envString: 'FIREBASE_API_KEY=envkey');
      await CloudConfig().save({'apiKey': 'appkey', 'appId': 'x', 'projectId': 'y'});

      expect(FirebaseConfig.isFromApp, isTrue);
      expect(FirebaseConfig.effectiveValues()['apiKey'], 'appkey');
    });

    test('campo ausente no app cai para o .env', () async {
      dotenv.loadFromString(envString: 'FIREBASE_MESSAGING_SENDER_ID=envsender');
      await CloudConfig().save({'apiKey': 'appkey', 'appId': 'x', 'projectId': 'y'});

      // apiKey vem do app; messagingSenderId não foi definido no app → .env
      expect(FirebaseConfig.effectiveValues()['apiKey'], 'appkey');
      expect(FirebaseConfig.effectiveValues()['messagingSenderId'], 'envsender');
    });

    test('restaurar padrão volta a usar o .env', () async {
      dotenv.loadFromString(envString: 'FIREBASE_API_KEY=envkey');
      await CloudConfig().save({'apiKey': 'appkey'});
      expect(FirebaseConfig.isFromApp, isTrue);

      await CloudConfig().clear();
      expect(FirebaseConfig.isFromApp, isFalse);
      expect(FirebaseConfig.effectiveValues()['apiKey'], 'envkey');
    });

    test('storageBucket vazio vira null nas options', () async {
      dotenv.loadFromString(
        envString:
            'FIREBASE_API_KEY=k\nFIREBASE_APP_ID=a\nFIREBASE_MESSAGING_SENDER_ID=s\nFIREBASE_PROJECT_ID=p',
      );
      expect(FirebaseConfig.options.storageBucket, isNull);
      expect(FirebaseConfig.options.apiKey, 'k');
    });
  });
}
