import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../auth/firebase_auth_controller.dart';
import '../crypto/e2ee.dart';
import 'firestore_chat_models.dart';

/// Firestore-backed chat with client-side encryption.
///
/// Firestore schema:
/// threads/{threadId}:
///   userAUid, userBUid, userAEmail, userBEmail, updatedAt
/// threads/{threadId}/messages/{messageId}:
///   fromUid, toUid, ciphertextB64, nonceB64, macB64, sentAt
class FirestoreChatController extends ChangeNotifier {
  FirestoreChatController({
    required this.auth,
    FirebaseFirestore? firestore,
    E2ee? e2ee,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _e2ee = e2ee ?? E2ee();

  final FirebaseAuthController auth;
  final FirebaseFirestore _db;
  final E2ee _e2ee;

  String _threadIdForUids(String a, String b) {
    final aa = a.compareTo(b) <= 0 ? a : b;
    final bb = a.compareTo(b) <= 0 ? b : a;
    return '$aa|$bb';
  }

  Future<FirestoreChatThread> getOrCreateThread({
    required String myUid,
    required String myEmail,
    required String otherUid,
    required String otherEmail,
  }) async {
    final id = _threadIdForUids(myUid, otherUid);
    final doc = _db.collection('threads').doc(id);

    await doc.set({
      'userAUid': myUid.compareTo(otherUid) <= 0 ? myUid : otherUid,
      'userBUid': myUid.compareTo(otherUid) <= 0 ? otherUid : myUid,
      'userAEmail': myUid.compareTo(otherUid) <= 0 ? myEmail : otherEmail,
      'userBEmail': myUid.compareTo(otherUid) <= 0 ? otherEmail : myEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final snap = await doc.get();
    final data = snap.data() as Map<String, dynamic>;

    return FirestoreChatThread(
      id: id,
      userAUid: data['userAUid'] as String,
      userBUid: data['userBUid'] as String,
      userAEmail: data['userAEmail'] as String,
      userBEmail: data['userBEmail'] as String,
      lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Stream<List<FirestoreChatThread>> threadsStream({required String myUid}) {
    // Query for userAUid==myUid OR userBUid==myUid isn't directly possible without
    // composite indexing tricks; keep it simple by merging two streams.
    final a = _db.collection('threads').where('userAUid', isEqualTo: myUid).snapshots();
    final b = _db.collection('threads').where('userBUid', isEqualTo: myUid).snapshots();

    final controller = StreamController<List<FirestoreChatThread>>();

    QuerySnapshot<Map<String, dynamic>>? lastA;
    QuerySnapshot<Map<String, dynamic>>? lastB;

    void emit() {
      if (lastA == null || lastB == null) return;
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[...lastA!.docs, ...lastB!.docs];

      // Deduplicate by id.
      final byId = <String, FirestoreChatThread>{};
      for (final d in docs) {
        final data = d.data();
        byId[d.id] = FirestoreChatThread(
          id: d.id,
          userAUid: data['userAUid'] as String,
          userBUid: data['userBUid'] as String,
          userAEmail: data['userAEmail'] as String,
          userBEmail: data['userBEmail'] as String,
          lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      }

      final threads = byId.values.toList(growable: false);
      threads.sort((x, y) => (y.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(x.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

      controller.add(threads);
    }

    late final StreamSubscription subA;
    late final StreamSubscription subB;

    subA = a.listen((snap) {
      lastA = snap;
      emit();
    }, onError: controller.addError);

    subB = b.listen((snap) {
      lastB = snap;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Stream<List<FirestoreEncryptedMessage>> encryptedMessagesStream({required String threadId}) {
    return _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FirestoreEncryptedMessage.fromDoc(threadId: threadId, doc: d)).toList());
  }

  Future<String> sendEncryptedMessage({
    required String threadId,
    required String fromUid,
    required String fromEmail,
    required String toUid,
    required String toEmail,
    required String plaintext,
  }) async {
    final meKeyPair = await _e2ee.getOrCreateIdentityKeyPair(uid: fromUid);

    final theirPubB64 = await auth.publicKeyForUid(toUid);
    if (theirPubB64 == null) {
      throw StateError('Recipient has no public key published yet.');
    }

    final theirPub = _e2ee.parsePublicKeyB64(theirPubB64);
    final threadKey = await _e2ee.deriveThreadKey(
      myIdentityKeyPair: meKeyPair,
      theirPublicKey: theirPub,
      threadId: threadId,
    );

    // Bind encryption to thread + participants.
    final aad = 'vibeu:$threadId:$fromUid:$toUid'.codeUnits;
    final enc = await _e2ee.encrypt(key: threadKey, plaintext: plaintext, aad: aad);

    final msgDoc = _db.collection('threads').doc(threadId).collection('messages').doc();
    await msgDoc.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'ciphertextB64': enc['ciphertextB64'],
      'nonceB64': enc['nonceB64'],
      'macB64': enc['macB64'],
      'sentAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('threads').doc(threadId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return msgDoc.id;
  }

  Future<String> decryptMessage({
    required String threadId,
    required FirestoreEncryptedMessage message,
    required String myUid,
    required String otherUid,
  }) async {
    final myKeyPair = await _e2ee.getOrCreateIdentityKeyPair(uid: myUid);

    final otherPubB64 = await auth.publicKeyForUid(otherUid);
    if (otherPubB64 == null) {
      throw StateError('Other user has no public key.');
    }

    final otherPub = _e2ee.parsePublicKeyB64(otherPubB64);
    final threadKey = await _e2ee.deriveThreadKey(
      myIdentityKeyPair: myKeyPair,
      theirPublicKey: otherPub,
      threadId: threadId,
    );

    final aad = 'vibeu:$threadId:${message.fromUid}:${message.toUid}'.codeUnits;

    return _e2ee.decrypt(
      key: threadKey,
      ciphertextB64: message.ciphertextB64,
      nonceB64: message.nonceB64,
      macB64: message.macB64,
      aad: aad,
    );
  }
}
