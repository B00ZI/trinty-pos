import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart' as obx;

import 'package:Easify/models/category.dart';
import 'package:Easify/models/product.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:Easify/providers/dashboard_provider.dart'
    show objectBoxProvider;
import 'package:Easify/screens/management_screen.dart';
import 'package:Easify/service/category_service.dart';
import 'package:Easify/widgets/category_card.dart';

/// Batch 7 — P21: categories are linked to products BY NAME (kept that way
/// on purpose: ids would need a schema change + codegen, which this project
/// avoids). The name is a live reference, so:
///
///  * renaming a category must carry every product along — otherwise the
///    products keep the old tag and vanish from the order screen;
///  * a category that still holds products must not be deletable;
///  * editing must keep the category's place in the reorderable grid
///    (the old dialog reset displayOrder to 0 — every edited category
///    jumped to the front);
///  * a new category appends after the existing ones.
void main() {
  final storeAvailable = Platform.environment['PATH']?.split(';').any(
          (d) => File('$d/objectbox.dll').existsSync()) ??
      false;
  final storeSkip = storeAvailable
      ? null
      : 'objectbox.dll not on PATH — build windows debug and add '
          'build\\windows\\x64\\runner\\Debug to PATH';

  ({obx.Store store, Directory dir}) openStore(String tag) {
    final dir = Directory.systemTemp.createTempSync(tag);
    final store = Store(getObjectBoxModel(), directory: dir.path);
    return (store: store, dir: dir);
  }

  Product product(String name, {String? category}) =>
      Product(name: name, price: 10, category: category);

  group('P21 — a rename carries its products along (service rules)', () {
    test('renaming retags every product behind the old name', () {
      final s = openStore('easify_b7_rename');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      final cat = Category(name: 'Cafés', displayOrder: 3);
      s.store.box<Category>().put(cat);
      s.store.box<Product>().putMany([
        product('Express', category: 'Cafés'),
        product('Cappuccino', category: 'Cafés'),
        product('Thé menthe', category: 'Boissons'),
      ]);

      final moved = CategoryService.putKeepingProducts(
          s.store, Category(id: cat.id, name: 'Boissons chaudes'),
          oldName: 'Cafés');

      expect(moved, 2, reason: 'both coffee products follow the rename');
      final products = s.store.box<Product>().getAll();
      expect(products.firstWhere((p) => p.name == 'Express').category,
          'Boissons chaudes');
      expect(products.firstWhere((p) => p.name == 'Cappuccino').category,
          'Boissons chaudes');
      expect(products.firstWhere((p) => p.name == 'Thé menthe').category,
          'Boissons',
          reason: 'products of other categories stay untouched');
      expect(s.store.box<Category>().get(cat.id)!.name, 'Boissons chaudes');
    }, skip: storeSkip);

    test('renaming a category nobody uses is a plain save', () {
      final s = openStore('easify_b7_empty');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      final cat = Category(name: 'Jus pressés');
      s.store.box<Category>().put(cat);

      final moved = CategoryService.putKeepingProducts(
          s.store, Category(id: cat.id, name: 'Cocktails'),
          oldName: 'Jus pressés');

      expect(moved, 0);
      expect(s.store.box<Category>().get(cat.id)!.name, 'Cocktails');
    }, skip: storeSkip);

    test('saving without renaming leaves every product alone', () {
      final s = openStore('easify_b7_same');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      final cat = Category(name: 'Desserts', displayOrder: 1);
      s.store.box<Category>().put(cat);
      s.store.box<Product>().put(product('Cheesecake', category: 'Desserts'));

      // Same name, new image only (oldName == name → no cascade).
      final moved = CategoryService.putKeepingProducts(
          s.store,
          Category(id: cat.id, name: 'Desserts', displayOrder: 1),
          oldName: 'Desserts');

      expect(moved, 0);
      expect(s.store.box<Product>().getAll().single.category, 'Desserts');
      expect(s.store.box<Category>().getAll().single.displayOrder, 1,
          reason: 'a save without rename keeps the grid position');
    }, skip: storeSkip);

    test('usageCount tells exactly what the delete guard needs', () {
      final s = openStore('easify_b7_usage');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      s.store.box<Product>().putMany([
        product('Express', category: 'Cafés'),
        product('Noisette', category: 'Cafés'),
        product('Thé', category: 'Boissons'),
      ]);

      expect(CategoryService.usageCount(s.store, 'Cafés'), 2);
      expect(CategoryService.usageCount(s.store, 'Boissons'), 1);
      expect(CategoryService.usageCount(s.store, 'Pâtisseries'), 0);
      expect(CategoryService.usageCount(s.store, ''), 0);
    }, skip: storeSkip);

    test('a new category is appended after the existing ones', () {
      final s = openStore('easify_b7_order');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      expect(CategoryService.nextDisplayOrder(s.store), 0,
          reason: 'the very first category starts the list at 0');

      s.store.box<Category>().putMany([
        Category(name: 'A', displayOrder: 0),
        Category(name: 'B', displayOrder: 4),
      ]);
      expect(CategoryService.nextDisplayOrder(s.store), 5,
          reason: 'the next new category goes after the last one, '
              'never to the front');
    }, skip: storeSkip);
  });

  group('P21 — through the real category screen', () {
    Future<obx.Store> pumpCategories(
        WidgetTester tester, obx.Store store) async {
      final objectbox = ObjectBox.attach(store);
      await tester.pumpWidget(ProviderScope(
        overrides: [objectBoxProvider.overrideWithValue(objectbox)],
        child: const MaterialApp(home: CategoriesListSection()),
      ));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets(
        'editing keeps the grid position and every product follows the rename',
        (tester) async {
      final s = openStore('easify_b7_ui_edit');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      s.store.box<Category>().putMany([
        Category(name: 'Boissons', displayOrder: 0),
        Category(name: 'Cafés', displayOrder: 2),
      ]);
      s.store.box<Product>().put(product('Express', category: 'Cafés'));

      await pumpCategories(tester, s.store);

      // Pencil on the "Cafés" card → the real edit dialog.
      final card = find.ancestor(
          of: find.text('Cafés'), matching: find.byType(CategoryCard));
      await tester
          .tap(find.descendant(of: card, matching: find.byIcon(Icons.edit)));
      await tester.pumpAndSettle();
      expect(find.text('Modifier Catégorie'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Espressos');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // The product follows — it must not stay under the old name.
      expect(s.store.box<Product>().getAll().single.category, 'Espressos');

      // The category kept its identity and its place (used to reset to 0).
      final saved = s.store.box<Category>().getAll();
      expect(saved.map((c) => c.name), isNot(contains('Cafés')));
      final renamed = saved.firstWhere((c) => c.name == 'Espressos');
      expect(renamed.id, isNot(0), reason: 'same entity, not a duplicate');
      expect(renamed.displayOrder, 2,
          reason: 'editing must not jump the card to the front');
      expect(saved.firstWhere((c) => c.name == 'Boissons').displayOrder, 0);
    }, skip: storeSkip != null);

    testWidgets('a category that still holds products cannot be deleted',
        (tester) async {
      final s = openStore('easify_b7_ui_del');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      s.store.box<Category>().put(Category(name: 'Cafés', displayOrder: 0));
      s.store.box<Product>().putMany([
        product('Express', category: 'Cafés'),
        product('Noisette', category: 'Cafés'),
      ]);

      await pumpCategories(tester, s.store);

      final card = find.ancestor(
          of: find.text('Cafés'), matching: find.byType(CategoryCard));
      await tester
          .tap(find.descendant(of: card, matching: find.byIcon(Icons.delete)));
      await tester.pumpAndSettle();

      // Refused with the count — before any PIN prompt.
      expect(
          find.text(
              '« Cafés » : 2 produits l\'utilisent encore — changez-leur de catégorie d\'abord.'),
          findsOneWidget);
      expect(s.store.box<Category>().getAll(), hasLength(1),
          reason: 'the category must still be there');
      expect(s.store.box<Product>().getAll(), hasLength(2),
          reason: 'the products must still be there');
    }, skip: storeSkip != null);

    testWidgets('a new category is created at the end of the list',
        (tester) async {
      final s = openStore('easify_b7_ui_new');
      addTearDown(() {
        s.store.close();
        s.dir.deleteSync(recursive: true);
      });

      s.store.box<Category>().putMany([
        Category(name: 'Entrées', displayOrder: 0),
        Category(name: 'Plats', displayOrder: 1),
      ]);

      await pumpCategories(tester, s.store);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle Catégorie'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Desserts');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final desserts =
          s.store.box<Category>().getAll().firstWhere((c) => c.name == 'Desserts');
      expect(desserts.displayOrder, 2,
          reason: 'a new category appends after the existing ones '
              '(the old code put it at the front with 0)');
    }, skip: storeSkip != null);
  });
}
