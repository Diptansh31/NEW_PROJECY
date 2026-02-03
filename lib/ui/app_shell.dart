import 'package:flutter/material.dart';

import 'pages/campus_page.dart';
import 'pages/discover_page.dart';
import 'pages/feed_page.dart';
import 'pages/messages_page.dart';
import 'pages/profile_page.dart';

import '../auth/firebase_auth_controller.dart';
import '../social/social_graph_controller.dart';
import '../chat/firestore_chat_controller.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.signedInUid,
    required this.signedInEmail,
    required this.onSignOut,
    required this.auth,
    required this.social,
    required this.chat,
  });

  final String signedInUid;
  final String signedInEmail;
  final VoidCallback onSignOut;
  final FirebaseAuthController auth;
  final SocialGraphController social;
  final FirestoreChatController chat;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = <_DestinationSpec>[
    _DestinationSpec('Feed', Icons.home_outlined, Icons.home),
    _DestinationSpec('Discover', Icons.explore_outlined, Icons.explore),
    _DestinationSpec('Messages', Icons.chat_bubble_outline, Icons.chat_bubble),
    _DestinationSpec('Campus', Icons.groups_outlined, Icons.groups),
    _DestinationSpec('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1024;

    final page = _pageForIndex(_index);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _LeftRail(
              selectedIndex: _index,
              onSelected: (i) => setState(() => _index = i),
              email: widget.signedInEmail,
              onSignOut: widget.onSignOut,
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    children: [
                      Expanded(flex: 7, child: page),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 3,
                        child: _RightSidebar(
                          signedInEmail: widget.signedInEmail,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('vibeU'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }

  Widget _pageForIndex(int index) {
    switch (index) {
      case 0:
        return const FeedPage();
      case 1:
        return DiscoverPage(
          signedInEmail: widget.signedInEmail,
          auth: widget.auth,
          social: widget.social,
        );
      case 2:
        return MessagesPage(
          signedInUid: widget.signedInUid,
          signedInEmail: widget.signedInEmail,
          auth: widget.auth,
          social: widget.social,
          chat: widget.chat,
        );
      case 3:
        return const CampusPage();
      case 4:
        return ProfilePage(
          signedInEmail: widget.signedInEmail,
          onSignOut: widget.onSignOut,
        );
      default:
        return const FeedPage();
    }
  }
}

class _DestinationSpec {
  const _DestinationSpec(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _LeftRail extends StatelessWidget {
  const _LeftRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.email,
    required this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'vibeU',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Feed'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore),
                    label: Text('Discover'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon: Icon(Icons.chat_bubble),
                    label: Text('Messages'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: Text('Campus'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Profile'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightSidebar extends StatelessWidget {
  const _RightSidebar({required this.signedInEmail});

  final String signedInEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Suggestions',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const _SuggestionTile(name: 'Ananya • CSE', subtitle: '2nd year • Music, travel'),
          const _SuggestionTile(name: 'Sahil • Mechanical', subtitle: '3rd year • Gym, anime'),
          const _SuggestionTile(name: 'Riya • IT', subtitle: '1st year • Photography'),
          const SizedBox(height: 24),
          Text(
            'Upcoming on campus',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Cultural Night',
            subtitle: 'Fri 7:00 PM • Auditorium',
            icon: Icons.celebration,
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Hackathon mixer',
            subtitle: 'Sat 5:00 PM • LT-2',
            icon: Icons.code,
          ),
          const SizedBox(height: 24),
          Text(
            'Privacy',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'vibeU is campus-only. Keep your profile respectful and safe.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: FilledButton.tonal(
        onPressed: null,
        child: const Text('Connect'),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
