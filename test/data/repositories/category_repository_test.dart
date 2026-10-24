import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' hide UserCategory;
import 'package:haqly_mobile/data/repositories/category_repository.dart';
import 'package:haqly_mobile/domain/models/category_constants.dart';
import 'package:haqly_mobile/domain/models/category_kind.dart';
import 'package:haqly_mobile/domain/models/user_category.dart';

void main() {
  late AppDatabase db;
  late DriftCategoryRepository repo;
  final fixedClock = FixedClock(DateTime.utc(2026, 10, 24, 12, 0, 0));

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftCategoryRepository(db, clock: fixedClock);
  });

  tearDown(() async {
    await db.close();
  });

  UserCategory createSampleCategory({
    String id = 'cat-1',
    String userId = 'LOCAL',
    String name = 'Gym & Fitness',
    CategoryKind kind = CategoryKind.expense,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    final created = createdAt ?? DateTime.utc(2026, 10, 24, 10, 0, 0);
    return UserCategory(
      id: id,
      userId: userId,
      name: name,
      kind: kind,
      createdAt: created,
      clientUpdatedAt: created,
      deletedAt: deletedAt,
    );
  }

  group('TASK-024: CategoryRepository - CRUD & Outbox Atomicity', () {
    test(
      'save inserts category and enqueues outbox pointer atomically',
      () async {
        final category = createSampleCategory();
        await repo.save(category);

        final fetched = await repo.getById('cat-1');
        expect(fetched, isNotNull);
        expect(fetched!.id, 'cat-1');
        expect(fetched.name, 'Gym & Fitness');
        expect(fetched.kind, CategoryKind.expense);
        expect(fetched.isDeleted, isFalse);

        final outboxEntries = await db.select(db.outbox).get();
        expect(outboxEntries.length, 1);
        expect(outboxEntries.first.recordTable, 'user_categories');
        expect(outboxEntries.first.rowId, 'cat-1');
        expect(outboxEntries.first.attempts, 0);
      },
    );

    test('save updates category and coalesces outbox pointer', () async {
      final category = createSampleCategory();
      await repo.save(category);

      final updated = category.copyWith(name: 'Fitness & Health');
      await repo.save(updated);

      final fetched = await repo.getById('cat-1');
      expect(fetched!.name, 'Fitness & Health');

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.recordTable, 'user_categories');
      expect(outboxEntries.first.rowId, 'cat-1');
    });

    test('softDelete sets deleted_at and enqueues outbox pointer', () async {
      final category = createSampleCategory();
      await repo.save(category);

      await repo.softDelete('cat-1');

      final fetched = await repo.getById('cat-1');
      expect(fetched, isNull);

      final rawRow = await (db.select(
        db.userCategories,
      )..where((c) => c.id.equals('cat-1'))).getSingle();
      expect(rawRow.deletedAt, isNotNull);

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.recordTable, 'user_categories');
      expect(outboxEntries.first.rowId, 'cat-1');
    });

    test('softDelete on non-existent category is a safe no-op', () async {
      await repo.softDelete('non-existent');

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.isEmpty, isTrue);
    });
  });

  group('TASK-024: CategoryRepository - Queries & Defaults Combination', () {
    test(
      'getCustomCategories filters by kind and excludes soft-deleted',
      () async {
        await repo.save(
          createSampleCategory(
            id: 'cat-exp-1',
            name: 'Books',
            kind: CategoryKind.expense,
          ),
        );
        await repo.save(
          createSampleCategory(
            id: 'cat-inc-1',
            name: 'Teaching',
            kind: CategoryKind.income,
          ),
        );
        await repo.save(
          createSampleCategory(
            id: 'cat-exp-del',
            name: 'Old Category',
            kind: CategoryKind.expense,
          ),
        );
        await repo.softDelete('cat-exp-del');

        final expenseCustom = await repo.getCustomCategories(
          CategoryKind.expense,
        );
        expect(expenseCustom.length, 1);
        expect(expenseCustom.first.name, 'Books');

        final incomeCustom = await repo.getCustomCategories(
          CategoryKind.income,
        );
        expect(incomeCustom.length, 1);
        expect(incomeCustom.first.name, 'Teaching');
      },
    );

    test(
      'getAllCategoryNames returns canonical defaults when no custom exist',
      () async {
        final expenseNames = await repo.getAllCategoryNames(
          CategoryKind.expense,
        );
        expect(expenseNames, CategoryConstants.defaultExpenseCategories);
        expect(expenseNames, [
          'Meals',
          'Transport',
          'Extras',
          'Bills',
          'Health',
          'Other',
        ]);

        final incomeNames = await repo.getAllCategoryNames(CategoryKind.income);
        expect(incomeNames, CategoryConstants.defaultIncomeCategories);
        expect(incomeNames, [
          'Salary',
          'Freelance',
          'Business',
          'Investment',
          'Bonus',
          'Student',
          'Other',
        ]);
      },
    );

    test('getAllCategoryNames appends custom categories without duplicate defaults', () async {
      await repo.save(
        createSampleCategory(
          id: 'c-1',
          name: 'Electronics',
          kind: CategoryKind.expense,
        ),
      );
      await repo.save(
        createSampleCategory(
          id: 'c-2',
          name: 'Education',
          kind: CategoryKind.expense,
        ),
      );
      // Save duplicate of default name
      await repo.save(
        createSampleCategory(
          id: 'c-3',
          name: 'Meals',
          kind: CategoryKind.expense,
        ),
      );

      final names = await repo.getAllCategoryNames(CategoryKind.expense);
      expect(names, [
        'Meals',
        'Transport',
        'Extras',
        'Bills',
        'Health',
        'Other',
        'Electronics',
        'Education',
      ]);
    });

    test(
      'getByName retrieves category case-insensitively and respects kind',
      () async {
        await repo.save(
          createSampleCategory(
            id: 'c-1',
            name: 'Gadgets',
            kind: CategoryKind.expense,
          ),
        );

        final foundExact = await repo.getByName(
          'Gadgets',
          CategoryKind.expense,
        );
        expect(foundExact, isNotNull);
        expect(foundExact!.id, 'c-1');

        final foundLower = await repo.getByName(
          'gadgets',
          CategoryKind.expense,
        );
        expect(foundLower, isNotNull);

        final foundWrongKind = await repo.getByName(
          'Gadgets',
          CategoryKind.income,
        );
        expect(foundWrongKind, isNull);
      },
    );

    test('isCustomCategory checks custom vs default', () async {
      await repo.save(
        createSampleCategory(
          id: 'c-1',
          name: 'Cosmetics',
          kind: CategoryKind.expense,
        ),
      );

      // Built-in default
      expect(
        await repo.isCustomCategory('Meals', CategoryKind.expense),
        isFalse,
      );
      expect(
        await repo.isCustomCategory('meals', CategoryKind.expense),
        isFalse,
      );

      // Custom category
      expect(
        await repo.isCustomCategory('Cosmetics', CategoryKind.expense),
        isTrue,
      );
      expect(
        await repo.isCustomCategory('cosmetics', CategoryKind.expense),
        isTrue,
      );

      // Non-existent
      expect(
        await repo.isCustomCategory('Unicorn', CategoryKind.expense),
        isFalse,
      );
    });
  });

  group('TASK-024: CategoryRepository - Reactive Streams', () {
    test('watchCustomCategories emits updates reactively', () async {
      final streamEvents = <List<UserCategory>>[];
      final subscription = repo
          .watchCustomCategories(CategoryKind.expense)
          .listen(streamEvents.add);

      await pumpEventQueue();
      expect(streamEvents.length, 1);
      expect(streamEvents.first.isEmpty, isTrue);

      await repo.save(createSampleCategory(id: 'c-1', name: 'Charity'));
      await pumpEventQueue();
      expect(streamEvents.length, 2);
      expect(streamEvents.last.map((c) => c.name).toList(), ['Charity']);

      await repo.softDelete('c-1');
      await pumpEventQueue();
      expect(streamEvents.length, 3);
      expect(streamEvents.last.isEmpty, isTrue);

      await subscription.cancel();
    });

    test('watchAllCategoryNames emits combined list reactively', () async {
      final streamEvents = <List<String>>[];
      final subscription = repo
          .watchAllCategoryNames(CategoryKind.expense)
          .listen(streamEvents.add);

      await pumpEventQueue();
      expect(streamEvents.length, 1);
      expect(streamEvents.first, CategoryConstants.defaultExpenseCategories);

      await repo.save(createSampleCategory(id: 'c-1', name: 'Subscriptions'));
      await pumpEventQueue();
      expect(streamEvents.length, 2);
      expect(streamEvents.last, [
        ...CategoryConstants.defaultExpenseCategories,
        'Subscriptions',
      ]);

      await subscription.cancel();
    });
  });
}
