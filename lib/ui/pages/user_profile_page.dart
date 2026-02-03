import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    super.key,
    required this.currentUserUid,
    required this.user,
    required this.social,
  });

  final String currentUserUid;
  final AppUser user;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(user.username)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundImage: user.profileImageBytes == null
                    ? null
                    : MemoryImage(Uint8List.fromList(user.profileImageBytes!)),
                child: user.profileImageBytes == null ? const Icon(Icons.person, size: 36) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
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
                  Text('About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(user.bio.isEmpty ? 'No bio yet.' : user.bio),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(user.gender.label)),
                      for (final i in user.interests) Chip(label: Text(i)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<FriendStatus>(
            stream: social.friendStatusStream(myUid: currentUserUid, otherUid: user.uid),
            builder: (context, snap) {
              final s = snap.data;
              if (s == null) {
                return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
              }

              return _ActionCard(
                status: s,
                onAdd: () => runAsyncAction(
                      context,
                      () => social.sendRequest(fromUid: currentUserUid, toUid: user.uid),
                    ),
                onCancel: () => runAsyncAction(
                      context,
                      () => social.cancelOutgoing(fromUid: currentUserUid, toUid: user.uid),
                    ),
                onAccept: () => runAsyncAction(
                      context,
                      () => social.acceptIncoming(toUid: currentUserUid, fromUid: user.uid),
                    ),
                onDecline: () => runAsyncAction(
                      context,
                      () => social.declineIncoming(toUid: currentUserUid, fromUid: user.uid),
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.status,
    required this.onAdd,
    required this.onCancel,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendStatus status;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Connection', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (status.areFriends) ...[
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.check),
                label: const Text('Friends'),
              ),
            ] else if (status.hasIncomingRequest) ...[
              FilledButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Accept request'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onDecline,
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
              ),
            ] else if (status.hasOutgoingRequest) ...[
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.hourglass_top),
                label: const Text('Requested'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.undo),
                label: const Text('Cancel request'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add),
                label: const Text('Add friend'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
