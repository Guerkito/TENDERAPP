class PurchaseModel {
  final int? id;
  final int supplierId;
  final DateTime date;
  final double totalAmount;
  final String? notes;

  PurchaseModel({
    this.id,
    required this.supplierId,
    required this.date,
    required this.totalAmount,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'date': date.toIso8601String(),
      'total_amount': totalAmount,
      'notes': notes,
    };
  }

  factory PurchaseModel.fromMap(Map<String, dynamic> map) {
    return PurchaseModel(
      id: map['id'],
      supplierId: map['supplier_id'],
      date: DateTime.parse(map['date']),
      totalAmount: map['total_amount'],
      notes: map['notes'],
    );
  }
}
