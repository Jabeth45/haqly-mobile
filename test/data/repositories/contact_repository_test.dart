import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/core/services/clock.dart';
import 'package:haqly_mobile/data/db/app_database.dart' hide Contact;
import 'package:haqly_mobile/data/repositories/contact_repository.dart';
import 'package:haqly_mobile/domain/models/contact.dart';

void main() {
  late AppDatabase db;
  late DriftContactRepository repo;
  final fixedClock = FixedClock(DateTime.utc(2026, 10, 24, 12, 0, 0));

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftContactRepository(db, clock: fixedClock);
  });

  tearDown(() async {
    await db.close();
  });

  Contact createSampleContact({
    String id = 'cnt-1',
    String userId = 'LOCAL',
    String name = 'Abebe Bikila',
    String? phone = '+251911223344',
    String? note = 'Friend from university',
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    final created = createdAt ?? DateTime.utc(2026, 10, 24, 10, 0, 0);
    return Contact(
      id: id,
      userId: userId,
      name: name,
      phone: phone,
      note: note,
      createdAt: created,
      clientUpdatedAt: created,
      deletedAt: deletedAt,
    );
  }

  group('TASK-024: ContactRepository - CRUD & Outbox Atomicity', () {
    test(
      'save inserts contact and enqueues outbox pointer atomically',
      () async {
        final contact = createSampleContact();
        await repo.save(contact);

        final fetched = await repo.getById('cnt-1');
        expect(fetched, isNotNull);
        expect(fetched!.id, 'cnt-1');
        expect(fetched.name, 'Abebe Bikila');
        expect(fetched.phone, '+251911223344');
        expect(fetched.note, 'Friend from university');
        expect(fetched.isDeleted, isFalse);

        final outboxEntries = await db.select(db.outbox).get();
        expect(outboxEntries.length, 1);
        expect(outboxEntries.first.recordTable, 'contacts');
        expect(outboxEntries.first.rowId, 'cnt-1');
        expect(outboxEntries.first.attempts, 0);
      },
    );

    test('save updates contact and coalesces outbox pointer', () async {
      final contact = createSampleContact();
      await repo.save(contact);

      final updated = contact.copyWith(phone: '+251922334455');
      await repo.save(updated);

      final fetched = await repo.getById('cnt-1');
      expect(fetched!.phone, '+251922334455');

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.recordTable, 'contacts');
      expect(outboxEntries.first.rowId, 'cnt-1');
    });

    test('softDelete sets deleted_at and enqueues outbox pointer', () async {
      final contact = createSampleContact();
      await repo.save(contact);

      await repo.softDelete('cnt-1');

      // Should no longer be retrievable by getById
      final fetched = await repo.getById('cnt-1');
      expect(fetched, isNull);

      // Verify row still exists in DB with deleted_at set
      final rawRow = await (db.select(
        db.contacts,
      )..where((c) => c.id.equals('cnt-1'))).getSingle();
      expect(rawRow.deletedAt, isNotNull);

      // Outbox coalesced to 1 entry
      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.length, 1);
      expect(outboxEntries.first.recordTable, 'contacts');
      expect(outboxEntries.first.rowId, 'cnt-1');
    });

    test('softDelete on non-existent contact is a safe no-op', () async {
      await repo.softDelete('non-existent');

      final outboxEntries = await db.select(db.outbox).get();
      expect(outboxEntries.isEmpty, isTrue);
    });
  });

  group('TASK-024: ContactRepository - Queries & Lookups', () {
    test(
      'getByName retrieves contact case-insensitively and excludes deleted',
      () async {
        final contact = createSampleContact(name: 'Derartu Tulu');
        await repo.save(contact);

        final fetchedExact = await repo.getByName('Derartu Tulu');
        expect(fetchedExact, isNotNull);
        expect(fetchedExact!.id, 'cnt-1');

        final fetchedLower = await repo.getByName('derartu tulu');
        expect(fetchedLower, isNotNull);

        final fetchedUpper = await repo.getByName('DERARTU TULU');
        expect(fetchedUpper, isNotNull);

        // Soft delete
        await repo.softDelete('cnt-1');
        final fetchedAfterDelete = await repo.getByName('Derartu Tulu');
        expect(fetchedAfterDelete, isNull);
      },
    );

    test(
      'getAll returns all active contacts ordered by name ascending',
      () async {
        await repo.save(createSampleContact(id: 'c-1', name: 'Zelalem'));
        await repo.save(createSampleContact(id: 'c-2', name: 'Almaz'));
        await repo.save(createSampleContact(id: 'c-3', name: 'Chala'));
        await repo.save(createSampleContact(id: 'c-4', name: 'Deleted Person'));
        await repo.softDelete('c-4');

        final all = await repo.getAll();
        expect(all.length, 3);
        expect(all.map((c) => c.name).toList(), ['Almaz', 'Chala', 'Zelalem']);
      },
    );

    test(
      'search filters by name or phone substring case-insensitively',
      () async {
        await repo.save(
          createSampleContact(
            id: 'c-1',
            name: 'Haile Gebrselassie',
            phone: '+251911001122',
          ),
        );
        await repo.save(
          createSampleContact(
            id: 'c-2',
            name: 'Kenenisa Bekele',
            phone: '+251922003344',
          ),
        );
        await repo.save(
          createSampleContact(
            id: 'c-3',
            name: 'Sileshi Sihine',
            phone: '+251933005566',
          ),
        );

        // Match by partial name
        final byName = await repo.search('gebr');
        expect(byName.length, 1);
        expect(byName.first.name, 'Haile Gebrselassie');

        // Match by partial phone
        final byPhone = await repo.search('0033');
        expect(byPhone.length, 1);
        expect(byPhone.first.name, 'Kenenisa Bekele');

        // Empty query returns all
        final all = await repo.search('');
        expect(all.length, 3);

        // No match
        final none = await repo.search('XYZ');
        expect(none.isEmpty, isTrue);
      },
    );
  });

  group('TASK-024: ContactRepository - Reactive Streams', () {
    test('watchAll emits updated contact list on insert and delete', () async {
      final streamEvents = <List<Contact>>[];
      final subscription = repo.watchAll().listen(streamEvents.add);

      await pumpEventQueue();
      expect(streamEvents.length, 1);
      expect(streamEvents.first.isEmpty, isTrue);

      await repo.save(createSampleContact(id: 'c-1', name: 'Abebe'));
      await pumpEventQueue();
      expect(streamEvents.length, 2);
      expect(streamEvents.last.length, 1);

      await repo.softDelete('c-1');
      await pumpEventQueue();
      expect(streamEvents.length, 3);
      expect(streamEvents.last.isEmpty, isTrue);

      await subscription.cancel();
    });

    test('watchSearch emits filtered list reactively', () async {
      await repo.save(createSampleContact(id: 'c-1', name: 'Abebe'));
      await repo.save(createSampleContact(id: 'c-2', name: 'Abera'));
      await repo.save(createSampleContact(id: 'c-3', name: 'Chala'));

      final streamEvents = <List<Contact>>[];
      final subscription = repo.watchSearch('Abe').listen(streamEvents.add);

      await pumpEventQueue();
      expect(streamEvents.length, 1);
      expect(streamEvents.first.map((c) => c.name).toList(), [
        'Abebe',
        'Abera',
      ]);

      // Add another matching contact
      await repo.save(createSampleContact(id: 'c-4', name: 'Abel'));
      await pumpEventQueue();
      expect(streamEvents.length, 2);
      expect(streamEvents.last.map((c) => c.name).toList(), [
        'Abebe',
        'Abel',
        'Abera',
      ]);

      await subscription.cancel();
    });
  });
}
