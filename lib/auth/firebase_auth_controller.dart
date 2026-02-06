import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'firestore_user_repository.dart';
import '../crypto/e2ee.dart';
import '../crypto/key_backup.dart';

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

    // Avoid overwriting an existing public key (would break decryption of old messages).
    final existing = await _db.collection('users').doc(u.uid).get();
    final existingKey = (existing.data() ?? const <String, dynamic>{})['publicKeyX25519B64'] as String?;

    if (existingKey == null) {
      await _db.collection('users').doc(u.uid).set({
        'publicKeyX25519B64': publicKeyB64,
        'publicKeyUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<String?> publicKeyForUid(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    return data?['publicKeyX25519B64'] as String?;
  }

  AppUser _userFromMap(String fallbackUid, Map<String, dynamic> data) {
    return AppUser(
      uid: (data['uid'] as String?) ?? fallbackUid,
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

  Future<AppUser?> publicProfileByUid(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return _userFromMap(uid, data);
  }

  Stream<AppUser?> profileStreamByUid(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return _userFromMap(uid, data);
    });
  }

  /// Stream the uid of the current user's active match (if any).
  ///
  /// Expected field: users/{uid}.activeMatchWithUid (string|null)
  Stream<String?> activeMatchWithUidStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      return data?['activeMatchWithUid'] as String?;
    });
  }

  Stream<String?> activeCoupleThreadIdStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      return data?['activeCoupleThreadId'] as String?;
    });
  }

  Future<void> updateProfileImage({required String uid, required List<int> bytes}) async {
    await _db.collection('users').doc(uid).set({
      'profileImageB64': base64Encode(bytes),
      'profileImageUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Updates the user's profile information.
  Future<void> updateProfile({
    required String uid,
    String? username,
    Gender? gender,
    String? bio,
    List<String>? interests,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (username != null) updates['username'] = username.trim();
    if (gender != null) updates['gender'] = gender.name;
    if (bio != null) updates['bio'] = bio.trim();
    if (interests != null) updates['interests'] = interests;

    await _db.collection('users').doc(uid).set(updates, SetOptions(merge: true));
  }

  /// Encrypted backup of the identity key seed to Firestore.
  ///
  /// Stores at: users/{uid}/key_backups/identity
  Future<void> backupIdentityKey({required String passphrase}) async {
    final u = firebaseUser;
    if (u == null) throw StateError('Not signed in');

    // Ensure we have a seed.
    await e2ee.getOrCreateIdentityKeyPair(uid: u.uid);
    final seed = await e2ee.readIdentitySeed(uid: u.uid);
    if (seed == null) throw StateError('Identity seed missing');

    final blob = await KeyBackup.encryptSeed(seed32: seed, passphrase: passphrase);

    await _db.collection('users').doc(u.uid).collection('key_backups').doc('identity').set({
      ...blob,
      'uid': u.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Restore identity seed from Firestore backup into secure storage.
  ///
  /// After restore, we verify the derived public key matches the published one.
  Future<void> restoreIdentityKey({required String passphrase}) async {
    final u = firebaseUser;
    if (u == null) throw StateError('Not signed in');

    final doc = await _db.collection('users').doc(u.uid).collection('key_backups').doc('identity').get();
    final data = doc.data();
    if (data == null) throw StateError('No key backup found');

    final seed = await KeyBackup.decryptSeed(backup: data, passphrase: passphrase);
    await e2ee.writeIdentitySeed(uid: u.uid, seed32: seed);

    // Verify public key consistency.
    final kp = await e2ee.getOrCreateIdentityKeyPair(uid: u.uid);
    final pub = await e2ee.publicKeyB64(kp);
    final userDoc = await _db.collection('users').doc(u.uid).get();
    final existingKey = (userDoc.data() ?? const <String, dynamic>{})['publicKeyX25519B64'] as String?;

    if (existingKey != null && existingKey != pub) {
      throw StateError(
        'Restored key does not match the key previously published. Old chats may be undecryptable on this device.',
      );
    }

    // Publish if missing.
    await ensurePublicKeyPublished();
  }

  /// Fetch multiple user profiles by uid. Firestore `whereIn` supports up to 10.
  Future<List<AppUser>> publicProfilesByUids(List<String> uids) async {
    if (uids.isEmpty) return const <AppUser>[];

    final out = <AppUser>[];
    for (var i = 0; i < uids.length; i += 10) {
      final chunk = uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10);
      final snap = await _db.collection('users').where('uid', whereIn: chunk).get();
      for (final d in snap.docs) {
        final data = d.data();
        out.add(_userFromMap(d.id, data));
      }
    }

    return out;
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
