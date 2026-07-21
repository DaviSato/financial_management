import 'package:financial_management/services/logo_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LogoConfig().clear(); // zera o estado do singleton entre os testes
  });

  test('sem token no app, usa o do .env', () async {
    dotenv.loadFromString(envString: 'LOGO_DEV_TOKEN=env_token');
    await LogoConfig().load();

    expect(LogoConfig().token, 'env_token');
    expect(LogoConfig().isFromApp, false);
    expect(LogoConfig().hasToken, true);
  });

  test('token do app sobrepõe o do .env', () async {
    dotenv.loadFromString(envString: 'LOGO_DEV_TOKEN=env_token');
    await LogoConfig().save(publishable: 'app_token');

    expect(LogoConfig().token, 'app_token');
    expect(LogoConfig().isFromApp, true);
  });

  test('clear remove o token do app e volta ao .env', () async {
    dotenv.loadFromString(envString: 'LOGO_DEV_TOKEN=env_token');
    await LogoConfig().save(publishable: 'app_token');
    await LogoConfig().clear();

    expect(LogoConfig().token, 'env_token');
    expect(LogoConfig().isFromApp, false);
  });

  test('sem token no app e sem .env, fica vazio', () async {
    dotenv.loadFromString(envString: '', isOptional: true);
    await LogoConfig().clear();

    expect(LogoConfig().hasToken, false);
    expect(LogoConfig().token, '');
  });
}
