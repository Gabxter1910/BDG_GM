import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/currency_formatter.dart';
import '../models/product_model.dart';

class ProductRowTile extends StatelessWidget {
  final Product product;
  final double bcvRate;
  final VoidCallback onTap;
  final Widget? trailingAction;

  const ProductRowTile({
    super.key,
    required this.product,
    required this.bcvRate,
    required this.onTap,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    final priceBs = product.priceInBs(bcvRate);
    final isOutOfStock = product.stock <= 0;
    final isLowStock =
        product.stock > 0 && product.stock <= AppConstants.defaultLowStockThreshold;

    final Color stockBgColor;
    final Color stockTextColor;
    if (isOutOfStock) {
      stockBgColor = const Color(0xFFFFEBEE);
      stockTextColor = const Color(0xFFC62828);
    } else if (isLowStock) {
      stockBgColor = const Color(0xFFFFF8E1);
      stockTextColor = const Color(0xFFEF6C00);
    } else {
      stockBgColor = const Color(0xFFE8F5E9);
      stockTextColor = const Color(0xFF2E7D32);
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.8),
          ),
        ),
        child: Row(
          children: [
            // Nombre y código de barras
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1C1E),
                    ),
                  ),
                  if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          size: 13,
                          color: Color(0xFF6C757D),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.barcode!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6C757D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Etiqueta de Stock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: stockBgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Stock: ${product.stock}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: stockTextColor,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Precios en USD (anclado) y Bs (calculado al BCV)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatUsd(product.priceUsd),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.formatBs(priceBs),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF495057),
                  ),
                ),
              ],
            ),

            if (trailingAction != null) ...[
              const SizedBox(width: 6),
              trailingAction!,
            ],
          ],
        ),
      ),
    );
  }
}