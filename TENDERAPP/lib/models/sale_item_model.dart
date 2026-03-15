class SaleItem {
  int? id;
  int saleId;
  int productId;
  int quantity;
  double priceAtSale;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.priceAtSale,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'price_at_sale': priceAtSale,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'],
      productId: map['product_id'],
      quantity: (map['quantity'] as num).toInt(),
      priceAtSale: (map['price_at_sale'] as num).toDouble(),
    );
  }
}
