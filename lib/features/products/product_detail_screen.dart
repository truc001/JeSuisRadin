import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/extensions/double_extensions.dart';
import '../../core/api/open_prices_client.dart';
import '../scan/add_price_bottom_sheet.dart';

class ProductDetailScreen extends ConsumerWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<Product?>(
        stream: db.watchProductById(productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final product = snapshot.data;
          if (product == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Produit introuvable')),
            );
          }

          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'fab_product_detail',
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un prix'),
              onPressed: () => showAddPriceBottomSheet(
                context,
                productId: productId,
                productName: product.name,
              ),
            ),
            body: CustomScrollView(
              slivers: [
                _ProductAppBar(product: product, productId: productId),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _BestPriceSection(db: db, productId: productId),
                      const SizedBox(height: 24),
                      _AllPricesSection(db: db, productId: productId, cs: cs),
                      const SizedBox(height: 24),
                      _OpenPricesSection(barcode: product.barcode, cs: cs),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      );
  }
}

class _OpenPricesSection extends StatefulWidget {
  final String? barcode;
  final ColorScheme cs;

  const _OpenPricesSection({required this.barcode, required this.cs});

  @override
  State<_OpenPricesSection> createState() => _OpenPricesSectionState();
}

class _OpenPricesSectionState extends State<_OpenPricesSection> {
  late Future<List<OpenPrice>> _pricesFuture;
  final _client = OpenPricesClient();

  @override
  void initState() {
    super.initState();
    _pricesFuture = widget.barcode != null
        ? _client.fetchPrices(widget.barcode!)
        : Future.value([]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.barcode == null) return const SizedBox.shrink();

    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.public_outlined, size: 18, color: widget.cs.tertiary),
            const SizedBox(width: 8),
            Text(
              'Prix communautaires (Open Food Facts)',
              style: tt.titleMedium?.copyWith(color: widget.cs.tertiary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<OpenPrice>>(
          future: _pricesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final prices = snapshot.data ?? [];
            if (prices.isEmpty) {
              return Text(
                'Aucun prix communautaire trouvé (moins de 60 jours)',
                style: tt.bodyMedium?.copyWith(color: widget.cs.onSurfaceVariant),
              );
            }

            return Card(
              color: widget.cs.tertiaryContainer.withValues(alpha: 0.3),
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: widget.cs.tertiary.withValues(alpha: 0.2)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: prices.length > 3 ? 3 : prices.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final price = prices[index];
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              price.storeName ?? 'Magasin inconnu',
                              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (price.address != null || price.city != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  [price.address, price.city]
                                      .whereType<String>()
                                      .join(', '),
                                  style: tt.labelSmall?.copyWith(
                                    color: widget.cs.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Text(
                              DateFormat('dd/MM/yyyy').format(price.date),
                              style: tt.labelSmall?.copyWith(color: widget.cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${price.price.toStringAsFixed(2)} ${price.currency == 'EUR' ? '€' : price.currency}',
                        style: tt.titleMedium?.copyWith(
                          color: widget.cs.tertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ProductAppBar extends StatelessWidget {
  final Product product;
  final int productId;

  const _ProductAppBar({required this.product, required this.productId});

  void _confirmDelete(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final db = ProviderScope.containerOf(context).read(databaseProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: cs.error),
        title: const Text('Supprimer ce produit ?'),
        content: Text(
          'Le produit "${product.name}" et tous ses prix seront supprimés définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              await db.deleteProduct(productId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                context.go('/products');
              }
            },
            child: Text('Supprimer', style: TextStyle(color: cs.onError)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SliverAppBar(
      expandedHeight: product.imageUrl != null ? 240 : null,
      pinned: true,
      scrolledUnderElevation: 3,
      actions: [
        IconButton(
          icon: const Icon(Icons.show_chart),
          onPressed: () => context.push('/products/$productId/history'),
          tooltip: 'Historique des prix',
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: cs.error),
          onPressed: () => _confirmDelete(context),
          tooltip: 'Supprimer le produit',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: product.imageUrl != null
          ? FlexibleSpaceBar(
              background: Image.network(
                product.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: cs.surfaceContainerHighest,
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: tt.titleMedium?.copyWith(color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.brand != null)
                      Text(
                        product.brand!,
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            )
          : FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(72, 0, 56, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: tt.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.brand != null)
                    Text(
                      product.brand!,
                      style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
    );
  }
}

class _BestPriceSection extends StatelessWidget {
  final AppDatabase db;
  final int productId;

  const _BestPriceSection({required this.db, required this.productId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_offer_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Meilleur prix',
              style: tt.titleMedium?.copyWith(color: cs.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<PriceWithStore?>(
          stream: db.watchCheapestStore(productId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final cheapest = snapshot.data;
            if (cheapest == null) {
              return Card(
                color: cs.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(
                        'Aucun prix enregistré',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.star_rounded, color: cs.onPrimary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cheapest.price.price.formatPrice(),
                            style: tt.headlineSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            cheapest.store.name,
                            style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yy').format(cheapest.price.date),
                      style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AllPricesSection extends StatelessWidget {
  final AppDatabase db;
  final int productId;
  final ColorScheme cs;

  const _AllPricesSection({
    required this.db,
    required this.productId,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storefront_outlined, size: 18, color: cs.secondary),
            const SizedBox(width: 8),
            Text(
              'Prix par magasin',
              style: tt.titleMedium?.copyWith(color: cs.secondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<PriceWithStore>>(
          stream: db.watchPricesForProduct(productId),
          builder: (context, snapshot) {
            final prices = snapshot.data ?? [];
            if (prices.isEmpty) {
              return Text(
                'Aucun prix enregistré',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              );
            }
            return Column(
              children: prices.asMap().entries.map((entry) {
                final i = entry.key;
                final pws = entry.value;
                return Column(
                  children: [
                    Dismissible(
                      key: ValueKey(pws.price.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
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
                            title: const Text('Supprimer ce prix ?'),
                            content: Text(
                              'Le prix chez "${pws.store.name}" sera supprimé.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Annuler'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: cs.error),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('Supprimer',
                                    style: TextStyle(color: cs.onError)),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (_) => db.deletePrice(pws.price.id),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.store_outlined,
                              size: 20,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pws.store.name, style: tt.bodyLarge),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(pws.price.date),
                                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            pws.price.price.formatPrice(),
                            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (i < prices.length - 1)
                      Divider(
                        height: 24,
                        indent: 52,
                        color: cs.outlineVariant,
                      ),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
