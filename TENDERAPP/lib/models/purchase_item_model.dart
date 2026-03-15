class PurchaseItemModel {
  final int? id;
  final int purchaseId;
  final int productId;
  final num quantity;
  final double costPrice; // El precio al que compramos cada unidad

  PurchaseItemModel({
    this.id,
    required this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.costPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'product_id': productId,
      'quantity': quantity,
      'cost_price': costPrice,
    };
  }

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      id: map['id'],
      purchaseId: map['purchase_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      costPrice: map['cost_price'],
    );
  }
}
