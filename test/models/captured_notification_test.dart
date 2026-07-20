import 'package:financial_management/models/captured_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fromJson', () {
    test('lê o payload gravado pelo serviço nativo', () {
      final n = CapturedNotification.fromJson({
        'packageName': 'com.nu.production',
        'title': 'Compra aprovada',
        'text': 'R\$ 45,90 em PADARIA',
        'bigText': '',
        'subText': '',
        'postTime': 1753041600123,
      }, filePath: '/data/fila/1753041600123_abc.json');

      expect(n.packageName, 'com.nu.production');
      expect(n.title, 'Compra aprovada');
      expect(n.postedAt, DateTime.fromMillisecondsSinceEpoch(1753041600123));
      expect(n.filePath, '/data/fila/1753041600123_abc.json');
    });

    test('tolera campos ausentes sem lançar', () {
      final n = CapturedNotification.fromJson(
        {'packageName': 'com.x'},
        filePath: '/tmp/a.json',
      );

      expect(n.title, '');
      expect(n.body, '');
      expect(n.postedAt.millisecondsSinceEpoch, 0);
    });
  });

  group('body', () {
    test('prefere bigText, que traz o texto sem truncar', () {
      final n = CapturedNotification.fromJson({
        'text': 'Compra aprovada de R\$ 1.2…',
        'bigText': 'Compra aprovada de R\$ 1.234,56 em SUPERMERCADO CENTRAL',
      }, filePath: '/tmp/a.json');

      expect(n.body, contains('SUPERMERCADO CENTRAL'));
    });

    test('cai para text quando não há bigText', () {
      final n = CapturedNotification.fromJson({
        'text': 'Pix recebido',
        'bigText': '',
      }, filePath: '/tmp/a.json');

      expect(n.body, 'Pix recebido');
    });
  });

  group('fullText', () {
    test('junta os campos preenchidos e ignora os vazios', () {
      final n = CapturedNotification.fromJson({
        'title': 'Compra aprovada',
        'text': 'R\$ 45,90 em PADARIA',
        'bigText': '',
        'subText': 'Cartão final 1234',
      }, filePath: '/tmp/a.json');

      expect(
        n.fullText,
        'Compra aprovada · R\$ 45,90 em PADARIA · Cartão final 1234',
      );
    });

    test('não deixa separador solto quando só há um campo', () {
      final n = CapturedNotification.fromJson({
        'title': 'Compra aprovada',
      }, filePath: '/tmp/a.json');

      expect(n.fullText, 'Compra aprovada');
    });
  });

  test('toJson faz round-trip com fromJson', () {
    final original = CapturedNotification.fromJson({
      'packageName': 'com.nu.production',
      'title': 'Pix enviado',
      'text': 'R\$ 100,00 para Fulano',
      'bigText': 'R\$ 100,00 para Fulano de Tal',
      'subText': 'Conta',
      'postTime': 1753041600123,
    }, filePath: '/tmp/a.json');

    final restored = CapturedNotification.fromJson(
      original.toJson(),
      filePath: original.filePath,
    );

    expect(restored.packageName, original.packageName);
    expect(restored.title, original.title);
    expect(restored.text, original.text);
    expect(restored.bigText, original.bigText);
    expect(restored.subText, original.subText);
    expect(restored.postedAt, original.postedAt);
  });
}
