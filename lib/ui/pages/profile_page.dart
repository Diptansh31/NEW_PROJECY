import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../../posts/firestore_posts_controller.dart';
import '../../posts/post_models.dart';
import '../widgets/async_action.dart';
import 'edit_profile_page.dart';
import 'friends_list_page.dart';
import 'my_post_detail_page.dart';
import 'post_image_widget.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.signedInUid,
    required this.signedInEmail,
    required this.onSignOut,
    required this.auth,
    required this.social,
    required this.posts,
  });

  final String signedInUid;
  final String signedInEmail;
  final VoidCallback onSignOut;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final FirestorePostsController posts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder(
      stream: auth.profileStreamByUid(signedInUid),
      builder: (context, snapshot) {
        final me = snapshot.data;

        final avatar = InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () => runAsyncAction(context, () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
              withData: true,
            );
            if (result == null || result.files.isEmpty) return;
            final bytes = result.files.single.bytes;
            if (bytes == null) return;

            await auth.updateProfileImage(uid: signedInUid, bytes: bytes);
          }),
          child: CircleAvatar(
            radius: 34,
            backgroundImage: (me?.profileImageBytes == null)
                ? null
                : MemoryImage(Uint8List.fromList(me!.profileImageBytes!)),
            child: (me?.profileImageBytes == null)
                ? const Icon(Icons.person, size: 36)
                : null,
          ),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me?.username.isNotEmpty == true ? me!.username : 'Your Profile',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        signedInEmail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: me != null
                                ? () => _navigateToEditProfile(context, me)
                                : null,
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit profile'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => runAsyncAction(context, () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                withData: true,
                              );
                              if (result == null || result.files.isEmpty) return;
                              final bytes = result.files.single.bytes;
                              if (bytes == null) return;
                              await auth.updateProfileImage(uid: signedInUid, bytes: bytes);
                            }),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Add photos'),
                          ),
                        ],
                      ),
                      if (me?.bio.isEmpty ?? true) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tip: add a bio and interests to get more matches.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _SectionCard(
              title: 'Friends',
              child: StreamBuilder<Set<String>>(
                stream: social.friendsStream(uid: signedInUid),
                builder: (context, snap) {
                  final count = snap.data?.length;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FriendsListPage(
                            signedInUid: signedInUid,
                            auth: auth,
                            social: social,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.group_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              count == null ? '… friends' : '$count friends',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'About',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (me?.bio.isNotEmpty ?? false) ...[
                    Text(
                      me!.bio,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Icon(
                        _genderIcon(me?.gender),
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        me?.gender.label ?? 'Not specified',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (me?.interests.isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final interest in me!.interests)
                          Chip(
                            label: Text(interest),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                  if ((me?.bio.isEmpty ?? true) && (me?.interests.isEmpty ?? true)) ...[
                    Text(
                      'No bio or interests yet. Tap "Edit profile" to add them!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Your posts',
              child: StreamBuilder<List<Post>>(
                stream: posts.userPostsStream(uid: signedInUid),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text('Failed to load posts: ${snap.error}');
                  }
                  if (!snap.hasData) {
                    return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                  }

                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const Text('No posts yet. Create one from the Feed tab.');
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemBuilder: (context, index) {
                      final p = items[index];
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => MyPostDetailPage(post: p)),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: PostImage(post: p),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Security',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'End-to-end encryption (WhatsApp-like)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Back up your encryption key with a passphrase so you can restore chats on a new device. We never store your passphrase.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final pass = await _askPassphrase(context, title: 'Backup encryption key');
                          if (!context.mounted) return;
                          if (pass == null || pass.isEmpty) return;
                          await runAsyncAction(context, () => auth.backupIdentityKey(passphrase: pass));
                        },
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Backup key'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final pass = await _askPassphrase(context, title: 'Restore encryption key');
                          if (!context.mounted) return;
                          if (pass == null || pass.isEmpty) return;
                          await runAsyncAction(context, () => auth.restoreIdentityKey(passphrase: pass));
                        },
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('Restore key'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              title: 'Account',
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToEditProfile(BuildContext context, AppUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          currentUser: user,
          auth: auth,
        ),
      ),
    );
  }

  IconData _genderIcon(Gender? gender) {
    return switch (gender) {
      Gender.male => Icons.male,
      Gender.female => Icons.female,
      Gender.nonBinary => Icons.transgender,
      Gender.preferNotToSay => Icons.person_outline,
      null => Icons.person_outline,
    };
  }
}

Future<String?> _askPassphrase(BuildContext context, {required String title}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Passphrase',
            hintText: 'Choose a strong passphrase',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
