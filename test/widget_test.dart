// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bdg_gm/main.dart';
import 'package:bdg_gm/providers/bcv_provider.dart';
import 'package:bdg_gm/providers/cart_provider.dart';
import 'package:bdg_gm/providers/inventory_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shows inventory home screen', (WidgetTester tester) async {
    final bcvProvider = BcvProvider();
    final inventoryProvider = InventoryProvider();
    final cartProvider = CartProvider();
    addTearDown(bcvProvider.dispose);
    addTearDown(inventoryProvider.dispose);
    addTearDown(cartProvider.dispose);

    await tester.pumpWidget(
      BdgGmApp(
        bcvProvider: bcvProvider,
        inventoryProvider: inventoryProvider,
        cartProvider: cartProvider,
      ),
    );

    expect(find.text('BDG_GM'), findsOneWidget);
    expect(find.text('Inventario'), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}
