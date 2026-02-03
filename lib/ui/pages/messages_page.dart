import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../chat/firestore_chat_models.dart';
import '../../social/social_graph_controller.dart';
import '_messages_widgets.dart';
import 'chat_thread_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    required this.signedInUid,
    required this.signedInEmail,
    required this.auth,
    required this.social,
    required this.chat,
  });

  final String signedInUid;
  final String signedInEmail;
  final FirebaseAuthController auth;
  final SocialGraphController social;
  final FirestoreChatController chat;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AppUser?> get _currentUser async => widget.auth.getUserByEmail(widget.signedInEmail);

  Future<List<AppUser>> _friends() async {
    final meEmail = widget.signedInEmail;
    final all = await widget.auth.getAllUsers();
    final out = all
        .where((u) => u.email != meEmail && widget.social.areFriends(meEmail, u.email))
        .toList(growable: false);
    out.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    return out;
  }

  Future<void> _openChatWith({required AppUser current, required AppUser other}) async {
    final thread = await widget.chat.getOrCreateThread(
      myUid: current.uid,
      myEmail: current.email,
      otherUid: other.uid,
      otherEmail: other.email,
    );

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadPage(
          currentUser: current,
          otherUser: other,
          thread: thread,
          chat: widget.chat,
          social: widget.social,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([_currentUser, _friends()]),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentUser = data[0] as AppUser?;
        final friends = data[1] as List<AppUser>;

        if (currentUser == null) {
          return const Center(child: Text('Profile not found.'));
        }

        final theme = Theme.of(context);
        final query = _searchController.text.trim().toLowerCase();
        final matches = query.isEmpty
            ? friends
            : friends.where((u) => u.username.toLowerCase().contains(query)).toList(growable: false);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search friends by username to chat…',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (query.isNotEmpty) ...[
                    Text('Start chat', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (matches.isEmpty)
                      Text(
                        'No friends match “${_searchController.text.trim()}”.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      )
                    else
                      for (final u in matches)
                        UserStartTile(
                          user: u,
                          onTap: () => _openChatWith(current: currentUser, other: u),
                        ),
                    const SizedBox(height: 16),
                  ],

                  Text('Conversations', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),

                  StreamBuilder<List<FirestoreChatThread>>(
                    stream: widget.chat.threadsStream(myUid: currentUser.uid),
                    builder: (context, threadSnap) {
                      final threads = threadSnap.data;
                      if (threads == null) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (threads.isEmpty) {
                        return Text(
                          'No conversations yet. Search a friend above to start chatting.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        );
                      }

                      return Column(
                        children: [
                          for (final t in threads)
                            Builder(
                              builder: (context) {
                                // Find user by email (fallback) to display username/avatar.
                                final otherEmail = t.otherEmail(currentUser.uid);
                                final other = friends.where((u) => u.email == otherEmail).cast<AppUser?>().firstOrNull;

                                if (other == null) {
                                  return ConversationTile(
                                    otherUser: AppUser(
                                      uid: t.otherUid(currentUser.uid),
                                      email: otherEmail,
                                      username: otherEmail,
                                      gender: currentUser.gender,
                                      bio: '',
                                      interests: const <String>[],
                                    ),
                                    lastMessage: null,
                                    unread: 0,
                                    onTap: () {},
                                  );
                                }

                                return ConversationTile(
                                  otherUser: other,
                                  lastMessage: null,
                                  unread: 0,
                                  onTap: () => _openChatWith(current: currentUser, other: other),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
