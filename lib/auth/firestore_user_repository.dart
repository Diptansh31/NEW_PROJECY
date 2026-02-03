import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

class FirestoreUserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Fetch all user profiles.
  Future<List<AppUser>> fetchAllUsers() async {
    final snap = await _db.collection('users').get();
    return snap.docs.map(_fromDoc).toList(growable: false);
  }

  Future<AppUser?> fetchUserByEmail(String email) async {
    final e = email.trim().toLowerCase();
    final snap = await _db.collection('users').where('email', isEqualTo: e).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return _fromDoc(snap.docs.first);
  }

  static AppUser _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AppUser(
      uid: (data['uid'] as String?) ?? doc.id,
      email: (data['email'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      gender: _genderFromString(data['gender'] as String?),
      bio: (data['bio'] as String?) ?? '',
      interests: (data['interests'] as List<dynamic>?)?.cast<String>() ?? const <String>[],
      profileImageBytes: (data['profileImageB64'] as String?) == null
          ? null
          : base64Decode(data['profileImageB64'] as String),
    );
  }

  static Gender _genderFromString(String? s) {
    switch (s) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'nonBinary':
        return Gender.nonBinary;
      case 'preferNotToSay':
      default:
        return Gender.preferNotToSay;
    }
  }
}
