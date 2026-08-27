import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../platform_utils.dart';
import '../repositories/history_repository.dart';
import '../services/gift_service.dart';
import '../../spiritual_nourishment/local_worship/services/local_worship_preference_store.dart';
import 'password_strength.dart';
import '../../models/chat_message.dart';
import '../../models/shared_reflection.dart';
import '../../models/user_profile.dart';

/// Outcome of an auth action that may migrate guest history.
class AuthMigrationResult {
  final User user;
  final HistoryMergeResult? mergeResult;
  final bool accountLinked;
  final String? anonymousUidBeforeAuth;

  const AuthMigrationResult({
    required this.user,
    this.mergeResult,
    this.accountLinked = false,
    this.anonymousUidBeforeAuth,
  });

  bool get shouldShowMergeFeedback =>
      mergeResult != null && mergeResult!.newlyAddedCount > 0;
}

/// Firebase auth succeeded; guest data migration can finish after the UI closes.
class AuthSessionHandoff {
  const AuthSessionHandoff({
    required this.user,
    required this.guestData,
    this.anonymousUidBeforeAuth,
    this.inMemoryHistory = const [],
  });

  final User user;
  final List<ChatMessage> guestData;
  final String? anonymousUidBeforeAuth;
  final List<ChatMessage> inMemoryHistory;

  bool get needsGuestMigration =>
      guestData.isNotEmpty ||
      (anonymousUidBeforeAuth != null &&
          anonymousUidBeforeAuth!.isNotEmpty &&
          anonymousUidBeforeAuth != user.uid);
}

class AuthCoordinator {
  AuthCoordinator({
    AuthService? authService,
    HistoryRepository? historyRepository,
    GiftService? giftService,
  })  : _auth = authService ?? AuthService(),
        _history = historyRepository ?? HistoryRepository(),
        _gifts = giftService ?? GiftService();

  final AuthService _auth;
  final HistoryRepository _history;
  final GiftService _gifts;

  Future<void> continueAsGuest() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  /// Ensures a Firebase user exists (restored session, or anonymous guest).
  Future<User?> ensureSession({bool allowGuest = true}) async {
    await _auth.waitForAuthReady();
    var user = _auth.currentUser;
    if (user != null) return user;
    if (!allowGuest) return null;
    return _auth.signInAnonymously();
  }

  /// Saves a shared reflection into the signed-in user's session history.
  Future<bool> saveSharedReflectionToJourney({
    required SharedReflection reflection,
    required List<ChatMessage> currentHistory,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw FirebaseAuthException(
        code: 'requires-sign-in',
        message: 'Sign in to save this reflection to your journey.',
      );
    }

    final alreadySaved = currentHistory.any(
      (m) => m.isUser && m.text.trim() == reflection.question.trim(),
    );
    if (alreadySaved) return false;

    final when = reflection.createdAt ?? DateTime.now();
    final merged = _history.mergeHistories(currentHistory, [
      ChatMessage(isUser: true, text: reflection.question, timestamp: when),
      ChatMessage(
        isUser: false,
        text: reflection.response,
        timestamp: when.add(const Duration(seconds: 1)),
      ),
    ]);

    await _history.saveHistory(merged);
    return true;
  }

  /// Collect guest history — bounded wait; iOS Safari Firestore reads can stall the UI.
  Future<List<ChatMessage>> _collectGuestHistory({
    required List<ChatMessage> inMemoryHistory,
    required String anonymousUid,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final anonFirestore = await _history
          .loadHistoryForUid(anonymousUid)
          .timeout(timeout);
      return _history.mergeHistories(inMemoryHistory, anonFirestore);
    } catch (_) {
      return inMemoryHistory;
    }
  }

  /// Snapshot guest data while the anonymous token can still read it.
  Future<({String? anonymousUid, List<ChatMessage> guestData})>
      _captureGuestSession(List<ChatMessage> inMemoryHistory) async {
    final previousUser = _auth.currentUser;
    final anonymousUid =
        previousUser?.isAnonymous == true ? previousUser!.uid : null;
    if (anonymousUid == null) {
      return (anonymousUid: null, guestData: inMemoryHistory);
    }
    final guestData = await _collectGuestHistory(
      inMemoryHistory: inMemoryHistory,
      anonymousUid: anonymousUid,
      timeout: const Duration(seconds: 2),
    );
    return (anonymousUid: anonymousUid, guestData: guestData);
  }

  Future<AuthSessionHandoff> signInWithEmailAuthOnly({
    required String email,
    required String password,
    required List<ChatMessage> inMemoryHistory,
  }) async {
    final guest = await _captureGuestSession(inMemoryHistory);

    final user = await _auth.signInWithEmail(
      email,
      password,
      ensureDocument: false,
    );
    if (user == null) {
      throw FirebaseAuthException(code: 'user-null', message: 'Sign-in failed');
    }
    await _auth.waitForSignedInUser();
    try {
      await user.getIdToken();
    } catch (_) {}
    return AuthSessionHandoff(
      user: user,
      guestData: guest.guestData,
      anonymousUidBeforeAuth: guest.anonymousUid,
      inMemoryHistory: inMemoryHistory,
    );
  }

  Future<AuthSessionHandoff> registerWithEmailAuthOnly({
    required String email,
    required String password,
    required List<ChatMessage> inMemoryHistory,
  }) async {
    final guest = await _captureGuestSession(inMemoryHistory);
    final previousUser = _auth.currentUser;
    final anonymousUid = guest.anonymousUid;

    if (previousUser?.isAnonymous == true) {
      await _auth.signOutAndWaitForCleared();
      try {
        final user = await _auth.registerWithEmail(
          email,
          password,
          ensureDocument: false,
        );
        if (user == null) {
          throw FirebaseAuthException(
            code: 'user-null',
            message: 'Registration failed',
          );
        }
        await _auth.waitForSignedInUser();
        return AuthSessionHandoff(
          user: user,
          guestData: guest.guestData,
          anonymousUidBeforeAuth: anonymousUid,
          inMemoryHistory: inMemoryHistory,
        );
      } on FirebaseAuthException catch (e) {
        if (_auth.currentUser == null) {
          try {
            await _auth.signInAnonymously();
          } catch (_) {}
        }
        if (e.code == 'email-already-in-use') {
          throw FirebaseAuthException(
            code: 'email-already-in-use',
            message:
                'An account already exists with this email. Please sign in instead.',
          );
        }
        rethrow;
      } catch (e) {
        if (_auth.currentUser == null) {
          try {
            await _auth.signInAnonymously();
          } catch (_) {}
        }
        rethrow;
      }
    }

    final user = await _auth.registerWithEmail(
      email,
      password,
      ensureDocument: false,
    );
    if (user == null) {
      throw FirebaseAuthException(code: 'user-null', message: 'Registration failed');
    }
    await _auth.waitForSignedInUser();
    return AuthSessionHandoff(
      user: user,
      guestData: guest.guestData,
      anonymousUidBeforeAuth: anonymousUid,
      inMemoryHistory: inMemoryHistory,
    );
  }

  Future<AuthSessionHandoff> signInWithGoogleAuthOnly({
    required List<ChatMessage> inMemoryHistory,
  }) async {
    final guest = await _captureGuestSession(inMemoryHistory);

    final user = await _auth.signInWithGoogle(ensureDocument: false);
    if (user == null) {
      throw FirebaseAuthException(code: 'user-null', message: 'Google sign-in failed');
    }
    await _auth.waitForSignedInUser();
    try {
      await user.getIdToken();
    } catch (_) {}
    return AuthSessionHandoff(
      user: user,
      guestData: guest.guestData,
      anonymousUidBeforeAuth: guest.anonymousUid,
      inMemoryHistory: inMemoryHistory,
    );
  }

  /// Runs after the auth sheet closes — Firestore merge must not block the modal.
  Future<AuthMigrationResult> completeMigration(AuthSessionHandoff handoff) async {
    try {
      await handoff.user.getIdToken();
    } catch (_) {}

    try {
      await _auth.ensureUserDocument(handoff.user);
    } catch (e) {
      print('completeMigration ensureUserDocument: $e');
    }
    try {
      await LocalWorshipPreferenceStore().migrateLocalToSignedInAccount();
    } catch (e) {
      print('LocalWorshipPreferenceStore.migrate: $e');
    }

    var guestData = handoff.guestData;
    if (guestData.isEmpty) {
      guestData = handoff.inMemoryHistory;
    }

    try {
      if (handoff.needsGuestMigration &&
          handoff.anonymousUidBeforeAuth != null &&
          handoff.anonymousUidBeforeAuth != handoff.user.uid) {
        return await _finalizeGuestMigration(
          user: handoff.user,
          guestData: guestData,
          anonymousUidBeforeAuth: handoff.anonymousUidBeforeAuth,
        );
      }

      final mergeResult = await _history.migrateGuestHistoryToCurrentUser(
        inMemoryHistory: guestData,
      );

      return AuthMigrationResult(
        user: handoff.user,
        mergeResult: mergeResult,
        anonymousUidBeforeAuth: handoff.anonymousUidBeforeAuth,
      );
    } catch (e) {
      print('completeMigration: $e');
      return AuthMigrationResult(
        user: handoff.user,
        anonymousUidBeforeAuth: handoff.anonymousUidBeforeAuth,
      );
    }
  }

  Future<AuthMigrationResult> _finalizeGuestMigration({
    required User user,
    required List<ChatMessage> guestData,
    required String? anonymousUidBeforeAuth,
    bool accountLinked = false,
  }) async {
    final mergeResult = await _history.migrateGuestHistoryToCurrentUser(
      inMemoryHistory: guestData,
    );

    if (anonymousUidBeforeAuth != null &&
        anonymousUidBeforeAuth != user.uid) {
      await _gifts.migrateGuestGifts(anonymousUidBeforeAuth);
    }

    return AuthMigrationResult(
      user: user,
      mergeResult: mergeResult,
      accountLinked: accountLinked,
      anonymousUidBeforeAuth: anonymousUidBeforeAuth,
    );
  }

  /// Legacy one-shot sign-in (blocks until Firestore migration completes).
  Future<AuthMigrationResult> signInWithEmail({
    required String email,
    required String password,
    required List<ChatMessage> inMemoryHistory,
  }) async {
    final handoff = await signInWithEmailAuthOnly(
      email: email,
      password: password,
      inMemoryHistory: inMemoryHistory,
    );
    return completeMigration(handoff);
  }

  Future<AuthMigrationResult> registerWithEmail({
    required String email,
    required String password,
    required List<ChatMessage> inMemoryHistory,
  }) async {
    final handoff = await registerWithEmailAuthOnly(
      email: email,
      password: password,
      inMemoryHistory: inMemoryHistory,
    );
    return completeMigration(handoff);
  }

  Future<AuthMigrationResult> signInWithGoogle({
    required List<ChatMessage> inMemoryHistory,
  }) async {
    final handoff = await signInWithGoogleAuthOnly(
      inMemoryHistory: inMemoryHistory,
    );
    return completeMigration(handoff);
  }

  Future<void> signOut() async {
    await _auth.signOutAndWaitForCleared();
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// LOCAL persistence keeps users signed in across browser sessions until logout.
  Future<void> initializePersistence() async {
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }
  }

  /// Waits for Firebase Auth to emit initial state (restores persisted sessions).
  Future<User?> waitForAuthReady() async {
    try {
      return await authStateChanges.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => currentUser,
      );
    } catch (_) {
      return currentUser;
    }
  }

  bool get hasRegisteredAccount {
    final user = currentUser;
    return user != null && !user.isAnonymous;
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  /// True when the signed-in user may change an email/password credential.
  bool get canChangePassword {
    final user = currentUser;
    if (user == null || user.isAnonymous) return false;
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return false;
    return user.providerData.any((provider) => provider.providerId == 'password');
  }

  /// Re-authenticates and updates the password for email/password accounts.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      throw FirebaseAuthException(
        code: 'requires-sign-in',
        message: 'Sign in to change your password.',
      );
    }

    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-email',
        message: 'This account has no email address for password sign-in.',
      );
    }

    if (currentPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-password',
        message: 'Enter your current password.',
      );
    }

    final strengthError = PasswordStrength.validate(newPassword);
    if (strengthError != null) {
      throw Exception(strengthError);
    }

    if (currentPassword == newPassword) {
      throw Exception('Choose a new password that differs from your current one.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      await ensureUserDocument(credential.user!);
      return credential.user;
    } catch (e) {
      print('Anonymous sign-in error: $e');
      rethrow;
    }
  }

  Future<User?> signInWithEmail(
    String email,
    String password, {
    bool ensureDocument = true,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (ensureDocument && credential.user != null) {
        await ensureUserDocument(credential.user!);
      }
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> registerWithEmail(
    String email,
    String password, {
    bool ensureDocument = true,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (ensureDocument && credential.user != null) {
        await ensureUserDocument(credential.user!);
      }
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle({bool ensureDocument = true}) async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        if (ensureDocument && userCredential.user != null) {
          await ensureUserDocument(userCredential.user!);
        }
        return userCredential.user;
      } else {
        await _googleSignIn.initialize();
        final googleUser = await _googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.idToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        if (ensureDocument && userCredential.user != null) {
          await ensureUserDocument(userCredential.user!);
        }
        return userCredential.user;
      }
    } catch (e) {
      print('Google sign-in error: $e');
      rethrow;
    }
  }

  Future<User> linkWithGoogle(User anonymousUser) async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final result = await anonymousUser.linkWithPopup(googleProvider);
      return result.user!;
    } else {
      await _googleSignIn.initialize();
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.idToken,
        idToken: googleAuth.idToken,
      );
      final result = await anonymousUser.linkWithCredential(credential);
      return result.user!;
    }
  }

  Future<void> ensureUserDocument(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final authDisplayName = _profileDisplayNameFromAuth(user);

    if (!doc.exists) {
      await docRef.set({
        'email': user.email,
        if (authDisplayName != null) 'displayName': authDisplayName,
        'photoURL': user.photoURL,
        'favoriteSaint': null,
        'shareAnonymouslyByDefault': true,
        'isAnonymous': user.isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'sessionHistory': [],
        'preferences': {
          'theme': 'light',
          'notifications': true,
        },
      });
    } else {
      final existingName = doc.data()?['displayName']?.toString();
      final existingPhoto = doc.data()?['photoURL']?.toString();
      final updates = <String, dynamic>{
        'lastActive': FieldValue.serverTimestamp(),
        'email': user.email,
        'isAnonymous': user.isAnonymous,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Preserve a user-uploaded or previously saved photo; only fill from OAuth when empty.
      if (existingPhoto == null || existingPhoto.isEmpty) {
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          updates['photoURL'] = user.photoURL;
        }
      }

      // Keep a user-chosen name; only fill from OAuth when missing or invalid.
      if (!UserProfile.isValidDisplayName(existingName, accountEmail: user.email) &&
          authDisplayName != null) {
        updates['displayName'] = authDisplayName;
      }

      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  /// OAuth display name only — never email or email local-part.
  static String? _profileDisplayNameFromAuth(User user) {
    final fromAuth = user.displayName?.trim();
    if (UserProfile.isValidDisplayName(fromAuth, accountEmail: user.email)) {
      return fromAuth;
    }
    return null;
  }

  Future<User?> getCurrentUser() async => _auth.currentUser;

  Future<void> signOut() async {
    await signOutAndWaitForCleared();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Sign out and wait for auth state to clear — required on iOS Safari before
  /// createUserWithEmailAndPassword, or registration can hang indefinitely.
  Future<void> signOutAndWaitForCleared() async {
    await _auth.signOut();
    try {
      await authStateChanges
          .firstWhere((user) => user == null)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best effort — proceed even if the stream did not emit null in time.
    }
    if (kIsWeb && isMobileWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Waits until Firebase reports a signed-in registered user.
  Future<User?> waitForSignedInUser({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final existing = currentUser;
    if (existing != null && !existing.isAnonymous) {
      return existing;
    }
    try {
      return await authStateChanges
          .firstWhere((user) => user != null && !user.isAnonymous)
          .timeout(timeout);
    } catch (_) {
      return currentUser;
    }
  }
}
