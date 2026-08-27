import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_profile.dart';
import 'profile_photo_service.dart';

class UserProfileService {
  UserProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ProfilePhotoService? photoService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _photoService = photoService ?? ProfilePhotoService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ProfilePhotoService _photoService;

  ProfilePhotoService get photoService => _photoService;

  DocumentReference<Map<String, dynamic>>? _docForUid(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return _firestore.collection('users').doc(uid);
  }

  Stream<UserProfile?> watchCurrentUserProfile() {
    final uid = _auth.currentUser?.uid;
    return watchProfileForUid(uid);
  }

  Stream<UserProfile?> watchProfileForUid(String? uid) {
    final doc = _docForUid(uid);
    if (doc == null) return Stream.value(null);

    return doc.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserProfile.fromMap(snap.id, snap.data()!);
    }).transform(
      StreamTransformer<UserProfile?, UserProfile?>.fromHandlers(
        handleData: (data, sink) => sink.add(data),
        handleError: (error, stackTrace, sink) {
          // Keep the profile screen usable when Firestore hiccups on web.
          sink.add(null);
        },
      ),
    );
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    final doc = _docForUid(uid);
    if (doc == null) return null;

    final snap = await doc.get();
    if (!snap.exists || snap.data() == null) return null;
    return UserProfile.fromMap(snap.id, snap.data()!);
  }

  Future<void> upsertProfile({
    required String displayName,
    String? favoriteSaint,
    bool? shareAnonymouslyByDefault,
    String? photoUrl,
    bool clearPhoto = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Sign in to update your profile.');
    }

    final trimmedName = displayName.trim();
    if (!UserProfile.isValidDisplayName(
      trimmedName,
      accountEmail: _auth.currentUser?.email,
    )) {
      throw Exception(
        'Please enter a display name (not your email address).',
      );
    }

    final doc = _docForUid(uid)!;
    final existing = await doc.get();
    final current = existing.data();

    final data = <String, dynamic>{
      'displayName': trimmedName,
      'favoriteSaint': favoriteSaint?.trim().isEmpty == true
          ? null
          : favoriteSaint?.trim(),
      if (shareAnonymouslyByDefault != null)
        'shareAnonymouslyByDefault': shareAnonymouslyByDefault,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (clearPhoto) {
      data['photoURL'] = null;
    } else if (photoUrl != null) {
      data['photoURL'] = photoUrl;
    } else if (current?['photoURL'] == null &&
        _auth.currentUser?.photoURL != null) {
      data['photoURL'] = _auth.currentUser!.photoURL;
    }

    await doc.set(data, SetOptions(merge: true));
  }

  Future<String?> uploadProfilePhoto({ImageSource? source}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to add a profile photo.');
    }
    if (user.isAnonymous) {
      throw Exception(
        'Create an account (not guest) to save a profile photo.',
      );
    }

    final url = await _photoService.pickAndUpload(
      source: source ?? ImageSource.gallery,
    );
    if (url == null) return null;

    await _docForUid(user.uid)!.set(
      {
        'photoURL': url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return url;
  }

  Future<String?> uploadPickedProfilePhoto(ProfilePhotoPick picked) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to add a profile photo.');
    }
    if (user.isAnonymous) {
      throw Exception(
        'Create an account (not guest) to save a profile photo.',
      );
    }

    final url = await _photoService.uploadPicked(picked);
    if (url == null) return null;

    await _docForUid(user.uid)!.set(
      {
        'photoURL': url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return url;
  }

  /// When Storage has `profile.jpg` but Firestore lacks `photoURL`, repair the link.
  /// Skipped on web — web reads `photoURL` from Firestore and displays via HTML img.
  Future<String?> syncPhotoUrlFromStorage() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return null;

    final profile = await getCurrentUserProfile();
    final existing = profile?.photoUrl?.trim();
    if (existing != null &&
        existing.isNotEmpty &&
        ProfilePhotoService.isFirebaseStorageUrl(existing)) {
      return existing;
    }

    final url = await _photoService.getDownloadUrlForCurrentUser();
    if (url == null || url.isEmpty) return null;

    await _docForUid(user.uid)!.set(
      {
        'photoURL': url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return url;
  }

  Future<void> removeProfilePhoto() async {
    await _photoService.deleteStoredPhoto();

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _docForUid(uid)!.set(
      {
        'photoURL': null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Optional hint from OAuth (Google, etc.) — never the email local-part.
  String? suggestedDisplayName() {
    final user = _auth.currentUser;
    if (user == null) return null;
    final fromAuth = user.displayName?.trim();
    if (UserProfile.isValidDisplayName(fromAuth, accountEmail: user.email)) {
      return fromAuth;
    }
    return null;
  }

  Future<void> completeInstitutionalPasswordSetup({
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to update your password.');
    }

    await user.updatePassword(newPassword);

    await _docForUid(user.uid)!.set(
      {
        'mustChangePassword': false,
        'accountStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markInstitutionalWelcomeSeen() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _docForUid(uid)!.set(
      {
        'hasSeenInstitutionalWelcome': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
