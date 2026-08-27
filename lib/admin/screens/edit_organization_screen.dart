import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/brand_image_service.dart';
import '../../core/services/profile_photo_service.dart';
import '../../widgets/group_brand_mark.dart';
import '../models/organization.dart';
import '../providers/admin_providers.dart';

Future<T?> openEditOrganizationScreen<T>(
  BuildContext context, {
  required String orgId,
}) {
  return Navigator.push<T>(
    context,
    MaterialPageRoute(
      builder: (_) => EditOrganizationScreen(orgId: orgId),
    ),
  );
}

/// Organization Admin / Overall Admin: one logo for the whole organization.
class EditOrganizationScreen extends ConsumerStatefulWidget {
  const EditOrganizationScreen({
    super.key,
    required this.orgId,
  });

  final String orgId;

  @override
  ConsumerState<EditOrganizationScreen> createState() =>
      _EditOrganizationScreenState();
}

class _EditOrganizationScreenState
    extends ConsumerState<EditOrganizationScreen> {
  final _nameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  OrganizationType _type = OrganizationType.parish;
  bool _hydrated = false;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  void _hydrateFrom(Organization org) {
    if (_hydrated) return;
    _hydrated = true;
    _nameController.text = org.name;
    _logoUrlController.text = org.resolvedLogoUrl ?? '';
    _type = org.type;
  }

  Future<void> _uploadFile() async {
    setState(() => _uploading = true);
    try {
      final picked = await ref.read(orgLogoServiceProvider).pickImage();
      if (picked == null) return;
      BrandImageService.instance.putOrgLogo(widget.orgId, picked.bytes);
      final url = await ref.read(orgLogoServiceProvider).uploadLogo(
            orgId: widget.orgId,
            picked: picked,
          );
      if (!mounted) return;
      setState(() {
        _logoUrlController.text = ProfilePhotoService.displayUrl(
              url,
              cacheBustMs: DateTime.now().millisecondsSinceEpoch,
            ) ??
            url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization logo uploaded.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final url = ProfilePhotoService.stripCacheBuster(
        _logoUrlController.text.trim(),
      );
      await ref.read(organizationServiceProvider).updateOrganization(
            orgId: widget.orgId,
            name: _nameController.text,
            type: _type,
            logoUrl: url,
            clearLogo: url.isEmpty,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(organizationProvider(widget.orgId));
    final isAdmin = ref.watch(isOrganizationAdminProvider(widget.orgId));

    return orgAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit organization')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit organization')),
        body: Center(child: Text('$e')),
      ),
      data: (org) {
        if (org == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit organization')),
            body: const Center(child: Text('Organization not found')),
          );
        }
        _hydrateFrom(org);
        final previewUrl = _logoUrlController.text.trim().isNotEmpty
            ? _logoUrlController.text.trim()
            : org.resolvedLogoUrl;

        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit organization')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only organization administrators and overall administrators '
                  'can set the organization logo.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Edit organization')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'One logo for ${org.name}. Groups, group Gifts, and the school '
                'schedule use this image. It does not replace the WWJD-DI app logo.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.45),
              ),
              const SizedBox(height: 20),
              Center(
                child: GroupBrandMark(
                  groupName: _nameController.text.trim().isEmpty
                      ? org.name
                      : _nameController.text.trim(),
                  logoUrl: previewUrl,
                  orgId: widget.orgId,
                  size: 88,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _uploading || _saving ? null : _uploadFile,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(_uploading ? 'Uploading…' : 'Upload logo'),
                  ),
                  if (previewUrl != null)
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _logoUrlController.clear()),
                      child: const Text('Remove logo'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Organization name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<OrganizationType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: OrganizationType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _type = value);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _logoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Logo image URL (optional)',
                  hintText: 'https://…',
                  border: OutlineInputBorder(),
                  helperText:
                      'Upload a file above, or paste an HTTPS image link.',
                ),
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving || _uploading ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save organization'),
              ),
            ],
          ),
        );
      },
    );
  }
}
