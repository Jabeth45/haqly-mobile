import 'package:haqly_mobile/domain/models/ledger_type.dart';
import 'package:haqly_mobile/domain/money.dart';

/// Pure Dart entity representing a ledger entry (money lent or borrowed).
/// Follows docs/DOMAIN_SPEC.md and docs/ARCHITECTURE.md.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    this.userId = 'LOCAL',
    required this.person,
    required this.amount,
    this.currency = 'ETB',
    required this.type,
    this.note,
    this.settled = false,
    required this.localDate,
    required this.createdAt,
    required this.clientUpdatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String person;
  final Money amount;
  final String currency;
  final LedgerType type;
  final String? note;
  final bool settled;

  /// Device-local date string 'YYYY-MM-DD' when entry was recorded.
  final String localDate;

  final DateTime createdAt;
  final DateTime clientUpdatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isLent => type == LedgerType.lent;
  bool get isBorrowed => type == LedgerType.borrowed;
  bool get isOpen => !settled && !isDeleted;

  LedgerEntry copyWith({
    String? id,
    String? userId,
    String? person,
    Money? amount,
    String? currency,
    LedgerType? type,
    String? note,
    bool? settled,
    String? localDate,
    DateTime? createdAt,
    DateTime? clientUpdatedAt,
    DateTime? deletedAt,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      person: person ?? this.person,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      note: note ?? this.note,
      settled: settled ?? this.settled,
      localDate: localDate ?? this.localDate,
      createdAt: createdAt ?? this.createdAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          person == other.person &&
          amount == other.amount &&
          currency == other.currency &&
          type == other.type &&
          note == other.note &&
          settled == other.settled &&
          localDate == other.localDate &&
          createdAt == other.createdAt &&
          clientUpdatedAt == other.clientUpdatedAt &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      person.hashCode ^
      amount.hashCode ^
      currency.hashCode ^
      type.hashCode ^
      note.hashCode ^
      settled.hashCode ^
      localDate.hashCode ^
      createdAt.hashCode ^
      clientUpdatedAt.hashCode ^
      deletedAt.hashCode;

  @override
  String toString() =>
      'LedgerEntry(id: $id, person: $person, amount: ${Money.format(amount)}, currency: $currency, type: $type, settled: $settled, localDate: $localDate, isDeleted: $isDeleted)';
}
