class PaymentMethod {
  static const String cash = 'Efectivo';
  static const String card = 'Tarjeta';
  static const String nequi = 'Nequi / Daviplata';
  static const String credit = 'Fiado';
  static const String mixed = 'Mixto';

  static const List<String> all = [cash, card, nequi, credit];
}

class MovementType {
  static const String charge = 'Cargo';
  static const String payment = 'Abono';
}

class SaleStatus {
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}
