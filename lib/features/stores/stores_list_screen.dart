import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:geolocator/geolocator.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/location_service.dart';

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
        onPressed: () => _showStoreDialog(context, ref, db, null),
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
              final hasGps = store.latitude != null && store.longitude != null;
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (store.location != null)
                        Text(
                          store.location!,
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      if (hasGps)
                        Row(
                          children: [
                            Icon(Icons.my_location, size: 12, color: cs.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Position GPS enregistrée',
                              style: tt.labelSmall?.copyWith(color: cs.primary),
                            ),
                          ],
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showStoreDialog(context, ref, db, store),
                        tooltip: 'Modifier',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error),
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

  void _showStoreDialog(BuildContext context, WidgetRef ref, AppDatabase db, Store? store) {
    showDialog(
      context: context,
      builder: (ctx) => _StoreDialog(db: db, store: store, ref: ref),
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

class _StoreDialog extends StatefulWidget {
  final AppDatabase db;
  final Store? store;
  final WidgetRef ref;

  const _StoreDialog({required this.db, required this.store, required this.ref});

  @override
  State<_StoreDialog> createState() => _StoreDialogState();
}

class _StoreDialogState extends State<_StoreDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  double? _latitude;
  double? _longitude;
  bool _fetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store?.name);
    _locationController = TextEditingController(text: widget.store?.location);
    _latitude = widget.store?.latitude;
    _longitude = widget.store?.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final locationService = widget.ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position GPS enregistrée'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La localisation est désactivée sur cet appareil'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission de localisation refusée'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGps = _latitude != null && _longitude != null;

    return AlertDialog(
      icon: Icon(widget.store == null ? Icons.add_business_outlined : Icons.edit_outlined),
      title: Text(widget.store == null ? 'Nouveau magasin' : 'Modifier le magasin'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
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
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Adresse (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            // GPS location button
            OutlinedButton.icon(
              icon: _fetchingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(hasGps ? Icons.my_location : Icons.location_searching),
              label: Text(
                hasGps
                    ? 'Position GPS enregistrée — Mettre à jour'
                    : 'Enregistrer ma position GPS',
              ),
              onPressed: _fetchingLocation ? null : _fetchCurrentLocation,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                foregroundColor: hasGps
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            if (hasGps)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () async {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            final location = _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim();

            if (widget.store == null) {
              await widget.db.insertStore(StoresCompanion.insert(
                name: name,
                location: Value(location),
                latitude: Value(_latitude),
                longitude: Value(_longitude),
              ));
            } else {
              await widget.db.updateStore(widget.store!.copyWith(
                name: name,
                location: Value(location),
                latitude: Value(_latitude),
                longitude: Value(_longitude),
              ));
            }
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(widget.store == null ? 'Magasin ajouté' : 'Magasin modifié'),
                behavior: SnackBarBehavior.floating,
              ));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
