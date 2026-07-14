import 'package:flutter/material.dart';
import '../core/database/decision_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyHistoryScreen extends StatelessWidget {
  const MyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My History')),
      body: user == null 
        ? const Center(child: Text('Sign in to view your history.'))
        : StreamBuilder<QuerySnapshot>(
            stream: DecisionRepository().getUserDecisions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final decisions = snapshot.data!.docs;
              if (decisions.isEmpty) {
                return const Center(child: Text('No saved conversations yet.'));
              }
              return ListView.builder(
                itemCount: decisions.length,
                itemBuilder: (context, index) {
                  final data = decisions[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text((data['userMessage'] ?? '').toString()),
                    subtitle: Text((data['timestamp'] as Timestamp?)?.toDate().toString() ?? ''),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Full Response'),
                          content: SingleChildScrollView(child: Text(data['aiResponse'] ?? '')),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
    );
  }
}