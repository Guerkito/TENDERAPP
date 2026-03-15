import 'product_batch_model.dart';

class Product {
  int? id;
  String name;
  String? barcode;
  String? description;
  double purchasePrice;
  double salePrice;
  num stock; // Changed to num for precision if needed in weights
  String? expirationDate; // Keeping for backward compatibility (primary/first batch)
  String productType; // 'product' or 'fruver'
  String? unit; // 'kg', 'lb', 'unit', etc.
  List<ProductBatch> batches;

  Product({
    this.id,
    required this.name,
    this.barcode,
    this.description,
    required this.purchasePrice,
    required this.salePrice,
    required this.stock,
    this.expirationDate,
    this.productType = 'product',
    this.unit,
    this.batches = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'description': description,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'stock': stock,
      'expiration_date': expirationDate,
      'product_type': productType,
      'unit': unit,
    };
  }

  // Helper method to get the sale_price from map correctly (safeguard)
  static double _getSalePrice(Map<String, dynamic> map) {
    return (map['sale_price'] as num).toDouble();
  }

  factory Product.fromMap(Map<String, dynamic> map, {List<ProductBatch> batches = const []}) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      description: map['description'],
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      stock: (map['stock'] as num),
      expirationDate: map['expiration_date'],
      productType: map['product_type'] ?? 'product',
      unit: map['unit'],
      batches: batches,
    );
  }
}
