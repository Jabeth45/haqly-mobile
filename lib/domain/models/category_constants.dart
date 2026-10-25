import 'package:haqly_mobile/domain/models/category_kind.dart';

/// Built-in category defaults and emoji mapping.
/// Follows docs/PRD.md FR-E2, FR-E3 and docs/DOMAIN_SPEC.md §9. Pure Dart only.
abstract final class CategoryConstants {
  /// Default expense categories in specified display order.
  static const List<String> defaultExpenseCategories = [
    'Meals',
    'Transport',
    'Extras',
    'Bills',
    'Health',
    'Other',
  ];

  /// Default income categories in specified display order.
  static const List<String> defaultIncomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Bonus',
    'Student',
    'Other',
  ];

  /// Emoji mappings for default expense categories.
  static const Map<String, String> expenseEmojis = {
    'Meals': '🍽️',
    'Transport': '🚗',
    'Extras': '✨',
    'Bills': '📋',
    'Health': '💊',
    'Other': '📦',
  };

  /// Fallback emoji when no specific emoji is configured.
  static const String fallbackEmoji = '📦';

  /// Returns the emoji icon for a category name.
  static String emojiFor(String category, {CategoryKind? kind}) {
    return expenseEmojis[category] ?? fallbackEmoji;
  }
}
