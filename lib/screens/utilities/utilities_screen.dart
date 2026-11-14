import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/db_helper.dart';
import '../../core/services/csv_export_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product_model.dart';
import '../../providers/bcv_provider.dart';
import '../../providers/cart_provider.dart';

class UtilitiesScreen extends StatefulWidget {
  final BcvProvider bcvProvider;
  final CartProvider cartProvider;

  const UtilitiesScreen({
    super.key,
    required this.bcvProvider,
    required this.cartProvider,
  });

  @override
  State<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends State<UtilitiesScreen> {
  // Controladores de la calculadora de pago mixto / vuelto
  final TextEditingController _totalChargeCtrl = TextEditingController();
  final TextEditingController _paidUsdCtrl = TextEditingController();
  final TextEditingController _paidBsCtrl = TextEditingController();
  bool _chargeInUsd = true;

  // Estado de stock bajo
  int _lowStockThreshold = AppConstants.defaultLowStockThreshold;
  List<Product> _lowStockProducts = [];
  bool _loadingLowStock = true;

  // Estado de exportación CSV
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadLowStock();
  }

  @override
  void dispose() {
    _totalChargeCtrl.dispose();
    _paidUsdCtrl.dispose();
    _paidBsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLowStock() async {
    setState(() => _loadingLowStock = true);
    final items = await DbHelper.instance.getLowStockProducts(
      threshold: _lowStockThreshold,
    );
    if (mounted) {
      setState(() {
        _lowStockProducts = items;
        _loadingLowStock = false;
      });
    }
  }

  double _parse(TextEditingController ctrl) {
    return double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 0.0;
  }

  Future<void> _showManualRateDialog() async {
    final ctrl = TextEditingController(
      text: widget.bcvProvider.rate.toStringAsFixed(2),
    );

    final newRate = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar tasa BCV manual'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Tasa (Bs. por 1 USD)',
            prefixText: 'Bs. ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                ctrl.text.trim().replaceAll(',', '.'),
              );
              if (parsed != null && parsed > 0) {
                Navigator.of(ctx).pop(parsed);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (newRate != null && mounted) {
      await widget.bcvProvider.updateManualRate(newRate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tasa BCV manual actualizada.')),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final exporter = CsvExportService();
      final count = await exporter.exportAndShareInventory(
        widget.bcvProvider.rate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Respaldo CSV generado ($count productos).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.bcvProvider,
          widget.cartProvider,
        ]),
        builder: (context, _) {
          final bcv = widget.bcvProvider;
          final rate = bcv.rate;

          // Cálculos en vivo de pago mixto
          final rawCharge = _parse(_totalChargeCtrl);
          final totalDueUsd = _chargeInUsd
              ? CurrencyFormatter.roundTwo(rawCharge)
              : CurrencyFormatter.bsToUsd(rawCharge, rate);

          final paidUsd = _parse(_paidUsdCtrl);
          final paidBs = _parse(_paidBsCtrl);
          final paidBsInUsd = CurrencyFormatter.bsToUsd(paidBs, rate);
          final totalPaidUsd = CurrencyFormatter.roundTwo(paidUsd + paidBsInUsd);
          final diffUsd = CurrencyFormatter.roundTwo(totalPaidUsd - totalDueUsd);
          final diffBs = CurrencyFormatter.usdToBs(diffUsd.abs(), rate);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // 1. SECCIÓN TASA BCV
              _SectionCard(
                title: 'Tasa de Cambio BCV',
                icon: Icons.currency_exchange,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bs. ${rate.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: bcv.isFromCache
                                ? const Color(0xFFFFF8E1)
                                : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            bcv.isFromCache ? 'Caché / Local' : 'Sincronizada',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: bcv.isFromCache
                                  ? const Color(0xFFEF6C00)
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Actualización: ${bcv.lastUpdated}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (bcv.statusMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        bcv.statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: bcv.isLoading
                                ? null
                                : () async {
                                    final ok = await bcv.refreshFromApi();
                                  if (context.mounted && ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Tasa BCV actualizada desde API.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            icon: bcv.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.sync, size: 18),
                            label: const Text('Actualizar API'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showManualRateDialog,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Editar manual'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. CALCULADORA DE PAGO MIXTO Y VUELTO (USD / BS)
              _SectionCard(
                title: 'Calculadora Pago Mixto y Vuelto',
                icon: Icons.calculate_outlined,
                trailing: widget.cartProvider.totalUsd > 0
                    ? TextButton(
                        onPressed: () {
                          setState(() {
                            _chargeInUsd = true;
                            _totalChargeCtrl.text =
                                widget.cartProvider.totalUsd.toStringAsFixed(2);
                          });
                        },
                        child: const Text('Usar total Caja'),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _totalChargeCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Total a cobrar',
                              prefixText: _chargeInUsd ? '\$ ' : 'Bs. ',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('USD')),
                              ButtonSegment(value: false, label: Text('Bs')),
                            ],
                            selected: {_chargeInUsd},
                            onSelectionChanged: (s) {
                              setState(() => _chargeInUsd = s.first);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _paidUsdCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Recibido USD',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _paidBsCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Recibido Bs.',
                              prefixText: 'Bs. ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (totalDueUsd > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: diffUsd >= 0
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              diffUsd >= 0
                                  ? 'VUELTO A ENTREGAR:'
                                  : 'FALTA POR COBRAR:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: diffUsd >= 0
                                    ? const Color(0xFF1B5E20)
                                    : const Color(0xFFB71C1C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  CurrencyFormatter.formatUsd(diffUsd.abs()),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatBs(diffBs),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_totalChargeCtrl.text.isNotEmpty ||
                        _paidUsdCtrl.text.isNotEmpty ||
                        _paidBsCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            _totalChargeCtrl.clear();
                            _paidUsdCtrl.clear();
                            _paidBsCtrl.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Limpiar calculadora'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. VISTA RÁPIDA DE STOCK BAJO
              _SectionCard(
                title: 'Alerta de Stock Bajo (≤ $_lowStockThreshold unid.)',
                icon: Icons.warning_amber_rounded,
                trailing: IconButton(
                  tooltip: 'Recargar lista',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadLowStock,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Umbral:',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        for (final val in [3, 5, 10]) ...[
                          ChoiceChip(
                            label: Text('≤ $val'),
                            selected: _lowStockThreshold == val,
                            onSelected: (_) {
                              _lowStockThreshold = val;
                              _loadLowStock();
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingLowStock)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_lowStockProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No hay productos con stock bajo en este umbral.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _lowStockProducts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final item = _lowStockProducts[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.stock == 0
                                          ? const Color(0xFFFFEBEE)
                                          : const Color(0xFFFFF8E1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Stock: ${item.stock}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: item.stock == 0
                                            ? const Color(0xFFC62828)
                                            : const Color(0xFFEF6C00),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. EXPORTACIÓN DE RESPALDO EN CSV
              _SectionCard(
                title: 'Respaldo de Inventario (CSV)',
                icon: Icons.file_download_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Exporta todos tus productos con códigos, precios anclados en USD, referencia en Bs y existencias para abrir en Excel o enviar por WhatsApp/Correo.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isExporting ? null : _exportCsv,
                      icon: const Icon(Icons.share_outlined),
                      label: Text(
                        _isExporting
                            ? 'Generando archivo...'
                            : 'Exportar y compartir CSV',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const Divider(height: 18),
          child,
        ],
      ),
    );
  }
}