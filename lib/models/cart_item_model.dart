import 'product_model.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get subtotalUsd => ((product.priceUsd * quantity) * 100).round() / 100;

  double subtotalBs(double bcvRate) =>
      ((subtotalUsd * bcvRate) * 100).round() / 100;
}