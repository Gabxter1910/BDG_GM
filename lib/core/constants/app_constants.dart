class AppConstants {
  static const String appName = 'BDG_GM';
  static const String dbName = 'bdg_gm_inventory.db';
  static const int dbVersion = 1;

  // Paginación estricta de 20 en 20 para bajo consumo de RAM
  static const int pageSize = 20;

  // Umbral por defecto para alerta de stock bajo en Utilidades
  static const int defaultLowStockThreshold = 5;

  // Endpoint JSON oficial BCV (ligero y rápido)
  static const String bcvApiUrl = 'https://ve.dolarapi.com/v1/dolares/oficial';

  // Claves de SharedPreferences
  static const String prefBcvRate = 'bcv_rate';
  static const String prefBcvLastUpdate = 'bcv_last_update';
  static const double defaultFallbackRate = 50.00;
}