import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// UI-only auth for prototyping.
/// Replace with Firebase Auth / backend later.
class LocalAuthController extends ChangeNotifier {
  final Map<String, _AccountRecord> _accountsByEmail = {};

  /// Returns all known users (signed up in this session).
  ///
  /// This is UI-only state for prototyping. A real app would fetch this from
  /// a backend.
  List<AppUser> get allUsers => _accountsByEmail.values.map((e) => e.user).toList(growable: false);

  AppUser? userByEmail(String email) => _accountsByEmail[email.trim().toLowerCase()]?.user;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  String? signUp({
    required String email,
    required String username,
    required String password,
    required Gender gender,
    required String bio,
    required List<String> interests,
    List<int>? profileImageBytes,
  }) {
    final key = email.trim().toLowerCase();
    if (_accountsByEmail.containsKey(key)) {
      return 'Account already exists for this email.';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    final user = AppUser(
      uid: key,
      email: key,
      username: username.trim(),
      gender: gender,
      bio: bio.trim(),
      interests: interests,
      profileImageBytes: profileImageBytes,
    );

    _accountsByEmail[key] = _AccountRecord(user: user, password: password);
    _currentUser = user;
    notifyListeners();
    return null;
  }

  String? signIn({required String email, required String password}) {
    final key = email.trim().toLowerCase();
    final record = _accountsByEmail[key];
    if (record == null) return 'No account found. Please sign up.';
    if (record.password != password) return 'Incorrect password.';

    _currentUser = record.user;
    notifyListeners();
    return null;
  }

  void signOut() {
    _currentUser = null;
    notifyListeners();
  }
}

class _AccountRecord {
  const _AccountRecord({required this.user, required this.password});

  final AppUser user;
  final String password;
}
