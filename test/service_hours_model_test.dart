import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/service_hours.dart';
import 'package:wwjd_app/models/reflection_source.dart';
import 'package:wwjd_app/models/reflection_thread.dart';

void main() {
  final created = DateTime(2026, 9, 1);

  group('ServiceProject', () {
    test('serializes without spiritual content and round-trips', () {
      final project = ServiceProject(
        id: 'p1',
        orgId: 'org1',
        title: 'Food pantry',
        description: 'Saturday packing',
        scope: 'Fall semester',
        location: 'Parish hall',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 12, 15),
        assignmentType: ServiceProject.assignmentGroups,
        assignedGroupIds: const ['g-hs'],
        mode: ServiceProject.modeRequiresApproval,
        approverUids: const ['approver1'],
        status: ServiceProject.statusActive,
        createdBy: 'admin1',
        createdAt: created,
      );

      final map = project.toMap();
      expect(map.containsKey('reflection'), isFalse);
      expect(map['orgId'], 'org1');
      expect(map['assignmentType'], 'groups');
      expect(map['mode'], 'requiresApproval');
      expect(map['createdBy'], 'admin1');
      expect(map['source'], ServiceProject.sourceAdmin);
      expect(map['proposalStatus'], ServiceProject.proposalNone);
      expect(map['nominatedApproverUids'], isEmpty);

      final restored = ServiceProject.fromMap('p1', {
        ...map,
        'startDate': project.startDate,
        'endDate': project.endDate,
        'createdAt': created,
      });
      expect(restored.title, 'Food pantry');
      expect(restored.assignedGroupIds, ['g-hs']);
      expect(restored.isAssignedToMember(['g-hs']), isTrue);
      expect(restored.isAssignedToMember(['g-other']), isFalse);
      expect(restored.initialEntryStatus, ServiceHourEntry.statusPending);
      expect(
        ServiceProject(
          id: 'orgwide',
          orgId: 'org1',
          title: 'All-parish',
          assignmentType: ServiceProject.assignmentOrganization,
          mode: ServiceProject.modeSelfReported,
          status: ServiceProject.statusActive,
          createdBy: 'admin1',
          createdAt: created,
        ).isAssignedToMember(const []),
        isTrue,
      );
    });

    test('inclusive start/end window', () {
      final project = ServiceProject(
        id: 'p1',
        orgId: 'org1',
        title: 'Camp',
        assignmentType: ServiceProject.assignmentOrganization,
        mode: ServiceProject.modeSelfReported,
        status: ServiceProject.statusActive,
        createdBy: 'admin1',
        createdAt: created,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      expect(project.isOpenOn(DateTime(2026, 9, 1)), isTrue);
      expect(project.isOpenOn(DateTime(2026, 9, 30)), isTrue);
      expect(project.isOpenOn(DateTime(2026, 8, 31)), isFalse);
      expect(project.isOpenOn(DateTime(2026, 10, 1)), isFalse);
    });

    test('isVisibleToMemberNow hides inactive, closed, and unassigned', () {
      ServiceProject project({
        String status = ServiceProject.statusActive,
        String assignment = ServiceProject.assignmentGroups,
        List<String> groups = const ['g-hs'],
        DateTime? start,
        DateTime? end,
      }) {
        return ServiceProject(
          id: 'p1',
          orgId: 'org1',
          title: 'Pantry',
          assignmentType: assignment,
          assignedGroupIds: groups,
          mode: ServiceProject.modeSelfReported,
          status: status,
          createdBy: 'admin1',
          createdAt: created,
          startDate: start,
          endDate: end,
        );
      }

      final now = DateTime(2026, 9, 15);
      expect(
        project().isVisibleToMemberNow(memberGroupIds: const ['g-hs'], now: now),
        isTrue,
      );
      expect(
        project(status: ServiceProject.statusInactive).isVisibleToMemberNow(
          memberGroupIds: const ['g-hs'],
          now: now,
        ),
        isFalse,
      );
      expect(
        project(start: DateTime(2026, 10, 1)).isVisibleToMemberNow(
          memberGroupIds: const ['g-hs'],
          now: now,
        ),
        isTrue,
      );
      expect(
        project(end: DateTime(2026, 9, 1)).isVisibleToMemberNow(
          memberGroupIds: const ['g-hs'],
          now: now,
        ),
        isFalse,
      );
      expect(
        project().isVisibleToMemberNow(memberGroupIds: const ['other'], now: now),
        isFalse,
      );
      expect(
        project(
          assignment: ServiceProject.assignmentOrganization,
          groups: const [],
        ).isVisibleToMemberNow(memberGroupIds: const [], now: now),
        isTrue,
      );
      expect(
        project().modeDisplayLabel,
        'Self-reported',
      );
    });

    test('member proposals stay unpublished until approved', () {
      final submitted = ServiceProject(
        id: 'p1',
        orgId: 'org1',
        title: 'Pantry',
        assignmentType: ServiceProject.assignmentOrganization,
        mode: ServiceProject.modeSelfReported,
        status: ServiceProject.statusInactive,
        source: ServiceProject.sourceMemberProposed,
        proposedByUid: 'u1',
        proposalStatus: ServiceProject.proposalSubmitted,
        createdBy: 'u1',
        createdAt: created,
      );
      expect(submitted.isPublished, isFalse);
      expect(
        submitted.isVisibleToMemberNow(memberGroupIds: const [], now: created),
        isFalse,
      );

      final approved = submitted.copyWith(
        status: ServiceProject.statusActive,
        proposalStatus: ServiceProject.proposalApproved,
      );
      expect(approved.isPublished, isTrue);
      expect(
        approved.isVisibleToMemberNow(memberGroupIds: const [], now: created),
        isTrue,
      );
      expect(approved.source, ServiceProject.sourceMemberProposed);
    });

    test('legacy maps default to admin source and none proposal status', () {
      final restored = ServiceProject.fromMap('p1', {
        'orgId': 'org1',
        'title': 'Legacy',
        'assignmentType': ServiceProject.assignmentOrganization,
        'mode': ServiceProject.modeSelfReported,
        'status': ServiceProject.statusActive,
        'createdBy': 'admin1',
        'createdAt': created,
      });
      expect(restored.source, ServiceProject.sourceAdmin);
      expect(restored.proposalStatus, ServiceProject.proposalNone);
      expect(restored.isPublished, isTrue);
    });
  });

  group('ServiceHourEntry totals and validation', () {
    ServiceProject pantry({
      String status = ServiceProject.statusActive,
      DateTime? start,
      DateTime? end,
    }) {
      return ServiceProject(
        id: 'p1',
        orgId: 'org1',
        title: 'Pantry',
        assignmentType: ServiceProject.assignmentOrganization,
        mode: ServiceProject.modeSelfReported,
        status: status,
        createdBy: 'admin1',
        createdAt: created,
        startDate: start,
        endDate: end,
      );
    }

    test('countedHours includes logged and approved only', () {
      ServiceHourEntry entry(String status, double hours) {
        return ServiceHourEntry(
          id: status,
          projectId: 'p1',
          orgId: 'org1',
          userId: 'u1',
          date: DateTime(2026, 9, 10),
          hours: hours,
          status: status,
          submittedAt: created,
        );
      }

      expect(
        ServiceHourEntry.countedHours([
          entry(ServiceHourEntry.statusLogged, 2),
          entry(ServiceHourEntry.statusPending, 3),
          entry(ServiceHourEntry.statusApproved, 1.25),
          entry(ServiceHourEntry.statusRejected, 4),
        ]),
        3.25,
      );
    });

    test('snapHours uses quarter-hour steps', () {
      expect(ServiceHourEntry.snapHours(1.1), 1);
      expect(ServiceHourEntry.snapHours(1.2), 1.25);
      expect(ServiceHourEntry.formatHours(2.5), '2.5');
    });

    test('rejects dates outside the project window', () {
      final project = pantry(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      );
      expect(
        ServiceHourEntryValidation.validate(
          project: project,
          date: DateTime(2026, 8, 31),
          hours: 1,
        ),
        contains('window'),
      );
      expect(
        ServiceHourEntryValidation.validate(
          project: project,
          date: DateTime(2026, 9, 10),
          hours: 1,
        ),
        isNull,
      );
    });

    test('upcoming window is visible but not selectable yet', () {
      final project = pantry(start: DateTime(2026, 10, 1));
      expect(
        ServiceHourEntryValidation.selectableDateRange(
          project,
          now: DateTime(2026, 9, 15),
        ),
        isNull,
      );
    });
  });

  group('ServiceHourEntry privacy', () {
    test('toMap stores hours metadata and a reflection id pointer only', () {
      final entry = ServiceHourEntry(
        id: 'e1',
        projectId: 'p1',
        orgId: 'org1',
        userId: 'u1',
        date: DateTime(2026, 9, 10),
        hours: 2.5,
        note: 'Drove van',
        status: ServiceHourEntry.statusPending,
        submittedAt: created,
        reflectionId: 'thread-1',
      );

      final map = entry.toMap();
      expect(map['hours'], 2.5);
      expect(map['note'], 'Drove van');
      expect(map['reflectionId'], 'thread-1');
      expect(map['source'], ServiceProject.sourceAdmin);
      expect(entry.toMap(includeReflectionId: false).containsKey('reflectionId'),
          isFalse);
      for (final key in ServiceHourEntry.forbiddenReflectionKeys) {
        expect(map.containsKey(key), isFalse, reason: key);
      }
      expect(map.values.whereType<String>().any((v) => v.contains('Dear Lord')),
          isFalse);
    });
  });

  group('ServiceProjectValidation', () {
    test('requires an approver when mode is requiresApproval', () {
      expect(
        ServiceProjectValidation.validate(
          title: 'Pantry',
          description: 'Pack boxes',
          assignmentType: ServiceProject.assignmentOrganization,
          assignedGroupIds: const [],
          mode: ServiceProject.modeRequiresApproval,
          approverUids: const [],
        ),
        contains('approver'),
      );
    });

    test('accepts self-reported org-wide project', () {
      expect(
        ServiceProjectValidation.validate(
          title: 'Pantry',
          description: 'Pack boxes',
          assignmentType: ServiceProject.assignmentOrganization,
          assignedGroupIds: const [],
          mode: ServiceProject.modeSelfReported,
          approverUids: const [],
        ),
        isNull,
      );
    });

    test('member proposal does not require approvers until admin publishes', () {
      expect(
        ServiceProjectValidation.validate(
          title: 'Pantry',
          description: 'Pack boxes',
          assignmentType: ServiceProject.assignmentOrganization,
          assignedGroupIds: const [],
          mode: ServiceProject.modeRequiresApproval,
          approverUids: const [],
          forMemberProposal: true,
        ),
        isNull,
      );
    });

    test('requires a group when assignment is groups', () {
      expect(
        ServiceProjectValidation.validate(
          title: 'Pantry',
          description: 'Pack boxes',
          assignmentType: ServiceProject.assignmentGroups,
          assignedGroupIds: const [],
          mode: ServiceProject.modeSelfReported,
          approverUids: const [],
        ),
        contains('group'),
      );
    });
  });

  group('Service reflection linkage', () {
    test('My Reflections thread points at project+entry without hour fields', () {
      const thread = ReflectionThread(
        id: 't1',
        userId: 'u1',
        source: ReflectionSource.service,
        title: 'After the pantry',
        linkedServiceProjectId: 'p1',
        linkedServiceEntryId: 'e1',
      );

      expect(ReflectionSource.label(thread.source), 'Service Hours');
      final map = thread.toMap();
      expect(map['source'], 'service');
      expect(map['linkedServiceProjectId'], 'p1');
      expect(map['linkedServiceEntryId'], 'e1');
      expect(map.containsKey('hours'), isFalse);
      expect(map.containsKey('orgId'), isFalse);
    });
  });
}
