import 'dart:math';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../../social/local_swipe_store.dart';
import '../widgets/async_error_view.dart';
import 'swipe_deck.dart';
import 'match_requests_page.dart';
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
  final _localSwipes = LocalSwipeStore();
  final Set<String> _swipedUids = <String>{};

  @override
  void initState() {
    super.initState();
    // Load local exclusions so users don't reappear even if Firestore writes fail.
    _localSwipes.loadExcludedUids(widget.signedInUid).then((set) {
      if (!mounted) return;
      setState(() => _swipedUids.addAll(set));
    });
  }

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

            return Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        Text(
                          'Match',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Match requests',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MatchRequestsPage(
                                  currentUid: widget.signedInUid,
                                  auth: widget.auth,
                                  social: widget.social,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.inbox_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SwipeDeck(
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

                // For friend/match, run the network write first.
                // If anything fails, throw so SwipeDeck can rollback the card.
                if (action == SwipeAction.friend) {
                  await widget.social.sendRequest(fromUid: widget.signedInUid, toUid: u.uid);
                } else if (action == SwipeAction.match) {
                  await widget.social.sendMatchRequest(fromUid: widget.signedInUid, toUid: u.uid);
                }

                // Persist locally (reliable) + best-effort Firestore write.
                await _localSwipes.addExcluded(widget.signedInUid, u.uid);

                try {
                  await widget.social.recordSwipe(
                    uid: widget.signedInUid,
                    otherUid: u.uid,
                    decision: switch (action) {
                      SwipeAction.match => SwipeDecision.match,
                      SwipeAction.friend => SwipeDecision.friend,
                      SwipeAction.skip => SwipeDecision.skip,
                    },
                  );
                } catch (_) {
                  // Ignore: local store already ensures it won't reappear.
                }
                    },
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

// Browse mode removed: app is now swipe-first (Tinder-style).
