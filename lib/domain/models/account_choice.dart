/// Choices presented to the user when linking or upgrading to an account
/// that already has cloud data while the device has local guest data (M4).
/// Follows docs/ARCHITECTURE.md Section 4 and Section 6.
enum ExistingAccountChoice {
  /// Discards local device guest data and hydrates cloud data into Drift.
  keepCloud,

  /// Adopts local device guest data to the account and queues it for cloud sync.
  replaceWithDevice,
}
