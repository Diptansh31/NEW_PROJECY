import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_error_view.dart';
import '../widgets/async_action.dart';
import 'friend_action_button.dart';
import 'user_profile_page.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({
    super.key,
    required this.signedInUid,
    required this.signedInEmail,
    required this.auth,
    required this.social,
  });

  final String signedInUid;
  final String signedInEmail;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Swipe'),
              Tab(text: 'Browse'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SwipeDiscover(
                  signedInUid: signedInUid,
                  auth: auth,
                  social: social,
                ),
                _BrowseDiscover(
                  signedInUid: signedInUid,
                  auth: auth,
                  social: social,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeDiscover extends StatefulWidget {
  const _SwipeDiscover({
    required this.signedInUid,
    required this.auth,
    required this.social,
  });

  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  State<_SwipeDiscover> createState() => _SwipeDiscoverState();
}

class _SwipeDiscoverState extends State<_SwipeDiscover> {
  int _index = 0;

  void _next(int count) {
    setState(() {
      _index = (_index + 1) % max(count, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<AppUser>>(
      future: widget.auth.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AsyncErrorView(error: snapshot.error!);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? const <AppUser>[];
        final candidates = all.where((u) => u.uid != widget.signedInUid).toList(growable: false);
        candidates.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

        if (candidates.isEmpty) {
          return const Center(child: Text('No students yet. Ask friends to sign up so you can discover them.'));
        }

        final u = candidates[_index % max(candidates.length, 1)];

        return StreamBuilder<FriendStatus>(
          stream: widget.social.friendStatusStream(myUid: widget.signedInUid, otherUid: u.uid),
          builder: (context, statusSnap) {
            if (statusSnap.hasError) {
              return AsyncErrorView(error: statusSnap.error!);
            }
            if (!statusSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final status = statusSnap.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => UserProfilePage(
                                      currentUserUid: widget.signedInUid,
                                      user: u,
                                      social: widget.social,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 360,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Center(
                                  child: CircleAvatar(
                                    radius: 44,
                                    backgroundImage: u.profileImageBytes == null
                                        ? null
                                        : MemoryImage(Uint8List.fromList(u.profileImageBytes!)),
                                    child: u.profileImageBytes == null ? const Icon(Icons.person, size: 54) : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              u.username,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              u.gender.label,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            Text(u.bio.isEmpty ? 'No bio yet.' : u.bio),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => _next(candidates.length),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Pass'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FriendActionButton(
                                    areFriends: status.areFriends,
                                    hasOutgoing: status.hasOutgoingRequest,
                                    hasIncoming: status.hasIncomingRequest,
                                    onAdd: () => runAsyncAction(
                                          context,
                                          () => widget.social.sendRequest(
                                            fromUid: widget.signedInUid,
                                            toUid: u.uid,
                                          ),
                                        ),
                                    onAccept: () => runAsyncAction(
                                          context,
                                          () => widget.social.acceptIncoming(
                                            toUid: widget.signedInUid,
                                            fromUid: u.uid,
                                          ),
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => UserProfilePage(
                                      currentUserUid: widget.signedInUid,
                                      user: u,
                                      social: widget.social,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.info_outline),
                              label: const Text('View profile'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BrowseDiscover extends StatelessWidget {
  const _BrowseDiscover({
    required this.signedInUid,
    required this.auth,
    required this.social,
  });

  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUser>>(
      future: auth.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AsyncErrorView(error: snapshot.error!);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? const <AppUser>[];
        final users = all.where((u) => u.uid != signedInUid).toList(growable: false);
        users.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

        if (users.isEmpty) {
          return const Center(child: Text('No students yet. Create a second account to see Discover suggestions.'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = switch (width) {
              >= 1100 => 5,
              >= 800 => 4,
              _ => 3,
            };

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: users.length,
              itemBuilder: (context, index) {
                return _BrowseTile(
                  currentUid: signedInUid,
                  user: users[index],
                  social: social,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({
    required this.currentUid,
    required this.user,
    required this.social,
  });

  final String currentUid;
  final AppUser user;
  final FirestoreSocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<FriendStatus>(
      stream: social.friendStatusStream(myUid: currentUid, otherUid: user.uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return AsyncErrorView(error: snap.error!);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final s = snap.data!;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfilePage(
                    currentUserUid: currentUid,
                    user: user,
                    social: social,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: 28,
                          backgroundImage: user.profileImageBytes == null
                              ? null
                              : MemoryImage(Uint8List.fromList(user.profileImageBytes!)),
                          child: user.profileImageBytes == null ? const Icon(Icons.person) : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.username,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.gender.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FriendActionButton(
                      areFriends: s.areFriends,
                      hasOutgoing: s.hasOutgoingRequest,
                      hasIncoming: s.hasIncomingRequest,
                      onAdd: () => runAsyncAction(
                            context,
                            () => social.sendRequest(fromUid: currentUid, toUid: user.uid),
                          ),
                      onAccept: () => runAsyncAction(
                            context,
                            () => social.acceptIncoming(toUid: currentUid, fromUid: user.uid),
                          ),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
