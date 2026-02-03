import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../auth/firebase_auth_controller.dart';
import '../notifications/firestore_notifications_controller.dart';
import '../notifications/notification_models.dart';
import 'firestore_chat_models.dart';

/// Firestore-backed chat (plaintext messages).
///
/// Schema:
/// threads/{threadId}:
///   userAUid, userBUid, userAEmail, userBEmail, updatedAt
/// threads/{threadId}/messages/{messageId}:
///   fromUid, toUid, text, sentAt
///
/// Notes:
/// - Older encrypted messages are tolerated and shown as "[Encrypted message]".
class FirestoreChatController extends ChangeNotifier {
  FirestoreChatController({
    required this.auth,
    FirebaseFirestore? firestore,
    FirestoreNotificationsController? notifications,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _notifications = notifications ??
            FirestoreNotificationsController(firestore: firestore ?? FirebaseFirestore.instance);

  final FirebaseAuthController auth;
  final FirebaseFirestore _db;
  final FirestoreNotificationsController _notifications;

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
    final a = _db.collection('threads').where('userAUid', isEqualTo: myUid).snapshots();
    final b = _db.collection('threads').where('userBUid', isEqualTo: myUid).snapshots();

    final controller = StreamController<List<FirestoreChatThread>>();

    QuerySnapshot<Map<String, dynamic>>? lastA;
    QuerySnapshot<Map<String, dynamic>>? lastB;

    void emit() {
      if (lastA == null || lastB == null) return;
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[...lastA!.docs, ...lastB!.docs];

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

  Stream<List<FirestoreMessage>> messagesStream({required String threadId}) {
    return _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FirestoreMessage.fromDoc(threadId: threadId, doc: d)).toList());
  }

  Future<String> sendMessagePlaintext({
    required String threadId,
    required String fromUid,
    required String fromEmail,
    required String toUid,
    required String toEmail,
    required String text,
    String? replyToMessageId,
    String? replyToFromUid,
    String? replyToText,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('text is empty');
    }

    final msgDoc = _db.collection('threads').doc(threadId).collection('messages').doc();
    await msgDoc.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      'replyToMessageId': replyToMessageId,
      'replyToFromUid': replyToFromUid,
      'replyToText': replyToText,
    });

    await _db.collection('threads').doc(threadId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Best-effort notification (if rules block this, message should still exist).
    try {
      await _notifications.create(
        toUid: toUid,
        fromUid: fromUid,
        type: NotificationType.message,
        threadId: threadId,
      );
    } catch (e) {
      // ignore: avoid_print
      print('Failed to create message notification: $e');
    }

    return msgDoc.id;
  }

  String displayText(FirestoreMessage message) {
    if (message.text != null) return message.text!;
    if (message.ciphertextB64 != null) return '[Encrypted message]';
    return '[Unsupported message]';
  }
}
