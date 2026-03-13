import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/open_prices_client.dart';
import '../database/app_database.dart';
import '../utils/fuzzy_matcher.dart';

// ---------------------------------------------------------------------------
// Modèle
// ---------------------------------------------------------------------------

enum MatchStatus { matched, manual, unmatched }

class ReceiptItemMatch {
  final ReceiptItem receiptItem;
  final Product? matchedProduct;
  final double? matchScore;
  final MatchStatus status;

  const ReceiptItemMatch({
    required this.receiptItem,
    this.matchedProduct,
    this.matchScore,
    this.status = MatchStatus.unmatched,
  });

  ReceiptItemMatch copyWith({
    Product? matchedProduct,
    double? matchScore,
    MatchStatus? status,
    bool clearProduct = false,
  }) {
    return ReceiptItemMatch(
      receiptItem: receiptItem,
      matchedProduct: clearProduct ? null : (matchedProduct ?? this.matchedProduct),
      matchScore: clearProduct ? null : (matchScore ?? this.matchScore),
      status: status ?? this.status,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final receiptMatchNotifierProvider =
    NotifierProvider<ReceiptMatchNotifier, List<ReceiptItemMatch>>(
  ReceiptMatchNotifier.new,
);

class ReceiptMatchNotifier extends Notifier<List<ReceiptItemMatch>> {
  @override
  List<ReceiptItemMatch> build() => [];

  /// Initialise et lance le matching automatique (Option A).
  void processItems(List<ReceiptItem> items, List<Product> allProducts) {
    state = items.map((item) {
      if (item.productName == null) {
        return ReceiptItemMatch(receiptItem: item);
      }

      final result = FuzzyMatcher.findBestMatch(
        query: item.productName!,
        products: allProducts,
      );

      if (result == null) {
        return ReceiptItemMatch(receiptItem: item);
      }

      return ReceiptItemMatch(
        receiptItem: item,
        matchedProduct: result.product,
        matchScore: result.score,
        status: FuzzyMatcher.isAutoMatch(result.score)
            ? MatchStatus.matched
            : MatchStatus.unmatched,
      );
    }).toList();
  }

  /// Association manuelle depuis la bottom sheet (Option C).
  void assignProduct(int index, Product product) {
    final updated = List<ReceiptItemMatch>.from(state);
    updated[index] = updated[index].copyWith(
      matchedProduct: product,
      matchScore: 1.0,
      status: MatchStatus.manual,
    );
    state = updated;
  }

  /// Supprime l'association d'un item.
  void clearMatch(int index) {
    final updated = List<ReceiptItemMatch>.from(state);
    updated[index] = ReceiptItemMatch(receiptItem: updated[index].receiptItem);
    state = updated;
  }

  void clear() => state = [];
}
