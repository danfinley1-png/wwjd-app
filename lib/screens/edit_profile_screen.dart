import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform_utils.dart';
import '../core/providers/app_providers.dart';
import '../models/user_profile.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_photo_editor.dart';
import '../widgets/read_aloud_voice_setting.dart';
import '../widgets/profile_messages_section.dart';
import 'change_password_screen.dart';

/// Full-screen profile editor reachable from the app menu.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider);
    final profile = profileAsync.valueOrNull;
    final accountEmail = ref.watch(authServiceProvider).currentUser?.email;
    final hasName = profile?.hasDisplayName(accountEmail) ?? false;
    ref.watch(authStateProvider);
    final canChangePassword = ref.read(authServiceProvider).canChangePassword;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (profileAsync.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (profileAsync.hasError)
            Card(
              color: Colors.orange.shade50,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Some profile details could not be synced from the cloud. '
                  'You can still edit your photo and name here.\n'
                  '${profileAsync.error}',
                  style: TextStyle(color: Colors.orange.shade900, height: 1.4),
                ),
              ),
            ),
          const Text(
            'A display name and optional photo help when you share with attribution. '
            'Favorite saint is optional. My Profile does not store a street address. '
            'Neighborhood and school locations for worship times are saved only in Near Me.',
            style: TextStyle(height: 1.5, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Center(
            child: ProfilePhotoEditor(photoUrl: profile?.photoUrl),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: ProfileAvatar(
                photoUrl: profile?.photoUrl,
                cacheBustMs: profile?.updatedAt?.millisecondsSinceEpoch,
                loadFromStorageWhenEmpty: !kIsWeb || isMobileWeb,
                radius: 24,
              ),
              title: Text(
                hasName ? profile!.effectiveDisplayName : 'No display name yet',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                profile?.favoriteSaint?.trim().isNotEmpty == true
                    ? 'Friend of ${profile!.favoriteSaint!.trim()}'
                    : 'Favorite saint not set',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                await EditProfileDialog.show(
                  context,
                  initialProfile: profile,
                );
              },
            ),
          ),
          if (canChangePassword) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change password'),
                subtitle: const Text('Update your email sign-in password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Share anonymously by default'),
            subtitle: const Text(
              'When sharing a Gift, anonymous sharing will be pre-selected.',
            ),
            value: profile?.shareAnonymouslyByDefault ?? true,
            onChanged: (value) async {
              final current = profile;
              final service = ref.read(userProfileServiceProvider);
              final email = ref.read(authServiceProvider).currentUser?.email;
              final name = current?.displayName?.trim();
              if (!UserProfile.isValidDisplayName(name, accountEmail: email)) {
                await EditProfileDialog.show(
                  context,
                  initialProfile: current,
                  subtitle:
                      'Set a display name first if you may share with attribution.',
                );
                return;
              }
              try {
                await service.upsertProfile(
                  displayName: name!,
                  favoriteSaint: current?.favoriteSaint,
                  shareAnonymouslyByDefault: value,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not update preference: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 12),
          const ReadAloudVoiceSetting(),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          const ProfileMessagesSection(),
        ],
      ),
    );
  }
}
