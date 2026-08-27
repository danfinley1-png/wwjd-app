enum GiftStatus {
  active,
  completed,
  paused;

  String get firestoreValue => name;

  static GiftStatus fromFirestore(String? value) {
    switch (value?.toLowerCase()) {
      case 'completed':
        return GiftStatus.completed;
      case 'paused':
        return GiftStatus.paused;
      case 'active':
      default:
        return GiftStatus.active;
    }
  }
}
