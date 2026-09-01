import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/firestore_auth_retry.dart';
import '../models/service_hours.dart';

/// One accepted organization membership used to query assigned projects.
class MemberServiceProjectScope {
  const MemberServiceProjectScope({
    required this.orgId,
    required this.groupIds,
  });

  final String orgId;
  final List<String> groupIds;
}

/// Admin writes for [ServiceProject] documents.
///
/// Never reads Seeking God's Wisdom, My Reflections, My History, or personal Gifts.
class ServiceProjectService {
  ServiceProjectService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _firestore.collection(ServiceProject.collection);

  Stream<List<ServiceProject>> watchForOrganization(String orgId) {
    return _projects.where('orgId', isEqualTo: orgId).snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => ServiceProject.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
      return items;
    });
  }

  /// Active projects assigned to the member's accepted orgs/groups.
  ///
  /// Uses assignment-scoped queries so Firestore rules can allow the list.
  Stream<List<ServiceProject>> watchAssignedActiveForMember(
    List<MemberServiceProjectScope> scopes,
  ) {
    if (scopes.isEmpty) return Stream.value(const []);

    return Stream<List<ServiceProject>>.multi((listener) {
      final buckets = <Object, Map<String, ServiceProject>>{};
      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
      var cancelled = false;

      void emit() {
        if (cancelled) return;
        final merged = <String, ServiceProject>{};
        for (final bucket in buckets.values) {
          merged.addAll(bucket);
        }
        final now = DateTime.now();
        final visible = <ServiceProject>[];
        for (final project in merged.values) {
          MemberServiceProjectScope? scope;
          for (final candidate in scopes) {
            if (candidate.orgId == project.orgId) {
              scope = candidate;
              break;
            }
          }
          if (scope == null) continue;
          if (!project.isVisibleToMemberNow(
            memberGroupIds: scope.groupIds,
            now: now,
          )) {
            continue;
          }
          visible.add(project);
        }
        visible.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        listener.add(visible);
      }

      void listenQuery(Object key, Query<Map<String, dynamic>> query) {
        subs.add(
          query.snapshots().listen(
            (snap) {
              buckets[key] = {
                for (final doc in snap.docs)
                  doc.id: ServiceProject.fromMap(doc.id, doc.data()),
              };
              emit();
            },
            onError: listener.addError,
          ),
        );
      }

      for (final scope in scopes) {
        listenQuery(
          '${scope.orgId}-org',
          _projects
              .where('orgId', isEqualTo: scope.orgId)
              .where(
                'assignmentType',
                isEqualTo: ServiceProject.assignmentOrganization,
              )
              .where('status', isEqualTo: ServiceProject.statusActive),
        );

        final groupIds =
            scope.groupIds.where((id) => id.trim().isNotEmpty).toList();
        for (var i = 0; i < groupIds.length; i += 10) {
          final end = i + 10 > groupIds.length ? groupIds.length : i + 10;
          final chunk = groupIds.sublist(i, end);
          listenQuery(
            '${scope.orgId}-groups-$i',
            _projects
                .where('orgId', isEqualTo: scope.orgId)
                .where('status', isEqualTo: ServiceProject.statusActive)
                .where('assignedGroupIds', arrayContainsAny: chunk),
          );
        }
      }

      listener.onCancel = () async {
        cancelled = true;
        for (final sub in subs) {
          await sub.cancel();
        }
      };
    });
  }

  Future<String> createProject({
    required String orgId,
    required String title,
    required String description,
    String scope = '',
    String location = '',
    DateTime? startDate,
    DateTime? endDate,
    required String assignmentType,
    List<String> assignedGroupIds = const [],
    required String mode,
    List<String> approverUids = const [],
    String status = ServiceProject.statusActive,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in as an organization administrator to create a project.');
    }

    final error = ServiceProjectValidation.validate(
      title: title,
      description: description,
      assignmentType: assignmentType,
      assignedGroupIds: assignedGroupIds,
      mode: mode,
      approverUids: approverUids,
      startDate: startDate,
      endDate: endDate,
    );
    if (error != null) throw StateError(error);

    final now = DateTime.now();
    final project = ServiceProject(
      id: '',
      orgId: orgId,
      title: title,
      description: description,
      scope: scope,
      location: location,
      startDate: startDate,
      endDate: endDate,
      assignmentType: assignmentType,
      assignedGroupIds: assignmentType == ServiceProject.assignmentGroups
          ? assignedGroupIds
          : const [],
      mode: mode,
      approverUids: mode == ServiceProject.modeRequiresApproval
          ? approverUids
          : const [],
      status: status,
      createdBy: uid,
      createdAt: now,
    );

    final doc = _projects.doc();
    await doc.set(project.toMap());
    return doc.id;
  }

  Future<void> updateProject({
    required ServiceProject existing,
    required String orgId,
    required String title,
    required String description,
    String scope = '',
    String location = '',
    DateTime? startDate,
    DateTime? endDate,
    required String assignmentType,
    List<String> assignedGroupIds = const [],
    required String mode,
    List<String> approverUids = const [],
    required String status,
  }) async {
    if (existing.orgId != orgId) {
      throw StateError('This project belongs to another organization.');
    }

    final error = ServiceProjectValidation.validate(
      title: title,
      description: description,
      assignmentType: assignmentType,
      assignedGroupIds: assignedGroupIds,
      mode: mode,
      approverUids: approverUids,
      startDate: startDate,
      endDate: endDate,
    );
    if (error != null) throw StateError(error);

    final updated = existing.copyWith(
      title: title,
      description: description,
      scope: scope,
      location: location,
      startDate: startDate,
      endDate: endDate,
      clearDates: startDate == null && endDate == null,
      assignmentType: assignmentType,
      assignedGroupIds: assignmentType == ServiceProject.assignmentGroups
          ? assignedGroupIds
          : const [],
      mode: mode,
      approverUids: mode == ServiceProject.modeRequiresApproval
          ? approverUids
          : const [],
      status: status,
    );

    await _projects.doc(existing.id).set(updated.toMap());
  }

  /// The signed-in member's own proposals (any status).
  ///
  /// Equality-only query so list rules can allow it (proposedByUid == uid).
  /// Sort in memory — avoids a composite index on createdAt.
  Stream<List<ServiceProject>> watchProposedByCurrentUser() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    return firestoreSnapshotsRetrying(
      auth: _auth,
      snapshots: () => _projects
          .where('proposedByUid', isEqualTo: uid)
          .snapshots(),
    ).map((snap) {
      final items = snap.docs
          .map((doc) => ServiceProject.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<String> proposeProject({
    required String orgId,
    required String title,
    required String description,
    String scope = '',
    String location = '',
    DateTime? startDate,
    DateTime? endDate,
    required String assignmentType,
    List<String> assignedGroupIds = const [],
    required String mode,
    List<String> nominatedApproverUids = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in with an accepted membership to propose a project.');
    }

    final error = ServiceProjectValidation.validate(
      title: title,
      description: description,
      assignmentType: assignmentType,
      assignedGroupIds: assignedGroupIds,
      mode: mode,
      approverUids: const [],
      startDate: startDate,
      endDate: endDate,
      forMemberProposal: true,
      nominatedApproverUids: nominatedApproverUids,
    );
    if (error != null) throw StateError(error);

    final now = DateTime.now();
    final project = ServiceProject(
      id: '',
      orgId: orgId,
      title: title,
      description: description,
      scope: scope,
      location: location,
      startDate: startDate,
      endDate: endDate,
      assignmentType: assignmentType,
      assignedGroupIds: assignmentType == ServiceProject.assignmentGroups
          ? assignedGroupIds
          : const [],
      mode: mode,
      approverUids: const [],
      nominatedApproverUids: nominatedApproverUids,
      status: ServiceProject.statusInactive,
      source: ServiceProject.sourceMemberProposed,
      proposedByUid: uid,
      proposalStatus: ServiceProject.proposalSubmitted,
      createdBy: uid,
      createdAt: now,
    );

    final doc = _projects.doc();
    await doc.set(project.toMap());
    return doc.id;
  }

  Future<void> resubmitProposal({
    required ServiceProject existing,
    required String title,
    required String description,
    String scope = '',
    String location = '',
    DateTime? startDate,
    DateTime? endDate,
    required String assignmentType,
    List<String> assignedGroupIds = const [],
    required String mode,
    List<String> nominatedApproverUids = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || existing.proposedByUid != uid) {
      throw StateError('Only the proposer can revise this project.');
    }
    if (existing.proposalStatus != ServiceProject.proposalRejected &&
        existing.proposalStatus != ServiceProject.proposalReturned) {
      throw StateError('Only rejected or returned proposals can be revised.');
    }

    final error = ServiceProjectValidation.validate(
      title: title,
      description: description,
      assignmentType: assignmentType,
      assignedGroupIds: assignedGroupIds,
      mode: mode,
      approverUids: const [],
      startDate: startDate,
      endDate: endDate,
      forMemberProposal: true,
      nominatedApproverUids: nominatedApproverUids,
    );
    if (error != null) throw StateError(error);

    final updated = existing.copyWith(
      title: title,
      description: description,
      scope: scope,
      location: location,
      startDate: startDate,
      endDate: endDate,
      clearDates: startDate == null && endDate == null,
      assignmentType: assignmentType,
      assignedGroupIds: assignmentType == ServiceProject.assignmentGroups
          ? assignedGroupIds
          : const [],
      mode: mode,
      nominatedApproverUids: nominatedApproverUids,
      approverUids: const [],
      status: ServiceProject.statusInactive,
      proposalStatus: ServiceProject.proposalSubmitted,
      clearProposalFeedback: true,
    );
    await _projects.doc(existing.id).set(updated.toMap());
  }

  Future<void> reviewProposal({
    required ServiceProject existing,
    required String proposalStatus,
    required String title,
    required String description,
    String scope = '',
    String location = '',
    DateTime? startDate,
    DateTime? endDate,
    required String assignmentType,
    List<String> assignedGroupIds = const [],
    required String mode,
    List<String> approverUids = const [],
    List<String> nominatedApproverUids = const [],
    String proposalNote = '',
    String rejectionReason = '',
  }) async {
    if (existing.source != ServiceProject.sourceMemberProposed) {
      throw StateError('This is not a member proposal.');
    }

    final forApprove = proposalStatus == ServiceProject.proposalApproved;
    final error = ServiceProjectValidation.validate(
      title: title,
      description: description,
      assignmentType: assignmentType,
      assignedGroupIds: assignedGroupIds,
      mode: mode,
      approverUids: forApprove ? approverUids : const [],
      startDate: startDate,
      endDate: endDate,
      forMemberProposal: !forApprove,
      nominatedApproverUids: nominatedApproverUids,
      proposalNote: proposalNote,
      rejectionReason: rejectionReason,
    );
    if (error != null) throw StateError(error);

    if (proposalStatus == ServiceProject.proposalRejected &&
        rejectionReason.trim().isEmpty) {
      throw StateError('Add a reason when rejecting a proposal.');
    }
    if (proposalStatus == ServiceProject.proposalReturned &&
        proposalNote.trim().isEmpty) {
      throw StateError('Add notes when returning a proposal for revision.');
    }

    final updated = existing.copyWith(
      title: title,
      description: description,
      scope: scope,
      location: location,
      startDate: startDate,
      endDate: endDate,
      clearDates: startDate == null && endDate == null,
      assignmentType: assignmentType,
      assignedGroupIds: assignmentType == ServiceProject.assignmentGroups
          ? assignedGroupIds
          : const [],
      mode: mode,
      approverUids: mode == ServiceProject.modeRequiresApproval && forApprove
          ? approverUids
          : const [],
      nominatedApproverUids: nominatedApproverUids,
      status: forApprove
          ? ServiceProject.statusActive
          : ServiceProject.statusInactive,
      proposalStatus: proposalStatus,
      proposalNote: proposalNote,
      rejectionReason: rejectionReason,
    );
    await _projects.doc(existing.id).set(updated.toMap());
  }

  /// Single-document read for Done-tab titles of projects that may no longer
  /// appear in the Active assigned list.
  Future<ServiceProject?> getById(String projectId) async {
    final id = projectId.trim();
    if (id.isEmpty) return null;
    final snap = await _projects.doc(id).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return ServiceProject.fromMap(snap.id, data);
  }
}
