import '../constants/app_constants.dart';

class Sale {
  int? id;
  double totalAmount;
  String paymentMethod;
  String saleDate;
  int? customerId;
  String status;

  Sale({
    this.id,
    required this.totalAmount,
    required this.paymentMethod,
    required this.saleDate,
    this.customerId,
    this.status = SaleStatus.completed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'sale_date': saleDate,
      'customer_id': customerId,
      'status': status,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'],
      saleDate: map['sale_date'],
      customerId: map['customer_id'],
      status: map['status'] as String? ?? SaleStatus.completed,
    );
  }
}
