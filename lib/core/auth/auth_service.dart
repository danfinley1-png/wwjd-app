import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../repositories/history_repository.dart';
import '../services/gift_service.dart';
import '../../models/chat_message.dart';
import '../../models/shared_reflection.dart';

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

  /// Collect in-memory + Firestore history for an anonymous guest before auth changes.
  Future<List<ChatMessage>> _collectGuestHistory({
    required List<ChatMessage> inMemoryHistory,
    required String anonymousUid,
  }) async {
    final anonFirestore = await _history.loadHistoryForUid(anonymousUid);
    return _history.mergeHistories(inMemoryHistory, anonFirestore);
  }

  Future<AuthMigrationResult> _finalizeGuestMigration({
    required User user,
    required List<ChatMessage> guestData,
    required String? anonymousUidBeforeAuth,
    bool accountLinked = false,
  }) async {
    await _auth.ensureUserDocument(user);

    final mergeResult = await _history.migrateGuestHistoryToCurrentUser(
      inMemoryHistory: guestData,
      anonymousUid: anonymousUidBeforeAuth != null &&
              anonymousUidBeforeAuth != user.uid
          ? anonymousUidBeforeAuth
          : null,
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

  Future<AuthMigrationResult> signInWithEmail({
    required String email,
    required String password,
    required List<ChatMessage> inMemoryHistory,
  }) async {
    final previousUser = _auth.currentUser;
    final anonymousUid =
        previousUser?.isAnonymous == true ? previousUser!.uid : null;

    // Guest → existing account: sign in directly (replaces anonymous session).
    // Do NOT link first — that hangs/fails when the email already exists.
    if (previousUser?.isAnonymous == true) {
      final guestData = await _collectGuestHistory(
        inMemoryHistory: inMemoryHistory,
        anonymousUid: anonymousUid!,
      );
      final user = await _auth.signInWithEmail(email, password);
      if (user == null) {
        throw FirebaseAuthException(code: 'user-null', message: 'Sign-in failed');
      }
      return _finalizeGuestMigration(
        user: user,
        guestData: guestData,
        anonymousUidBeforeAuth: anonymousUid,
      );
    }

    final user = await _auth.signInWithEmail(email, password);
    if (user == null) {
      throw FirebaseAuthException(code: 'user-null', message: 'Sign-in failed');
    }

    final mergeResult = await _history.migrateGuestHistoryToCurrentUser(
      inMemoryHistory: inMemoryHistory,
      anonymousUid: anonymousUid,
    );

    return AuthMigrationResult(
      user: user,
      mergeResult: mergeResult,
      anonymousUidBeforeAuth: anonymousUid,
    );
  }

  Future<AuthMigrationResult> registerWithEmail({
    required String email,
    required String password,
    required List<ChatMessage> inMemoryHistory,
  }) async {
    final previousUser = _auth.currentUser;
    final anonymousUid =
        previousUser?.isAnonymous == true ? previousUser!.uid : null;

    if (previousUser?.isAnonymous == true) {
      try {
        final credential = EmailAuthProvider.credential(
          email: email.trim(),
          password: password,
        );
        final linked = await previousUser!.linkWithCredential(credential);
        await _auth.ensureUserDocument(linked.user!);

        final mergeResult = await _history.migrateGuestHistoryToCurrentUser(
          inMemoryHistory: inMemoryHistory,
          anonymousUid: null,
        );

        return AuthMigrationResult(
          user: linked.user!,
          mergeResult: mergeResult,
          accountLinked: true,
          anonymousUidBeforeAuth: anonymousUid,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use' &&
            e.code != 'credential-already-in-use' &&
            e.code != 'account-exists-with-different-credential') {
          rethrow;
        }
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message:
              'An account already exists with this email. Please sign in instead.',
        );
      }
    }

    final user = await _auth.registerWithEmail(email, password);
    if (user == null) {
      throw FirebaseAuthException(code: 'user-null', message: 'Registration failed');
    }

    final mergeResult = await _history.migrateGuestHistoryToCurrentUser(
      inMemoryHistory: inMemoryHistory,
      anonymousUid: anonymousUid,
    );

    return AuthMigrationResult(
      user: user,
      mergeResult: mergeResult,
      anonymousUidBeforeAuth: anonymousUid,
    );
  }

  Future<AuthMigrationResult> signInWithGoogle({
    required List<ChatMessage> inMemoryHistory,
  }) async {
    final previousUser = _auth.currentUser;
    final anonymousUid =
        previousUser?.isAnonymous == true ? previousUser!.uid : null;

    if (previousUser?.isAnonymous == true) {
      final guestData = await _collectGuestHistory(
        inMemoryHistory: inMemoryHistory,
        anonymousUid: anonymousUid!,
      );
      final user = await _auth.signInWithGoogle();
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Google sign-in failed',
        );
      }
      return _finalizeGuestMigration(
        user: user,
        guestData: guestData,
        anonymousUidBeforeAuth: anonymousUid,
      );
    }

    final user = await _auth.signInWithGoogle();
    if (user == null) {
      throw FirebaseAuthException(code: 'user-null', message: 'Google sign-in failed');
    }

    final mergeResult = await _history.migrateGuestHistoryToCurrentUser(
      inMemoryHistory: inMemoryHistory,
      anonymousUid: anonymousUid,
    );

    return AuthMigrationResult(
      user: user,
      mergeResult: mergeResult,
      anonymousUidBeforeAuth: anonymousUid,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
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

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await ensureUserDocument(credential.user!);
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> registerWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await ensureUserDocument(credential.user!);
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        await ensureUserDocument(userCredential.user!);
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
        await ensureUserDocument(userCredential.user!);
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

    if (!doc.exists) {
      await docRef.set({
        'email': user.email,
        'displayName': user.displayName ??
            user.email?.split('@').first ??
            (user.isAnonymous ? 'Guest' : 'User'),
        'photoURL': user.photoURL,
        'isAnonymous': user.isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'sessionHistory': [],
        'preferences': {
          'theme': 'light',
          'notifications': true,
        },
      });
    } else {
      await docRef.set({
        'lastActive': FieldValue.serverTimestamp(),
        'email': user.email,
        'displayName': user.displayName ?? doc.data()?['displayName'],
        'photoURL': user.photoURL ?? doc.data()?['photoURL'],
        'isAnonymous': user.isAnonymous,
      }, SetOptions(merge: true));
    }
  }

  Future<User?> getCurrentUser() async => _auth.currentUser;

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
