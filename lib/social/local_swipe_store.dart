import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local persistence for swiped/handled profiles.
///
/// This is a fallback so the Discover deck can permanently hide profiles even if
/// Firestore writes are blocked by rules/offline.
class LocalSwipeStore {
  LocalSwipeStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String uid) => 'swipes_excluded_$uid';

  Future<Set<String>> loadExcludedUids(String uid) async {
    final raw = await _storage.read(key: _key(uid));
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  Future<void> addExcluded(String uid, String otherUid) async {
    final set = await loadExcludedUids(uid);
    set.add(otherUid);
    await _storage.write(key: _key(uid), value: jsonEncode(set.toList()..sort()));
  }

  Future<void> removeExcluded(String uid, String otherUid) async {
    final set = await loadExcludedUids(uid);
    set.remove(otherUid);
    await _storage.write(key: _key(uid), value: jsonEncode(set.toList()..sort()));
  }
}
