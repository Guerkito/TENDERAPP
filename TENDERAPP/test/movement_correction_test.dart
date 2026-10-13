import 'package:flutter_test/flutter_test.dart';
import 'package:tenderapp/constants/app_constants.dart';
import 'package:tenderapp/models/customer_movement_model.dart';

void main() {
  test('Cargo suma al saldo y Abono resta', () {
    expect(CustomerMovement.signedDelta(MovementType.charge, 50000), 50000);
    expect(
        CustomerMovement.signedDelta(MovementType.payment, 30000), -30000);
  });

  test('corregir un cargo de 50.000 a 5.000 deja el saldo en +5.000', () {
    // Lo que hace correctMovement: anular el original y registrar el nuevo.
    final delta = -CustomerMovement.signedDelta(MovementType.charge, 50000) +
        CustomerMovement.signedDelta(MovementType.charge, 5000);
    expect(delta, -45000);
  });

  test('anular un abono devuelve la deuda al saldo anterior', () {
    final delta = -CustomerMovement.signedDelta(MovementType.payment, 20000);
    expect(delta, 20000);
  });

  test('corregir un abono de 20.000 a 25.000 baja el saldo 5.000 más', () {
    final delta = -CustomerMovement.signedDelta(MovementType.payment, 20000) +
        CustomerMovement.signedDelta(MovementType.payment, 25000);
    expect(delta, -5000);
  });
}
