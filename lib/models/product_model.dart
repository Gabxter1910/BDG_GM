class Product {
  final int? id;
  final String? barcode;
  final String name;
  final double priceUsd;
  final int stock;
  final String updatedAt;

  const Product({
    this.id,
    this.barcode,
    required this.name,
    required this.priceUsd,
    required this.stock,
    required this.updatedAt,
  });

  /// Calcula el precio en Bolívares redondeado a 2 decimales según la tasa activa
  double priceInBs(double bcvRate) {
    return ((priceUsd * bcvRate) * 100).round() / 100;
  }

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    double? priceUsd,
    int? stock,
    String? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      priceUsd: priceUsd ?? this.priceUsd,
      stock: stock ?? this.stock,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final cleanBarcode = barcode?.trim();
    return {
      if (id != null) 'id': id,
      'barcode': (cleanBarcode == null || cleanBarcode.isEmpty) ? null : cleanBarcode,
      'name': name.trim(),
      'price_usd': ((priceUsd * 100).round()) / 100,
      'stock': stock,
      'updated_at': updatedAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      barcode: map['barcode'] as String?,
      name: map['name'] as String,
      priceUsd: (map['price_usd'] as num).toDouble(),
      stock: (map['stock'] as num).toInt(),
      updatedAt: map['updated_at'] as String,
    );
  }
}