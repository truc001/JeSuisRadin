import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import '../../core/services/location_service.dart';

class AddPriceScreen extends ConsumerStatefulWidget {
  final String barcode;
  final String? productName;
  final int? productId;

  const AddPriceScreen({
    super.key,
    required this.barcode,
    this.productName,
    this.productId,
  });

  @override
  ConsumerState<AddPriceScreen> createState() => _AddPriceScreenState();
}

class _AddPriceScreenState extends ConsumerState<AddPriceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _productNameController = TextEditingController();
  int? _selectedStoreId;
  DateTime _selectedDate = DateTime.now();
  int? _resolvedProductId;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _resolvedProductId = widget.productId;
    if (widget.productName != null) {
      _productNameController.text = widget.productName!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectNearestStore());
  }

  Future<void> _autoSelectNearestStore() async {
    final db = ref.read(databaseProvider);
    final locationService = ref.read(locationServiceProvider);
    final stores = await db.getAllStores();
    if (stores.isEmpty) return;

    // S'il n'y a qu'un seul magasin, le sélectionner directement
    if (stores.length == 1) {
      if (mounted) setState(() => _selectedStoreId = stores.first.id);
      return;
    }

    // Vérifier si au moins un magasin a des coordonnées GPS
    final hasGeoStores = stores.any((s) => s.latitude != null && s.longitude != null);
    if (!hasGeoStores) return;

    setState(() => _locating = true);
    try {
      final position = await locationService.getCurrentPosition();
      final nearest = locationService.findNearestStore(stores, position);
      if (nearest != null && mounted) {
        setState(() => _selectedStoreId = nearest.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Magasin le plus proche : ${nearest.name}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // Permission refusée ou service désactivé : on laisse l'utilisateur choisir manuellement
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedStoreId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un magasin'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    int productId = _resolvedProductId ?? 0;

    try {
      if (_resolvedProductId == null) {
        final name = _productNameController.text.trim();
        if (name.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Veuillez saisir le nom du produit'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        productId = await db.insertProduct(ProductsCompanion.insert(
          barcode: widget.barcode,
          name: name,
        ));
        _resolvedProductId = productId;
      }

      await db.upsertPrice(
        productId: productId,
        storeId: _selectedStoreId!,
        price: double.parse(_priceController.text.replaceAll(',', '.')),
        date: _selectedDate,
      );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Prix enregistré !'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/products/$productId');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un prix'),
        centerTitle: false,
        scrolledUnderElevation: 3,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Product info card
            Card(
              color: cs.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Produit',
                          style: tt.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_resolvedProductId == null) ...[
                      TextFormField(
                        controller: _productNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du produit *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) =>
                            v?.isEmpty == true ? 'Requis' : null,
                      ),
                      const SizedBox(height: 8),
                    ] else
                      Text(
                        widget.productName ?? '',
                        style: tt.titleMedium,
                      ),
                    if (widget.barcode.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.qr_code,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            widget.barcode,
                            style: tt.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Price field
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Prix',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro_outlined),
                suffixText: '€',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requis';
                final val = double.tryParse(v.replaceAll(',', '.'));
                if (val == null || val <= 0) return 'Prix invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Store dropdown
            StreamBuilder<List<Store>>(
              stream: db.watchAllStores(),
              builder: (context, snapshot) {
                final stores = snapshot.data ?? [];
                if (stores.isEmpty) {
                  return OutlinedButton.icon(
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Créer un magasin d\'abord'),
                    onPressed: () => context.push('/stores'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      value: _selectedStoreId,
                      decoration: InputDecoration(
                        labelText: 'Magasin',
                        border: const OutlineInputBorder(),
                        prefixIcon: _locating
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.store_outlined),
                      ),
                      items: stores
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStoreId = v),
                      validator: (v) => v == null ? 'Requis' : null,
                    ),
                    if (_locating)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          'Détection du magasin le plus proche...',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            // Date picker tile
            Card(
              color: cs.surfaceContainerLow,
              child: ListTile(
                leading: Icon(Icons.calendar_month_outlined,
                    color: cs.primary),
                title: Text(
                  DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedDate),
                  style: tt.bodyLarge,
                ),
                subtitle: Text(
                  'Date du relevé de prix',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                trailing: TextButton(
                  onPressed: _selectDate,
                  child: const Text('Modifier'),
                ),
                onTap: _selectDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Enregistrer le prix'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
