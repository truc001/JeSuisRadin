import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/open_prices_client.dart';
import '../../core/api/user_auth.dart';
import '../../core/database/app_database.dart';
import '../../core/extensions/double_extensions.dart';
import '../../core/providers/receipt_match_provider.dart';
import '../../core/utils/fuzzy_matcher.dart';
import '../../main.dart';

final _allProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(databaseProvider).getAllProducts();
});

class ReceiptScannerScreen extends ConsumerStatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  ConsumerState<ReceiptScannerScreen> createState() =>
      _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  final _picker = ImagePicker();

  File? _image;
  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsError = false;
  Timer? _pollingTimer;
  int? _currentProofId;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile =
        await _picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _statusMessage = null;
        _statusIsError = false;
        _currentProofId = null;
      });
      ref.read(receiptMatchNotifierProvider.notifier).clear();
      _uploadAndStartPolling();
    }
  }

  Future<void> _uploadAndStartPolling() async {
    if (_image == null) return;

    final client = ref.read(openPricesClientProvider);
    final credentials = ref.read(offCredentialsProvider);
    if (credentials == null) {
      _setStatus(
          'Vous devez être connecté à votre compte Open Food Facts.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _setStatus('Envoi du ticket...');

    try {
      final proofId =
          await client.uploadReceipt(_image!, credentials: credentials);

      if (proofId == null) {
        setState(() => _isLoading = false);
        _setStatus("L'envoi a échoué : identifiant vide.", isError: true);
        return;
      }

      setState(() => _currentProofId = proofId);
      _setStatus('Analyse automatique par l\'IA en cours...');
      _startPolling(proofId, credentials);
    } catch (e) {
      setState(() => _isLoading = false);
      _setStatus('Erreur : $e', isError: true);
    }
  }

  void _startPolling(int proofId, OffCredentials credentials) {
    _pollingTimer?.cancel();
    int attempts = 0;

    _pollingTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      attempts++;
      final client = ref.read(openPricesClientProvider);
      final items =
          await client.getReceiptItems(proofId, credentials: credentials);

      if (items.isNotEmpty) {
        timer.cancel();
        setState(() => _isLoading = false);
        _setStatus(
            'Analyse terminée — ${items.length} article(s) détecté(s).');
        _runMatching(items);
      } else if (attempts >= 12) {
        timer.cancel();
        setState(() => _isLoading = false);
        _setStatus(
            'L\'analyse prend plus de temps que prévu. Actualisez manuellement.');
      }
    });
  }

  Future<void> _manualRefresh() async {
    if (_currentProofId == null) return;
    final credentials = ref.read(offCredentialsProvider);
    if (credentials == null) return;

    setState(() => _isLoading = true);
    final client = ref.read(openPricesClientProvider);
    final items = await client.getReceiptItems(_currentProofId!,
        credentials: credentials);
    setState(() => _isLoading = false);

    if (items.isNotEmpty) {
      _setStatus('Données actualisées — ${items.length} article(s).');
      _runMatching(items);
    }
  }

  void _runMatching(List<ReceiptItem> items) {
    final allProductsAsync = ref.read(_allProductsProvider);
    allProductsAsync.whenData((allProducts) {
      ref
          .read(receiptMatchNotifierProvider.notifier)
          .processItems(items, allProducts);
    });
  }

  void _setStatus(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une nouvelle photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProductPicker(int itemIndex) {
    final allProductsAsync = ref.read(_allProductsProvider);
    allProductsAsync.whenData((allProducts) {
      if (!mounted) return;
      final currentMatch =
          ref.read(receiptMatchNotifierProvider)[itemIndex].matchedProduct;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _ProductPickerSheet(
          allProducts: allProducts,
          currentMatch: currentMatch,
          onSelect: (product) => ref
              .read(receiptMatchNotifierProvider.notifier)
              .assignProduct(itemIndex, product),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final offCreds = ref.watch(offCredentialsProvider);
    final matches = ref.watch(receiptMatchNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner un ticket'),
        centerTitle: false,
        scrolledUnderElevation: 3,
        actions: [
          if (_currentProofId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: _isLoading ? null : _manualRefresh,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offCreds == null) _buildConnectionBanner(cs, tt),
          if (_image == null)
            Expanded(child: _buildEmptyState(cs, tt, offCreds))
          else ...[
            _buildImagePreview(cs, offCreds),
            if (_statusMessage != null)
              _buildStatusCard(cs, tt),
            const Divider(height: 1),
            Expanded(
              child: matches.isEmpty
                  ? _buildLoadingPlaceholder(cs, tt)
                  : _buildItemList(matches, cs, tt),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-builders
  // ---------------------------------------------------------------------------

  Widget _buildConnectionBanner(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: cs.errorContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Connexion requise',
                      style: tt.titleMedium
                          ?.copyWith(color: cs.onErrorContainer)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'Configurez votre compte Open Food Facts dans les paramètres pour utiliser l\'analyse IA.',
                style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings),
                label: const Text('Aller aux paramètres'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      ColorScheme cs, TextTheme tt, OffCredentials? offCreds) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long,
                size: 80, color: cs.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 24),
            Text(
              'Prenez votre ticket en photo\npour extraire les prix automatiquement',
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: offCreds == null
                  ? null
                  : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Prendre une photo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: offCreds == null
                  ? null
                  : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Choisir depuis la galerie'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(ColorScheme cs, OffCredentials? offCreds) {
    return Stack(
      children: [
        Container(
          height: 160,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: FileImage(_image!),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black38,
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 24,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            onPressed:
                offCreds == null ? null : _showImageSourceDialog,
            icon: const Icon(Icons.camera_alt, size: 16),
            label: const Text('Changer'),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(ColorScheme cs, TextTheme tt) {
    final bgColor =
        _statusIsError ? cs.errorContainer : cs.primaryContainer;
    final fgColor = _statusIsError
        ? cs.onErrorContainer
        : cs.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: bgColor,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (_isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: fgColor),
                )
              else
                Icon(
                  _statusIsError
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  size: 18,
                  color: fgColor,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_statusMessage!,
                    style: tt.bodyMedium?.copyWith(color: fgColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading) ...[
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            Text('Extraction en cours...',
                style: tt.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ] else
            Text('Aucun article détecté pour le moment.',
                style:
                    tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildItemList(
      List<ReceiptItemMatch> matches, ColorScheme cs, TextTheme tt) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: matches.length,
      itemBuilder: (context, index) =>
          _buildItemCard(matches[index], index, cs, tt),
    );
  }

  Widget _buildItemCard(
      ReceiptItemMatch match, int index, ColorScheme cs, TextTheme tt) {
    final item = match.receiptItem;
    final product = match.matchedProduct;

    Color? cardColor;
    if (match.status == MatchStatus.matched) {
      cardColor = cs.secondaryContainer.withValues(alpha: 0.45);
    } else if (match.status == MatchStatus.manual) {
      cardColor = cs.tertiaryContainer.withValues(alpha: 0.45);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne principale
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  radius: 18,
                  child: Text(
                    '${item.quantity ?? 1}×',
                    style: tt.labelSmall
                        ?.copyWith(color: cs.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.productName ?? 'Produit inconnu',
                    style: tt.bodyLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.price?.formatPrice() ?? '--',
                  style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold, color: cs.primary),
                ),
              ],
            ),

            // Correspondance produit (si existante)
            if (product != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    match.status == MatchStatus.manual
                        ? Icons.link
                        : Icons.auto_awesome,
                    size: 13,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (product.brand != null) product.brand!,
                        product.name,
                      ].join(' · '),
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref
                        .read(receiptMatchNotifierProvider.notifier)
                        .clearMatch(index),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 14, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],

            // Bouton Associer
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: cs.primary,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => _showProductPicker(index),
                icon: const Icon(Icons.link, size: 15),
                label: Text(
                  product != null ? 'Changer l\'association' : 'Associer',
                  style: tt.labelSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet — sélection manuelle (Option C)
// ---------------------------------------------------------------------------

class _ProductPickerSheet extends StatefulWidget {
  final List<Product> allProducts;
  final Product? currentMatch;
  final void Function(Product) onSelect;

  const _ProductPickerSheet({
    required this.allProducts,
    this.currentMatch,
    required this.onSelect,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  late List<Product> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.allProducts;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = FuzzyMatcher.normalize(_searchController.text);
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.allProducts;
      } else {
        _filtered = widget.allProducts.where((p) {
          final name = FuzzyMatcher.normalize(p.name);
          final brand =
              p.brand != null ? FuzzyMatcher.normalize(p.brand!) : '';
          return name.contains(query) || brand.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Associer un produit', style: tt.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch();
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('Aucun produit trouvé',
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final p = _filtered[i];
                        final isSelected =
                            widget.currentMatch?.id == p.id;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: cs.secondaryContainer,
                          leading: p.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    p.imageUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.inventory_2_outlined,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor:
                                      cs.surfaceContainerHighest,
                                  child: Icon(Icons.inventory_2_outlined,
                                      color: cs.onSurfaceVariant,
                                      size: 20),
                                ),
                          title: Text(p.name),
                          subtitle: [p.brand, p.quantity]
                                      .whereType<String>()
                                      .isNotEmpty
                              ? Text(
                                  [p.brand, p.quantity]
                                      .whereType<String>()
                                      .join(' · '),
                                  style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                )
                              : null,
                          trailing: isSelected
                              ? Icon(Icons.check_circle,
                                  color: cs.primary)
                              : null,
                          onTap: () {
                            widget.onSelect(p);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
