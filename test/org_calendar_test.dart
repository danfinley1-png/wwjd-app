import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/admin_role.dart';
import 'package:wwjd_app/admin/models/org_calendar_event.dart';
import 'package:wwjd_app/admin/models/org_calendar_schedule.dart';
import 'package:wwjd_app/core/org_calendar_ics.dart';

void main() {
  group('OrgScheduleRow', () {
    test('requires title and freeform When to be complete', () {
      const blank = OrgScheduleRow(id: '1', title: '', whenText: '');
      expect(blank.isBlank, isTrue);
      expect(blank.isComplete, isFalse);

      const partial = OrgScheduleRow(id: '2', title: 'Chapel', whenText: '');
      expect(partial.isBlank, isFalse);
      expect(partial.isComplete, isFalse);

      const ready = OrgScheduleRow(
        id: '3',
        title: 'Chapel',
        whenText: 'Weekdays 7:20 AM',
      );
      expect(ready.isComplete, isTrue);
      expect(ready.displayWhen, 'Weekdays 7:20 AM');
    });

    test('displayWhen prefers freeform text over optional dates', () {
      final row = OrgScheduleRow(
        id: '4',
        title: 'Mass',
        whenText: 'First Friday of the month',
        startAt: DateTime(2026, 9, 4),
        endAt: DateTime(2026, 9, 5),
        allDay: true,
      );
      expect(row.displayWhen, 'First Friday of the month');
    });

    test('falls back to dated-event label when When is empty', () {
      final start = DateTime(2026, 8, 26, 9);
      final row = OrgScheduleRow(
        id: '5',
        title: 'Retreat',
        whenText: '',
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        allDay: false,
      );
      expect(
        row.displayWhen,
        OrgScheduleRow.fallbackWhenFromDates(startAt: start),
      );
    });

    test('serializes optional dated fields', () {
      final start = DateTime(2026, 9, 1, 15);
      final row = OrgScheduleRow(
        id: 'r1',
        title: 'Practice',
        whenText: 'Tuesdays during lunch periods',
        location: 'Gym',
        notes: 'Bring water',
        startAt: start,
        allDay: false,
      );
      final map = row.toMap(0);
      expect(map['title'], 'Practice');
      expect(map['whenText'], 'Tuesdays during lunch periods');
      expect(map['location'], 'Gym');
      expect(map['notes'], 'Bring water');
      final restored = OrgScheduleRow.fromMap({
        ...map,
        'startAt': start,
      });
      expect(restored.title, 'Practice');
      expect(restored.whenText, 'Tuesdays during lunch periods');
      expect(restored.startAt, start);
    });
  });

  group('OrgCalendarSchedule', () {
    test('org-wide schedule is visible to every member', () {
      final schedule = OrgCalendarSchedule.empty('org1');
      expect(schedule.isVisibleToMember(const []), isTrue);
      expect(schedule.isVisibleToMember(const ['g-a']), isTrue);
    });

    test('group schedule is visible only to overlapping groups', () {
      final schedule = OrgCalendarSchedule.empty('org1').copyWith(
        visibility: OrgCalendarVisibility.groups,
        groupIds: const ['varsity', 'jv'],
      );
      expect(schedule.isVisibleToMember(const ['varsity']), isTrue);
      expect(schedule.isVisibleToMember(const ['choir']), isFalse);
      expect(schedule.isVisibleToMember(const []), isFalse);
    });

    test('toMap drops blank rows and keeps complete ones', () {
      final schedule = OrgCalendarSchedule.empty('org1', createdByUid: 'admin')
          .copyWith(
        rows: const [
          OrgScheduleRow(id: 'a', title: 'Chapel', whenText: 'Weekdays 7:20 AM'),
          OrgScheduleRow(id: 'b', title: '', whenText: ''),
        ],
      );
      final map = schedule.toMap(updatedByUid: 'admin');
      final rows = map['rows'] as List<dynamic>;
      expect(rows, hasLength(1));
      expect((rows.first as Map)['title'], 'Chapel');
      expect(map['visibility'], 'organization');
      expect(map['groupIds'], isEmpty);
    });

    test('imports dated events into freeform When rows', () {
      final start = DateTime(2026, 8, 26, 9);
      final event = OrgCalendarEvent(
        id: 'e1',
        organizationId: 'org1',
        title: 'Opening Mass',
        category: OrgCalendarCategory.liturgy,
        allDay: false,
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        visibility: OrgCalendarVisibility.organization,
        groupIds: const [],
        createdByUid: 'admin',
        createdAt: start,
        location: 'Gymnasium',
        description: 'All school',
      );
      final schedule = OrgCalendarSchedule.fromEvents(
        orgId: 'org1',
        events: [event],
        createdByUid: 'admin',
      );
      expect(schedule.importedFromEvents, isTrue);
      expect(schedule.rows, hasLength(1));
      expect(schedule.rows.first.title, 'Opening Mass');
      expect(schedule.rows.first.whenText, isNotEmpty);
      expect(schedule.rows.first.location, 'Gymnasium');
      expect(schedule.rows.first.startAt, start);
    });
  });

  group('AdminRole calendar permission', () {
    test('only org admins manage the school calendar', () {
      expect(AdminRole.orgAdmin.canManageOrgCalendar, isTrue);
      expect(AdminRole.groupLeader.canManageOrgCalendar, isFalse);
      expect(AdminRole.member.canManageOrgCalendar, isFalse);
    });
  });

  group('OrgCalendarIcs', () {
    test('builds an all-day school calendar event', () {
      final event = OrgCalendarEvent(
        id: 'mass1',
        organizationId: 'school-a',
        title: 'All-School Mass',
        description: 'Gymnasium',
        location: 'Main gym',
        category: OrgCalendarCategory.liturgy,
        allDay: true,
        startAt: DateTime(2026, 9, 8),
        endAt: DateTime(2026, 9, 9),
        visibility: OrgCalendarVisibility.organization,
        groupIds: const [],
        createdByUid: 'admin',
        createdAt: DateTime(2026, 8, 1),
      );
      final ics = OrgCalendarIcs.build(event, organizationName: 'St. Mary School');
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('SUMMARY:All-School Mass'));
      expect(ics, contains('DTSTART;VALUE=DATE:20260908'));
    });
  });
}
