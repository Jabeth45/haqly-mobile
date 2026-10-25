/// Contact record for ledger autocomplete, loans, and debt tracking.
/// Follows docs/PRD.md FR-L4 and docs/ARCHITECTURE.md. Pure Dart only.
class Contact {
  const Contact({
    required this.id,
    this.userId = 'LOCAL',
    required this.name,
    this.phone,
    this.note,
    required this.createdAt,
    required this.clientUpdatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? phone;
  final String? note;
  final DateTime createdAt;
  final DateTime clientUpdatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Contact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? note,
    DateTime? createdAt,
    DateTime? clientUpdatedAt,
    DateTime? deletedAt,
  }) {
    return Contact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Contact &&
        id == other.id &&
        userId == other.userId &&
        name == other.name &&
        phone == other.phone &&
        note == other.note &&
        createdAt == other.createdAt &&
        clientUpdatedAt == other.clientUpdatedAt &&
        deletedAt == other.deletedAt;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      name.hashCode ^
      phone.hashCode ^
      note.hashCode ^
      createdAt.hashCode ^
      clientUpdatedAt.hashCode ^
      deletedAt.hashCode;

  @override
  String toString() =>
      'Contact(id: $id, userId: $userId, name: $name, phone: $phone, isDeleted: $isDeleted)';
}
