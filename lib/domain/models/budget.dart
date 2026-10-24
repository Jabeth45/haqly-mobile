import 'package:haqly_mobile/domain/money.dart';

/// User budget settings.
/// Stores monthly and/or weekly spending targets.
/// Follows docs/PRD.md, docs/ARCHITECTURE.md, and docs/DOMAIN_SPEC.md. Pure Dart only.
class Budget {
  const Budget({
    required this.id,
    this.userId = 'LOCAL',
    this.monthly,
    this.weekly,
    required this.updatedAt,
    required this.clientUpdatedAt,
  });

  final String id;
  final String userId;
  final Money? monthly;
  final Money? weekly;
  final DateTime updatedAt;
  final DateTime clientUpdatedAt;

  bool get hasMonthly => monthly != null;
  bool get hasWeekly => weekly != null;
  bool get isEmpty => monthly == null && weekly == null;

  Budget copyWith({
    String? id,
    String? userId,
    Money? Function()? monthly,
    Money? Function()? weekly,
    DateTime? updatedAt,
    DateTime? clientUpdatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      monthly: monthly != null ? monthly() : this.monthly,
      weekly: weekly != null ? weekly() : this.weekly,
      updatedAt: updatedAt ?? this.updatedAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Budget &&
        id == other.id &&
        userId == other.userId &&
        monthly == other.monthly &&
        weekly == other.weekly &&
        updatedAt == other.updatedAt &&
        clientUpdatedAt == other.clientUpdatedAt;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      monthly.hashCode ^
      weekly.hashCode ^
      updatedAt.hashCode ^
      clientUpdatedAt.hashCode;

  @override
  String toString() =>
      'Budget(id: $id, userId: $userId, monthly: ${monthly != null ? Money.format(monthly!) : 'null'}, weekly: ${weekly != null ? Money.format(weekly!) : 'null'})';
}
