import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';

enum SwipeAction { like, nope }

typedef OnSwipe = Future<void> Function(AppUser user, SwipeAction action);

typedef OnViewProfile = void Function(AppUser user);

class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.users,
    required this.onSwipe,
    required this.onViewProfile,
    this.mutualInterestsByUid = const <String, List<String>>{},
  });

  final List<AppUser> users;

  /// Map candidate uid -> mutual interests with current user.
  final Map<String, List<String>> mutualInterestsByUid;

  final OnSwipe onSwipe;
  final OnViewProfile onViewProfile;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck> {
  late List<AppUser> _queue;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _queue = List.of(widget.users);
  }

  @override
  void didUpdateWidget(covariant SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.users, widget.users)) {
      // Replace the queue with the latest filtered/sorted list from parent.
      _queue = List.of(widget.users);
    }
  }

  AppUser? get _current => _queue.isEmpty ? null : _queue.first;

  void _removeCurrent() {
    if (!mounted) return;
    if (_queue.isEmpty) return;
    setState(() {
      _queue.removeAt(0);
    });
  }

  void _handleSwipe(AppUser u, SwipeAction action) {
    if (_busy) return;

    // Optimistic UI: remove immediately for snappy UX.
    _removeCurrent();

    // Best-effort background write. Do not block the UI.
    setState(() => _busy = true);
    widget.onSwipe(u, action).catchError((_) {}).whenComplete(() {
      if (mounted) setState(() => _busy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = _current;

    if (u == null) {
      return Center(
        child: Text(
          'No one new right now',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final mutual = widget.mutualInterestsByUid[u.uid] ?? const <String>[];

    return Stack(
      children: [
        // Background card peek (next user)
        if (_queue.length > 1)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              child: Transform.scale(
                scale: 0.97,
                child: _ProfileCard(
                  user: _queue[1],
                  mutualInterests: widget.mutualInterestsByUid[_queue[1].uid] ?? const <String>[],
                  onTap: () => widget.onViewProfile(_queue[1]),
                ),
              ),
            ),
          ),

        // Top draggable card
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            child: _SwipeableCard(
              user: u,
              mutualInterests: mutual,
              enabled: !_busy,
              onNope: () => _handleSwipe(u, SwipeAction.nope),
              onLike: () => _handleSwipe(u, SwipeAction.like),
              onTap: () => widget.onViewProfile(u),
            ),
          ),
        ),

        // Action buttons
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionCircle(
                  tooltip: 'Nope',
                  icon: Icons.close,
                  color: theme.colorScheme.error,
                  onPressed: _busy ? null : () => _handleSwipe(u, SwipeAction.nope),
                ),
                const SizedBox(width: 22),
                _ActionCircle(
                  tooltip: 'Like',
                  icon: Icons.favorite,
                  color: theme.colorScheme.secondary,
                  onPressed: _busy ? null : () => _handleSwipe(u, SwipeAction.like),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        iconSize: 30,
      ),
    );
  }
}

class _SwipeableCard extends StatefulWidget {
  const _SwipeableCard({
    required this.user,
    required this.mutualInterests,
    required this.enabled,
    required this.onNope,
    required this.onLike,
    required this.onTap,
  });

  final AppUser user;
  final List<String> mutualInterests;
  final bool enabled;
  final VoidCallback onNope;
  final VoidCallback onLike;
  final VoidCallback onTap;

  @override
  State<_SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<_SwipeableCard> {
  Offset _drag = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dx = _drag.dx;
    final rotation = (dx / size.width) * 0.25;

    final label = dx.abs() < 18
        ? null
        : dx > 0
            ? _SwipeLabel.like
            : _SwipeLabel.nope;

    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: widget.enabled
          ? (d) => setState(() => _drag += d.delta)
          : null,
      onPanEnd: widget.enabled
          ? (d) {
              final threshold = size.width * 0.22;
              if (_drag.dx > threshold) {
                widget.onLike();
              } else if (_drag.dx < -threshold) {
                widget.onNope();
              }
              setState(() => _drag = Offset.zero);
            }
          : null,
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(
          angle: rotation,
          child: _ProfileCard(
            user: widget.user,
            mutualInterests: widget.mutualInterests,
            overlayLabel: label,
          ),
        ),
      ),
    );
  }
}

enum _SwipeLabel { like, nope }

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.mutualInterests,
    this.overlayLabel,
    this.onTap,
  });

  final AppUser user;
  final List<String> mutualInterests;
  final _SwipeLabel? overlayLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final image = user.profileImageBytes == null
        ? null
        : MemoryImage(Uint8List.fromList(user.profileImageBytes!));

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            if (image != null)
              Image(image: image, fit: BoxFit.cover)
            else
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.person, size: 88)),
              ),

            // Gradient for text readability
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x22000000),
                    Color(0x00000000),
                    Color(0xAA000000),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            // Like/Nope overlay label
            if (overlayLabel != null)
              Positioned(
                top: 22,
                left: overlayLabel == _SwipeLabel.like ? 22 : null,
                right: overlayLabel == _SwipeLabel.nope ? 22 : null,
                child: Transform.rotate(
                  angle: overlayLabel == _SwipeLabel.like ? -0.18 : 0.18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        width: 3,
                        color: overlayLabel == _SwipeLabel.like
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.error,
                      ),
                    ),
                    child: Text(
                      overlayLabel == _SwipeLabel.like ? 'LIKE' : 'NOPE',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: overlayLabel == _SwipeLabel.like
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom profile summary
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.bio.isEmpty ? user.gender.label : user.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92)),
                  ),
                  const SizedBox(height: 8),
                  if (mutualInterests.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Shared: ${mutualInterests.take(3).join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(user.gender.label),
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        labelStyle: const TextStyle(color: Colors.white),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      for (final i in user.interests.take(3))
                        Chip(
                          label: Text(i),
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          labelStyle: const TextStyle(color: Colors.white),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
