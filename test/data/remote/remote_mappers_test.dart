import 'package:flutter_test/flutter_test.dart';
import 'package:haqly_mobile/data/db/app_database.dart';
import 'package:haqly_mobile/data/remote/remote_mappers.dart';

void main() {
  group('TASK-026: RemoteMappers - Decimal Conversion & Parity', () {
    test('minorToDecimal converts santim to Birr decimal', () {
      expect(RemoteMappers.minorToDecimal(0), 0.0);
      expect(RemoteMappers.minorToDecimal(50), 0.50);
      expect(RemoteMappers.minorToDecimal(1250), 12.50);
      expect(RemoteMappers.minorToDecimal(1500000), 15000.00);
    });

    test('decimalToMinor converts decimal to santim without float drift', () {
      expect(RemoteMappers.decimalToMinor(0), 0);
      expect(RemoteMappers.decimalToMinor(0.50), 50);
      expect(RemoteMappers.decimalToMinor(12.50), 1250);
      expect(RemoteMappers.decimalToMinor(15000.00), 1500000);
    });

    test('expenseToRemote maps correctly to Supabase schema', () {
      const expense = Expense(
        id: 'exp-1',
        userId: 'user-1',
        name: 'Injera',
        amountMinor: 45000,
        category: 'Meals',
        type: 'expense',
        localDate: '2026-10-24',
        createdAt: '2026-10-24T10:00:00.000Z',
        clientUpdatedAt: '2026-10-24T10:00:00.000Z',
        deletedAt: null,
      );

      final remote = RemoteMappers.expenseToRemote(expense);
      expect(remote['id'], 'exp-1');
      expect(remote['user_id'], 'user-1');
      expect(remote['name'], 'Injera');
      expect(remote['amount'], 450.0);
      expect(remote['category'], 'Meals');
      expect(remote['type'], 'expense');
      expect(remote['local_date'], '2026-10-24');
      expect(remote['deleted_at'], isNull);
    });

    test('budgetToRemote handles null targets', () {
      const budget = Budget(
        id: 'bgt-1',
        userId: 'user-1',
        monthlyMinor: null,
        weeklyMinor: null,
        updatedAt: '2026-10-24T10:00:00.000Z',
        clientUpdatedAt: '2026-10-24T10:00:00.000Z',
      );

      final remote = RemoteMappers.budgetToRemote(budget);
      expect(remote['id'], 'bgt-1');
      expect(remote['monthly_budget'], isNull);
      expect(remote['weekly_budget'], isNull);
    });
  });
}
