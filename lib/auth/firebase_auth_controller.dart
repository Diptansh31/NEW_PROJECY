import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'firestore_user_repository.dart';
import '../crypto/e2ee.dart';

/// Firebase-auth backed controller.
///
/// Stores user profile (username/gender/bio/interests) in Firestore at `users/{uid}`.
class FirebaseAuthController extends ChangeNotifier {
  FirebaseAuthController({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    E2ee? e2ee,
  })  : _auth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        users = FirestoreUserRepository(firestore: firestore ?? FirebaseFirestore.instance),
        e2ee = e2ee ?? E2ee() {
    _sub = _auth.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirestoreUserRepository users;
  final E2ee e2ee;

  StreamSubscription<fb.User?>? _sub;

  fb.User? get firebaseUser => _auth.currentUser;
  bool get isSignedIn => firebaseUser != null;

  Future<AppUser?> getCurrentProfile() async {
    final u = firebaseUser;
    if (u == null) return null;

    final doc = await _db.collection('users').doc(u.uid).get();
    final data = doc.data();
    if (data == null) return null;

    return AppUser(
      uid: (data['uid'] as String?) ?? u.uid,
      email: (data['email'] as String?) ?? (u.email ?? ''),
      username: (data['username'] as String?) ?? '',
      gender: _genderFromString(data['gender'] as String?),
      bio: (data['bio'] as String?) ?? '',
      interests: (data['interests'] as List<dynamic>?)?.cast<String>() ?? const <String>[],
      profileImageBytes: (data['profileImageB64'] as String?) == null
          ? null
          : base64Decode(data['profileImageB64'] as String),
    );
  }

  Future<List<AppUser>> getAllUsers() => users.fetchAllUsers();
  Future<AppUser?> getUserByEmail(String email) => users.fetchUserByEmail(email);

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      await ensurePublicKeyPublished();
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp({
    required String email,
    required String username,
    required String password,
    required Gender gender,
    required String bio,
    required List<String> interests,
    List<int>? profileImageBytes,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = cred.user!.uid;
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': email.trim().toLowerCase(),
        'username': username.trim(),
        'gender': gender.name,
        'bio': bio.trim(),
        'interests': interests,
        'profileImageB64': profileImageBytes == null ? null : base64Encode(profileImageBytes),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await ensurePublicKeyPublished();
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> ensurePublicKeyPublished() async {
    final u = firebaseUser;
    if (u == null) return;

    final keyPair = await e2ee.getOrCreateIdentityKeyPair(uid: u.uid);
    final publicKeyB64 = await e2ee.publicKeyB64(keyPair);

    await _db.collection('users').doc(u.uid).set({
      'publicKeyX25519B64': publicKeyB64,
      'publicKeyUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> publicKeyForUid(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    return data?['publicKeyX25519B64'] as String?;
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
