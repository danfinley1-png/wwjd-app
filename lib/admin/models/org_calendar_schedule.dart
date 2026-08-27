import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'org_calendar_event.dart';

/// One row in a school / organization schedule template.
///
/// [whenText] is the primary timing field (freeform). Optional [startAt]/[endAt]
/// may exist from an earlier dated-event calendar and are not required to save.
class OrgScheduleRow {
  const OrgScheduleRow({
    required this.id,
    required this.title,
    required this.whenText,
    this.location = '',
    this.notes = '',
    this.sortOrder = 0,
    this.startAt,
    this.endAt,
    this.allDay,
  });

  static const titleMax = 200;
  static const whenMax = 200;
  static const locationMax = 200;
  static const notesMax = 2000;

  final String id;
  final String title;
  final String whenText;
  final String location;
  final String notes;
  final int sortOrder;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool? allDay;

  bool get isBlank => title.trim().isEmpty && whenText.trim().isEmpty;

  bool get isComplete =>
      title.trim().isNotEmpty && whenText.trim().isNotEmpty;

  /// Prefer freeform When; fall back to a dated-event label if present.
  String get displayWhen {
    if (whenText.trim().isNotEmpty) return whenText.trim();
    final start = startAt;
    if (start == null) return '';
    return fallbackWhenFromDates(
      startAt: start,
      endAt: endAt,
      allDay: allDay ?? false,
    );
  }

  Map<String, dynamic> toMap(int order) {
    return {
      'id': id,
      'title': title.trim(),
      'whenText': whenText.trim(),
      'location': location.trim(),
      'notes': notes.trim(),
      'sortOrder': order,
      if (startAt != null) 'startAt': Timestamp.fromDate(startAt!),
      if (endAt != null) 'endAt': Timestamp.fromDate(endAt!),
      if (allDay != null) 'allDay': allDay,
    };
  }

  factory OrgScheduleRow.fromMap(Map<String, dynamic> map, {int index = 0}) {
    return OrgScheduleRow(
      id: map['id'] as String? ?? 'row-$index',
      title: map['title'] as String? ?? '',
      whenText: map['whenText'] as String? ?? '',
      location: map['location'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? index,
      startAt: _readTimestamp(map['startAt']),
      endAt: _readTimestamp(map['endAt']),
      allDay: map['allDay'] as bool?,
    );
  }

  factory OrgScheduleRow.fromEvent(OrgCalendarEvent event, {int index = 0}) {
    return OrgScheduleRow(
      id: event.id,
      title: event.title,
      whenText: fallbackWhenFromDates(
        startAt: event.startAt,
        endAt: event.endAt,
        allDay: event.allDay,
      ),
      location: event.location,
      notes: event.description,
      sortOrder: index,
      startAt: event.startAt,
      endAt: event.endAt,
      allDay: event.allDay,
    );
  }

  OrgScheduleRow copyWith({
    String? title,
    String? whenText,
    String? location,
    String? notes,
    int? sortOrder,
  }) {
    return OrgScheduleRow(
      id: id,
      title: title ?? this.title,
      whenText: whenText ?? this.whenText,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
    );
  }

  static String fallbackWhenFromDates({
    required DateTime startAt,
    DateTime? endAt,
    bool allDay = false,
  }) {
    if (allDay) {
      return 'All day · ${DateFormat.yMMMEd().format(startAt)}';
    }
    return '${DateFormat.yMMMEd().format(startAt)} · ${DateFormat.jm().format(startAt)}';
  }
}

/// Shared school/organization schedule template (row list). Distinct from Gifts.
class OrgCalendarSchedule {
  const OrgCalendarSchedule({
    required this.id,
    required this.organizationId,
    required this.visibility,
    required this.groupIds,
    required this.rows,
    required this.createdByUid,
    required this.createdAt,
    this.updatedAt,
    this.persisted = false,
    this.importedFromEvents = false,
  });

  static const defaultDocId = 'default';
  static const maxRows = 80;

  final String id;
  final String organizationId;
  final OrgCalendarVisibility visibility;
  final List<String> groupIds;
  final List<OrgScheduleRow> rows;
  final String createdByUid;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool persisted;
  final bool importedFromEvents;

  bool get isOrganizationWide =>
      visibility == OrgCalendarVisibility.organization;

  List<OrgScheduleRow> get completeRows =>
      rows.where((row) => row.isComplete).toList();

  bool isVisibleToMember(Iterable<String> memberGroupIds) {
    if (isOrganizationWide) return true;
    final member = memberGroupIds.toSet();
    return groupIds.any(member.contains);
  }

  factory OrgCalendarSchedule.empty(String orgId, {String createdByUid = ''}) {
    return OrgCalendarSchedule(
      id: defaultDocId,
      organizationId: orgId,
      visibility: OrgCalendarVisibility.organization,
      groupIds: const [],
      rows: const [],
      createdByUid: createdByUid,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap({required String updatedByUid}) {
    final ready = <OrgScheduleRow>[];
    for (final row in rows) {
      if (row.isBlank) continue;
      ready.add(row);
    }
    return {
      'organizationId': organizationId,
      'visibility': visibility.firestoreValue,
      'groupIds': visibility == OrgCalendarVisibility.organization
          ? const <String>[]
          : groupIds,
      'rows': [
        for (var i = 0; i < ready.length; i++) ready[i].toMap(i),
      ],
      'createdByUid': createdByUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedByUid': updatedByUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory OrgCalendarSchedule.fromMap(String id, Map<String, dynamic> map) {
    final rawRows = map['rows'];
    final rawGroups = map['groupIds'];
    final rows = <OrgScheduleRow>[];
    if (rawRows is List) {
      for (var i = 0; i < rawRows.length; i++) {
        final item = rawRows[i];
        if (item is Map) {
          rows.add(
            OrgScheduleRow.fromMap(Map<String, dynamic>.from(item), index: i),
          );
        }
      }
      rows.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return OrgCalendarSchedule(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      visibility:
          orgCalendarVisibilityFromFirestore(map['visibility'] as String?),
      groupIds: rawGroups is List
          ? rawGroups.map((e) => e.toString()).toList()
          : const [],
      rows: rows,
      createdByUid: map['createdByUid'] as String? ?? '',
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readTimestamp(map['updatedAt']),
      persisted: true,
    );
  }

  factory OrgCalendarSchedule.fromEvents({
    required String orgId,
    required List<OrgCalendarEvent> events,
    String createdByUid = '',
  }) {
    final sorted = [...events]..sort((a, b) => a.startAt.compareTo(b.startAt));
    return OrgCalendarSchedule(
      id: defaultDocId,
      organizationId: orgId,
      visibility: OrgCalendarVisibility.organization,
      groupIds: const [],
      rows: [
        for (var i = 0; i < sorted.length; i++)
          OrgScheduleRow.fromEvent(sorted[i], index: i),
      ],
      createdByUid: createdByUid,
      createdAt: DateTime.now(),
      importedFromEvents: true,
    );
  }

  OrgCalendarSchedule copyWith({
    OrgCalendarVisibility? visibility,
    List<String>? groupIds,
    List<OrgScheduleRow>? rows,
    String? createdByUid,
    bool? persisted,
    bool? importedFromEvents,
  }) {
    return OrgCalendarSchedule(
      id: id,
      organizationId: organizationId,
      visibility: visibility ?? this.visibility,
      groupIds: groupIds ?? this.groupIds,
      rows: rows ?? this.rows,
      createdByUid: createdByUid ?? this.createdByUid,
      createdAt: createdAt,
      updatedAt: updatedAt,
      persisted: persisted ?? this.persisted,
      importedFromEvents: importedFromEvents ?? this.importedFromEvents,
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
