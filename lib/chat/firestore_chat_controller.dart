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
      'type': 'direct',
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

  /// Create a dedicated couple thread for a match.
  ///
  /// Thread id is random so it doesn't collide with direct threads.
  Future<FirestoreChatThread> createCoupleThread({
    required String uidA,
    required String emailA,
    required String uidB,
    required String emailB,
    String? matchId,
  }) async {
    final doc = _db.collection('threads').doc();

    final aUid = uidA.compareTo(uidB) <= 0 ? uidA : uidB;
    final bUid = uidA.compareTo(uidB) <= 0 ? uidB : uidA;
    final aEmail = uidA.compareTo(uidB) <= 0 ? emailA : emailB;
    final bEmail = uidA.compareTo(uidB) <= 0 ? emailB : emailA;

    await doc.set({
      'type': 'couple',
      'userAUid': aUid,
      'userBUid': bUid,
      'userAEmail': aEmail,
      'userBEmail': bEmail,
      if (matchId != null) 'matchId': matchId,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final snap = await doc.get();
    final data = snap.data() as Map<String, dynamic>;

    return FirestoreChatThread(
      id: doc.id,
      userAUid: data['userAUid'] as String,
      userBUid: data['userBUid'] as String,
      userAEmail: data['userAEmail'] as String,
      userBEmail: data['userBEmail'] as String,
      lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<FirestoreChatThread?> getThreadById(String threadId) async {
    final doc = await _db.collection('threads').doc(threadId).get();
    final data = doc.data();
    if (data == null) return null;

    return FirestoreChatThread(
      id: doc.id,
      userAUid: data['userAUid'] as String,
      userBUid: data['userBUid'] as String,
      userAEmail: (data['userAEmail'] as String?) ?? '',
      userBEmail: (data['userBEmail'] as String?) ?? '',
      lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Stream of chat threads for a user.
  /// 
  /// Uses Firestore's offline persistence to show cached threads when offline.
  Stream<List<FirestoreChatThread>> threadsStream({required String myUid}) {
    // Use a single OR query so the stream emits immediately and we don't get
    // stuck waiting for two separate listeners.
    // IMPORTANT: Your Firestore rules restrict couple threads (type=='couple')
    // to only be readable while still matched. That makes a broad list query fail.
    // So we only list direct threads here. Couple chat is opened via its id.
    final q = _db.collection('threads').where(
          Filter.and(
            Filter.or(
              Filter('userAUid', isEqualTo: myUid),
              Filter('userBUid', isEqualTo: myUid),
            ),
            // Backward compatible: older threads may not have `type`.
            Filter.or(
              Filter('type', isEqualTo: 'direct'),
              Filter('type', isNull: true),
            ),
          ),
        );

    return q.snapshots(includeMetadataChanges: true).map((snap) {
      final threads = snap.docs.map((d) {
        final data = d.data();
        return FirestoreChatThread(
          id: d.id,
          userAUid: data['userAUid'] as String,
          userBUid: data['userBUid'] as String,
          userAEmail: (data['userAEmail'] as String?) ?? '',
          userBEmail: (data['userBEmail'] as String?) ?? '',
          lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      }).toList(growable: false);

      threads.sort((x, y) => (y.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(x.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      return threads;
    });
  }

  /// Stream of messages for a thread.
  /// 
  /// Uses Firestore's offline persistence to show cached messages when offline.
  /// The [includeMetadataChanges] option ensures we get updates from cache immediately.
  Stream<List<FirestoreMessage>> messagesStream({required String threadId}) {
    return _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots(includeMetadataChanges: true)
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

    // Use local timestamp as fallback for immediate display, server timestamp for consistency
    final now = DateTime.now();
    final msgDoc = _db.collection('threads').doc(threadId).collection('messages').doc();
    await msgDoc.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      'sentAtLocal': Timestamp.fromDate(now), // Local fallback for pending writes
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

  Future<void> toggleReaction({
    required String threadId,
    required String messageId,
    required String emoji,
    required String uid,
  }) async {
    final msgRef = _db.collection('threads').doc(threadId).collection('messages').doc(messageId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(msgRef);
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final reactions = (data['reactions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final existing = (reactions[emoji] as List?)?.whereType<String>().toList() ?? <String>[];

      if (existing.contains(uid)) {
        existing.remove(uid);
      } else {
        existing.add(uid);
      }

      // Keep the map clean: remove emoji key if empty.
      if (existing.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = existing;
      }

      tx.update(msgRef, {'reactions': reactions});
    });
  }

  String displayText(FirestoreMessage message) {
    if (message.isCallMessage) {
      return _getCallDisplayText(message);
    }
    if (message.text != null) return message.text!;
    if (message.ciphertextB64 != null) return '[Encrypted message]';
    return '[Unsupported message]';
  }

  String _getCallDisplayText(FirestoreMessage message) {
    final duration = message.formattedCallDuration;
    switch (message.callStatus) {
      case CallMessageStatus.completed:
        return 'Voice call · $duration';
      case CallMessageStatus.missed:
        return 'Missed voice call';
      case CallMessageStatus.declined:
        return 'Declined voice call';
      case CallMessageStatus.cancelled:
        return 'Cancelled voice call';
      default:
        return 'Voice call';
    }
  }

  /// Sends a call message to record a voice call in the chat.
  /// 
  /// This is called when a voice call ends to show the call history in chat
  /// like WhatsApp does.
  Future<String> sendCallMessage({
    required String threadId,
    required String fromUid,
    required String toUid,
    required CallMessageStatus status,
    int? durationSeconds,
  }) async {
    final now = DateTime.now();
    final msgDoc = _db.collection('threads').doc(threadId).collection('messages').doc();
    
    await msgDoc.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'messageType': 'call',
      'callStatus': status.name,
      'callDurationSeconds': durationSeconds,
      'sentAt': FieldValue.serverTimestamp(),
      'sentAtLocal': Timestamp.fromDate(now),
    });

    await _db.collection('threads').doc(threadId).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return msgDoc.id;
  }

  /// Stream that emits true if there are any unread messages across all threads for this user.
  /// 
  /// A message is considered unread if:
  /// - It was sent to this user (toUid == myUid)
  /// - It hasn't been marked as read
  Stream<bool> hasUnreadMessagesStream({required String myUid}) {
    return _db
        .collection('users')
        .doc(myUid)
        .collection('notifications')
        .where('type', isEqualTo: 'message')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty);
  }

  /// Stream of the last message for a specific thread.
  Stream<FirestoreMessage?> lastMessageStream({required String threadId}) {
    return _db
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return FirestoreMessage.fromDoc(threadId: threadId, doc: snap.docs.first);
    });
  }
}
