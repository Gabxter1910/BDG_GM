import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'providers/bcv_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/inventory_provider.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final bcvProvider = BcvProvider()..init();
  final inventoryProvider = InventoryProvider()..loadInitial();
  final cartProvider = CartProvider();

  runApp(
    BdgGmApp(
      bcvProvider: bcvProvider,
      inventoryProvider: inventoryProvider,
      cartProvider: cartProvider,
    ),
  );
}

class BdgGmApp extends StatelessWidget {
  final BcvProvider bcvProvider;
  final InventoryProvider inventoryProvider;
  final CartProvider cartProvider;

  const BdgGmApp({
    super.key,
    required this.bcvProvider,
    required this.inventoryProvider,
    required this.cartProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          brightness: Brightness.light,
        ),
        // Desactiva animaciones pesadas de transición para fluidez en gama baja
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: HomeShell(
        bcvProvider: bcvProvider,
        inventoryProvider: inventoryProvider,
        cartProvider: cartProvider,
      ),
    );
  }
}