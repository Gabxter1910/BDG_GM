import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/database/db_helper.dart';
import '../models/product_model.dart';

class InventoryProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  final List<Product> _products = [];
  int _offset = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';
  int _totalCount = 0;

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;
  int get totalCount => _totalCount;

  Future<void> loadInitial({String? query}) async {
    if (query != null) {
      _searchQuery = query.trim();
    }

    _isLoading = true;
    _offset = 0;
    _hasMore = true;
    _products.clear();
    notifyListeners();

    final batch = await _db.getProductsPaginated(
      limit: AppConstants.pageSize,
      offset: 0,
      query: _searchQuery,
    );
    _totalCount = await _db.getTotalProductsCount();

    _products.addAll(batch);
    _offset = batch.length;
    _hasMore = batch.length == AppConstants.pageSize;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    final batch = await _db.getProductsPaginated(
      limit: AppConstants.pageSize,
      offset: _offset,
      query: _searchQuery,
    );

    _products.addAll(batch);
    _offset += batch.length;
    _hasMore = batch.length == AppConstants.pageSize;
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed == _searchQuery && _products.isNotEmpty) return;
    await loadInitial(query: trimmed);
  }

  Future<void> addProduct({
    required String name,
    String? barcode,
    required double priceUsd,
    required int stock,
  }) async {
    final product = Product(
      barcode: barcode,
      name: name,
      priceUsd: priceUsd,
      stock: stock,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await _db.insertProduct(product);
    await loadInitial();
  }

  Future<void> updateProduct(Product product) async {
    final updated = product.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _db.updateProduct(updated);
    await loadInitial();
  }

  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
    _products.removeWhere((item) => item.id == id);
    if (_totalCount > 0) _totalCount--;
    notifyListeners();
  }
}