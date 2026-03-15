class ExpenseModel {
  final int? id;
  final String description;
  final double amount;
  final DateTime date;
  final String category; // Ej: 'Servicios', 'Alquiler', 'Sueldos', 'Otros'

  ExpenseModel({
    this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'],
      description: map['description'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      category: map['category'],
    );
  }
}
