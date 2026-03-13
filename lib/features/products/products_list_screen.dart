import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/extensions/double_extensions.dart';
import '../../core/widgets/empty_state.dart';
import '../scan/scan_bottom_sheet.dart';

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final cheapestPrices = ref.watch(cheapestPricesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('JeSuisRadin'),
        centerTitle: false,
        scrolledUnderElevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/scan-receipt'),
            tooltip: 'Scanner un ticket',
          ),
          IconButton(
            icon: const Icon(Icons.store_outlined),
            onPressed: () => context.push('/stores'),
            tooltip: 'Magasins',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Paramètres',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_products_list',
        onPressed: () => showScanBottomSheet(context),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scanner'),
      ),
      body: StreamBuilder<List<Product>>(
        stream: db.watchAllProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Aucun produit scanné',
              subtitle: 'Scannez un produit pour commencer à comparer les prix',
            );
          }
          final pricesMap = cheapestPrices.valueOrNull ?? {};
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final cs = Theme.of(context).colorScheme;
              return Dismissible(
                key: ValueKey(product.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      icon: Icon(Icons.delete_outline, color: cs.error),
                      title: const Text('Supprimer ce produit ?'),
                      content: Text(
                        'Le produit "${product.name}" et tous ses prix seront supprimés définitivement.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: cs.error),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Supprimer', style: TextStyle(color: cs.onError)),
                        ),
                      ],
                    ),
                  ) ?? false;
                },
                onDismissed: (_) => db.deleteProduct(product.id),
                child: _ProductCard(
                  product: product,
                  cheapest: pricesMap[product.id],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final PriceWithStore? cheapest;

  const _ProductCard({required this.product, required this.cheapest});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/products/${product.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 56,
                  height: 56,
                  color: cs.surfaceContainerHighest,
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.inventory_2_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: tt.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.brand != null || product.quantity != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        [product.brand, product.quantity]
                            .where((e) => e != null)
                            .join(' · '),
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Cheapest price badge
              cheapest == null
                  ? Icon(Icons.chevron_right, color: cs.onSurfaceVariant)
                  : _PriceBadge(cheapest: cheapest!, cs: cs, tt: tt),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final PriceWithStore cheapest;
  final ColorScheme cs;
  final TextTheme tt;

  const _PriceBadge({
    required this.cheapest,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            cheapest.price.price.formatPrice(),
            style: tt.labelLarge?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            cheapest.store.name,
            style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

