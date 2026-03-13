import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../main.dart';
import '../../core/api/open_food_facts_client.dart';
import '../../core/database/app_database.dart';
import 'package:drift/drift.dart' hide Column;

final openFoodFactsClientProvider = Provider<OpenFoodFactsClient>((ref) {
  return OpenFoodFactsClient();
});

class ScanBottomSheet extends ConsumerStatefulWidget {
  const ScanBottomSheet({super.key});

  @override
  ConsumerState<ScanBottomSheet> createState() => _ScanBottomSheetState();
}

class _ScanBottomSheetState extends ConsumerState<ScanBottomSheet> {
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      final db = ref.read(databaseProvider);
      final client = ref.read(openFoodFactsClientProvider);

      var product = await db.getProductByBarcode(barcode);
      int? productId = product?.id;
      String? productName = product?.name;

      if (product == null) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Recherche du produit...'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        final result = await client.fetchProduct(barcode);
        final offProduct = result?.product;

        if (offProduct != null && offProduct.productName != null) {
          final category = offProduct.categoriesTags?.isNotEmpty == true
              ? offProduct.categoriesTags!.first
              : null;

          productId = await db.insertProduct(ProductsCompanion.insert(
            barcode: barcode,
            name: offProduct.productName!,
            brand: Value(offProduct.brands),
            imageUrl: Value(offProduct.imageFrontUrl),
            quantity: Value(offProduct.quantity),
            category: Value(category),
          ));
          productName = offProduct.productName;
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Produit introuvable sur OpenFoodFacts, saisissez le nom manuellement',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        context.push('/products/add-price', extra: {
          'barcode': barcode,
          'productName': productName,
          'productId': productId,
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _enterManually() {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          icon: const Icon(Icons.keyboard_outlined),
          title: const Text('Saisie manuelle'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Code-barres',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (controller.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  context.push('/products/add-price', extra: {
                    'barcode': controller.text,
                    'productName': null,
                    'productId': null,
                  });
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          // Drag handle (MD3)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scanner un produit',
                        style: tt.titleLarge,
                      ),
                      Text(
                        'Pointez la caméra vers le code-barres',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.keyboard_outlined),
                  onPressed: _enterManually,
                  tooltip: 'Saisie manuelle',
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurfaceVariant,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Scanner
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onBarcodeDetected,
                    ),
                    // Scan frame overlay
                    Center(
                      child: Container(
                        width: 220,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: cs.primary,
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (_isProcessing)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: cs.primary),
                              const SizedBox(height: 12),
                              Text(
                                'Recherche du produit...',
                                style: tt.bodyMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showScanBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const ScanBottomSheet(),
  );
}
