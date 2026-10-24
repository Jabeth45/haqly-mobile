import 'package:drift/drift.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' as db;
import 'package:haqly_mobile/domain/models/category_constants.dart';
import 'package:haqly_mobile/domain/models/category_kind.dart';
import 'package:haqly_mobile/domain/models/user_category.dart';

/// Abstract contract for managing user categories.
/// Follows docs/PRD.md FR-E2, FR-E3, docs/ARCHITECTURE.md Section 4, and docs/RULES.md.
abstract class CategoryRepository {
  /// Atomically persists or updates a custom user category and enqueues an outbox pointer.
  Future<void> save(UserCategory category);

  /// Atomically marks a custom category as soft-deleted and enqueues an outbox pointer.
  /// Past transaction entries retain their string category (no orphans).
  Future<void> softDelete(String id, {String userId = 'LOCAL'});

  /// Retrieves a single active custom category by id.
  Future<UserCategory?> getById(String id, {String userId = 'LOCAL'});

  /// Retrieves a single active custom category by exact name match (case-insensitive).
  Future<UserCategory?> getByName(
    String name,
    CategoryKind kind, {
    String userId = 'LOCAL',
  });

  /// Retrieves active custom categories for [userId] and [kind].
  Future<List<UserCategory>> getCustomCategories(
    CategoryKind kind, {
    String userId = 'LOCAL',
  });

  /// Watches active custom categories for [userId] and [kind].
  Stream<List<UserCategory>> watchCustomCategories(
    CategoryKind kind, {
    String userId = 'LOCAL',
  });

  /// Returns all available category names for [kind] (built-in defaults + active custom),
  /// with defaults in their canonical order and active custom categories appended.
  Future<List<String>> getAllCategoryNames(
    CategoryKind kind, {
    String userId = 'LOCAL',
  });

  /// Watches all available category names for [kind] (built-in defaults + active custom).
  Stream<List<String>> watchAllCategoryNames(
    CategoryKind kind, {
    String userId = 'LOCAL',
  });

  /// Checks whether [name] is a custom category for [userId] and [kind].
  Future<bool> isCustomCategory(
    String name,
    CategoryKind kind, {
    String userId = 'LOCAL',
  });
}

/// Drift SQLite implementation of [CategoryRepository].
class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db, {this.clock = const SystemClock()});

  final db.AppDatabase _db;
  final Clock clock;

  @override
  Future<void> save(UserCategory category) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      await _db
          .into(_db.userCategories)
          .insertOnConflictUpdate(
            db.UserCategoriesCompanion(
              id: Value(category.id),
              userId: Value(category.userId),
              name: Value(category.name),
              kind: Value(category.kind.wireValue),
              createdAt: Value(category.createdAt.toUtc().toIso8601String()),
              clientUpdatedAt: Value(nowUtcIso),
              deletedAt: Value(category.deletedAt?.toUtc().toIso8601String()),
            ),
          );

      await _enqueueOutbox('user_categories', category.id, nowUtcIso);
    });
  }

  @override
  Future<void> softDelete(String id, {String userId = 'LOCAL'}) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final updatedRows =
          await (_db.update(_db.userCategories)..where(
                (c) =>
                    c.id.equals(id) &
                    c.userId.equals(userId) &
                    c.deletedAt.isNull(),
              ))
              .write(
                db.UserCategoriesCompanion(
                  deletedAt: Value(nowUtcIso),
                  clientUpdatedAt: Value(nowUtcIso),
                ),
              );

      if (updatedRows > 0) {
        await _enqueueOutbox('user_categories', id, nowUtcIso);
      }
    });
  }

  @override
  Future<UserCategory?> getById(String id, {String userId = 'LOCAL'}) async {
    final row =
        await (_db.select(_db.userCategories)..where(
              (c) =>
                  c.id.equals(id) &
                  c.userId.equals(userId) &
                  c.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (row == null) return null;
    return _mapToDomain(row);
  }

  @override
  Future<UserCategory?> getByName(
    String name,
    CategoryKind kind, {
    String userId = 'LOCAL',
  }) async {
    final trimmed = name.trim().toLowerCase();
    final row =
        await (_db.select(_db.userCategories)..where(
              (c) =>
                  c.userId.equals(userId) &
                  c.kind.equals(kind.wireValue) &
                  c.deletedAt.isNull() &
                  c.name.lower().equals(trimmed),
            ))
            .getSingleOrNull();

    if (row == null) return null;
    return _mapToDomain(row);
  }

  @override
  Future<List<UserCategory>> getCustomCategories(
    CategoryKind kind, {
    String userId = 'LOCAL',
  }) async {
    final rows =
        await (_db.select(_db.userCategories)
              ..where(
                (c) =>
                    c.userId.equals(userId) &
                    c.kind.equals(kind.wireValue) &
                    c.deletedAt.isNull(),
              )
              ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
            .get();

    return rows.map(_mapToDomain).toList();
  }

  @override
  Stream<List<UserCategory>> watchCustomCategories(
    CategoryKind kind, {
    String userId = 'LOCAL',
  }) {
    return (_db.select(_db.userCategories)
          ..where(
            (c) =>
                c.userId.equals(userId) &
                c.kind.equals(kind.wireValue) &
                c.deletedAt.isNull(),
          )
          ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .watch()
        .map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Future<List<String>> getAllCategoryNames(
    CategoryKind kind, {
    String userId = 'LOCAL',
  }) async {
    final custom = await getCustomCategories(kind, userId: userId);
    return _combineWithDefaults(kind, custom);
  }

  @override
  Stream<List<String>> watchAllCategoryNames(
    CategoryKind kind, {
    String userId = 'LOCAL',
  }) {
    return watchCustomCategories(
      kind,
      userId: userId,
    ).map((custom) => _combineWithDefaults(kind, custom));
  }

  @override
  Future<bool> isCustomCategory(
    String name,
    CategoryKind kind, {
    String userId = 'LOCAL',
  }) async {
    final defaults = _defaultsFor(kind);
    final isDefault = defaults.any(
      (d) => d.trim().toLowerCase() == name.trim().toLowerCase(),
    );
    if (isDefault) return false;

    final existing = await getByName(name, kind, userId: userId);
    return existing != null;
  }

  List<String> _defaultsFor(CategoryKind kind) {
    return switch (kind) {
      CategoryKind.expense => CategoryConstants.defaultExpenseCategories,
      CategoryKind.income => CategoryConstants.defaultIncomeCategories,
    };
  }

  List<String> _combineWithDefaults(
    CategoryKind kind,
    List<UserCategory> custom,
  ) {
    final defaults = _defaultsFor(kind);
    final combined = List<String>.from(defaults);
    final lowerDefaults = defaults.map((d) => d.toLowerCase()).toSet();

    for (final c in custom) {
      if (!lowerDefaults.contains(c.name.trim().toLowerCase())) {
        combined.add(c.name.trim());
      }
    }
    return combined;
  }

  Future<void> _enqueueOutbox(
    String tableName,
    String rowId,
    String nowUtcIso,
  ) async {
    final existingOutbox =
        await (_db.select(_db.outbox)..where(
              (o) => o.recordTable.equals(tableName) & o.rowId.equals(rowId),
            ))
            .getSingleOrNull();

    if (existingOutbox == null) {
      await _db
          .into(_db.outbox)
          .insert(
            db.OutboxCompanion.insert(
              recordTable: tableName,
              rowId: rowId,
              createdAt: nowUtcIso,
            ),
          );
    } else {
      await (_db.update(
        _db.outbox,
      )..where((o) => o.id.equals(existingOutbox.id))).write(
        db.OutboxCompanion(
          createdAt: Value(nowUtcIso),
          attempts: const Value(0),
          lastError: const Value(null),
        ),
      );
    }
  }

  UserCategory _mapToDomain(db.UserCategory row) {
    return UserCategory(
      id: row.id,
      userId: row.userId,
      name: row.name,
      kind: CategoryKind.fromString(row.kind),
      createdAt: DateTime.parse(row.createdAt),
      clientUpdatedAt: DateTime.parse(row.clientUpdatedAt),
      deletedAt: row.deletedAt != null ? DateTime.parse(row.deletedAt!) : null,
    );
  }
}
