import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências de privacidade da exibição — por ora, ocultar rendimentos.
///
/// Persistente: uma vez oculto, permanece assim (inclusive após reabrir o app)
/// até o usuário reexibir. Só afeta a apresentação; os dados não mudam.
class PrivacyState extends ChangeNotifier {
  static const _hideIncomeKey = 'hide_income';

  bool _hideIncome = false;
  bool get hideIncome => _hideIncome;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hideIncome = prefs.getBool(_hideIncomeKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleHideIncome() async {
    _hideIncome = !_hideIncome;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideIncomeKey, _hideIncome);
  }
}
