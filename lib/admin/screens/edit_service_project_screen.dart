import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/user_text_input.dart';
import '../models/admin_role.dart';
import '../models/organization_membership.dart';
import '../models/service_hours.dart';
import '../providers/admin_providers.dart';

/// Create or edit a [ServiceProject] for one organization.
class EditServiceProjectScreen extends ConsumerStatefulWidget {
  const EditServiceProjectScreen({
    super.key,
    required this.orgId,
    required this.organizationName,
    this.existing,
  });

  final String orgId;
  final String organizationName;
  final ServiceProject? existing;

  @override
  ConsumerState<EditServiceProjectScreen> createState() =>
      _EditServiceProjectScreenState();
}

class _EditServiceProjectScreenState
    extends ConsumerState<EditServiceProjectScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _scope = TextEditingController();
  final _location = TextEditingController();
  String _assignmentType = ServiceProject.assignmentOrganization;
  String _mode = ServiceProject.modeSelfReported;
  String _status = ServiceProject.statusActive;
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _groupIds = {};
  final Set<String> _approverUids = {};
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _title.text = existing.title;
    _description.text = existing.description;
    _scope.text = existing.scope;
    _location.text = existing.location;
    _assignmentType = existing.assignmentType;
    _mode = existing.mode;
    _status = existing.status;
    _startDate = existing.startDate;
    _endDate = existing.endDate;
    _groupIds.addAll(existing.assignedGroupIds);
    _approverUids.addAll(existing.approverUids);
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
    final error = ServiceProjectValidation.validate(
      title: _title.text,
      description: _description.text,
      assignmentType: _assignmentType,
      assignedGroupIds: _groupIds.toList(),
      mode: _mode,
      approverUids: _approverUids.toList(),
      startDate: _startDate,
      endDate: _endDate,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    final service = ref.read(serviceProjectServiceProvider);
    try {
      if (_isEditing) {
        await service.updateProject(
          existing: widget.existing!,
          orgId: widget.orgId,
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
          status: _status,
        );
      } else {
        await service.createProject(
          orgId: widget.orgId,
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
          status: _status,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the service project: $e')),
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

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit service project' : 'Create service project'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only organization administrators and overall administrators '
              'can create or edit service projects.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat.yMMMd();
    final needsApprovers = _mode == ServiceProject.modeRequiresApproval;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit service project' : 'Create service project'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Volunteer project for ${widget.organizationName}. This is not '
            'Seeking God\'s Wisdom, My Reflections, or personal Gifts.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          ),
          const SizedBox(height: 20),
          UserTextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          UserTextField(
            controller: _description,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          UserTextField(
            controller: _scope,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Scope (optional)',
              hintText: 'e.g. Fall semester, Confirmation year',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          UserTextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Dates (optional)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(start: true),
                  child: Text(
                    _startDate == null
                        ? 'Start date'
                        : 'Start ${dateFormat.format(_startDate!)}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(start: false),
                  child: Text(
                    _endDate == null
                        ? 'End date'
                        : 'End ${dateFormat.format(_endDate!)}',
                  ),
                ),
              ),
            ],
          ),
          if (_startDate != null || _endDate != null)
            TextButton(
              onPressed: () => setState(() {
                _startDate = null;
                _endDate = null;
              }),
              child: const Text('Clear dates'),
            ),
          const SizedBox(height: 16),
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
          if (_assignmentType == ServiceProject.assignmentGroups) ...[
            const SizedBox(height: 4),
            if (groups.isEmpty)
              Text(
                'Add groups in this organization before assigning by group.',
                style: TextStyle(color: Colors.grey.shade700),
              )
            else
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
          ],
          const SizedBox(height: 16),
          Text('Hour logging', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<String>(
            title: const Text('Self-reported'),
            subtitle: const Text('Members log hours without a reviewer.'),
            value: ServiceProject.modeSelfReported,
            groupValue: _mode,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _mode = value);
            },
          ),
          RadioListTile<String>(
            title: const Text('Requires approval'),
            subtitle: const Text('An assigned approver reviews each entry.'),
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
              'Approvers (this organization only)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Name, email, and role only — not conversations or Gifts.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 8),
            if (_approverUids.isEmpty)
              Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Select at least one approver before saving a project '
                    'that requires approval.',
                  ),
                ),
              ),
            if (members.isEmpty)
              Text(
                'Invite members to this organization before assigning approvers.',
                style: TextStyle(color: Colors.grey.shade700),
              )
            else
              for (final member in members)
                CheckboxListTile(
                  value: _approverUids.contains(member.uid),
                  title: Text(_memberLabel(member)),
                  subtitle: Text(member.role.label),
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
          const SizedBox(height: 16),
          Text('Status', style: Theme.of(context).textTheme.titleSmall),
          SwitchListTile(
            title: Text(_status == ServiceProject.statusActive ? 'Active' : 'Inactive'),
            subtitle: const Text(
              'Inactive projects stay in the list but members cannot log new hours.',
            ),
            value: _status == ServiceProject.statusActive,
            onChanged: (active) {
              setState(() {
                _status = active
                    ? ServiceProject.statusActive
                    : ServiceProject.statusInactive;
              });
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Save project' : 'Create project'),
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
