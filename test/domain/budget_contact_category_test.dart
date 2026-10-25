import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/domain/models/budget.dart';
import 'package:haqly_mobile/domain/models/category_constants.dart';
import 'package:haqly_mobile/domain/models/category_kind.dart';
import 'package:haqly_mobile/domain/models/contact.dart';
import 'package:haqly_mobile/domain/models/user_category.dart';
import 'package:haqly_mobile/domain/money.dart';

void main() {
  group('TASK-024: Domain Models - Budget', () {
    final now = DateTime.utc(2026, 10, 24, 12, 0, 0);

    test('Budget properties, equality, and copyWith', () {
      final b1 = Budget(
        id: 'b-1',
        monthly: const Money.fromMinorUnits(50000),
        weekly: const Money.fromMinorUnits(12000),
        updatedAt: now,
        clientUpdatedAt: now,
      );

      expect(b1.hasMonthly, isTrue);
      expect(b1.hasWeekly, isTrue);
      expect(b1.isEmpty, isFalse);
      expect(b1.userId, 'LOCAL');
      expect(b1.toString(), contains('Br 500.00'));

      final b2 = Budget(
        id: 'b-1',
        monthly: const Money.fromMinorUnits(50000),
        weekly: const Money.fromMinorUnits(12000),
        updatedAt: now,
        clientUpdatedAt: now,
      );
      expect(b1, equals(b2));
      expect(b1.hashCode, equals(b2.hashCode));

      final cleared = b1.copyWith(monthly: () => null, weekly: () => null);
      expect(cleared.isEmpty, isTrue);
      expect(cleared.hasMonthly, isFalse);
      expect(cleared.hasWeekly, isFalse);
    });
  });

  group('TASK-024: Domain Models - Contact', () {
    final now = DateTime.utc(2026, 10, 24, 12, 0, 0);

    test('Contact properties, equality, and copyWith', () {
      final c1 = Contact(
        id: 'c-1',
        name: 'Abebe',
        phone: '+251911223344',
        note: 'Colleague',
        createdAt: now,
        clientUpdatedAt: now,
      );

      expect(c1.isDeleted, isFalse);
      expect(c1.toString(), contains('Abebe'));

      final c2 = Contact(
        id: 'c-1',
        name: 'Abebe',
        phone: '+251911223344',
        note: 'Colleague',
        createdAt: now,
        clientUpdatedAt: now,
      );
      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));

      final deleted = c1.copyWith(deletedAt: now);
      expect(deleted.isDeleted, isTrue);
      expect(deleted, isNot(equals(c1)));
    });
  });

  group('TASK-024: Domain Models - CategoryKind and Constants', () {
    test('CategoryKind string parsing and wireValue', () {
      expect(CategoryKind.fromString('expense'), CategoryKind.expense);
      expect(CategoryKind.fromString('EXPENSE'), CategoryKind.expense);
      expect(CategoryKind.fromString('income'), CategoryKind.income);
      expect(CategoryKind.fromString('INCOME'), CategoryKind.income);
      expect(CategoryKind.fromString('other'), CategoryKind.expense);
    });

    test('CategoryConstants emojis and defaults match DOMAIN_SPEC §9', () {
      expect(CategoryConstants.defaultExpenseCategories, [
        'Meals',
        'Transport',
        'Extras',
        'Bills',
        'Health',
        'Other',
      ]);

      expect(CategoryConstants.defaultIncomeCategories, [
        'Salary',
        'Freelance',
        'Business',
        'Investment',
        'Bonus',
        'Student',
        'Other',
      ]);

      expect(CategoryConstants.emojiFor('Meals'), '🍽️');
      expect(CategoryConstants.emojiFor('Transport'), '🚗');
      expect(CategoryConstants.emojiFor('Extras'), '✨');
      expect(CategoryConstants.emojiFor('Bills'), '📋');
      expect(CategoryConstants.emojiFor('Health'), '💊');
      expect(CategoryConstants.emojiFor('Other'), '📦');
      expect(CategoryConstants.emojiFor('UnknownCustom'), '📦');
    });
  });

  group('TASK-024: Domain Models - UserCategory', () {
    final now = DateTime.utc(2026, 10, 24, 12, 0, 0);

    test('UserCategory properties, equality, and emoji', () {
      final cat1 = UserCategory(
        id: 'uc-1',
        name: 'Meals',
        kind: CategoryKind.expense,
        createdAt: now,
        clientUpdatedAt: now,
      );

      expect(cat1.emoji, '🍽️');
      expect(cat1.isDeleted, isFalse);

      final catCustom = UserCategory(
        id: 'uc-2',
        name: 'CustomGym',
        kind: CategoryKind.expense,
        createdAt: now,
        clientUpdatedAt: now,
      );
      expect(catCustom.emoji, '📦');

      final deleted = cat1.copyWith(deletedAt: now);
      expect(deleted.isDeleted, isTrue);
    });
  });
}
