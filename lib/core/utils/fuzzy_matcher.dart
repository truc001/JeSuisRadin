import '../database/app_database.dart';

class MatchResult {
  final Product product;
  final double score;
  const MatchResult({required this.product, required this.score});
}

class FuzzyMatcher {
  static const double _autoMatchThreshold = 0.65;
  static const double _minScoreThreshold = 0.30;

  /// Retourne le meilleur match ou null si aucun score > [_minScoreThreshold].
  static MatchResult? findBestMatch({
    required String query,
    required List<Product> products,
  }) {
    if (products.isEmpty) return null;

    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return null;

    MatchResult? best;

    for (final product in products) {
      final score = _score(normalizedQuery, product);
      if (score > (best?.score ?? 0)) {
        best = MatchResult(product: product, score: score);
      }
    }

    if (best == null || best.score < _minScoreThreshold) return null;
    return best;
  }

  static bool isAutoMatch(double score) => score >= _autoMatchThreshold;

  /// Score composite entre 0.0 et 1.0.
  static double _score(String normalizedQuery, Product product) {
    final productName = normalize(product.name);
    final productBrand =
        product.brand != null ? normalize(product.brand!) : '';

    // Signal 1 : Levenshtein normalisé sur le nom seul
    final levScoreName = _levenshteinScore(normalizedQuery, productName);

    // Signal 2 : Levenshtein sur marque + nom concaténés
    final combined = '$productBrand $productName'.trim();
    final levScoreCombined = _levenshteinScore(normalizedQuery, combined);

    // Signal 3 : bonus contains (exact ou par mots)
    double containsBonus = 0.0;
    if (productName.contains(normalizedQuery) ||
        normalizedQuery.contains(productName)) {
      containsBonus = 0.20;
    } else {
      final queryWords =
          normalizedQuery.split(' ').where((w) => w.length > 2).toList();
      final productWords =
          productName.split(' ').where((w) => w.length > 2).toList();
      if (queryWords.isNotEmpty && productWords.isNotEmpty) {
        int hits = 0;
        for (final qw in queryWords) {
          for (final pw in productWords) {
            if (pw.contains(qw) || qw.contains(pw)) hits++;
          }
        }
        containsBonus = (hits / queryWords.length).clamp(0.0, 0.20);
      }
    }

    return (levScoreCombined * 0.5 + levScoreName * 0.3 + containsBonus)
        .clamp(0.0, 1.0);
  }

  static double _levenshteinScore(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final dist = _levenshtein(
      a.length > 50 ? a.substring(0, 50) : a,
      b.length > 50 ? b.substring(0, 50) : b,
    );
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (dist / maxLen);
  }

  static int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    var prev = List.generate(n + 1, (i) => i);
    var curr = List.filled(n + 1, 0);

    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = _min3(curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  static int _min3(int a, int b, int c) {
    if (a < b) return a < c ? a : c;
    return b < c ? b : c;
  }

  /// Normalise : minuscules, sans accents, sans ponctuation, espaces uniques.
  static String normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
