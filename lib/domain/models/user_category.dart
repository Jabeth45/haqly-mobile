import 'package:haqly_mobile/domain/models/category_constants.dart';
import 'package:haqly_mobile/domain/models/category_kind.dart';

/// User-defined custom expense or income category.
/// Follows docs/PRD.md FR-E3 and docs/ARCHITECTURE.md. Pure Dart only.
class UserCategory {
  const UserCategory({
    required this.id,
    this.userId = 'LOCAL',
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.clientUpdatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final CategoryKind kind;
  final DateTime createdAt;
  final DateTime clientUpdatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  String get emoji => CategoryConstants.emojiFor(name, kind: kind);

  UserCategory copyWith({
    String? id,
    String? userId,
    String? name,
    CategoryKind? kind,
    DateTime? createdAt,
    DateTime? clientUpdatedAt,
    DateTime? deletedAt,
  }) {
    return UserCategory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserCategory &&
        id == other.id &&
        userId == other.userId &&
        name == other.name &&
        kind == other.kind &&
        createdAt == other.createdAt &&
        clientUpdatedAt == other.clientUpdatedAt &&
        deletedAt == other.deletedAt;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      name.hashCode ^
      kind.hashCode ^
      createdAt.hashCode ^
      clientUpdatedAt.hashCode ^
      deletedAt.hashCode;

  @override
  String toString() =>
      'UserCategory(id: $id, userId: $userId, name: $name, kind: ${kind.wireValue}, isDeleted: $isDeleted)';
}
