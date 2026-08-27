import 'package:cloud_firestore/cloud_firestore.dart';

/// Platform-level (Overall / Super) administrator — not an org role.
class PlatformAdmin {
  const PlatformAdmin({
    required this.uid,
    required this.email,
    required this.registeredAt,
  });

  final String uid;
  final String email;
  final DateTime registeredAt;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': 'superAdmin',
      'registeredAt': Timestamp.fromDate(registeredAt),
    };
  }

  factory PlatformAdmin.fromMap(String uid, Map<String, dynamic> map) {
    return PlatformAdmin(
      uid: uid,
      email: map['email'] as String? ?? '',
      registeredAt: _readTimestamp(map['registeredAt']) ?? DateTime.now(),
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
