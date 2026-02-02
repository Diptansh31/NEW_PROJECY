import 'package:flutter/foundation.dart';

/// In-memory friend request + friends graph for prototyping.
///
/// Keys are user ids (currently email).
class SocialGraphController extends ChangeNotifier {
  final Map<String, Set<String>> _friendsByUser = <String, Set<String>>{};
  final Map<String, Set<String>> _outgoingRequestsByUser = <String, Set<String>>{};
  final Map<String, Set<String>> _incomingRequestsByUser = <String, Set<String>>{};

  Set<String> _friendsOf(String userId) =>
      _friendsByUser.putIfAbsent(userId, () => <String>{});

  Set<String> _outgoingOf(String userId) =>
      _outgoingRequestsByUser.putIfAbsent(userId, () => <String>{});

  Set<String> _incomingOf(String userId) =>
      _incomingRequestsByUser.putIfAbsent(userId, () => <String>{});

  bool areFriends(String a, String b) => _friendsOf(a).contains(b);

  bool hasOutgoingRequest(String from, String to) => _outgoingOf(from).contains(to);

  bool hasIncomingRequest(String to, String from) => _incomingOf(to).contains(from);

  /// Send a friend request from [from] to [to].
  /// No-op if already friends or if a request already exists in either direction.
  void sendRequest({required String from, required String to}) {
    if (from == to) return;
    if (areFriends(from, to)) return;

    // If the other person already requested you, accepting makes more sense.
    if (hasIncomingRequest(from, to)) return;
    if (hasOutgoingRequest(from, to)) return;

    _outgoingOf(from).add(to);
    _incomingOf(to).add(from);
    notifyListeners();
  }

  void cancelOutgoingRequest({required String from, required String to}) {
    if (_outgoingOf(from).remove(to)) {
      _incomingOf(to).remove(from);
      notifyListeners();
    }
  }

  void declineIncomingRequest({required String to, required String from}) {
    if (_incomingOf(to).remove(from)) {
      _outgoingOf(from).remove(to);
      notifyListeners();
    }
  }

  /// Accept an incoming request (from [from] -> [to]).
  void acceptRequest({required String to, required String from}) {
    if (!hasIncomingRequest(to, from)) return;

    _incomingOf(to).remove(from);
    _outgoingOf(from).remove(to);

    _friendsOf(to).add(from);
    _friendsOf(from).add(to);

    notifyListeners();
  }

  /// Remove friendship (unfriend).
  void removeFriend({required String a, required String b}) {
    final removedA = _friendsOf(a).remove(b);
    final removedB = _friendsOf(b).remove(a);
    if (removedA || removedB) notifyListeners();
  }
}
