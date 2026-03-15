class Customer {
  int? id;
  String name;
  String phone;
  double creditLimit;
  double totalPendingBalance;
  int points;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.creditLimit = 0.0,
    this.totalPendingBalance = 0.0,
    this.points = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'credit_limit': creditLimit,
      'total_pending_balance': totalPendingBalance,
      'points': points,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      totalPendingBalance: (map['total_pending_balance'] as num?)?.toDouble() ?? 0.0,
      points: map['points'] ?? 0,
    );
  }
}
