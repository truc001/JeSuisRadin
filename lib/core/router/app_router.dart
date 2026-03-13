import 'package:go_router/go_router.dart';
import '../../features/scan/add_price_screen.dart';
import '../../features/scan/receipt_scanner_screen.dart';
import '../../features/products/products_list_screen.dart';
import '../../features/products/product_detail_screen.dart';
import '../../features/stores/stores_list_screen.dart';
import '../../features/shopping_list/shopping_list_screen.dart';
import '../../features/shopping_list/shopping_list_comparison_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/products/price_history_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/products',
  routes: [
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsListScreen(),
      routes: [
        GoRoute(
          path: 'add-price',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return AddPriceScreen(
              barcode: extra['barcode'] as String,
              productName: extra['productName'] as String?,
              productId: extra['productId'] as int?,
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => ProductDetailScreen(
            productId: int.parse(state.pathParameters['id']!),
          ),
          routes: [
            GoRoute(
              path: 'history',
              builder: (context, state) => PriceHistoryScreen(
                productId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/scan-receipt',
      builder: (context, state) => const ReceiptScannerScreen(),
    ),
    GoRoute(
      path: '/stores',
      builder: (context, state) => const StoresListScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/lists',
      builder: (context, state) => const ShoppingListScreen(),
      routes: [
        GoRoute(
          path: ':id/compare',
          builder: (context, state) => ShoppingListComparisonScreen(
            listId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ],
    ),
  ],
);
