import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product_model.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/barcode_scanner_modal.dart';

class ProductFormSheet extends StatefulWidget {
  final InventoryProvider inventoryProvider;
  final double bcvRate;
  final Product? existingProduct;
  final String? initialBarcode;

  const ProductFormSheet({
    super.key,
    required this.inventoryProvider,
    required this.bcvRate,
    this.existingProduct,
    this.initialBarcode,
  });

  static Future<void> show(
    BuildContext context, {
    required InventoryProvider inventoryProvider,
    required double bcvRate,
    Product? existingProduct,
    String? initialBarcode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ProductFormSheet(
        inventoryProvider: inventoryProvider,
        bcvRate: bcvRate,
        existingProduct: existingProduct,
        initialBarcode: initialBarcode,
      ),
    );
  }

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;

  bool _inputInUsd = true;
  bool _isSaving = false;

  bool get _isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(
      text: p?.barcode ?? widget.initialBarcode ?? '',
    );
    _priceCtrl = TextEditingController(
      text: p != null ? p.priceUsd.toStringAsFixed(2) : '',
    );
    _stockCtrl = TextEditingController(
      text: p != null ? p.stock.toString() : '0',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  double _parseInputAmount() {
    final normalized = _priceCtrl.text.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  double _computedUsdPrice() {
    final raw = _parseInputAmount();
    if (raw <= 0) return 0.0;
    return _inputInUsd
        ? CurrencyFormatter.roundTwo(raw)
        : CurrencyFormatter.bsToUsd(raw, widget.bcvRate);
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerModal.scan(
      context,
      title: 'Escanear código del producto',
    );
    if (code != null && mounted) {
      setState(() {
        _barcodeCtrl.text = code;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    final usdPrice = _computedUsdPrice();
    if (usdPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un precio válido mayor a 0.')),
      );
      return;
    }

    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final updated = widget.existingProduct!.copyWith(
          name: _nameCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim(),
          priceUsd: usdPrice,
          stock: stock < 0 ? 0 : stock,
        );
        await widget.inventoryProvider.updateProduct(updated);
      } else {
        await widget.inventoryProvider.addProduct(
          name: _nameCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim(),
          priceUsd: usdPrice,
          stock: stock < 0 ? 0 : stock,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final product = widget.existingProduct;
    if (product?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Seguro que deseas eliminar "${product!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.inventoryProvider.deleteProduct(product!.id!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final rawAmount = _parseInputAmount();
    final anchoredUsd = _computedUsdPrice();
    final previewBs = CurrencyFormatter.usdToBs(anchoredUsd, widget.bcvRate);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Editar producto' : 'Nuevo producto',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_isEditing)
                    IconButton(
                      tooltip: 'Eliminar producto',
                      onPressed: _confirmDelete,
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Nombre del producto
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Escribe el nombre del artículo'
                    : null,
              ),
              const SizedBox(height: 12),

              // Código de barras / QR + Escáner
              TextFormField(
                controller: _barcodeCtrl,
                decoration: InputDecoration(
                  labelText: 'Código de barras / QR (opcional)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'Escanear código',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Selector de moneda de ingreso (USD o Bs)
              Row(
                children: [
                  const Text(
                    'Ingresar monto en:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(value: true, label: Text('USD (\$)')),
                        ButtonSegment<bool>(value: false, label: Text('Bs.')),
                      ],
                      selected: {_inputInUsd},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _inputInUsd = selection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Precio y Stock en fila
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: _inputInUsd ? 'Precio USD *' : 'Precio Bs *',
                        prefixText: _inputInUsd ? '\$ ' : 'Bs. ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (val) {
                        final parsed = double.tryParse(
                          (val ?? '').trim().replaceAll(',', '.'),
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Monto inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (val) {
                        final parsed = int.tryParse((val ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              // Vista previa del valor anclado en USD y equivalente en Bs
              if (rawAmount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Base anclada: ${CurrencyFormatter.formatUsd(anchoredUsd)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      Text(
                        'Ref: ${CurrencyFormatter.formatBs(previewBs)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isEditing ? 'Guardar cambios' : 'Registrar producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}