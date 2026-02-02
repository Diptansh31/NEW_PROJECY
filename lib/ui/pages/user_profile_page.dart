import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../social/social_graph_controller.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    super.key,
    required this.currentUserId,
    required this.user,
    required this.social,
  });

  final String currentUserId;
  final AppUser user;
  final SocialGraphController social;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: social,
      builder: (context, _) {
        final theme = Theme.of(context);
        final otherId = user.email;

        final areFriends = social.areFriends(currentUserId, otherId);
        final hasOutgoing = social.hasOutgoingRequest(currentUserId, otherId);
        final hasIncoming = social.hasIncomingRequest(currentUserId, otherId);

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
                    child: user.profileImageBytes == null
                        ? const Icon(Icons.person, size: 36)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
              _ActionCard(
                areFriends: areFriends,
                hasOutgoing: hasOutgoing,
                hasIncoming: hasIncoming,
                onAdd: () => social.sendRequest(from: currentUserId, to: otherId),
                onCancel: () => social.cancelOutgoingRequest(from: currentUserId, to: otherId),
                onAccept: () => social.acceptRequest(to: currentUserId, from: otherId),
                onDecline: () => social.declineIncomingRequest(to: currentUserId, from: otherId),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.areFriends,
    required this.hasOutgoing,
    required this.hasIncoming,
    required this.onAdd,
    required this.onCancel,
    required this.onAccept,
    required this.onDecline,
  });

  final bool areFriends;
  final bool hasOutgoing;
  final bool hasIncoming;
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
            if (areFriends) ...[
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.check),
                label: const Text('Friends'),
              ),
            ] else if (hasIncoming) ...[
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
            ] else if (hasOutgoing) ...[
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
