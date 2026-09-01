import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/models/organization_membership.dart';
import '../admin/models/admin_role.dart';
import '../admin/models/service_hours.dart';
import '../admin/providers/admin_providers.dart';
import '../core/app_colors.dart';
import '../core/models/shareable_group.dart';
import '../core/providers/app_providers.dart';
import '../core/user_text_input.dart';

/// Member create / revise a service project proposal.
class ProposeServiceProjectScreen extends ConsumerStatefulWidget {
  const ProposeServiceProjectScreen({
    super.key,
    this.existing,
    this.initialOrgId,
  });

  final ServiceProject? existing;
  final String? initialOrgId;

  @override
  ConsumerState<ProposeServiceProjectScreen> createState() =>
      _ProposeServiceProjectScreenState();
}

class _ProposeServiceProjectScreenState
    extends ConsumerState<ProposeServiceProjectScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _scope = TextEditingController();
  final _location = TextEditingController();
  String? _orgId;
  String _assignmentType = ServiceProject.assignmentOrganization;
  String _mode = ServiceProject.modeSelfReported;
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _groupIds = {};
  final Set<String> _nominated = {};
  bool _saving = false;

  bool get _isRevise => widget.existing != null;
  bool get _readOnly {
    final existing = widget.existing;
    if (existing == null) return false;
    return existing.proposalStatus == ServiceProject.proposalSubmitted ||
        existing.proposalStatus == ServiceProject.proposalApproved;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      _orgId = widget.initialOrgId;
      return;
    }
    _orgId = existing.orgId;
    _title.text = existing.title;
    _description.text = existing.description;
    _scope.text = existing.scope;
    _location.text = existing.location;
    _assignmentType = existing.assignmentType;
    _mode = existing.mode;
    _startDate = existing.startDate;
    _endDate = existing.endDate;
    _groupIds.addAll(existing.assignedGroupIds);
    _nominated.addAll(existing.nominatedApproverUids);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _scope.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    if (_readOnly) return;
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

  Future<void> _save() async {
    if (_readOnly || _saving) return;
    final orgId = _orgId;
    if (orgId == null || orgId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an organization.')),
      );
      return;
    }

    final error = ServiceProjectValidation.validate(
      title: _title.text,
      description: _description.text,
      assignmentType: _assignmentType,
      assignedGroupIds: _groupIds.toList(),
      mode: _mode,
      approverUids: const [],
      startDate: _startDate,
      endDate: _endDate,
      forMemberProposal: true,
      nominatedApproverUids: _nominated.toList(),
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    final service = ref.read(serviceProjectServiceProvider);
    try {
      if (_isRevise) {
        await service.resubmitProposal(
          existing: widget.existing!,
          title: _title.text,
          description: _description.text,
          scope: _scope.text,
          location: _location.text,
          startDate: _startDate,
          endDate: _endDate,
          assignmentType: _assignmentType,
          assignedGroupIds: _groupIds.toList(),
          mode: _mode,
          nominatedApproverUids: _nominated.toList(),
        );
      } else {
        await service.proposeProject(
          orgId: orgId,
          title: _title.text,
          description: _description.text,
          scope: _scope.text,
          location: _location.text,
          startDate: _startDate,
          endDate: _endDate,
          assignmentType: _assignmentType,
          assignedGroupIds: _groupIds.toList(),
          mode: _mode,
          nominatedApproverUids: _nominated.toList(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRevise
                ? 'Proposal resubmitted for review.'
                : 'Proposal submitted for review.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the proposal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgs = ref.watch(memberOrganizationsProvider).valueOrNull ?? const [];
    if (_orgId == null && orgs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _orgId == null && orgs.isNotEmpty) {
          setState(() => _orgId = orgs.first.id);
        }
      });
    }
    final orgId = _orgId ?? '';
    final members =
        orgId.isEmpty
            ? const <OrganizationMembership>[]
            : ref.watch(organizationMembersProvider(orgId)).valueOrNull ??
                const [];
    final groups =
        ref.watch(profileGroupMembershipsProvider).valueOrNull ??
            const <ShareableGroup>[];
    final myGroups = groups.where((g) => g.organizationId == orgId).toList();
    final existing = widget.existing;
    final dateFmt = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isRevise ? 'Your proposal' : 'Propose a service project'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (existing != null) ...[
            Text(
              existing.proposalStatusLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryMaroon,
              ),
            ),
            if (existing.rejectionReason.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Reason: ${existing.rejectionReason.trim()}'),
                ),
              ),
            ],
            if (existing.proposalNote.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Notes: ${existing.proposalNote.trim()}'),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          AbsorbPointer(
            absorbing: _readOnly,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          if (!_isRevise && orgs.length > 1)
            DropdownButtonFormField<String>(
              initialValue: orgs.any((o) => o.id == _orgId) ? _orgId : orgs.first.id,
              decoration: const InputDecoration(
                labelText: 'Organization',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final org in orgs)
                  DropdownMenuItem(value: org.id, child: Text(org.name)),
              ],
              onChanged: _readOnly
                  ? null
                  : (id) => setState(() {
                        _orgId = id;
                        _groupIds.clear();
                        _nominated.clear();
                      }),
            )
          else if (orgs.isNotEmpty)
            Text(
              orgs
                  .firstWhere((o) => o.id == orgId, orElse: () => orgs.first)
                  .name,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
            maxLines: 6,
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
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start date (optional)'),
            subtitle: Text(
              _startDate == null ? 'Not set' : dateFmt.format(_startDate!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _readOnly ? null : () => _pickDate(start: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End date (optional)'),
            subtitle: Text(
              _endDate == null ? 'Not set' : dateFmt.format(_endDate!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _readOnly ? null : () => _pickDate(start: false),
          ),
          if (!_readOnly && (_startDate != null || _endDate != null))
            TextButton(
              onPressed: () => setState(() {
                _startDate = null;
                _endDate = null;
              }),
              child: const Text('Clear dates'),
            ),
          const SizedBox(height: 8),
          Text('Assignment', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<String>(
            title: const Text('Whole organization'),
            value: ServiceProject.assignmentOrganization,
            groupValue: _assignmentType,
            onChanged: _readOnly
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _assignmentType = value);
                  },
          ),
          RadioListTile<String>(
            title: const Text('My group(s)'),
            value: ServiceProject.assignmentGroups,
            groupValue: _assignmentType,
            onChanged: _readOnly || myGroups.isEmpty
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _assignmentType = value);
                  },
          ),
          if (_assignmentType == ServiceProject.assignmentGroups) ...[
            if (myGroups.isEmpty)
              const Text(
                'Join a group in this organization before assigning by group.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final group in myGroups)
                    FilterChip(
                      label: Text(group.groupName),
                      selected: _groupIds.contains(group.groupId),
                      onSelected: _readOnly
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected) {
                                  _groupIds.add(group.groupId);
                                } else {
                                  _groupIds.remove(group.groupId);
                                }
                              });
                            },
                    ),
                ],
              ),
          ],
          const SizedBox(height: 12),
          Text('Hour logging', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<String>(
            title: const Text('Self-reported'),
            value: ServiceProject.modeSelfReported,
            groupValue: _mode,
            onChanged: _readOnly
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _mode = value);
                  },
          ),
          RadioListTile<String>(
            title: const Text('Requires approval'),
            value: ServiceProject.modeRequiresApproval,
            groupValue: _mode,
            onChanged: _readOnly
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _mode = value);
                  },
          ),
          if (_mode == ServiceProject.modeRequiresApproval) ...[
            const SizedBox(height: 8),
            const Text(
              'Nominated approvers (optional). An organization administrator '
              'sets the final approvers.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 8),
            for (final member in members)
              CheckboxListTile(
                value: _nominated.contains(member.uid),
                title: Text(_memberLabel(member)),
                subtitle: Text(member.role.label),
                onChanged: _readOnly
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected == true) {
                            if (_nominated.length >= ServiceProject.approversMax) {
                              return;
                            }
                            _nominated.add(member.uid);
                          } else {
                            _nominated.remove(member.uid);
                          }
                        });
                      },
              ),
          ],
            ],
          ),
          ),
          if (!_readOnly) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRevise ? 'Resubmit for review' : 'Submit proposal'),
            ),
          ],
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
