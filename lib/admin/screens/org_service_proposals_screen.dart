import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_hours.dart';
import '../providers/admin_providers.dart';
import 'review_service_proposal_screen.dart';

/// Review queue of member-proposed service projects for one organization.
class OrgServiceProposalsPanel extends ConsumerStatefulWidget {
  const OrgServiceProposalsPanel({
    super.key,
    required this.orgId,
    required this.organizationName,
  });

  final String orgId;
  final String organizationName;

  @override
  ConsumerState<OrgServiceProposalsPanel> createState() =>
      _OrgServiceProposalsPanelState();
}

class _OrgServiceProposalsPanelState
    extends ConsumerState<OrgServiceProposalsPanel> {
  String _filter = ServiceProject.proposalSubmitted;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isOrganizationAdminProvider(widget.orgId));
    final projectsAsync =
        ref.watch(organizationServiceProjectsProvider(widget.orgId));

    if (!isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Only organization administrators can review proposed projects.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load proposals: $e')),
      data: (projects) {
        final proposals = projects
            .where((p) => p.isMemberProposed)
            .where((p) => p.proposalStatus != ServiceProject.proposalApproved)
            .toList();
        final visible = proposals
            .where((p) => p.proposalStatus == _filter)
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Member-proposed projects for ${widget.organizationName}. '
              'Approve to publish, reject with a reason, or return for revision.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(
                    'Submitted (${_count(proposals, ServiceProject.proposalSubmitted)})',
                  ),
                  selected: _filter == ServiceProject.proposalSubmitted,
                  onSelected: (_) => setState(
                    () => _filter = ServiceProject.proposalSubmitted,
                  ),
                ),
                ChoiceChip(
                  label: Text(
                    'Returned (${_count(proposals, ServiceProject.proposalReturned)})',
                  ),
                  selected: _filter == ServiceProject.proposalReturned,
                  onSelected: (_) => setState(
                    () => _filter = ServiceProject.proposalReturned,
                  ),
                ),
                ChoiceChip(
                  label: Text(
                    'Rejected (${_count(proposals, ServiceProject.proposalRejected)})',
                  ),
                  selected: _filter == ServiceProject.proposalRejected,
                  onSelected: (_) => setState(
                    () => _filter = ServiceProject.proposalRejected,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_emptyMessage(_filter)),
                ),
              )
            else
              ...visible.map(
                (project) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.mark_email_unread_outlined),
                    title: Text(project.title),
                    subtitle: Text(_subtitle(project)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewServiceProposalScreen(
                            orgId: widget.orgId,
                            organizationName: widget.organizationName,
                            proposal: project,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  int _count(List<ServiceProject> items, String status) =>
      items.where((p) => p.proposalStatus == status).length;

  String _emptyMessage(String filter) {
    switch (filter) {
      case ServiceProject.proposalReturned:
        return 'No proposals are waiting on a member revision.';
      case ServiceProject.proposalRejected:
        return 'No rejected proposals to track.';
      default:
        return 'No submitted proposals in the review queue.';
    }
  }

  String _subtitle(ServiceProject project) {
    final mode =
        project.requiresApproval ? 'Requires approval' : 'Self-reported';
    final reason = project.rejectionReason.trim();
    if (project.proposalStatus == ServiceProject.proposalRejected &&
        reason.isNotEmpty) {
      return '${project.proposalStatusLabel} · $mode · $reason';
    }
    final note = project.proposalNote.trim();
    if (note.isNotEmpty) {
      return '${project.proposalStatusLabel} · $mode · $note';
    }
    return '${project.proposalStatusLabel} · $mode';
  }
}
