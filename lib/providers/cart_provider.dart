import 'package:flutter/foundation.dart';
import '../core/database/db_helper.dart';
import '../core/utils/currency_formatter.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  final List<CartItem> _items = [];
  bool _isProcessing = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isProcessing => _isProcessing;
  bool get isEmpty => _items.isEmpty;

  int get totalUnits => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalUsd {
    final raw = _items.fold(0.0, (sum, item) => sum + item.subtotalUsd);
    return CurrencyFormatter.roundTwo(raw);
  }

  double totalBs(double bcvRate) {
    return CurrencyFormatter.usdToBs(totalUsd, bcvRate);
  }

  /// Agrega un producto validando el stock disponible.
  /// Retorna null si tuvo éxito o un mensaje de advertencia si falta stock.
  String? addProduct(Product product, {int quantity = 1}) {
    if (product.stock <= 0) {
      return 'Sin stock disponible para "${product.name}".';
    }

    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index != -1) {
      final currentQty = _items[index].quantity;
      if (currentQty + quantity > product.stock) {
        return 'Stock máximo alcanzado (${product.stock} disp.).';
      }
      _items[index].quantity += quantity;
    } else {
      if (quantity > product.stock) {
        return 'Solo hay ${product.stock} unidades disponibles.';
      }
      _items.add(CartItem(product: product, quantity: quantity));
    }

    notifyListeners();
    return null;
  }

  /// Busca un código de barras/QR en SQLite y lo agrega directo al carrito
  Future<String?> addByBarcode(String barcode) async {
    final product = await _db.getProductByBarcode(barcode);
    if (product == null) {
      return 'Producto no registrado ($barcode).';
    }
    return addProduct(product);
  }

  String? incrementQuantity(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return null;

    final item = _items[index];
    if (item.quantity + 1 > item.product.stock) {
      return 'Stock máximo alcanzado (${item.product.stock} disp.).';
    }

    item.quantity++;
    notifyListeners();
    return null;
  }

  void decrementQuantity(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;

    if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
    }
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// Descuenta las unidades vendidas en SQLite y vacía el carrito
  Future<bool> checkout() async {
    if (_items.isEmpty || _isProcessing) return false;

    _isProcessing = true;
    notifyListeners();

    try {
      await _db.processSale(_items);
      _items.clear();
      return true;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}