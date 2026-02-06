import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'pages/discover_page.dart';
import 'pages/feed_page.dart';
import 'pages/messages_page.dart';
import 'pages/profile_page.dart';
import 'pages/notifications_page.dart';
import 'pages/voice_call_page.dart';

import '../auth/firebase_auth_controller.dart';
import '../call/call_models.dart';
import '../call/call_notification_service.dart';
import '../call/fcm_call_service.dart';
import '../call/firestore_call_signaling.dart';
import '../call/voice_call_controller.dart';
import '../chat/firestore_chat_models.dart' show CallMessageStatus;
import '../social/firestore_social_graph_controller.dart';
import '../chat/firestore_chat_controller.dart';
import '../notifications/firestore_notifications_controller.dart';
import '../posts/firestore_posts_controller.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.signedInUid,
    required this.signedInEmail,
    required this.onSignOut,
    required this.auth,
    required this.social,
    required this.chat,
    required this.notifications,
    required this.posts,
  });

  final String signedInUid;
  final String signedInEmail;
  final VoidCallback onSignOut;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;
  final FirestoreChatController chat;
  final FirestoreNotificationsController notifications;
  final FirestorePostsController posts;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  StreamSubscription? _threadsWarmSub;
  StreamSubscription<List<VoiceCall>>? _incomingCallsSub;
  StreamSubscription<RemoteMessage>? _fcmForegroundSub;

  // Streams for unread indicators
  late final Stream<bool> _hasUnreadMessagesStream;
  late final Stream<int> _unreadNotificationsStream;

  // Voice call support
  late final VoiceCallController _callController;
  late final FirestoreCallSignaling _callSignaling;
  bool _isHandlingCall = false;

  @override
  void initState() {
    super.initState();
    // Warm chat threads so Chats tab feels instant.
    _threadsWarmSub = widget.chat.threadsStream(myUid: widget.signedInUid).listen((_) {});
    
    // Initialize unread streams
    _hasUnreadMessagesStream = widget.chat.hasUnreadMessagesStream(myUid: widget.signedInUid);
    _unreadNotificationsStream = widget.notifications.unreadCountStream(uid: widget.signedInUid);

    // Initialize voice call controller
    _callSignaling = FirestoreCallSignaling();
    _callController = VoiceCallController(signaling: _callSignaling);

    // Set up callback to save call messages to chat
    _callController.onCallEnded = _onCallEnded;

    // Initialize notifications and FCM
    _initializeCallNotifications();

    // Listen for incoming calls via Firestore (when app is in foreground)
    _incomingCallsSub = _callSignaling
        .incomingCallsStream(widget.signedInUid)
        .listen(_handleIncomingCalls);
  }

  Future<void> _initializeCallNotifications() async {
    // Initialize call notification service
    await CallNotificationService.instance.initialize();

    // Set up notification action callbacks
    CallNotificationService.instance.onCallAccepted = _acceptCallFromNotification;
    CallNotificationService.instance.onCallDeclined = _declineCallFromNotification;

    // Initialize FCM service and save token
    await FcmCallService.instance.initialize(widget.signedInUid);

    // Listen for foreground FCM messages
    _fcmForegroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('AppShell: Foreground FCM message: ${message.data}');

    if (message.data['type'] == 'incoming_call') {
      final callId = message.data['callId'] as String?;
      final callerName = message.data['callerName'] as String? ?? 'Unknown';
      final callerUid = message.data['callerUid'] as String? ?? '';

      if (callId != null && !_isHandlingCall) {
        // Show incoming call notification with ringtone
        await CallNotificationService.instance.showIncomingCall(
          callId: callId,
          callerName: callerName,
          callerUid: callerUid,
        );
      }
    } else if (message.data['type'] == 'call_ended') {
      final callId = message.data['callId'] as String?;
      if (callId != null) {
        await CallNotificationService.instance.hideIncomingCall(callId);
      }
    }
  }

  Future<void> _acceptCallFromNotification(String callId, String callerUid) async {
    if (_isHandlingCall) return;
    _isHandlingCall = true;

    // Get caller info
    final callerUser = await widget.auth.publicProfileByUid(callerUid);
    final currentUser = await widget.auth.publicProfileByUid(widget.signedInUid);

    if (callerUser == null || currentUser == null || !mounted) {
      _isHandlingCall = false;
      return;
    }

    // Mark call as connected
    await CallNotificationService.instance.setCallConnected(callId);

    // Navigate to call page
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VoiceCallPage(
            currentUser: currentUser,
            otherUser: callerUser,
            callController: _callController,
            isIncoming: true,
            incomingCallId: callId,
          ),
        ),
      );
    }

    _isHandlingCall = false;
  }

  Future<void> _declineCallFromNotification(String callId, String callerUid) async {
    await _callController.rejectCall(callId);
    await CallNotificationService.instance.hideIncomingCall(callId);
  }

  Future<void> _handleIncomingCalls(List<VoiceCall> calls) async {
    if (calls.isEmpty || _isHandlingCall) return;
    if (_callController.state != LocalCallState.idle) return;

    final call = calls.first;

    // Get caller info
    final callerUser = await widget.auth.publicProfileByUid(call.callerUid);
    if (callerUser == null || !mounted) return;

    // Show incoming call notification with ringtone and vibration
    await CallNotificationService.instance.showIncomingCall(
      callId: call.id,
      callerName: callerUser.username,
      callerUid: call.callerUid,
    );
  }

  /// Called when a voice call ends. Saves the call as a message in the chat thread.
  Future<void> _onCallEnded(
    String callerUid,
    String calleeUid,
    bool wasConnected,
    int? durationSeconds,
    CallEndReason reason,
  ) async {
    try {
      // Get or create thread between the two users
      final currentUserProfile = await widget.auth.publicProfileByUid(widget.signedInUid);
      final otherUid = callerUid == widget.signedInUid ? calleeUid : callerUid;
      final otherUserProfile = await widget.auth.publicProfileByUid(otherUid);

      if (currentUserProfile == null || otherUserProfile == null) {
        debugPrint('AppShell: Could not get user profiles for call message');
        return;
      }

      final thread = await widget.chat.getOrCreateThread(
        myUid: widget.signedInUid,
        myEmail: currentUserProfile.email,
        otherUid: otherUid,
        otherEmail: otherUserProfile.email,
      );

      // Map CallEndReason to CallMessageStatus
      CallMessageStatus status;
      switch (reason) {
        case CallEndReason.completed:
          status = CallMessageStatus.completed;
          break;
        case CallEndReason.missed:
          status = CallMessageStatus.missed;
          break;
        case CallEndReason.declined:
          status = CallMessageStatus.declined;
          break;
        case CallEndReason.cancelled:
        case CallEndReason.failed:
          status = CallMessageStatus.cancelled;
          break;
      }

      // Save call message to chat
      // fromUid is the caller (person who initiated the call)
      await widget.chat.sendCallMessage(
        threadId: thread.id,
        fromUid: callerUid,
        toUid: calleeUid,
        status: status,
        durationSeconds: wasConnected ? durationSeconds : null,
      );

      debugPrint('AppShell: Call message saved - status: $status, duration: $durationSeconds');
    } catch (e) {
      debugPrint('AppShell: Error saving call message: $e');
    }
  }

  @override
  void dispose() {
    _threadsWarmSub?.cancel();
    _incomingCallsSub?.cancel();
    _fcmForegroundSub?.cancel();
    _callController.dispose();
    CallNotificationService.instance.dispose();
    super.dispose();
  }

  // Tinder-like nav: Match (swipe) first, then Feed, Chats, Profile.
  static const _destinations = <_DestinationSpec>[
    _DestinationSpec('Match', Icons.local_fire_department_outlined, Icons.local_fire_department),
    _DestinationSpec('Feed', Icons.grid_view_outlined, Icons.grid_view),
    _DestinationSpec('Chats', Icons.chat_bubble_outline, Icons.chat_bubble),
    _DestinationSpec('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              signedInUid: widget.signedInUid,
              auth: widget.auth,
              notifications: widget.notifications,
              hasUnreadMessagesStream: _hasUnreadMessagesStream,
              unreadNotificationsStream: _unreadNotificationsStream,
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

    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark 
            ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'vibeU',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<int>(
            stream: _unreadNotificationsStream,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationsPage(
                          signedInUid: widget.signedInUid,
                          auth: widget.auth,
                          notifications: widget.notifications,
                        ),
                      ),
                    );
                  },
                  icon: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_outlined,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                                width: 2,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: page,
      bottomNavigationBar: StreamBuilder<bool>(
        stream: _hasUnreadMessagesStream,
        builder: (context, snapshot) {
          final hasUnreadMessages = snapshot.data ?? false;
          return Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (int i = 0; i < _destinations.length; i++)
                      _buildNavItem(
                        index: i,
                        icon: _destinations[i].icon,
                        selectedIcon: _destinations[i].selectedIcon,
                        label: _destinations[i].label,
                        isSelected: _index == i,
                        showBadge: i == 2 && hasUnreadMessages,
                        theme: theme,
                        isDark: isDark,
                        onTap: () => setState(() => _index = i),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required bool showBadge,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 24,
                ),
                if (showBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pageForIndex(int index) {
    switch (index) {
      case 0:
        return DiscoverPage(
          signedInUid: widget.signedInUid,
          signedInEmail: widget.signedInEmail,
          auth: widget.auth,
          social: widget.social,
        );
      case 1:
        return FeedPage(
          currentUid: widget.signedInUid,
          posts: widget.posts,
        );
      case 2:
        return MessagesPage(
          signedInUid: widget.signedInUid,
          signedInEmail: widget.signedInEmail,
          auth: widget.auth,
          social: widget.social,
          chat: widget.chat,
          notifications: widget.notifications,
          callController: _callController,
        );
      case 3:
        return ProfilePage(
          signedInUid: widget.signedInUid,
          signedInEmail: widget.signedInEmail,
          onSignOut: widget.onSignOut,
          auth: widget.auth,
          social: widget.social,
          posts: widget.posts,
        );
      default:
        return DiscoverPage(
          signedInUid: widget.signedInUid,
          signedInEmail: widget.signedInEmail,
          auth: widget.auth,
          social: widget.social,
        );
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
    required this.signedInUid,
    required this.auth,
    required this.notifications,
    required this.hasUnreadMessagesStream,
    required this.unreadNotificationsStream,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String email;
  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreNotificationsController notifications;
  final Stream<bool> hasUnreadMessagesStream;
  final Stream<int> unreadNotificationsStream;

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
              child: StreamBuilder<bool>(
                stream: hasUnreadMessagesStream,
                builder: (context, snapshot) {
                  final hasUnreadMessages = snapshot.data ?? false;
                  return NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelected,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.local_fire_department_outlined),
                        selectedIcon: Icon(Icons.local_fire_department),
                        label: Text('Match'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.grid_view_outlined),
                        selectedIcon: Icon(Icons.grid_view),
                        label: Text('Feed'),
                      ),
                      NavigationRailDestination(
                        icon: _BadgeIcon(
                          icon: Icons.chat_bubble_outline,
                          showBadge: hasUnreadMessages,
                        ),
                        selectedIcon: _BadgeIcon(
                          icon: Icons.chat_bubble,
                          showBadge: hasUnreadMessages,
                        ),
                        label: const Text('Chats'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('Profile'),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<int>(
                stream: unreadNotificationsStream,
                builder: (context, snapshot) {
                  final hasUnread = (snapshot.data ?? 0) > 0;
                  return OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationsPage(
                            signedInUid: signedInUid,
                            auth: auth,
                            notifications: notifications,
                          ),
                        ),
                      );
                    },
                    icon: _BadgeIcon(
                      icon: Icons.favorite_border,
                      showBadge: hasUnread,
                    ),
                    label: const Text('Notifications'),
                  );
                },
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

/// A widget that shows an icon with an optional notification dot badge.
/// Similar to Instagram's unread indicator.
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.showBadge,
  });

  final IconData icon;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    if (!showBadge) {
      return Icon(icon);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
