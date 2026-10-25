import 'package:doctor_computer/data/models/category_model.dart';
import 'package:doctor_computer/data/models/product_model.dart';

/// Result of a local catalog search.
class ProductSearchResult {
  final List<ProductModel> products;

  /// True when not every keyword matched (results are the closest matches).
  final bool partial;

  /// Budget (in rupiah) detected in the query, e.g. "10 jutaan".
  final double? maxPrice;

  const ProductSearchResult({
    required this.products,
    this.partial = false,
    this.maxPrice,
  });
}

/// Tokenized, ranked catalog search. Works fully offline and does not depend
/// on any filter state of the catalog screen.
class ProductSearch {
  ProductSearch._();

  static const Set<String> _stopWords = {
    'yang', 'untuk', 'buat', 'dan', 'di', 'dengan', 'ke', 'dari', 'saya',
    'aku', 'mau', 'cari', 'carikan', 'tolong', 'yg', 'utk', 'dgn', 'atau',
    'ada', 'apa', 'the', 'a', 'an', 'for', 'with', 'and', 'of', 'saja',
    'dong', 'ya', 'kak', 'rekomendasi', 'rekomendasikan', 'produk',
  };

  static const Set<String> _cheapWords = {
    'murah', 'budget', 'terjangkau', 'hemat', 'ekonomis', 'cheap',
  };

  /// Keyword -> category id.
  static const Map<String, String> _categoryAliases = {
    'ssd': 'storage',
    'nvme': 'storage',
    'hdd': 'storage',
    'harddisk': 'storage',
    'penyimpanan': 'storage',
    'storage': 'storage',
    'router': 'networking',
    'wifi': 'networking',
    'jaringan': 'networking',
    'networking': 'networking',
    'laptop': 'laptop',
    'notebook': 'laptop',
    'monitor': 'monitor',
    'layar': 'monitor',
    'keyboard': 'keyboard',
    'mouse': 'mouse',
    'headset': 'headset',
    'desktop': 'desktop',
  };

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-\.\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts a budget like "10 juta", "10jt", "10 jutaan", "500 ribu".
  static double? extractBudget(String query) {
    final m = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(juta|jutaan|jt|ribu|rb)\b',
      caseSensitive: false,
    ).firstMatch(query.toLowerCase());
    if (m == null) return null;
    final number = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (number == null) return null;
    final unit = m.group(2)!;
    final isMillion = unit.startsWith('j');
    final base = number * (isMillion ? 1000000 : 1000);
    // "10 jutaan" means "around 10 million", so allow a little headroom.
    return unit == 'jutaan' ? base * 1.15 : base;
  }

  static ProductSearchResult search(
    String query,
    List<ProductModel> catalog, {
    List<CategoryModel> categories = const [],
    int limit = 50,
  }) {
    final raw = query.trim();
    if (raw.isEmpty) return const ProductSearchResult(products: []);

    final maxPrice = extractBudget(raw);
    var text = raw.toLowerCase();
    if (maxPrice != null) {
      text = text.replaceAll(
        RegExp(r'(\d+(?:[.,]\d+)?)\s*(juta|jutaan|jt|ribu|rb)\b'),
        ' ',
      );
    }

    final allTokens = _normalize(text)
        .split(' ')
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList();
    final wantsCheap = allTokens.any(_cheapWords.contains);
    final tokens = allTokens.where((t) => !_cheapWords.contains(t)).toList();

    // Category names (e.g. "Penyimpanan") are searchable too.
    final categoryNames = <String, String>{
      for (final c in categories)
        c.id.toLowerCase(): '${c.name} ${c.nameId}'.toLowerCase(),
    };

    var pool = catalog;
    if (maxPrice != null) {
      pool = pool.where((p) => p.price <= maxPrice).toList();
    }

    // Only intent words (budget / cheap): show the best-fitting products.
    if (tokens.isEmpty) {
      final sorted = List<ProductModel>.from(pool);
      if (wantsCheap) {
        sorted.sort((a, b) => a.price.compareTo(b.price));
      } else if (maxPrice != null) {
        sorted.sort((a, b) => b.price.compareTo(a.price));
      } else {
        return const ProductSearchResult(products: []);
      }
      return ProductSearchResult(
        products: sorted.take(limit).toList(),
        maxPrice: maxPrice,
      );
    }

    int scoreFor(ProductModel p, String token) {
      final name = p.name.toLowerCase();
      final brand = p.brand.toLowerCase();
      final catId = p.categoryId.toLowerCase();

      if (name.contains(token)) {
        return name.startsWith(token) || name.contains(' $token') ? 5 : 4;
      }
      if (brand.contains(token)) return 4;

      final aliasCat = _categoryAliases[token];
      if (aliasCat != null && catId == aliasCat) return 3;
      if (catId == token || (categoryNames[catId]?.contains(token) ?? false)) {
        return 3;
      }

      final extra =
          '${p.description} ${p.descriptionId} ${p.specs.values.join(' ')}'
              .toLowerCase();
      if (extra.contains(token)) return 1;
      return 0;
    }

    final strict = <MapEntry<ProductModel, int>>[];
    final loose = <MapEntry<ProductModel, int>>[];

    for (final p in pool) {
      var total = 0;
      var matched = 0;
      for (final t in tokens) {
        final s = scoreFor(p, t);
        if (s > 0) {
          matched++;
          total += s;
        }
      }
      if (matched == 0) continue;
      final entry = MapEntry(p, total);
      if (matched == tokens.length) {
        strict.add(entry);
      } else {
        loose.add(entry);
      }
    }

    final usingLoose = strict.isEmpty && tokens.length > 1;
    final ranked = usingLoose ? loose : strict;

    ranked.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      if (wantsCheap) return a.key.price.compareTo(b.key.price);
      return b.key.rating.compareTo(a.key.rating);
    });

    return ProductSearchResult(
      products: ranked.take(limit).map((e) => e.key).toList(),
      partial: usingLoose,
      maxPrice: maxPrice,
    );
  }
}
