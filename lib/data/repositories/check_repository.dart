import 'package:drift/drift.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' as db;
import 'package:haqly_mobile/domain/check_calculator.dart';
import 'package:haqly_mobile/domain/models/check_item.dart';
import 'package:haqly_mobile/domain/money.dart';

abstract class CheckRepository {
  Future<void> save(CheckItem item);

  Future<void> softDelete(String id, {String userId = 'LOCAL'});

  Future<CheckItem?> getById(String id, {String userId = 'LOCAL'});

  Stream<List<CheckItem>> watchAll({String userId = 'LOCAL'});

  Stream<List<CheckItem>> watchByDate(
    String localDate, {
    String userId = 'LOCAL',
  });

  Future<List<Verdict>> getVerdicts({
    String? startLocalDate,
    String? endLocalDate,
    String userId = 'LOCAL',
  });

  Future<List<Verdict>> getRecentVerdicts({
    int limit = 10,
    String userId = 'LOCAL',
  });
}

class DriftCheckRepository implements CheckRepository {
  DriftCheckRepository(this._db, {this.clock = const SystemClock()});

  final db.AppDatabase _db;
  final Clock clock;

  @override
  Future<void> save(CheckItem item) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      await _db
          .into(_db.checkItems)
          .insertOnConflictUpdate(
            db.CheckItemsCompanion(
              id: Value(item.id),
              userId: Value(item.userId),
              name: Value(item.name),
              priceMinor: Value(item.price.minorUnits),
              uses: Value(item.uses),
              costPerUseMinor: Value(item.costPerUseMinor),
              verdict: Value(item.verdict.wireValue),
              regretLevel: Value(item.regretLevel),
              localDate: Value(item.localDate),
              createdAt: Value(item.createdAt.toUtc().toIso8601String()),
              clientUpdatedAt: Value(nowUtcIso),
              deletedAt: Value(item.deletedAt?.toUtc().toIso8601String()),
            ),
          );

      await _enqueueOutbox('check_items', item.id, nowUtcIso);
    });
  }

  @override
  Future<void> softDelete(String id, {String userId = 'LOCAL'}) async {
    final nowUtcIso = clock.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final updatedRows =
          await (_db.update(_db.checkItems)..where(
                (c) =>
                    c.id.equals(id) &
                    c.userId.equals(userId) &
                    c.deletedAt.isNull(),
              ))
              .write(
                db.CheckItemsCompanion(
                  deletedAt: Value(nowUtcIso),
                  clientUpdatedAt: Value(nowUtcIso),
                ),
              );

      if (updatedRows > 0) {
        await _enqueueOutbox('check_items', id, nowUtcIso);
      }
    });
  }

  @override
  Future<CheckItem?> getById(String id, {String userId = 'LOCAL'}) async {
    final row =
        await (_db.select(_db.checkItems)..where(
              (c) =>
                  c.id.equals(id) &
                  c.userId.equals(userId) &
                  c.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    return row != null ? _mapToDomain(row) : null;
  }

  @override
  Stream<List<CheckItem>> watchAll({String userId = 'LOCAL'}) {
    final query = _db.select(_db.checkItems)
      ..where((c) => c.userId.equals(userId) & c.deletedAt.isNull())
      ..orderBy([
        (c) => OrderingTerm.desc(c.localDate),
        (c) => OrderingTerm.desc(c.createdAt),
      ]);

    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Stream<List<CheckItem>> watchByDate(
    String localDate, {
    String userId = 'LOCAL',
  }) {
    final query = _db.select(_db.checkItems)
      ..where(
        (c) =>
            c.userId.equals(userId) &
            c.localDate.equals(localDate) &
            c.deletedAt.isNull(),
      )
      ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]);

    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Future<List<Verdict>> getVerdicts({
    String? startLocalDate,
    String? endLocalDate,
    String userId = 'LOCAL',
  }) async {
    final query = _db.selectOnly(_db.checkItems)
      ..where(
        _db.checkItems.userId.equals(userId) &
            _db.checkItems.deletedAt.isNull() &
            (startLocalDate != null
                ? _db.checkItems.localDate.isBiggerOrEqualValue(startLocalDate)
                : const Constant(true)) &
            (endLocalDate != null
                ? _db.checkItems.localDate.isSmallerOrEqualValue(endLocalDate)
                : const Constant(true)),
      )
      ..orderBy([
        OrderingTerm.desc(_db.checkItems.localDate),
        OrderingTerm.desc(_db.checkItems.createdAt),
      ])
      ..addColumns([_db.checkItems.verdict]);

    final rows = await query.get();
    return rows
        .map((r) => Verdict.fromWire(r.read(_db.checkItems.verdict)!))
        .toList();
  }

  @override
  Future<List<Verdict>> getRecentVerdicts({
    int limit = 10,
    String userId = 'LOCAL',
  }) async {
    final query = _db.selectOnly(_db.checkItems)
      ..where(
        _db.checkItems.userId.equals(userId) &
            _db.checkItems.deletedAt.isNull(),
      )
      ..orderBy([
        OrderingTerm.desc(_db.checkItems.localDate),
        OrderingTerm.desc(_db.checkItems.createdAt),
      ])
      ..limit(limit)
      ..addColumns([_db.checkItems.verdict]);

    final rows = await query.get();
    return rows
        .map((r) => Verdict.fromWire(r.read(_db.checkItems.verdict)!))
        .toList();
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

  CheckItem _mapToDomain(db.CheckItem row) {
    return CheckItem(
      id: row.id,
      userId: row.userId,
      name: row.name,
      price: Money.fromMinorUnits(row.priceMinor),
      uses: row.uses,
      costPerUseMinor: row.costPerUseMinor,
      verdict: Verdict.fromWire(row.verdict),
      regretLevel: row.regretLevel,
      localDate: row.localDate,
      createdAt: DateTime.parse(row.createdAt),
      clientUpdatedAt: DateTime.parse(row.clientUpdatedAt),
      deletedAt: row.deletedAt != null ? DateTime.parse(row.deletedAt!) : null,
    );
  }
}
