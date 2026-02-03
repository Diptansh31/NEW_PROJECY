import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';

class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({
    super.key,
    required this.currentUser,
    required this.auth,
    required this.social,
  });

  final AppUser currentUser;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Friend requests')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<int>(
            future: social.friendsCount(uid: currentUser.uid),
            builder: (context, snap) {
              final count = snap.data;
              return Text(
                count == null ? 'Friends: …' : 'Friends: $count',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              );
            },
          ),
          const SizedBox(height: 16),

          Text('Incoming', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          StreamBuilder<List<FriendRequest>>(
            stream: social.incomingRequestsStream(uid: currentUser.uid),
            builder: (context, snap) {
              final requests = snap.data;
              if (requests == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (requests.isEmpty) {
                return Text(
                  'No incoming requests.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }

              return Column(
                children: [
                  for (final r in requests)
                    FutureBuilder<AppUser?>(
                      future: auth.publicProfileByUid(r.fromUid),
                      builder: (context, uSnap) {
                        final u = uSnap.data;
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(u?.username ?? r.fromUid),
                            subtitle: Text(u?.email ?? ''),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () async => runAsyncAction(
                                      context,
                                      () => social.declineIncoming(toUid: currentUser.uid, fromUid: r.fromUid),
                                    ),
                                  child: const Text('Decline'),
                                ),
                                FilledButton(
                                  onPressed: () async => runAsyncAction(
                                      context,
                                      () => social.acceptIncoming(toUid: currentUser.uid, fromUid: r.fromUid),
                                    ),
                                  child: const Text('Accept'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          Text('Outgoing', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          StreamBuilder<List<FriendRequest>>(
            stream: social.outgoingRequestsStream(uid: currentUser.uid),
            builder: (context, snap) {
              final requests = snap.data;
              if (requests == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (requests.isEmpty) {
                return Text(
                  'No outgoing requests.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }

              return Column(
                children: [
                  for (final r in requests)
                    FutureBuilder<AppUser?>(
                      future: auth.publicProfileByUid(r.toUid),
                      builder: (context, uSnap) {
                        final u = uSnap.data;
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(u?.username ?? r.toUid),
                            subtitle: Text(u?.email ?? ''),
                            trailing: OutlinedButton(
                              onPressed: () async => runAsyncAction(
                                context,
                                () => social.cancelOutgoing(fromUid: currentUser.uid, toUid: r.toUid),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
