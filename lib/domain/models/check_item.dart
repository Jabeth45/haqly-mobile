import 'package:haqly_mobile/domain/check_calculator.dart';
import 'package:haqly_mobile/domain/money.dart';

class CheckItem {
  const CheckItem({
    required this.id,
    this.userId = 'LOCAL',
    required this.name,
    required this.price,
    required this.uses,
    this.costPerUseMinor,
    required this.verdict,
    required this.regretLevel,
    required this.localDate,
    required this.createdAt,
    required this.clientUpdatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final Money price;
  final double uses;
  final int? costPerUseMinor;
  final Verdict verdict;
  final int regretLevel;
  final String localDate;
  final DateTime createdAt;
  final DateTime clientUpdatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  CheckItem copyWith({
    String? id,
    String? userId,
    String? name,
    Money? price,
    double? uses,
    int? costPerUseMinor,
    Verdict? verdict,
    int? regretLevel,
    String? localDate,
    DateTime? createdAt,
    DateTime? clientUpdatedAt,
    DateTime? deletedAt,
  }) {
    return CheckItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      price: price ?? this.price,
      uses: uses ?? this.uses,
      costPerUseMinor: costPerUseMinor ?? this.costPerUseMinor,
      verdict: verdict ?? this.verdict,
      regretLevel: regretLevel ?? this.regretLevel,
      localDate: localDate ?? this.localDate,
      createdAt: createdAt ?? this.createdAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          price == other.price &&
          uses == other.uses &&
          costPerUseMinor == other.costPerUseMinor &&
          verdict == other.verdict &&
          regretLevel == other.regretLevel &&
          localDate == other.localDate &&
          createdAt == other.createdAt &&
          clientUpdatedAt == other.clientUpdatedAt &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      name.hashCode ^
      price.hashCode ^
      uses.hashCode ^
      costPerUseMinor.hashCode ^
      verdict.hashCode ^
      regretLevel.hashCode ^
      localDate.hashCode ^
      createdAt.hashCode ^
      clientUpdatedAt.hashCode ^
      deletedAt.hashCode;
}
