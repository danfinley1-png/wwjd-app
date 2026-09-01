import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical service project created by an Organization Admin.
///
/// Lives at `serviceProjects/{projectId}`. This is institutional volunteer
/// metadata — not Seeking God's Wisdom, My History, or personal Gifts.
class ServiceProject {
  const ServiceProject({
    required this.id,
    required this.orgId,
    required this.title,
    required this.assignmentType,
    required this.mode,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.description = '',
    this.scope = '',
    this.location = '',
    this.startDate,
    this.endDate,
    this.assignedGroupIds = const [],
    this.approverUids = const [],
    this.source = sourceAdmin,
    this.proposedByUid,
    this.proposalStatus = proposalNone,
    this.proposalNote = '',
    this.rejectionReason = '',
    this.nominatedApproverUids = const [],
    this.updatedAt,
  });

  static const collection = 'serviceProjects';

  static const assignmentOrganization = 'organization';
  static const assignmentGroups = 'groups';
  static const assignmentTypes = [assignmentOrganization, assignmentGroups];

  static const modeSelfReported = 'selfReported';
  static const modeRequiresApproval = 'requiresApproval';
  static const modes = [modeSelfReported, modeRequiresApproval];

  static const statusActive = 'active';
  static const statusInactive = 'inactive';
  static const statuses = [statusActive, statusInactive];

  static const titleMax = 200;
  static const descriptionMax = 4000;
  static const scopeMax = 200;
  static const locationMax = 300;
  static const groupsMax = 30;
  static const approversMax = 20;
  static const proposalNoteMax = 2000;

  static const sourceAdmin = 'admin';
  static const sourceMemberProposed = 'memberProposed';
  static const sources = [sourceAdmin, sourceMemberProposed];

  static const proposalNone = 'none';
  static const proposalSubmitted = 'submitted';
  static const proposalApproved = 'approved';
  static const proposalRejected = 'rejected';
  static const proposalReturned = 'returned';
  static const proposalStatuses = [
    proposalNone,
    proposalSubmitted,
    proposalApproved,
    proposalRejected,
    proposalReturned,
  ];

  final String id;
  final String orgId;
  final String title;
  final String description;
  final String scope;
  final String location;
  final DateTime? startDate;
  final DateTime? endDate;
  final String assignmentType;
  final List<String> assignedGroupIds;
  final String mode;
  final List<String> approverUids;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String source;
  final String? proposedByUid;
  final String proposalStatus;
  final String proposalNote;
  final String rejectionReason;
  final List<String> nominatedApproverUids;

  bool get isActive => status == statusActive;
  bool get isOrgWide => assignmentType == assignmentOrganization;
  bool get requiresApproval => mode == modeRequiresApproval;
  bool get isMemberProposed => source == sourceMemberProposed;

  /// Live for assigned members (admin-created, or member-proposed after approval).
  bool get isPublished {
    if (!isActive) return false;
    if (proposalStatus == proposalNone) return true;
    return proposalStatus == proposalApproved;
  }

  String get proposalStatusLabel {
    switch (proposalStatus) {
      case proposalSubmitted:
        return 'Submitted';
      case proposalApproved:
        return 'Approved';
      case proposalRejected:
        return 'Rejected';
      case proposalReturned:
        return 'Returned for revision';
      default:
        return 'Admin-created';
    }
  }

  /// Member-facing label — not an admin field.
  String get modeDisplayLabel =>
      requiresApproval ? 'Requires approval' : 'Self-reported';

  /// Whether [day] falls inside an optional start/end window (inclusive).
  /// Used for hour-logging eligibility — not for member list visibility.
  bool isOpenOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = startDate;
    if (start != null) {
      final s = DateTime(start.year, start.month, start.day);
      if (d.isBefore(s)) return false;
    }
    final end = endDate;
    if (end != null) {
      final e = DateTime(end.year, end.month, end.day);
      if (d.isAfter(e)) return false;
    }
    return true;
  }

  /// True when [day] is after an optional end date (project is over).
  bool hasEndedOn(DateTime day) {
    final end = endDate;
    if (end == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final e = DateTime(end.year, end.month, end.day);
    return d.isAfter(e);
  }

  /// Member of [memberGroupIds] may log hours when the project is assigned
  /// to the whole org or to one of those groups.
  bool isAssignedToMember(List<String> memberGroupIds) {
    if (isOrgWide) return true;
    final mine = memberGroupIds.toSet();
    return assignedGroupIds.any(mine.contains);
  }

  /// Active assigned projects, including upcoming ones so members can plan.
  /// Hides Inactive projects and those past their end date.
  bool isVisibleToMemberNow({
    required List<String> memberGroupIds,
    DateTime? now,
  }) {
    if (!isPublished) return false;
    if (hasEndedOn(now ?? DateTime.now())) return false;
    return isAssignedToMember(memberGroupIds);
  }

  String get initialEntryStatus =>
      requiresApproval ? ServiceHourEntry.statusPending : ServiceHourEntry.statusLogged;

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'title': title.trim(),
      'description': description.trim(),
      'scope': scope.trim(),
      'location': location.trim(),
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'assignmentType': assignmentType,
      'assignedGroupIds': assignedGroupIds,
      'mode': mode,
      'approverUids': approverUids,
      'status': status,
      'source': source,
      if (proposedByUid != null && proposedByUid!.trim().isNotEmpty)
        'proposedByUid': proposedByUid!.trim(),
      'proposalStatus': proposalStatus,
      if (proposalNote.trim().isNotEmpty) 'proposalNote': proposalNote.trim(),
      if (rejectionReason.trim().isNotEmpty)
        'rejectionReason': rejectionReason.trim(),
      'nominatedApproverUids': nominatedApproverUids,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ServiceProject copyWith({
    String? title,
    String? description,
    String? scope,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
    String? assignmentType,
    List<String>? assignedGroupIds,
    String? mode,
    List<String>? approverUids,
    String? status,
    String? source,
    String? proposedByUid,
    String? proposalStatus,
    String? proposalNote,
    String? rejectionReason,
    List<String>? nominatedApproverUids,
    bool clearProposalFeedback = false,
    DateTime? updatedAt,
  }) {
    return ServiceProject(
      id: id,
      orgId: orgId,
      title: title ?? this.title,
      description: description ?? this.description,
      scope: scope ?? this.scope,
      location: location ?? this.location,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      assignmentType: assignmentType ?? this.assignmentType,
      assignedGroupIds: assignedGroupIds ?? this.assignedGroupIds,
      mode: mode ?? this.mode,
      approverUids: approverUids ?? this.approverUids,
      status: status ?? this.status,
      source: source ?? this.source,
      proposedByUid: proposedByUid ?? this.proposedByUid,
      proposalStatus: proposalStatus ?? this.proposalStatus,
      proposalNote: clearProposalFeedback
          ? ''
          : (proposalNote ?? this.proposalNote),
      rejectionReason: clearProposalFeedback
          ? ''
          : (rejectionReason ?? this.rejectionReason),
      nominatedApproverUids:
          nominatedApproverUids ?? this.nominatedApproverUids,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ServiceProject.fromMap(String id, Map<String, dynamic> map) {
    return ServiceProject(
      id: id,
      orgId: map['orgId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      scope: map['scope']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      startDate: _readTimestamp(map['startDate']),
      endDate: _readTimestamp(map['endDate']),
      assignmentType: map['assignmentType']?.toString() ?? assignmentOrganization,
      assignedGroupIds: _readStringList(map['assignedGroupIds']),
      mode: map['mode']?.toString() ?? modeSelfReported,
      approverUids: _readStringList(map['approverUids']),
      status: map['status']?.toString() ?? statusActive,
      createdBy: map['createdBy']?.toString() ?? '',
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _readTimestamp(map['updatedAt']),
      source: map['source']?.toString().isNotEmpty == true
          ? map['source'].toString()
          : sourceAdmin,
      proposedByUid: map['proposedByUid']?.toString(),
      proposalStatus: map['proposalStatus']?.toString().isNotEmpty == true
          ? map['proposalStatus'].toString()
          : proposalNone,
      proposalNote: map['proposalNote']?.toString() ?? '',
      rejectionReason: map['rejectionReason']?.toString() ?? '',
      nominatedApproverUids: _readStringList(map['nominatedApproverUids']),
    );
  }
}

/// One member-logged volunteer shift. Hours metadata only — never reflection body.
///
/// Lives at `serviceHourEntries/{entryId}`. Private service reflections live
/// under `users/{uid}/reflections` and are linked only by [reflectionId].
class ServiceHourEntry {
  const ServiceHourEntry({
    required this.id,
    required this.projectId,
    required this.orgId,
    required this.userId,
    required this.date,
    required this.hours,
    required this.status,
    required this.submittedAt,
    this.note = '',
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote = '',
    this.reflectionId,
    this.source = ServiceProject.sourceAdmin,
  });

  static const collection = 'serviceHourEntries';

  static const statusLogged = 'logged';
  static const statusPending = 'pending';
  static const statusApproved = 'approved';
  static const statusRejected = 'rejected';
  static const statuses = [
    statusLogged,
    statusPending,
    statusApproved,
    statusRejected,
  ];

  static const noteMax = 2000;
  static const reviewNoteMax = 2000;
  static const hoursMin = 0.25;
  static const hoursMax = 24.0;

  /// Keys that must never appear on this document (privacy boundary).
  static const forbiddenReflectionKeys = [
    'reflection',
    'reflectionText',
    'reflectionBody',
    'body',
    'journal',
    'privateNote',
  ];

  final String id;
  final String projectId;
  final String orgId;
  final String userId;
  final DateTime date;
  final double hours;
  final String note;
  final String status;
  final DateTime submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String reviewNote;
  /// Pointer only — the reflection document is owner-only under My Reflections.
  final String? reflectionId;
  /// Copied from the project at create time for Admin-created vs Member-proposed reports.
  final String source;

  bool get isOwnerEditable =>
      status == statusLogged || status == statusPending;

  bool get countsTowardTotal =>
      status == statusLogged || status == statusApproved;

  String get statusDisplayLabel {
    switch (status) {
      case statusLogged:
        return 'Logged';
      case statusPending:
        return 'Pending';
      case statusApproved:
        return 'Approved';
      case statusRejected:
        return 'Rejected';
      default:
        return status;
    }
  }

  bool get hasReflection =>
      reflectionId != null && reflectionId!.trim().isNotEmpty;

  ServiceHourEntry copyWith({
    DateTime? date,
    double? hours,
    String? note,
    String? status,
    String? reflectionId,
    bool clearReflectionId = false,
    String? source,
  }) {
    return ServiceHourEntry(
      id: id,
      projectId: projectId,
      orgId: orgId,
      userId: userId,
      date: date ?? this.date,
      hours: hours ?? this.hours,
      note: note ?? this.note,
      status: status ?? this.status,
      submittedAt: submittedAt,
      reviewedBy: reviewedBy,
      reviewedAt: reviewedAt,
      reviewNote: reviewNote,
      reflectionId: clearReflectionId ? null : (reflectionId ?? this.reflectionId),
      source: source ?? this.source,
    );
  }

  /// Hours that count toward the member total (logged + approved only).
  static double countedHours(Iterable<ServiceHourEntry> entries) {
    var total = 0.0;
    for (final entry in entries) {
      if (entry.countsTowardTotal) total += entry.hours;
    }
    return total;
  }

  /// Snap to 0.25-hour steps inside the allowed range.
  static double snapHours(double raw) {
    final snapped = (raw * 4).round() / 4;
    if (snapped < hoursMin) return hoursMin;
    if (snapped > hoursMax) return hoursMax;
    return snapped;
  }

  static String formatHours(double hours) {
    final snapped = snapHours(hours);
    if (snapped == snapped.roundToDouble()) {
      return snapped.toInt().toString();
    }
    return snapped.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  }

  Map<String, dynamic> toMap({bool includeReflectionId = true}) {
    return {
      'projectId': projectId,
      'orgId': orgId,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'hours': hours,
      'note': note.trim(),
      'status': status,
      'source': source,
      'submittedAt': Timestamp.fromDate(submittedAt),
      if (reviewedBy != null && reviewedBy!.trim().isNotEmpty)
        'reviewedBy': reviewedBy!.trim(),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewNote.trim().isNotEmpty) 'reviewNote': reviewNote.trim(),
      if (includeReflectionId &&
          reflectionId != null &&
          reflectionId!.trim().isNotEmpty)
        'reflectionId': reflectionId!.trim(),
    };
  }

  factory ServiceHourEntry.fromMap(String id, Map<String, dynamic> map) {
    return ServiceHourEntry(
      id: id,
      projectId: map['projectId']?.toString() ?? '',
      orgId: map['orgId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      date: _readTimestamp(map['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      hours: (map['hours'] as num?)?.toDouble() ?? 0,
      note: map['note']?.toString() ?? '',
      status: map['status']?.toString() ?? statusPending,
      submittedAt:
          _readTimestamp(map['submittedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      reviewedBy: map['reviewedBy']?.toString(),
      reviewedAt: _readTimestamp(map['reviewedAt']),
      reviewNote: map['reviewNote']?.toString() ?? '',
      reflectionId: map['reflectionId']?.toString(),
      source: map['source']?.toString().isNotEmpty == true
          ? map['source'].toString()
          : ServiceProject.sourceAdmin,
    );
  }
}

List<String> _readStringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
}

/// Client-side checks that match Firestore create/update rules for projects.
class ServiceProjectValidation {
  ServiceProjectValidation._();

  static String? validate({
    required String title,
    required String description,
    required String assignmentType,
    required List<String> assignedGroupIds,
    required String mode,
    required List<String> approverUids,
    DateTime? startDate,
    DateTime? endDate,
    bool forMemberProposal = false,
    List<String> nominatedApproverUids = const [],
    String proposalNote = '',
    String rejectionReason = '',
  }) {
    if (title.trim().isEmpty) return 'Title is required.';
    if (title.trim().length > ServiceProject.titleMax) {
      return 'Title must be ${ServiceProject.titleMax} characters or fewer.';
    }
    if (description.trim().isEmpty) return 'Description is required.';
    if (description.trim().length > ServiceProject.descriptionMax) {
      return 'Description must be ${ServiceProject.descriptionMax} characters or fewer.';
    }
    if (assignmentType == ServiceProject.assignmentGroups &&
        assignedGroupIds.isEmpty) {
      return 'Select at least one group, or assign the whole organization.';
    }
    if (!forMemberProposal &&
        mode == ServiceProject.modeRequiresApproval &&
        approverUids.isEmpty) {
      return 'Requires approval needs at least one approver from this organization.';
    }
    if (nominatedApproverUids.length > ServiceProject.approversMax) {
      return 'At most ${ServiceProject.approversMax} nominated approvers.';
    }
    if (proposalNote.trim().length > ServiceProject.proposalNoteMax) {
      return 'Review notes must be ${ServiceProject.proposalNoteMax} characters or fewer.';
    }
    if (rejectionReason.trim().length > ServiceProject.proposalNoteMax) {
      return 'The reason must be ${ServiceProject.proposalNoteMax} characters or fewer.';
    }
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      return 'End date cannot be before the start date.';
    }
    return null;
  }
}

/// Client-side checks that match Firestore create/update rules for hour entries.
class ServiceHourEntryValidation {
  ServiceHourEntryValidation._();

  static String? validate({
    required ServiceProject project,
    required DateTime date,
    required double hours,
    String note = '',
  }) {
    if (!project.isPublished) {
      return 'This project is not accepting hours.';
    }
    if (!project.isOpenOn(date)) {
      return 'Choose a date inside the project window.';
    }
    final snapped = ServiceHourEntry.snapHours(hours);
    if (hours <= 0 || snapped < ServiceHourEntry.hoursMin) {
      return 'Hours must be at least ${ServiceHourEntry.formatHours(ServiceHourEntry.hoursMin)}.';
    }
    if (snapped > ServiceHourEntry.hoursMax) {
      return 'Hours cannot exceed ${ServiceHourEntry.formatHours(ServiceHourEntry.hoursMax)} in one entry.';
    }
    if (note.trim().length > ServiceHourEntry.noteMax) {
      return 'The work note must be ${ServiceHourEntry.noteMax} characters or fewer.';
    }
    return null;
  }

  /// Inclusive first/last calendar days a member may pick, or null if none.
  static ({DateTime first, DateTime last})? selectableDateRange(
    ServiceProject project, {
    DateTime? now,
  }) {
    if (!project.isPublished) return null;
    final today = now ?? DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    var first = project.startDate == null
        ? DateTime(todayDay.year - 2, todayDay.month, todayDay.day)
        : DateTime(
            project.startDate!.year,
            project.startDate!.month,
            project.startDate!.day,
          );
    var last = project.endDate == null
        ? todayDay
        : DateTime(
            project.endDate!.year,
            project.endDate!.month,
            project.endDate!.day,
          );
    if (last.isAfter(todayDay)) last = todayDay;
    if (first.isAfter(last)) return null;
    return (first: first, last: last);
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
