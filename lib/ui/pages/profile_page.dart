import 'package:flutter/material.dart';

import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import 'friend_requests_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.signedInUid,
    required this.signedInEmail,
    required this.onSignOut,
    required this.auth,
    required this.social,
  });

  final String signedInUid;
  final String signedInEmail;
  final VoidCallback onSignOut;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 34, child: Icon(Icons.person, size: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Profile',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    signedInEmail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Friends',
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('Friend requests'),
                subtitle: const Text('Your incoming and outgoing requests'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final me = await auth.publicProfileByUid(signedInUid);
                  if (me == null || !context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FriendRequestsPage(
                        currentUser: me,
                        auth: auth,
                        social: social,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'About',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This section is LinkedIn-style: your academic identity + interests.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('CSE')),
                  Chip(label: Text('1st year')),
                  Chip(label: Text('Hostel: H-5')),
                  Chip(label: Text('Interests: Music, Travel')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Highlights',
          child: Column(
            children: const [
              ListTile(
                leading: Icon(Icons.favorite_border),
                title: Text('Matches'),
                subtitle: Text('0 (placeholder)'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.photo_library_outlined),
                title: Text('Posts'),
                subtitle: Text('0 (placeholder)'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.groups_outlined),
                title: Text('Groups'),
                subtitle: Text('0 (placeholder)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Safety',
          child: Text(
            'Campus-only doesn’t mean risk-free. Add reporting, blocking, and consent prompts early.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
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
