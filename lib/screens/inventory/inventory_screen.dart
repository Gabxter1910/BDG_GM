import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/bcv_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/barcode_scanner_modal.dart';
import '../../widgets/product_row_tile.dart';
import 'product_form_sheet.dart';

class InventoryScreen extends StatefulWidget {
  final InventoryProvider inventoryProvider;
  final BcvProvider bcvProvider;

  const InventoryScreen({
    super.key,
    required this.inventoryProvider,
    required this.bcvProvider,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 180) {
      widget.inventoryProvider.loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      widget.inventoryProvider.search(value);
    });
    setState(() {});
  }

  Future<void> _scanToSearch() async {
    final code = await BarcodeScannerModal.scan(
      context,
      title: 'Buscar producto por código',
    );
    if (code != null && mounted) {
      _searchCtrl.text = code;
      setState(() {});
      await widget.inventoryProvider.search(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Column(
        children: [
          // Barra de búsqueda + botón de escáner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchCtrl.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                              widget.inventoryProvider.search('');
                            },
                          ),
                        IconButton(
                          tooltip: 'Escanear código',
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          onPressed: _scanToSearch,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ListenableBuilder(
                  listenable: widget.inventoryProvider,
                  builder: (_, __) {
                    final inv = widget.inventoryProvider;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mostrando ${inv.products.length} de ${inv.totalCount} productos',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6C757D),
                          ),
                        ),
                        if (inv.searchQuery.isNotEmpty)
                          const Text(
                            'Filtro activo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Lista paginada de 20 en 20
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                widget.inventoryProvider,
                widget.bcvProvider,
              ]),
              builder: (context, _) {
                final inv = widget.inventoryProvider;
                final rate = widget.bcvProvider.rate;

                if (inv.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (inv.products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            inv.searchQuery.isEmpty
                                ? 'Aún no hay productos registrados.\nPulsa "+ Nuevo" para agregar el primero.'
                                : 'No se encontraron productos para "${inv.searchQuery}".',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          if (inv.searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                ProductFormSheet.show(
                                  context,
                                  inventoryProvider: inv,
                                  bcvRate: rate,
                                  initialBarcode: inv.searchQuery,
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Registrar este código'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  itemCount: inv.products.length + (inv.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= inv.products.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      );
                    }

                    final product = inv.products[index];
                    return ProductRowTile(
                      product: product,
                      bcvRate: rate,
                      onTap: () => ProductFormSheet.show(
                        context,
                        inventoryProvider: inv,
                        bcvRate: rate,
                        existingProduct: product,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ProductFormSheet.show(
          context,
          inventoryProvider: widget.inventoryProvider,
          bcvRate: widget.bcvProvider.rate,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
    );
  }
}