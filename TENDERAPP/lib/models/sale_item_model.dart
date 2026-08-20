class SaleItem {
  int? id;
  int saleId;
  int productId;
  int quantity;
  double priceAtSale;
  double discount;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.priceAtSale,
    this.discount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'price_at_sale': priceAtSale,
      'discount': discount,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'],
      productId: map['product_id'],
      quantity: (map['quantity'] as num).toInt(),
      priceAtSale: (map['price_at_sale'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
