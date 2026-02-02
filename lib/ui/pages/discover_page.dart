import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/local_auth_controller.dart';
import '../../social/social_graph_controller.dart';
import 'friend_action_button.dart';
import 'user_profile_page.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({
    super.key,
    required this.signedInEmail,
    required this.auth,
    required this.social,
  });

  final String signedInEmail;
  final LocalAuthController auth;
  final SocialGraphController social;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Rebuild Discover when friend state changes.
      animation: social,
      builder: (context, _) {
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
                      signedInEmail: signedInEmail,
                      auth: auth,
                      social: social,
                    ),
                    _BrowseDiscover(
                      signedInEmail: signedInEmail,
                      auth: auth,
                      social: social,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwipeDiscover extends StatefulWidget {
  const _SwipeDiscover({
    required this.signedInEmail,
    required this.auth,
    required this.social,
  });

  final String signedInEmail;
  final LocalAuthController auth;
  final SocialGraphController social;

  @override
  State<_SwipeDiscover> createState() => _SwipeDiscoverState();
}

class _SwipeDiscoverState extends State<_SwipeDiscover> {
  int _index = 0;

  List<AppUser> get _candidates {
    final others = widget.auth.allUsers
        .where((u) => u.email != widget.signedInEmail)
        .toList(growable: false);

    // Stable sort so the swipe experience is deterministic.
    others.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    return others;
  }

  void _next() {
    setState(() {
      final count = max(_candidates.length, 1);
      _index = (_index + 1) % count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final candidates = _candidates;
    if (candidates.isEmpty) {
      return const Center(
        child: Text('No students yet. Ask friends to sign up so you can discover them.'),
      );
    }

    final u = candidates[_index % candidates.length];
    final otherId = u.email;

    final areFriends = widget.social.areFriends(widget.signedInEmail, otherId);
    final hasOutgoing = widget.social.hasOutgoingRequest(widget.signedInEmail, otherId);
    final hasIncoming = widget.social.hasIncomingRequest(widget.signedInEmail, otherId);

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
                              currentUserId: widget.signedInEmail,
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
                            child: u.profileImageBytes == null
                                ? const Icon(Icons.person, size: 54)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      u.username,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      u.gender.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(u.bio.isEmpty ? 'No bio yet.' : u.bio),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _next,
                            icon: const Icon(Icons.close),
                            label: const Text('Pass'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FriendActionButton(
                            areFriends: areFriends,
                            hasOutgoing: hasOutgoing,
                            hasIncoming: hasIncoming,
                            onAdd: () => widget.social.sendRequest(
                              from: widget.signedInEmail,
                              to: otherId,
                            ),
                            onAccept: () => widget.social.acceptRequest(
                              to: widget.signedInEmail,
                              from: otherId,
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
                              currentUserId: widget.signedInEmail,
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
  }
}

class _BrowseDiscover extends StatelessWidget {
  const _BrowseDiscover({
    required this.signedInEmail,
    required this.auth,
    required this.social,
  });

  final String signedInEmail;
  final LocalAuthController auth;
  final SocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final users = auth.allUsers.where((u) => u.email != signedInEmail).toList(growable: false);
    users.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

    if (users.isEmpty) {
      return const Center(
        child: Text('No students yet. Create a second account to see Discover suggestions.'),
      );
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
              currentUserId: signedInEmail,
              user: users[index],
              social: social,
            );
          },
        );
      },
    );
  }
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({
    required this.currentUserId,
    required this.user,
    required this.social,
  });

  final String currentUserId;
  final AppUser user;
  final SocialGraphController social;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final otherId = user.email;
    final areFriends = social.areFriends(currentUserId, otherId);
    final hasOutgoing = social.hasOutgoingRequest(currentUserId, otherId);
    final hasIncoming = social.hasIncomingRequest(currentUserId, otherId);

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
                currentUserId: currentUserId,
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
                      child: user.profileImageBytes == null
                          ? const Icon(Icons.person)
                          : null,
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FriendActionButton(
                  areFriends: areFriends,
                  hasOutgoing: hasOutgoing,
                  hasIncoming: hasIncoming,
                  onAdd: () => social.sendRequest(from: currentUserId, to: otherId),
                  onAccept: () => social.acceptRequest(to: currentUserId, from: otherId),
                  dense: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
