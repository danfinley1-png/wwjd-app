import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/organization_membership.dart';
import '../models/admin_role.dart';
import '../models/service_hours.dart';
import '../providers/admin_providers.dart';
import '../../core/app_colors.dart';
import '../../core/user_text_input.dart';

/// Org Admin review of a member-proposed service project.
class ReviewServiceProposalScreen extends ConsumerStatefulWidget {
  const ReviewServiceProposalScreen({
    super.key,
    required this.orgId,
    required this.organizationName,
    required this.proposal,
  });

  final String orgId;
  final String organizationName;
  final ServiceProject proposal;

  @override
  ConsumerState<ReviewServiceProposalScreen> createState() =>
      _ReviewServiceProposalScreenState();
}

class _ReviewServiceProposalScreenState
    extends ConsumerState<ReviewServiceProposalScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _scope;
  late final TextEditingController _location;
  late final TextEditingController _note;
  late final TextEditingController _reason;
  late String _assignmentType;
  late String _mode;
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _groupIds = {};
  final Set<String> _approverUids = {};
  final Set<String> _nominated = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.proposal;
    _title = TextEditingController(text: p.title);
    _description = TextEditingController(text: p.description);
    _scope = TextEditingController(text: p.scope);
    _location = TextEditingController(text: p.location);
    _note = TextEditingController(text: p.proposalNote);
    _reason = TextEditingController(text: p.rejectionReason);
    _assignmentType = p.assignmentType;
    _mode = p.mode;
    _startDate = p.startDate;
    _endDate = p.endDate;
    _groupIds.addAll(p.assignedGroupIds);
    _approverUids.addAll(p.approverUids);
    if (_approverUids.isEmpty) {
      _approverUids.addAll(p.nominatedApproverUids);
    }
    _nominated.addAll(p.nominatedApproverUids);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _scope.dispose();
    _location.dispose();
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit(String proposalStatus) async {
    if (_saving) return;
    final error = ServiceProjectValidation.validate(
      title: _title.text,
      description: _description.text,
      assignmentType: _assignmentType,
      assignedGroupIds: _groupIds.toList(),
      mode: _mode,
      approverUids: proposalStatus == ServiceProject.proposalApproved
          ? _approverUids.toList()
          : const [],
      startDate: _startDate,
      endDate: _endDate,
      forMemberProposal: proposalStatus != ServiceProject.proposalApproved,
      nominatedApproverUids: _nominated.toList(),
      proposalNote: _note.text,
      rejectionReason: _reason.text,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(serviceProjectServiceProvider).reviewProposal(
            existing: widget.proposal,
            proposalStatus: proposalStatus,
            title: _title.text,
            description: _description.text,
            scope: _scope.text,
            location: _location.text,
            startDate: _startDate,
            endDate: _endDate,
            assignmentType: _assignmentType,
            assignedGroupIds: _groupIds.toList(),
            mode: _mode,
            approverUids: _approverUids.toList(),
            nominatedApproverUids: _nominated.toList(),
            proposalNote: _note.text,
            rejectionReason: _reason.text,
          );
      if (!mounted) return;
      final label = proposalStatus == ServiceProject.proposalApproved
          ? 'Proposal approved. It is now live for assigned members.'
          : proposalStatus == ServiceProject.proposalRejected
              ? 'Proposal rejected.'
              : 'Proposal returned for revision.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the review: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isOrganizationAdminProvider(widget.orgId));
    final groups =
        ref.watch(organizationGroupsProvider(widget.orgId)).valueOrNull ??
            const [];
    final members =
        ref.watch(organizationMembersProvider(widget.orgId)).valueOrNull ??
            const [];
    final dateFormat = DateFormat.yMMMd();
    final needsApprovers = _mode == ServiceProject.modeRequiresApproval;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proposed project')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only organization administrators can review proposals.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Review proposal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Member proposal for ${widget.organizationName}. '
            'Status: ${widget.proposal.proposalStatusLabel}.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 16),
          UserTextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          UserTextField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          UserTextField(
            controller: _scope,
            decoration: const InputDecoration(
              labelText: 'Scope (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          UserTextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start date'),
            subtitle: Text(
              _startDate == null ? 'Not set' : dateFormat.format(_startDate!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pickDate(start: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End date'),
            subtitle: Text(
              _endDate == null ? 'Not set' : dateFormat.format(_endDate!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pickDate(start: false),
          ),
          Text('Assignment', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<String>(
            title: const Text('Whole organization'),
            value: ServiceProject.assignmentOrganization,
            groupValue: _assignmentType,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _assignmentType = value);
            },
          ),
          RadioListTile<String>(
            title: const Text('Selected groups'),
            value: ServiceProject.assignmentGroups,
            groupValue: _assignmentType,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _assignmentType = value);
            },
          ),
          if (_assignmentType == ServiceProject.assignmentGroups)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final group in groups)
                  FilterChip(
                    label: Text(group.name),
                    selected: _groupIds.contains(group.id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _groupIds.add(group.id);
                        } else {
                          _groupIds.remove(group.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Text('Hour logging', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<String>(
            title: const Text('Self-reported'),
            value: ServiceProject.modeSelfReported,
            groupValue: _mode,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _mode = value);
            },
          ),
          RadioListTile<String>(
            title: const Text('Requires approval'),
            value: ServiceProject.modeRequiresApproval,
            groupValue: _mode,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _mode = value);
            },
          ),
          if (needsApprovers) ...[
            const SizedBox(height: 8),
            Text(
              'Final approvers (required to approve)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (_nominated.isNotEmpty)
              Text(
                'Member nominated ${_nominated.length} '
                'approver${_nominated.length == 1 ? '' : 's'}.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            for (final member in members)
              CheckboxListTile(
                value: _approverUids.contains(member.uid),
                title: Text(_memberLabel(member)),
                subtitle: Text(
                  _nominated.contains(member.uid)
                      ? '${member.role.label} · Nominated'
                      : member.role.label,
                ),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      if (_approverUids.length >= ServiceProject.approversMax) {
                        return;
                      }
                      _approverUids.add(member.uid);
                    } else {
                      _approverUids.remove(member.uid);
                    }
                  });
                },
              ),
          ],
          const SizedBox(height: 12),
          UserTextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes to the proposer (required to return)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          UserTextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Rejection reason (required to reject)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving
                ? null
                : () => _submit(ServiceProject.proposalApproved),
            child: const Text('Approve and publish'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () => _submit(ServiceProject.proposalReturned),
            child: const Text('Return for revision'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving
                ? null
                : () => _submit(ServiceProject.proposalRejected),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _memberLabel(OrganizationMembership member) {
    final name = member.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = member.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Organization member';
  }
}
