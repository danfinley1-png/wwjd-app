import 'package:cloud_firestore/cloud_firestore.dart';

/// Minimal user profile stored at `users/{uid}`.
class UserProfile {
  final String uid;
  final String? displayName;
  final String? favoriteSaint;
  final bool shareAnonymouslyByDefault;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool mustChangePassword;
  final bool hasSeenInstitutionalWelcome;
  final String? provisionedByOrgId;

  const UserProfile({
    required this.uid,
    this.displayName,
    this.favoriteSaint,
    this.shareAnonymouslyByDefault = true,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
    this.mustChangePassword = false,
    this.hasSeenInstitutionalWelcome = false,
    this.provisionedByOrgId,
  });

  bool get needsPasswordSetup => mustChangePassword;

  bool get shouldShowInstitutionalWelcome =>
      !hasSeenInstitutionalWelcome && !mustChangePassword;

  /// Whether [displayName] is a real chosen name — never an email or placeholder.
  static bool isValidDisplayName(
    String? name, {
    String? accountEmail,
  }) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    if (lower == 'guest' || lower == 'user') return false;
    if (trimmed.contains('@')) return false;

    final email = accountEmail?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      if (lower == email) return false;
      if (email.contains('@')) {
        final localPart = email.split('@').first;
        if (localPart.isNotEmpty && lower == localPart) return false;
      }
    }

    return true;
  }

  bool hasDisplayName([String? accountEmail]) =>
      isValidDisplayName(displayName, accountEmail: accountEmail);

  String get effectiveDisplayName => displayName?.trim() ?? '';

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName']?.toString(),
      favoriteSaint: map['favoriteSaint']?.toString(),
      shareAnonymouslyByDefault: map['shareAnonymouslyByDefault'] as bool? ?? true,
      photoUrl: map['photoURL']?.toString() ?? map['photoUrl']?.toString(),
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
      mustChangePassword: map['mustChangePassword'] as bool? ?? false,
      hasSeenInstitutionalWelcome:
          map['hasSeenInstitutionalWelcome'] as bool? ?? false,
      provisionedByOrgId: map['provisionedByOrgId'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool merge = true}) {
    return {
      'displayName': displayName?.trim(),
      'favoriteSaint': favoriteSaint?.trim().isEmpty == true
          ? null
          : favoriteSaint?.trim(),
      'shareAnonymouslyByDefault': shareAnonymouslyByDefault,
      'photoURL': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      'mustChangePassword': mustChangePassword,
      'hasSeenInstitutionalWelcome': hasSeenInstitutionalWelcome,
      if (provisionedByOrgId != null) 'provisionedByOrgId': provisionedByOrgId,
      if (!merge) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? favoriteSaint,
    bool? shareAnonymouslyByDefault,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? mustChangePassword,
    bool? hasSeenInstitutionalWelcome,
    String? provisionedByOrgId,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      favoriteSaint: favoriteSaint ?? this.favoriteSaint,
      shareAnonymouslyByDefault:
          shareAnonymouslyByDefault ?? this.shareAnonymouslyByDefault,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      hasSeenInstitutionalWelcome:
          hasSeenInstitutionalWelcome ?? this.hasSeenInstitutionalWelcome,
      provisionedByOrgId: provisionedByOrgId ?? this.provisionedByOrgId,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
