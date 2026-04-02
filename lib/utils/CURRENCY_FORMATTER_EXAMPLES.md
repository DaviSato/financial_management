/// Exemplos de uso do CurrencyFormatter
///
/// Formatter é usado automaticamente em:
/// - Dashboard (valores de rendimento, gastos, saldo)
/// - Tela de Rendimentos (lista de rendimentos)
/// - Tela de Gastos (lista de gastos e breakdown de categorias)
///
/// Exemplos:
///
/// `dart
/// import 'package:financial_management/utils/currency_formatter.dart';
///
/// // Formatar um valor em moeda brasileira
/// double valor = 3450.00;
/// String formatted = CurrencyFormatter.format(valor);
/// // Resultado: "R$ 3.450,00"
///
/// // Formatar sem símbolo
/// String noSymbol = CurrencyFormatter.formatNoSymbol(valor);
/// // Resultado: "3.450,00"
///
/// // Fazer parse de entrada do usuário
/// String userInput = "R$ 1.234,56";
/// double? parsed = CurrencyFormatter.parse(userInput);
/// // Resultado: 1234.56
/// `
