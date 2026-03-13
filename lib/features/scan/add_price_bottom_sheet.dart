import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';

class AddPriceBottomSheet extends ConsumerStatefulWidget {
  final int productId;
  final String productName;

  const AddPriceBottomSheet({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  ConsumerState<AddPriceBottomSheet> createState() =>
      _AddPriceBottomSheetState();
}

class _AddPriceBottomSheetState extends ConsumerState<AddPriceBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  int? _selectedStoreId;
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _priceController.dispose();
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
    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un magasin'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final db = ref.read(databaseProvider);

    try {
      await db.upsertPrice(
        productId: widget.productId,
        storeId: _selectedStoreId!,
        price: double.parse(_priceController.text.replaceAll(',', '.')),
        date: _selectedDate,
      );

      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Prix enregistré !'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ajouter un prix', style: tt.titleLarge),
                          Text(
                            widget.productName,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Price field
                TextFormField(
                  controller: _priceController,
                  autofocus: true,
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
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/stores');
                        },
                      );
                    }
                    return DropdownButtonFormField<int>(
                      initialValue: _selectedStoreId,
                      decoration: const InputDecoration(
                        labelText: 'Magasin',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                      items: stores
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedStoreId = v),
                      validator: (v) => v == null ? 'Requis' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Date picker
                Card(
                  color: cs.surfaceContainerLow,
                  child: ListTile(
                    leading:
                        Icon(Icons.calendar_month_outlined, color: cs.primary),
                    title: Text(
                      DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedDate),
                      style: tt.bodyLarge,
                    ),
                    subtitle: Text(
                      'Date du relevé',
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
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
        ),
      ),
    );
  }
}

void showAddPriceBottomSheet(
  BuildContext context, {
  required int productId,
  required String productName,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => AddPriceBottomSheet(
      productId: productId,
      productName: productName,
    ),
  );
}
