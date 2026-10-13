import '../constants/app_constants.dart';

class CustomerMovement {
  int? id;
  int customerId;
  String dateTime;
  String type; // 'Cargo' o 'Abono'
  double amount;
  String description;
  int? saleId;

  CustomerMovement({
    this.id,
    required this.customerId,
    required this.dateTime,
    required this.type,
    required this.amount,
    required this.description,
    this.saleId,
  });

  /// Efecto del movimiento sobre el saldo pendiente: Cargo suma, Abono resta.
  static double signedDelta(String type, double amount) =>
      type == MovementType.charge ? amount : -amount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'date_time': dateTime,
      'type': type,
      'amount': amount,
      'description': description,
      'sale_id': saleId,
    };
  }

  factory CustomerMovement.fromMap(Map<String, dynamic> map) {
    return CustomerMovement(
      id: map['id'],
      customerId: map['customer_id'],
      dateTime: map['date_time'],
      type: map['type'],
      amount: (map['amount'] as num).toDouble(),
      description: map['description'],
      saleId: map['sale_id'],
    );
  }
}
