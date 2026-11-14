import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product_model.dart';
import '../../providers/bcv_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/barcode_scanner_modal.dart';

class PosScreen extends StatefulWidget {
  final CartProvider cartProvider;
  final BcvProvider bcvProvider;
  final InventoryProvider inventoryProvider;

  const PosScreen({
    super.key,
    required this.cartProvider,
    required this.bcvProvider,
    required this.inventoryProvider,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Product> _quickResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _quickResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 220), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final matches = await DbHelper.instance.getProductsPaginated(
        limit: 8,
        offset: 0,
        query: trimmed,
      );
      if (mounted) {
        setState(() {
          _quickResults = matches;
          _isSearching = false;
        });
      }
    });
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1B5E20),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _scanAndAdd() async {
    final code = await BarcodeScannerModal.scan(
      context,
      title: 'Escanear producto para Caja',
    );
    if (code == null || !mounted) return;

    final error = await widget.cartProvider.addByBarcode(code);
    if (error != null) {
      _showFeedback(error, isError: true);
    } else {
      _showFeedback('Agregado: $code');
    }
  }

  void _selectSearchResult(Product product) {
    final error = widget.cartProvider.addProduct(product);
    if (error != null) {
      _showFeedback(error, isError: true);
      return;
    }
    _searchCtrl.clear();
    setState(() => _quickResults = []);
  }

  Future<void> _confirmCheckout() async {
    final cart = widget.cartProvider;
    final rate = widget.bcvProvider.rate;
    if (cart.isEmpty || cart.isProcessing) return;

    final totalUsd = cart.totalUsd;
    final totalBs = cart.totalBs(rate);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Artículos en carrito: ${cart.totalUnits} unid.'),
            const SizedBox(height: 10),
            Text(
              'Total USD: ${CurrencyFormatter.formatUsd(totalUsd)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total Bs: ${CurrencyFormatter.formatBs(totalBs)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Se descontarán estas unidades del inventario.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar venta'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await cart.checkout();
      if (success) {
        // Sincroniza el lote visible en Inventario con el nuevo stock
        await widget.inventoryProvider.loadInitial();
        _showFeedback('Venta registrada y stock actualizado.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Column(
        children: [
          // Buscador rápido + botón de escáner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Buscar producto para agregar...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _quickResults = []);
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _scanAndAdd,
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text('Escanear'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                // Lista desplegable de coincidencias rápidas (máx. 8)
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else if (_quickResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 210),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _quickResults.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (_, index) {
                        final prod = _quickResults[index];
                        final rate = widget.bcvProvider.rate;
                        return ListTile(
                          dense: true,
                          title: Text(
                            prod.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Stock: ${prod.stock}  |  ${CurrencyFormatter.formatBs(prod.priceInBs(rate))}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            CurrencyFormatter.formatUsd(prod.priceUsd),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          onTap: () => _selectSearchResult(prod),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Lista de artículos en el carrito
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                widget.cartProvider,
                widget.bcvProvider,
              ]),
              builder: (context, _) {
                final cart = widget.cartProvider;
                final rate = widget.bcvProvider.rate;

                if (cart.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.point_of_sale_outlined,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'El carrito de venta está vacío.\nEscanea un código o busca un producto arriba.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    final prod = item.product;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.8),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Nombre y precio unitario
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${CurrencyFormatter.formatUsd(prod.priceUsd)} c/u  (Disp: ${prod.stock})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Controles - / cantidad / +
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () =>
                                    cart.decrementQuantity(prod.id!),
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  final err = cart.incrementQuantity(prod.id!);
                                  if (err != null) {
                                    _showFeedback(err, isError: true);
                                  }
                                },
                              ),
                            ],
                          ),

                          // Subtotal USD / Bs
                          SizedBox(
                            width: 88,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatUsd(item.subtotalUsd),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatBs(
                                    item.subtotalBs(rate),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Barra inferior fija con totales y botón Cobrar
          ListenableBuilder(
            listenable: Listenable.merge([
              widget.cartProvider,
              widget.bcvProvider,
            ]),
            builder: (context, _) {
              final cart = widget.cartProvider;
              final rate = widget.bcvProvider.rate;

              return Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total (${cart.totalUnits} unid.): ${CurrencyFormatter.formatUsd(cart.totalUsd)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.formatBs(cart.totalBs(rate)),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!cart.isEmpty) ...[
                      IconButton(
                        tooltip: 'Vaciar carrito',
                        onPressed: cart.clearCart,
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    FilledButton.icon(
                      onPressed: cart.isEmpty || cart.isProcessing
                          ? null
                          : _confirmCheckout,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Cobrar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}