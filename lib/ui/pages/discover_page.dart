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
  final Set<String> _swipedUids = <String>{};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(AppUser?, List<AppUser>)>(
      future: () async {
        final me = await widget.auth.publicProfileByUid(widget.signedInUid);
        final all = await widget.auth.getAllUsers();
        return (me, all);
      }(),
      builder: (context, snap) {
        if (snap.hasError) {
          return AsyncErrorView(error: snap.error!);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final me = snap.data!.$1;
        final all = snap.data!.$2;

        final myInterests = (me?.interests ?? const <String>[])
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();

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

            bool oppositeGender(AppUser u) {
              // Enforce opposite gender only for male<->female. For other values,
              // we don't filter (since there isn't a single "opposite").
              final g = me?.gender;
              if (g == Gender.male) return u.gender == Gender.female;
              if (g == Gender.female) return u.gender == Gender.male;
              return true;
            }

            final candidates = all
                .where((u) =>
                    u.uid != widget.signedInUid &&
                    !friends.contains(u.uid) &&
                    !_swipedUids.contains(u.uid) &&
                    oppositeGender(u))
                .toList(growable: false);

            // Compute mutual interests.
            final mutualByUid = <String, List<String>>{};
            int mutualCount(AppUser u) {
              if (myInterests.isEmpty) return 0;
              final theirs = u.interests
                  .map((e) => e.trim().toLowerCase())
                  .where((e) => e.isNotEmpty)
                  .toSet();
              final mutual = myInterests.intersection(theirs).toList()..sort();

              // Keep nicer display capitalization (original strings) if possible.
              final display = <String>[];
              for (final m in mutual) {
                final original = u.interests.firstWhere(
                  (x) => x.trim().toLowerCase() == m,
                  orElse: () => m,
                );
                display.add(original);
              }
              mutualByUid[u.uid] = display;
              return mutual.length;
            }

            // Sort by mutual interest count (desc). Tie-break with randomness so the deck stays fresh.
            final rnd = Random();
            candidates.sort((a, b) {
              final am = mutualCount(a);
              final bm = mutualCount(b);
              if (am != bm) return bm.compareTo(am);
              return rnd.nextBool() ? 1 : -1;
            });

            return SwipeDeck(
              users: candidates,
              mutualInterestsByUid: mutualByUid,
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
                // Immediately mark as swiped so it doesn't re-appear on rebuild.
                if (mounted) {
                  setState(() => _swipedUids.add(u.uid));
                }

                // Persist swipe decision (prevents repeats across sessions once rules allow).
                await widget.social.recordSwipe(
                  uid: widget.signedInUid,
                  otherUid: u.uid,
                  decision: action == SwipeAction.like ? SwipeDecision.like : SwipeDecision.nope,
                );

                if (action == SwipeAction.like) {
                  await widget.social.sendMatchRequest(fromUid: widget.signedInUid, toUid: u.uid);
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
