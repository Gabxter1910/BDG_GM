import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../providers/bcv_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/inventory_provider.dart';
import 'inventory/inventory_screen.dart';
import 'pos/pos_screen.dart';
import 'utilities/utilities_screen.dart';

class HomeShell extends StatefulWidget {
  final BcvProvider bcvProvider;
  final InventoryProvider inventoryProvider;
  final CartProvider cartProvider;

  const HomeShell({
    super.key,
    required this.bcvProvider,
    required this.inventoryProvider,
    required this.cartProvider,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget activeScreen;
    switch (_selectedIndex) {
      case 0:
        activeScreen = InventoryScreen(
          inventoryProvider: widget.inventoryProvider,
          bcvProvider: widget.bcvProvider,
        );
        break;
      case 1:
        activeScreen = PosScreen(
          cartProvider: widget.cartProvider,
          bcvProvider: widget.bcvProvider,
          inventoryProvider: widget.inventoryProvider,
        );
        break;
      default:
        activeScreen = UtilitiesScreen(
          bcvProvider: widget.bcvProvider,
          cartProvider: widget.cartProvider,
        );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Indicador permanente de tasa BCV activa (tocar lleva a Utilidades)
          ListenableBuilder(
            listenable: widget.bcvProvider,
            builder: (_, __) {
              final bcv = widget.bcvProvider;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ActionChip(
                  backgroundColor: const Color(0xFF1565C0),
                  side: BorderSide.none,
                  avatar: bcv.isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.currency_exchange,
                          size: 16,
                          color: Colors.white,
                        ),
                  label: Text(
                    'BCV: Bs. ${bcv.rate.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _selectedIndex = 2);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: activeScreen,
      bottomNavigationBar: ListenableBuilder(
        listenable: widget.cartProvider,
        builder: (_, __) {
          final units = widget.cartProvider.totalUnits;
          return NavigationBar(
            selectedIndex: _selectedIndex,
            height: 64,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Inventario',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: units > 0,
                  label: Text('$units'),
                  child: const Icon(Icons.point_of_sale_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: units > 0,
                  label: Text('$units'),
                  child: const Icon(Icons.point_of_sale),
                ),
                label: 'Caja',
              ),
              const NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: 'Utilidades',
              ),
            ],
          );
        },
      ),
    );
  }
}