import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/empty_state.dart';

class StoresListScreen extends ConsumerWidget {
  const StoresListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Magasins'),
        centerTitle: false,
        scrolledUnderElevation: 3,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_stores_list',
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Ajouter'),
        onPressed: () => _showStoreDialog(context, db, null),
      ),
      body: StreamBuilder<List<Store>>(
        stream: db.watchAllStores(),
        builder: (context, snapshot) {
          final stores = snapshot.data ?? [];
          if (stores.isEmpty) {
            return const EmptyState(
              icon: Icons.store_outlined,
              title: 'Aucun magasin',
              subtitle: 'Ajoutez vos magasins habituels pour comparer les prix',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.store_outlined,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  title: Text(store.name, style: tt.bodyLarge),
                  subtitle: store.location != null
                      ? Text(
                          store.location!,
                          style:
                              tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showStoreDialog(context, db, store),
                        tooltip: 'Modifier',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: cs.error),
                        onPressed: () => _deleteStore(context, db, store),
                        tooltip: 'Supprimer',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showStoreDialog(BuildContext context, AppDatabase db, Store? store) {
    final nameController = TextEditingController(text: store?.name);
    final locationController = TextEditingController(text: store?.location);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(store == null ? Icons.add_business_outlined : Icons.edit_outlined),
        title: Text(store == null ? 'Nouveau magasin' : 'Modifier le magasin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store_outlined),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Adresse (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              if (store == null) {
                await db.insertStore(StoresCompanion.insert(
                  name: name,
                  location: Value(locationController.text.trim().isEmpty
                      ? null
                      : locationController.text.trim()),
                ));
              } else {
                await db.updateStore(store.copyWith(
                  name: name,
                  location: Value(locationController.text.trim().isEmpty
                      ? null
                      : locationController.text.trim()),
                ));
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                messenger.showSnackBar(SnackBar(
                  content: Text(store == null ? 'Magasin ajouté' : 'Magasin modifié'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _deleteStore(BuildContext context, AppDatabase db, Store store) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: cs.error),
        title: const Text('Supprimer ce magasin ?'),
        content: Text('Supprimer "${store.name}" supprimera également tous les prix associés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              await db.deleteStore(store.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Supprimer', style: TextStyle(color: cs.onError)),
          ),
        ],
      ),
    );
  }
}
