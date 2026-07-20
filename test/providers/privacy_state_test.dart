import 'package:financial_management/providers/privacy_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('começa mostrando os valores', () async {
    SharedPreferences.setMockInitialValues({});
    final state = PrivacyState();
    await state.load();
    expect(state.hideIncome, isFalse);
  });

  test('toggle alterna e persiste', () async {
    SharedPreferences.setMockInitialValues({});
    final state = PrivacyState();
    await state.load();

    await state.toggleHideIncome();
    expect(state.hideIncome, isTrue);

    // Uma nova instância lê o valor persistido.
    final reloaded = PrivacyState();
    await reloaded.load();
    expect(reloaded.hideIncome, isTrue);
  });
}
