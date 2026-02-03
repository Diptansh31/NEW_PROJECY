import 'dart:math';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_error_view.dart';
import 'swipe_deck.dart';
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
    // Tinder-like experience: full-screen swipe deck.
    return _SwipeDiscover(
      signedInUid: signedInUid,
      auth: auth,
      social: social,
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
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUser>>(
      future: widget.auth.getAllUsers(),
      builder: (context, userSnap) {
        if (userSnap.hasError) {
          return AsyncErrorView(error: userSnap.error!);
        }
        if (userSnap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = userSnap.data ?? const <AppUser>[];

        return StreamBuilder<Set<String>>(
          stream: widget.social.friendsStream(uid: widget.signedInUid),
          builder: (context, friendsSnap) {
            if (friendsSnap.hasError) {
              return AsyncErrorView(error: friendsSnap.error!);
            }
            if (!friendsSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final friends = friendsSnap.data!;
            final candidates = all
                .where((u) => u.uid != widget.signedInUid && !friends.contains(u.uid))
                .toList(growable: false);

            // Add a bit of randomness so it feels more like a matching deck.
            candidates.shuffle(Random());

            return SwipeDeck(
              users: candidates,
              onViewProfile: (u) {
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
              onSwipe: (u, action) async {
                if (action == SwipeAction.like) {
                  await widget.social.sendRequest(fromUid: widget.signedInUid, toUid: u.uid);
                }
                // action == nope: no-op for now
              },
            );
          },
        );
      },
    );
  }
}

// Browse mode removed: app is now swipe-first (Tinder-style).
