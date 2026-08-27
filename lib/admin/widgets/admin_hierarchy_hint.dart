import 'package:flutter/material.dart';

import '../../widgets/group_brand_mark.dart';

/// Brief admin copy: organizations (institutions) contain groups (teams/circles).
class AdminHierarchyHint extends StatelessWidget {
  const AdminHierarchyHint({super.key, this.compact = false});

  /// Smaller padding when nested under a section heading.
  final bool compact;

  static const String organizationsDefinition =
      'An organization is a school, parish, or ministry institution.';
  static const String groupsDefinition =
      'A group is a team or circle within one organization (e.g. youth group, confirmation class).';
  static const String hierarchyLine =
      'Organizations contain groups — set up the institution first, then add groups inside it.';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50.withValues(alpha: compact ? 0.65 : 1),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: compact ? 20 : 22,
            color: Colors.blueGrey.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              compact
                  ? hierarchyLine
                  : '$organizationsDefinition $groupsDefinition $hierarchyLine',
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                height: 1.45,
                color: Colors.blueGrey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section label for organization lists (institutions, not groups).
class AdminOrganizationsSectionHeader extends StatelessWidget {
  const AdminOrganizationsSectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your organizations',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Schools, parishes, and ministry institutions you administer — not individual groups.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Heading for the groups tab inside one organization.
class AdminOrganizationGroupsHeader extends StatelessWidget {
  const AdminOrganizationGroupsHeader({
    super.key,
    required this.organizationName,
    this.orgId,
    this.logoUrl,
  });

  final String organizationName;
  final String? orgId;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GroupBrandMark(
              groupName: organizationName,
              logoUrl: logoUrl,
              orgId: orgId,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Groups in this organization',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Teams and circles that belong to $organizationName — members join groups '
          'after they are part of the organization.',
          style: TextStyle(
            color: Colors.grey.shade700,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
