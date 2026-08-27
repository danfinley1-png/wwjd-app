import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../config/admin_config.dart';
import '../models/admin_role.dart';
import '../models/group_membership_invite.dart';
import '../models/ministry_group.dart';
import '../models/organization.dart';
import '../models/organization_invite.dart';
import '../models/organization_membership.dart';
import '../services/admin_access_service.dart';
import '../services/group_gift_service.dart';
import '../models/group_gift.dart';
import '../services/group_invite_service.dart';
import '../services/group_schedule_service.dart';
import '../models/group_schedule.dart';
import '../models/org_calendar_schedule.dart';
import '../services/organization_service.dart';
import '../utils/group_gift_share_access.dart';
import '../services/org_logo_service.dart';
import '../services/org_calendar_service.dart';
import '../services/platform_admin_service.dart';
import '../services/usage_report_service.dart';

final organizationServiceProvider = Provider<OrganizationService>((ref) {
  return OrganizationService();
});

final orgLogoServiceProvider = Provider<OrgLogoService>((ref) {
  return OrgLogoService();
});

final platformAdminServiceProvider = Provider<PlatformAdminService>((ref) {
  return PlatformAdminService();
});

final usageReportServiceProvider = Provider<UsageReportService>((ref) {
  return UsageReportService();
});

final groupInviteServiceProvider = Provider<GroupInviteService>((ref) {
  return GroupInviteService();
});

final groupScheduleServiceProvider = Provider<GroupScheduleService>((ref) {
  return GroupScheduleService();
});

final groupGiftServiceProvider = Provider<GroupGiftService>((ref) {
  return GroupGiftService();
});

final orgCalendarServiceProvider = Provider<OrgCalendarService>((ref) {
  return OrgCalendarService();
});

final userProvisioningServiceProvider = Provider<UserProvisioningService>((ref) {
  return UserProvisioningService();
});

final adminAccessServiceProvider = Provider<AdminAccessService>((ref) {
  return AdminAccessService();
});

final isSuperAdminProvider = StreamProvider<bool>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(platformAdminServiceProvider).watchIsSuperAdmin();
});

/// Whether the current user may enter the Admin area (leaders, bootstrap, invites).
final adminAccessStatusProvider = FutureProvider<AdminAccessStatus>((ref) async {
  if (!ref.watch(adminLayerEnabledProvider)) {
    return AdminAccessStatus.memberOnly;
  }
  ref.watch(authStateProvider);
  return ref.watch(adminAccessServiceProvider).evaluateAccess();
});

final adminLayerEnabledProvider = Provider<bool>((ref) {
  return AdminConfig.adminLayerEnabled;
});

final userOrganizationsProvider = StreamProvider<List<Organization>>((ref) {
  if (!ref.watch(adminLayerEnabledProvider)) {
    return Stream.value(const []);
  }
  ref.watch(authStateProvider);
  final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
  final service = ref.watch(organizationServiceProvider);
  if (isSuperAdmin) {
    return service.watchAllOrganizations();
  }
  return service.watchOrganizationsForCurrentUser();
});

/// Organizations the signed-in user has joined — not the full platform list.
final memberOrganizationsProvider = StreamProvider<List<Organization>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(organizationServiceProvider).watchOrganizationsForCurrentUser();
});

@immutable
class OrgMemberCalendarKey {
  const OrgMemberCalendarKey({
    required this.orgId,
    required this.groupKey,
  });

  final String orgId;
  final String groupKey;

  @override
  bool operator ==(Object other) {
    return other is OrgMemberCalendarKey &&
        other.orgId == orgId &&
        other.groupKey == groupKey;
  }

  @override
  int get hashCode => Object.hash(orgId, groupKey);
}

final orgCalendarScheduleAdminProvider =
    StreamProvider.family<OrgCalendarSchedule, String>((ref, orgId) {
  ref.watch(authStateProvider);
  return ref.watch(orgCalendarServiceProvider).watchScheduleForAdmin(orgId);
});

final memberOrgCalendarScheduleProvider = StreamProvider.family<
    OrgCalendarSchedule, OrgMemberCalendarKey>((ref, key) {
  ref.watch(authStateProvider);
  final groupIds =
      key.groupKey.isEmpty ? const <String>[] : key.groupKey.split(',');
  return ref.watch(orgCalendarServiceProvider).watchScheduleForMember(
        orgId: key.orgId,
        groupIds: groupIds,
      );
});

final pendingOrgInvitesProvider =
    StreamProvider<List<OrganizationInvite>>((ref) {
  if (!ref.watch(adminLayerEnabledProvider)) {
    return Stream.value(const []);
  }
  ref.watch(authStateProvider);
  return ref
      .watch(organizationServiceProvider)
      .watchPendingInvitesForCurrentUser();
});

/// Pending organization invitations for My Profile (email-based delivery).
final pendingOrgInvitesForUserProvider =
    StreamProvider<List<OrganizationInvite>>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.authStateChanges.asyncExpand((user) {
    final email = user?.email;
    if (email == null || email.isEmpty) {
      return Stream.value(const <OrganizationInvite>[]);
    }
    return ref
        .read(organizationServiceProvider)
        .watchPendingOrgInvitesForEmail(email);
  });
});

final pendingProfileInviteCountProvider = Provider<int>((ref) {
  final orgCount =
      ref.watch(pendingOrgInvitesForUserProvider).valueOrNull?.length ?? 0;
  final groupCount =
      ref.watch(pendingGroupInvitesForUserProvider).valueOrNull?.length ?? 0;
  return orgCount + groupCount;
});

final hasPendingInvitesProvider = Provider<bool>((ref) {
  final invites = ref.watch(pendingOrgInvitesProvider).valueOrNull ?? const [];
  return invites.isNotEmpty;
});

final isOrgAdminProvider = Provider<bool>((ref) {
  final orgs = ref.watch(userOrganizationsProvider).valueOrNull ?? const [];
  if (orgs.isEmpty) return false;
  // Detailed per-org role is resolved in organizationMembershipProvider.
  return ref.watch(adminLayerEnabledProvider);
});

/// Legacy — Admin is not linked from the personal sidebar.
@Deprecated('Admin entry is via /admin/sign-in only')
final canAccessAdminLayerProvider = Provider<bool>((ref) => false);

final organizationProvider =
    StreamProvider.family<Organization?, String>((ref, orgId) {
  ref.watch(authStateProvider);
  return ref.watch(organizationServiceProvider).watchOrganization(orgId);
});

final organizationMembershipProvider =
    StreamProvider.family<OrganizationMembership?, String>((ref, orgId) {
  ref.watch(authStateProvider);
  return ref.watch(organizationServiceProvider).watchMembership(orgId: orgId);
});

final organizationMembersProvider =
    StreamProvider.family<List<OrganizationMembership>, String>((ref, orgId) {
  return ref.watch(organizationServiceProvider).watchMembers(orgId);
});

final organizationGroupsProvider =
    StreamProvider.family<List<MinistryGroup>, String>((ref, orgId) {
  return ref.watch(organizationServiceProvider).watchGroups(orgId);
});

final organizationInvitesProvider =
    StreamProvider.family<List<OrganizationInvite>, String>((ref, orgId) {
  return ref.watch(organizationServiceProvider).watchInvitesForOrganization(orgId);
});

final organizationGroupInvitesProvider =
    StreamProvider.family<List<GroupMembershipInvite>, String>((ref, orgId) {
  return ref.watch(groupInviteServiceProvider).watchOrgGroupInvites(orgId);
});

typedef OrgGroupKey = (String orgId, String groupId);

final organizationGroupSchedulesProvider =
    StreamProvider.family<List<GroupSchedule>, OrgGroupKey>((ref, key) {
  final (orgId, groupId) = key;
  return ref.watch(groupScheduleServiceProvider).watchSchedules(
        orgId: orgId,
        groupId: groupId,
      );
});

final organizationGroupGiftsProvider =
    StreamProvider.family<List<GroupGift>, OrgGroupKey>((ref, key) {
  final (orgId, groupId) = key;
  return ref.watch(groupGiftServiceProvider).watchGifts(
        orgId: orgId,
        groupId: groupId,
      );
});

final pendingGroupInvitesForUserProvider =
    StreamProvider<List<GroupMembershipInvite>>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.authStateChanges.asyncExpand((user) {
    if (user == null) {
      return Stream.value(const <GroupMembershipInvite>[]);
    }
    return ref.read(groupInviteServiceProvider).watchPendingInvitesForUid(user.uid);
  });
});

/// True when the current user may view Pastoral Insights for [orgId].
final canViewOrgInsightsProvider = Provider.family<bool, String>((ref, orgId) {
  final membership =
      ref.watch(organizationMembershipProvider(orgId)).valueOrNull;
  return membership?.role.canViewPastoralInsights ?? false;
});

/// True when the current user is an org administrator for [orgId].
final isOrganizationAdminProvider = Provider.family<bool, String>((ref, orgId) {
  if (ref.watch(isSuperAdminProvider).valueOrNull == true) return true;

  final membership =
      ref.watch(organizationMembershipProvider(orgId)).valueOrNull;
  if (membership?.role.canManageOrganization == true) return true;

  final org = ref.watch(organizationProvider(orgId)).valueOrNull;
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  return org != null && uid != null && org.createdByUid == uid;
});

/// True when the current user may create or edit groups for [orgId].
final canManageOrgGroupsProvider = Provider.family<bool, String>((ref, orgId) {
  if (ref.watch(isSuperAdminProvider).valueOrNull == true) return true;

  final membership =
      ref.watch(organizationMembershipProvider(orgId)).valueOrNull;
  if (membership?.role.canManageGroups == true) return true;

  final org = ref.watch(organizationProvider(orgId)).valueOrNull;
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  return org != null && uid != null && org.createdByUid == uid;
});

/// True when the current user may create, edit, or share Gifts for a group.
final canManageGroupGiftsProvider =
    Provider.family<bool, OrgGroupKey>((ref, key) {
  final (orgId, groupId) = key;
  if (ref.watch(isOrganizationAdminProvider(orgId))) return true;

  final membership =
      ref.watch(organizationMembershipProvider(orgId)).valueOrNull;
  return GroupGiftShareAccess.canManageGroupGifts(
    isOrgAdmin: false,
    role: membership?.role,
    memberGroupIds: membership?.groupIds ?? const [],
    groupId: groupId,
  );
});

/// Map of group id → display name for insights filters.
final organizationGroupLabelsProvider =
    Provider.family<Map<String, String>, String>((ref, orgId) {
  final groups = ref.watch(organizationGroupsProvider(orgId)).valueOrNull ?? const [];
  return {for (final g in groups) g.id: g.name};
});

/// Distinct age bands configured on org groups.
final organizationAgeBandsProvider =
    Provider.family<List<String>, String>((ref, orgId) {
  final groups = ref.watch(organizationGroupsProvider(orgId)).valueOrNull ?? const [];
  final bands = groups
      .map((g) => g.ageBand?.trim())
      .whereType<String>()
      .where((b) => b.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return bands;
});

/// Roles the current user holds in at least one organization.
final userAdminRolesProvider = Provider<Set<AdminRole>>((ref) {
  // Lightweight summary — full membership per org uses organizationMembershipProvider.
  final orgs = ref.watch(userOrganizationsProvider).valueOrNull ?? const [];
  if (orgs.isEmpty) return {};
  // Membership streams are per-org; for sidebar badge we infer from index docs via org list + first membership fetch is heavy.
  // Consumers needing exact role should watch organizationMembershipProvider(orgId).
  return {AdminRole.orgAdmin, AdminRole.groupLeader, AdminRole.member};
});
