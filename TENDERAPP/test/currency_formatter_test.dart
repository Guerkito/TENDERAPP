import 'package:flutter_test/flutter_test.dart';
import 'package:tenderapp/api/currency_formatter.dart';

void main() {
  test('formatea pesos colombianos con el símbolo delante', () {
    expect(CurrencyFormatter.format(4200), r'$ 4.200');
    expect(CurrencyFormatter.format(0), r'$ 0');
    expect(CurrencyFormatter.format(1500000), r'$ 1.500.000');
  });

  test('los negativos llevan el signo antes del símbolo', () {
    expect(CurrencyFormatter.format(-1500), r'-$ 1.500');
  });

  test('cantidades enteras sin decimales y fracciones tal cual', () {
    expect(CurrencyFormatter.quantity(18), '18');
    expect(CurrencyFormatter.quantity(0.5), '0.5');
  });
}
