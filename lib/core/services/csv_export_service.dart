import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../utils/currency_formatter.dart';

class CsvExportService {
  Future<int> exportAndShareInventory(double currentBcvRate) async {
    final products = await DbHelper.instance.getAllProductsForExport();

    final buffer = StringBuffer();
    // Cabecera compatible con Excel y Google Sheets
    buffer.writeln(
      'ID,Codigo_Barras,Nombre,Precio_USD,Precio_Bs_Ref,Stock,Ultima_Actualizacion',
    );

    for (final item in products) {
      final barcode = _escapeCsv(item.barcode ?? '');
      final name = _escapeCsv(item.name);
      final usd = item.priceUsd.toStringAsFixed(2);
      final bs = CurrencyFormatter.usdToBs(item.priceUsd, currentBcvRate)
          .toStringAsFixed(2);
      final updated = _escapeCsv(item.updatedAt);

      buffer.writeln(
        '${item.id ?? ''},$barcode,$name,$usd,$bs,${item.stock},$updated',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filePath = p.join(tempDir.path, 'respaldo_bdg_gm_$stamp.csv');

    final file = File(filePath);
    // Agregamos BOM UTF-8 (\uFEFF) para evitar caracteres rotos en Excel
    final bytes = utf8.encode('\uFEFF${buffer.toString()}');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Respaldo de inventario BDG_GM (${products.length} productos)',
    );

    return products.length;
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}