class ProductBatch {
  final int? id;
  final int productId;
  final String? expirationDate;
  final double stock;

  ProductBatch({
    this.id,
    required this.productId,
    this.expirationDate,
    required this.stock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'expiration_date': expirationDate,
      'stock': stock,
    };
  }

  factory ProductBatch.fromMap(Map<String, dynamic> map) {
    return ProductBatch(
      id: map['id'],
      productId: map['product_id'],
      expirationDate: map['expiration_date'],
      stock: (map['stock'] as num).toDouble(),
    );
  }
}
