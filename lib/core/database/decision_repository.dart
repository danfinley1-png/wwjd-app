import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DecisionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveDecision(String userMessage, String aiResponse) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Guest - don't save

    await _db.collection('decisions').add({
      'userId': user.uid,
      'userMessage': userMessage,
      'aiResponse': aiResponse,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getUserDecisions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _db.collection('decisions')
      .where('userId', isEqualTo: user.uid)
      .orderBy('timestamp', descending: true)
      .snapshots();
  }
}