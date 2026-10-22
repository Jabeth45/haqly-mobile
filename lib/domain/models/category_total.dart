import 'package:haqly_mobile/domain/money.dart';

/// Aggregated total expenditure or income grouped by category.
/// Pure Dart only.
class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.total,
    required this.count,
  });

  final String category;
  final Money total;
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryTotal &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          total == other.total &&
          count == other.count;

  @override
  int get hashCode => category.hashCode ^ total.hashCode ^ count.hashCode;

  @override
  String toString() =>
      'CategoryTotal(category: $category, total: ${Money.format(total)}, count: $count)';
}
