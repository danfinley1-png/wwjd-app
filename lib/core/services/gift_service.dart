import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/gift_activity.dart';

class GiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user's activities collection
  CollectionReference get _userActivities => 
      _firestore.collection('users').doc(_auth.currentUser?.uid).collection('activities');

  // Shared activities collection (for community)
  CollectionReference get _sharedActivities => 
      _firestore.collection('shared_activities');

  // Save or update activity for current user
  Future<void> saveActivity(GiftActivity activity) async {
    if (_auth.currentUser == null) return;
    await _userActivities.doc(activity.id).set(activity.toMap());
  }

  // Get all activities for current user
  Stream<List<GiftActivity>> getUserActivities() {
    if (_auth.currentUser == null) return Stream.value([]);
    return _userActivities.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => GiftActivity.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  // Share activity to community
  Future<void> shareActivity(GiftActivity activity, {String? recipientUid}) async {
    if (_auth.currentUser == null) return;

    final sharedData = {
      ...activity.toMap(),
      'sharedBy': _auth.currentUser!.uid,
      'sharedAt': FieldValue.serverTimestamp(),
      'status': 'pending', // pending, accepted, declined
      'recipientUid': recipientUid,
    };

    await _sharedActivities.add(sharedData);
  }

  // Get pending shared activities for current user
  Stream<List<GiftActivity>> getPendingSharedActivities() {
    if (_auth.currentUser == null) return Stream.value([]);
    return _sharedActivities
        .where('recipientUid', isEqualTo: _auth.currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GiftActivity.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Accept shared activity
  Future<void> acceptSharedActivity(String sharedDocId, GiftActivity activity) async {
    if (_auth.currentUser == null) return;
    await _sharedActivities.doc(sharedDocId).update({'status': 'accepted'});
    await saveActivity(activity); // Add to user's own list
  }
}