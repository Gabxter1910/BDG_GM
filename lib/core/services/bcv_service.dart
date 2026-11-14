import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../utils/currency_formatter.dart';

class BcvResult {
  final double rate;
  final String lastUpdated;
  final bool isFromCache;
  final String? errorMessage;

  const BcvResult({
    required this.rate,
    required this.lastUpdated,
    this.isFromCache = false,
    this.errorMessage,
  });
}

class BcvService {
  Future<BcvResult> getCachedRate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRate =
        prefs.getDouble(AppConstants.prefBcvRate) ?? AppConstants.defaultFallbackRate;
    final savedDate =
        prefs.getString(AppConstants.prefBcvLastUpdate) ?? 'Sin sincronizar (Valor base)';

    return BcvResult(
      rate: savedRate,
      lastUpdated: savedDate,
      isFromCache: true,
    );
  }

  Future<BcvResult> fetchAndCacheOfficialRate() async {
    try {
      final response = await http
          .get(Uri.parse(AppConstants.bcvApiUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final rawRate =
            (data['promedio'] as num?)?.toDouble() ?? (data['venta'] as num?)?.toDouble();

        if (rawRate != null && rawRate > 0) {
          final cleanRate = CurrencyFormatter.roundFour(rawRate);
          final timestamp = _buildFormattedNow();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(AppConstants.prefBcvRate, cleanRate);
          await prefs.setString(AppConstants.prefBcvLastUpdate, timestamp);

          return BcvResult(
            rate: cleanRate,
            lastUpdated: timestamp,
            isFromCache: false,
          );
        }
      }

      final cached = await getCachedRate();
      return BcvResult(
        rate: cached.rate,
        lastUpdated: cached.lastUpdated,
        isFromCache: true,
        errorMessage: 'Respuesta inválida del servidor BCV (${response.statusCode}).',
      );
    } catch (_) {
      final cached = await getCachedRate();
      return BcvResult(
        rate: cached.rate,
        lastUpdated: cached.lastUpdated,
        isFromCache: true,
        errorMessage: 'Sin conexión. Usando última tasa guardada.',
      );
    }
  }

  Future<BcvResult> saveManualRate(double manualRate) async {
    final cleanRate = CurrencyFormatter.roundFour(manualRate);
    final timestamp = '${_buildFormattedNow()} (Manual)';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.prefBcvRate, cleanRate);
    await prefs.setString(AppConstants.prefBcvLastUpdate, timestamp);

    return BcvResult(
      rate: cleanRate,
      lastUpdated: timestamp,
      isFromCache: false,
    );
  }

  String _buildFormattedNow() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}