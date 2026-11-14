import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/cart_item_model.dart';
import '../../models/product_model.dart';
import '../constants/app_constants.dart';

class DbHelper {
  DbHelper._internal();
  static final DbHelper instance = DbHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT,
        name TEXT NOT NULL,
        price_usd REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // Índices para filtrar por nombre o escanear código en milisegundos
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
  }

  /// Consulta paginada (LIMIT 20 OFFSET X) con filtro opcional por nombre o código
  Future<List<Product>> getProductsPaginated({
    required int limit,
    required int offset,
    String query = '',
  }) async {
    final db = await database;
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      final maps = await db.query(
        'products',
        orderBy: 'name COLLATE NOCASE ASC',
        limit: limit,
        offset: offset,
      );
      return maps.map((e) => Product.fromMap(e)).toList();
    }

    final pattern = '%$cleanQuery%';
    final maps = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
      offset: offset,
    );
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  /// Búsqueda exacta por código de barras o QR (para el escáner)
  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [cleanCode],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  /// Conteo total de productos registrados
  Future<int> getTotalProductsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as total FROM products');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Crear producto
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert('products', product.toMap());
  }

  /// Actualizar producto
  Future<int> updateProduct(Product product) async {
    final db = await database;
    return db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  /// Eliminar producto
  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Descuento masivo y atómico de stock al confirmar venta en Caja
  Future<void> processSale(List<CartItem> items) async {
    if (items.isEmpty) return;
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final item in items) {
        if (item.product.id == null) continue;
        await txn.rawUpdate(
          '''
          UPDATE products 
          SET stock = MAX(0, stock - ?), updated_at = ? 
          WHERE id = ?
          ''',
          [item.quantity, now, item.product.id],
        );
      }
    });
  }

  /// Productos con stock bajo para la pestaña Utilidades
  Future<List<Product>> getLowStockProducts({
    int threshold = AppConstants.defaultLowStockThreshold,
  }) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'stock <= ?',
      whereArgs: [threshold],
      orderBy: 'stock ASC, name COLLATE NOCASE ASC',
    );
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  /// Lectura completa únicamente para exportar respaldo CSV
  Future<List<Product>> getAllProductsForExport() async {
    final db = await database;
    final maps = await db.query(
      'products',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return maps.map((e) => Product.fromMap(e)).toList();
  }
}