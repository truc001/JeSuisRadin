import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get barcode => text().unique()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get quantity => text().nullable()();
  TextColumn get category => text().nullable()();
}

class Stores extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
}

class Prices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get storeId => integer().references(Stores, #id)();
  RealColumn get price => real()();
  DateTimeColumn get date => dateTime()();
}

class ShoppingLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class ShoppingListItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId => integer().references(ShoppingLists, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
}

@DriftDatabase(tables: [Products, Stores, Prices, ShoppingLists, ShoppingListItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Products DAO methods
  Future<List<Product>> getAllProducts() => select(products).get();

  Stream<List<Product>> watchAllProducts() => select(products).watch();

  Future<Product?> getProductByBarcode(String barcode) =>
      (select(products)..where((p) => p.barcode.equals(barcode))).getSingleOrNull();

  Future<int> insertProduct(ProductsCompanion product) =>
      into(products).insertOnConflictUpdate(product);

  Future<int> deleteProduct(int id) async {
    await (delete(prices)..where((p) => p.productId.equals(id))).go();
    await (delete(shoppingListItems)..where((i) => i.productId.equals(id))).go();
    return (delete(products)..where((p) => p.id.equals(id))).go();
  }

  // Stores DAO methods
  Stream<List<Store>> watchAllStores() => select(stores).watch();

  Future<List<Store>> getAllStores() => select(stores).get();

  Future<int> insertStore(StoresCompanion store) =>
      into(stores).insert(store);

  Future<bool> updateStore(Store store) => update(stores).replace(store);

  Future<int> deleteStore(int id) =>
      (delete(stores)..where((s) => s.id.equals(id))).go();

  // Prices DAO methods
  Future<int> insertPrice(PricesCompanion price) =>
      into(prices).insert(price);

  Future<int> deletePrice(int id) =>
      (delete(prices)..where((p) => p.id.equals(id))).go();

  /// Upsert : met à jour le prix si un enregistrement existe déjà pour ce
  /// couple (productId, storeId), sinon insère une nouvelle ligne.
  Future<void> upsertPrice({
    required int productId,
    required int storeId,
    required double price,
    required DateTime date,
  }) async {
    final existing = await (select(prices)
          ..where((p) =>
              p.productId.equals(productId) & p.storeId.equals(storeId)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(prices)..where((p) => p.id.equals(existing.id))).write(
        PricesCompanion(
          price: Value(price),
          date: Value(date),
        ),
      );
    } else {
      await into(prices).insert(PricesCompanion.insert(
        productId: productId,
        storeId: storeId,
        price: price,
        date: date,
      ));
    }
  }

  Stream<List<PriceWithStore>> watchPricesForProduct(int productId) {
    final query = select(prices).join([
      innerJoin(stores, stores.id.equalsExp(prices.storeId)),
    ])
      ..where(prices.productId.equals(productId))
      ..orderBy([OrderingTerm.desc(prices.date)]);
    return query.watch().map((rows) => rows.map((row) => PriceWithStore(
      price: row.readTable(prices),
      store: row.readTable(stores),
    )).toList());
  }

  Stream<Product?> watchProductById(int id) =>
      (select(products)..where((p) => p.id.equals(id))).watchSingleOrNull();

  // Watch cheapest store for a product (réactif)
  Stream<PriceWithStore?> watchCheapestStore(int productId) {
    return watchPricesForProduct(productId).map((priceList) {
      if (priceList.isEmpty) return null;
      // Garder uniquement le prix le plus récent par magasin
      final latestByStore = <int, PriceWithStore>{};
      for (final pws in priceList) {
        final existing = latestByStore[pws.store.id];
        if (existing == null || pws.price.date.isAfter(existing.price.date)) {
          latestByStore[pws.store.id] = pws;
        }
      }
      return latestByStore.values.reduce(
        (a, b) => a.price.price <= b.price.price ? a : b,
      );
    });
  }

  // Get cheapest store for a product (latest price per store)
  Future<PriceWithStore?> getCheapestStore(int productId) async {
    final query = customSelect(
      '''
      SELECT p.*, s.name as store_name, s.location as store_location
      FROM prices p
      INNER JOIN stores s ON s.id = p.store_id
      WHERE p.product_id = ?
        AND p.date = (
          SELECT MAX(p2.date) FROM prices p2
          WHERE p2.product_id = p.product_id AND p2.store_id = p.store_id
        )
      ORDER BY p.price ASC
      LIMIT 1
      ''',
      variables: [Variable.withInt(productId)],
      readsFrom: {prices, stores},
    );

    final rows = await query.get();
    if (rows.isEmpty) return null;

    final row = rows.first;
    return PriceWithStore(
      price: Price(
        id: row.read<int>('id'),
        productId: row.read<int>('product_id'),
        storeId: row.read<int>('store_id'),
        price: row.read<double>('price'),
        date: DateTime.fromMillisecondsSinceEpoch(row.read<int>('date') * 1000),
      ),
      store: Store(
        id: row.read<int>('store_id'),
        name: row.read<String>('store_name'),
        location: row.readNullable<String>('store_location'),
      ),
    );
  }

  Stream<Map<int, PriceWithStore>> watchAllCheapestPrices() {
    return customSelect(
      '''
      SELECT p.id, p.product_id, p.store_id, p.price, p.date,
             s.name as store_name, s.location as store_location
      FROM prices p
      INNER JOIN stores s ON s.id = p.store_id
      WHERE p.date = (
        SELECT MAX(p2.date) FROM prices p2
        WHERE p2.product_id = p.product_id AND p2.store_id = p.store_id
      )
      AND p.price = (
        SELECT MIN(p3.price) FROM prices p3
        INNER JOIN (
          SELECT product_id, store_id, MAX(date) as max_date
          FROM prices
          GROUP BY product_id, store_id
        ) latest ON p3.product_id = latest.product_id
          AND p3.store_id = latest.store_id
          AND p3.date = latest.max_date
        WHERE p3.product_id = p.product_id
      )
      GROUP BY p.product_id
      ''',
      readsFrom: {prices, stores},
    ).watch().map((rows) {
      final map = <int, PriceWithStore>{};
      for (final row in rows) {
        final productId = row.read<int>('product_id');
        map[productId] = PriceWithStore(
          price: Price(
            id: row.read<int>('id'),
            productId: productId,
            storeId: row.read<int>('store_id'),
            price: row.read<double>('price'),
            date: DateTime.fromMillisecondsSinceEpoch(row.read<int>('date') * 1000),
          ),
          store: Store(
            id: row.read<int>('store_id'),
            name: row.read<String>('store_name'),
            location: row.readNullable<String>('store_location'),
          ),
        );
      }
      return map;
    });
  }

  // Shopping lists
  Stream<List<ShoppingList>> watchAllShoppingLists() =>
      select(shoppingLists).watch();

  Future<int> insertShoppingList(ShoppingListsCompanion list) =>
      into(shoppingLists).insert(list);

  Future<bool> updateShoppingList(ShoppingList list) =>
      update(shoppingLists).replace(list);

  Future<int> deleteShoppingList(int id) async {
    await (delete(shoppingListItems)..where((i) => i.listId.equals(id))).go();
    return (delete(shoppingLists)..where((l) => l.id.equals(id))).go();
  }

  Stream<List<ShoppingListItemWithProduct>> watchItemsForList(int listId) {
    final query = select(shoppingListItems).join([
      innerJoin(products, products.id.equalsExp(shoppingListItems.productId)),
    ])..where(shoppingListItems.listId.equals(listId));
    return query.watch().map((rows) => rows.map((row) => ShoppingListItemWithProduct(
      item: row.readTable(shoppingListItems),
      product: row.readTable(products),
    )).toList());
  }

  Future<int> insertShoppingListItem(ShoppingListItemsCompanion item) =>
      into(shoppingListItems).insert(item);

  Future<bool> updateShoppingListItem(ShoppingListItem item) =>
      update(shoppingListItems).replace(item);

  Future<int> deleteShoppingListItem(int id) =>
      (delete(shoppingListItems)..where((i) => i.id.equals(id))).go();

  Future<Map<Store, double>> getComparisonForList(int listId) async {
    if (listId == 0) return {};

    final rows = await customSelect(
      '''
      SELECT s.id as store_id, s.name as store_name, s.location as store_location,
             SUM(latest_p.price * i.quantity) as total,
             COUNT(DISTINCT i.product_id) as covered
      FROM shopping_list_items i
      INNER JOIN (
        SELECT p.product_id, p.store_id, p.price
        FROM prices p
        WHERE p.date = (
          SELECT MAX(p2.date) FROM prices p2
          WHERE p2.product_id = p.product_id AND p2.store_id = p.store_id
        )
      ) latest_p ON latest_p.product_id = i.product_id
      INNER JOIN stores s ON s.id = latest_p.store_id
      WHERE i.list_id = ?
      GROUP BY s.id
      HAVING covered = (SELECT COUNT(DISTINCT product_id) FROM shopping_list_items WHERE list_id = ?)
      ''',
      variables: [Variable.withInt(listId), Variable.withInt(listId)],
      readsFrom: {shoppingListItems, prices, stores},
    ).get();

    final result = <Store, double>{};
    for (final row in rows) {
      result[Store(
        id: row.read<int>('store_id'),
        name: row.read<String>('store_name'),
        location: row.readNullable<String>('store_location'),
      )] = row.read<double>('total');
    }
    return result;
  }

  Stream<Map<Store, double>> watchComparisonForList(int listId) {
    if (listId == 0) return Stream.value({});

    return customSelect(
      '''
      SELECT s.id as store_id, s.name as store_name, s.location as store_location,
             SUM(latest_p.price * i.quantity) as total,
             COUNT(DISTINCT i.product_id) as covered
      FROM shopping_list_items i
      INNER JOIN (
        SELECT p.product_id, p.store_id, p.price
        FROM prices p
        WHERE p.date = (
          SELECT MAX(p2.date) FROM prices p2
          WHERE p2.product_id = p.product_id AND p2.store_id = p.store_id
        )
      ) latest_p ON latest_p.product_id = i.product_id
      INNER JOIN stores s ON s.id = latest_p.store_id
      WHERE i.list_id = ?
      GROUP BY s.id
      HAVING covered = (SELECT COUNT(DISTINCT product_id) FROM shopping_list_items WHERE list_id = ?)
      ''',
      variables: [Variable.withInt(listId), Variable.withInt(listId)],
      readsFrom: {shoppingListItems, prices, stores},
    ).watch().map((rows) {
      final result = <Store, double>{};
      for (final row in rows) {
        result[Store(
          id: row.read<int>('store_id'),
          name: row.read<String>('store_name'),
          location: row.readNullable<String>('store_location'),
        )] = row.read<double>('total');
      }
      return result;
    });
  }
}

class PriceWithStore {
  final Price price;
  final Store store;
  PriceWithStore({required this.price, required this.store});
}

class ShoppingListItemWithProduct {
  final ShoppingListItem item;
  final Product product;
  ShoppingListItemWithProduct({required this.item, required this.product});
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'comparateur.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
