import 'package:flutter/material.dart';

import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';

class MatchRequestsPage extends StatelessWidget {
  const MatchRequestsPage({
    super.key,
    required this.currentUid,
    required this.auth,
    required this.social,
  });

  final String currentUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Match requests')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Likes you', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: social.incomingMatchRequestsStream(uid: currentUid),
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (items.isEmpty) {
                return Text(
                  'No incoming match requests yet.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }

              return Column(
                children: [
                  for (final r in items)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(r.fromUid, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: const Text('Wants to match'),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Decline',
                              onPressed: () => runAsyncAction(
                                context,
                                () => social.declineMatchRequest(toUid: currentUid, fromUid: r.fromUid),
                              ),
                              icon: const Icon(Icons.close),
                            ),
                            FilledButton(
                              onPressed: () => runAsyncAction(
                                context,
                                () => social.acceptMatchRequest(toUid: currentUid, fromUid: r.fromUid),
                                successMessage: 'Matched!',
                              ),
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text('Your requests', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: social.outgoingMatchRequestsStream(uid: currentUid),
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (items.isEmpty) {
                return Text(
                  'No outgoing requests.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }

              return Column(
                children: [
                  for (final r in items)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.hourglass_top)),
                        title: Text(r.toUid, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: const Text('Pending'),
                        trailing: TextButton(
                          onPressed: () => runAsyncAction(
                            context,
                            () => social.cancelOutgoingMatchRequest(fromUid: currentUid, toUid: r.toUid),
                            successMessage: 'Cancelled',
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
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
