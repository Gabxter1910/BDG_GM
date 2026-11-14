import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/services/bcv_service.dart';

class BcvProvider extends ChangeNotifier {
  final BcvService _bcvService = BcvService();

  double _rate = AppConstants.defaultFallbackRate;
  String _lastUpdated = 'Cargando...';
  bool _isLoading = false;
  bool _isFromCache = true;
  String? _statusMessage;

  double get rate => _rate;
  String get lastUpdated => _lastUpdated;
  bool get isLoading => _isLoading;
  bool get isFromCache => _isFromCache;
  String? get statusMessage => _statusMessage;

  /// Carga instantánea desde disco y actualización automática en segundo plano
  Future<void> init() async {
    final cached = await _bcvService.getCachedRate();
    _rate = cached.rate;
    _lastUpdated = cached.lastUpdated;
    _isFromCache = cached.isFromCache;
    notifyListeners();

    await refreshFromApi();
  }

  Future<bool> refreshFromApi() async {
    _isLoading = true;
    _statusMessage = null;
    notifyListeners();

    final result = await _bcvService.fetchAndCacheOfficialRate();
    _rate = result.rate;
    _lastUpdated = result.lastUpdated;
    _isFromCache = result.isFromCache;
    _statusMessage = result.errorMessage;
    _isLoading = false;
    notifyListeners();

    return result.errorMessage == null;
  }

  Future<bool> updateManualRate(double newRate) async {
    if (newRate <= 0) return false;

    final result = await _bcvService.saveManualRate(newRate);
    _rate = result.rate;
    _lastUpdated = result.lastUpdated;
    _isFromCache = false;
    _statusMessage = null;
    notifyListeners();
    return true;
  }
}