import 'package:drift/drift.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' as db;
import 'package:haqly_mobile/domain/models/contact.dart';

/// Abstract contract for managing user contacts for ledger debts and tracking.
/// Follows docs/PRD.md FR-L4, docs/ARCHITECTURE.md Section 4, and docs/RULES.md.
abstract class ContactRepository {
  /// Atomically persists or updates a contact and enqueues an outbox pointer.
  Future<void> save(Contact contact);

  /// Atomically marks a contact as soft-deleted and enqueues an outbox pointer.
  Future<void> softDelete(String id, {String userId = 'LOCAL'});

  /// Retrieves a single active (non-deleted) contact by id.
  Future<Contact?> getById(String id, {String userId = 'LOCAL'});

  /// Retrieves a single active contact by exact name match (case-insensitive).
  Future<Contact?> getByName(String name, {String userId = 'LOCAL'});

  /// Retrieves all active contacts for [userId], ordered by name ASC.
  Future<List<Contact>> getAll({String userId = 'LOCAL'});

  /// Watches all active contacts for [userId], ordered by name ASC.
  Stream<List<Contact>> watchAll({String userId = 'LOCAL'});

  /// Searches active contacts by name or phone (case-insensitive substring match).
  Future<List<Contact>> search(String query, {String userId = 'LOCAL'});

  /// Watches active contacts matching a search query.
  Stream<List<Contact>> watchSearch(String query, {String userId = 'LOCAL'});
}

/// Drift SQLite implementation of [ContactRepository].
class DriftContactRepository implements ContactRepository {
  DriftContactRepository(this._db, {this.clock = const SystemClock()});

  final db.AppDatabase _db;
  final Clock clock;

  @override
  Future<void> save(Contact contact) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      await _db
          .into(_db.contacts)
          .insertOnConflictUpdate(
            db.ContactsCompanion(
              id: Value(contact.id),
              userId: Value(contact.userId),
              name: Value(contact.name),
              phone: Value(contact.phone),
              note: Value(contact.note),
              createdAt: Value(contact.createdAt.toUtc().toIso8601String()),
              clientUpdatedAt: Value(nowUtcIso),
              deletedAt: Value(contact.deletedAt?.toUtc().toIso8601String()),
            ),
          );

      await _enqueueOutbox('contacts', contact.id, nowUtcIso);
    });
  }

  @override
  Future<void> softDelete(String id, {String userId = 'LOCAL'}) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final updatedRows =
          await (_db.update(_db.contacts)..where(
                (c) =>
                    c.id.equals(id) &
                    c.userId.equals(userId) &
                    c.deletedAt.isNull(),
              ))
              .write(
                db.ContactsCompanion(
                  deletedAt: Value(nowUtcIso),
                  clientUpdatedAt: Value(nowUtcIso),
                ),
              );

      if (updatedRows > 0) {
        await _enqueueOutbox('contacts', id, nowUtcIso);
      }
    });
  }

  @override
  Future<Contact?> getById(String id, {String userId = 'LOCAL'}) async {
    final row =
        await (_db.select(_db.contacts)..where(
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
  Future<Contact?> getByName(String name, {String userId = 'LOCAL'}) async {
    final trimmed = name.trim().toLowerCase();
    final row =
        await (_db.select(_db.contacts)..where(
              (c) =>
                  c.userId.equals(userId) &
                  c.deletedAt.isNull() &
                  c.name.lower().equals(trimmed),
            ))
            .getSingleOrNull();

    if (row == null) return null;
    return _mapToDomain(row);
  }

  @override
  Future<List<Contact>> getAll({String userId = 'LOCAL'}) async {
    final rows =
        await (_db.select(_db.contacts)
              ..where((c) => c.userId.equals(userId) & c.deletedAt.isNull())
              ..orderBy([(c) => OrderingTerm.asc(c.name)]))
            .get();

    return rows.map(_mapToDomain).toList();
  }

  @override
  Stream<List<Contact>> watchAll({String userId = 'LOCAL'}) {
    return (_db.select(_db.contacts)
          ..where((c) => c.userId.equals(userId) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch()
        .map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Future<List<Contact>> search(String query, {String userId = 'LOCAL'}) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return getAll(userId: userId);
    }

    final rows =
        await (_db.select(_db.contacts)
              ..where(
                (c) =>
                    c.userId.equals(userId) &
                    c.deletedAt.isNull() &
                    (c.name.lower().like('%$trimmed%') |
                        (c.phone.isNotNull() &
                            c.phone.lower().like('%$trimmed%'))),
              )
              ..orderBy([(c) => OrderingTerm.asc(c.name)]))
            .get();

    return rows.map(_mapToDomain).toList();
  }

  @override
  Stream<List<Contact>> watchSearch(String query, {String userId = 'LOCAL'}) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return watchAll(userId: userId);
    }

    return (_db.select(_db.contacts)
          ..where(
            (c) =>
                c.userId.equals(userId) &
                c.deletedAt.isNull() &
                (c.name.lower().like('%$trimmed%') |
                    (c.phone.isNotNull() & c.phone.lower().like('%$trimmed%'))),
          )
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch()
        .map((rows) => rows.map(_mapToDomain).toList());
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

  Contact _mapToDomain(db.Contact row) {
    return Contact(
      id: row.id,
      userId: row.userId,
      name: row.name,
      phone: row.phone,
      note: row.note,
      createdAt: DateTime.parse(row.createdAt),
      clientUpdatedAt: DateTime.parse(row.clientUpdatedAt),
      deletedAt: row.deletedAt != null ? DateTime.parse(row.deletedAt!) : null,
    );
  }
}
