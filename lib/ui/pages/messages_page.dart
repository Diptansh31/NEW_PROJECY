import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../chat/firestore_chat_models.dart';
import '../../social/firestore_social_graph_controller.dart';
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
  final FirestoreSocialGraphController social;
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

  Future<void> _openChatWith({required AppUser current, required AppUser other, bool isMatchChat = false}) async {
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
          isMatchChat: isMatchChat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _currentUser,
      builder: (context, userSnap) {
        final currentUser = userSnap.data;
        if (currentUser == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<Set<String>>(
          stream: widget.social.friendsStream(uid: currentUser.uid),
          builder: (context, friendsSnap) {
            final friendUids = friendsSnap.data;
            if (friendUids == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return FutureBuilder<List<AppUser>>(
              future: widget.auth.getAllUsers(),
              builder: (context, allSnap) {
                final allUsers = allSnap.data;
                if (allUsers == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final friends = allUsers.where((u) => friendUids.contains(u.uid)).toList(growable: false);
                friends.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

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
                            Text('Start chat',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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

                          StreamBuilder<String?>(
                            stream: widget.auth.activeMatchWithUidStream(currentUser.uid),
                            builder: (context, matchSnap) {
                              final matchUid = matchSnap.data;
                              if (matchUid == null || matchUid.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              final matchUser = allUsers.where((u) => u.uid == matchUid).cast<AppUser?>().firstOrNull;
                              if (matchUser == null) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Card(
                                  elevation: 0,
                                  child: ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.favorite)),
                                    title: Text(
                                      'Your Match · ${matchUser.username}',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                    subtitle: Text(
                                      'Pinned',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _openChatWith(current: currentUser, other: matchUser, isMatchChat: true),
                                  ),
                                ),
                              );
                            },
                          ),

                          Text('Conversations',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                );
                              }

                              return Column(
                                children: [
                                  for (final t in threads)
                                    Builder(
                                      builder: (context) {
                                        final otherUid = t.otherUid(currentUser.uid);
                                        final other = allUsers.where((u) => u.uid == otherUid).cast<AppUser?>().firstOrNull;

                                        if (other == null) {
                                          return const SizedBox.shrink();
                                        }

                                        return ConversationTile(
                                          otherUser: other,
                                          // TODO: last message preview/decryption for list.
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
          },
        );
      },
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
