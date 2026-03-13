import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/empty_state.dart';

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listes de courses'),
        centerTitle: false,
        scrolledUnderElevation: 3,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_shopping_lists',
        icon: const Icon(Icons.playlist_add),
        label: const Text('Nouvelle liste'),
        onPressed: () => _createList(context, db),
      ),
      body: StreamBuilder<List<ShoppingList>>(
        stream: db.watchAllShoppingLists(),
        builder: (context, snapshot) {
          final lists = snapshot.data ?? [];
          if (lists.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Aucune liste de courses',
              subtitle: 'Créez une liste pour comparer les prix totaux par magasin',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: list.isActive
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      list.isActive
                          ? Icons.shopping_cart_outlined
                          : Icons.check_circle_outline,
                      color: list.isActive
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  title: Text(list.name, style: tt.bodyLarge),
                  subtitle: Text(
                    list.isActive ? 'En cours' : 'Terminée',
                    style: tt.labelSmall?.copyWith(
                      color: list.isActive ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.compare_arrows_rounded),
                        onPressed: () => context.push('/lists/${list.id}/compare'),
                        tooltip: 'Comparer les prix',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        onPressed: () => _confirmDelete(context, db, list),
                      ),
                    ],
                  ),
                  onTap: () => _openList(context, db, list),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _createList(BuildContext context, AppDatabase db) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.playlist_add),
        title: const Text('Nouvelle liste'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom de la liste',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.shopping_cart_outlined),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await db.insertShoppingList(ShoppingListsCompanion.insert(
                  name: controller.text.trim(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppDatabase db, ShoppingList list) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: cs.error),
        title: const Text('Supprimer cette liste ?'),
        content: Text('La liste "${list.name}" sera supprimée définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              await db.deleteShoppingList(list.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Supprimer', style: TextStyle(color: cs.onError)),
          ),
        ],
      ),
    );
  }

  void _openList(BuildContext context, AppDatabase db, ShoppingList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ShoppingListDetailScreen(list: list, db: db),
      ),
    );
  }
}

class _ShoppingListDetailScreen extends ConsumerStatefulWidget {
  final ShoppingList list;
  final AppDatabase db;

  const _ShoppingListDetailScreen({required this.list, required this.db});

  @override
  ConsumerState<_ShoppingListDetailScreen> createState() =>
      _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState
    extends ConsumerState<_ShoppingListDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list.name),
        centerTitle: false,
        scrolledUnderElevation: 3,
        actions: [
          FilledButton.tonal(
            onPressed: () =>
                context.push('/lists/${widget.list.id}/compare'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.compare_arrows_rounded, size: 18),
                SizedBox(width: 6),
                Text('Comparer'),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<ShoppingListItemWithProduct>>(
        stream: widget.db.watchItemsForList(widget.list.id),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.add_shopping_cart_outlined,
              title: 'Liste vide',
              subtitle: 'Ajoutez des produits pour comparer les prix',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: item.product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.inventory_2_outlined,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                  ),
                  title: Text(item.product.name, style: tt.bodyLarge),
                  subtitle: item.product.brand != null
                      ? Text(
                          item.product.brand!,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        style: IconButton.styleFrom(
                          foregroundColor: cs.onSurfaceVariant,
                        ),
                        onPressed: item.item.quantity <= 1
                            ? null
                            : () => widget.db.updateShoppingListItem(
                                  item.item.copyWith(
                                      quantity: item.item.quantity - 1),
                                ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item.item.quantity}',
                          style: tt.titleSmall?.copyWith(
                              color: cs.onSecondaryContainer),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          foregroundColor: cs.primary,
                        ),
                        onPressed: () => widget.db.updateShoppingListItem(
                          item.item
                              .copyWith(quantity: item.item.quantity + 1),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        onPressed: () => widget.db
                            .deleteShoppingListItem(item.item.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_shopping_list_detail',
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un produit'),
        onPressed: () => _addProduct(context),
      ),
    );
  }

  void _addProduct(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final products = await widget.db.getAllProducts();
    if (!context.mounted) return;

    if (products.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Aucun produit. Scannez d\'abord un produit.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un produit'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (_, i) => ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: products[i].imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          products[i].imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
              ),
              title: Text(products[i].name, style: tt.bodyMedium),
              onTap: () async {
                await widget.db.insertShoppingListItem(
                  ShoppingListItemsCompanion.insert(
                    listId: widget.list.id,
                    productId: products[i].id,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
