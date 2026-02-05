import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_models.dart';

/// Firestore-backed notifications.
///
/// Schema:
/// users/{uid}/notifications/{notificationId}
///   toUid, fromUid, type, createdAt, read, threadId?, targetId?
class FirestoreNotificationsController {
  FirestoreNotificationsController({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<AppNotification>> notificationsStream({required String uid, int limit = 100}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromDoc).toList(growable: false));
  }

  Stream<int> unreadCountStream({required String uid}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  Future<void> markRead({required String uid, required String notificationId}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .set({'read': true}, SetOptions(merge: true));
  }

  Future<void> markAllRead({required String uid}) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.set(d.reference, {'read': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Mark all message notifications for a specific thread as read.
  Future<void> markMessageNotificationsRead({
    required String uid,
    required String threadId,
  }) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('type', isEqualTo: 'message')
        .where('threadId', isEqualTo: threadId)
        .where('read', isEqualTo: false)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.set(d.reference, {'read': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> create({
    required String toUid,
    required String fromUid,
    required NotificationType type,
    String? threadId,
    String? targetId,
  }) async {
    final ref = _db.collection('users').doc(toUid).collection('notifications').doc();
    await ref.set({
      'toUid': toUid,
      'fromUid': fromUid,
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'threadId': threadId,
      'targetId': targetId,
    });
  }

  /// Placeholder for posts feature: call when [fromUid] likes [toUid]'s post.
  Future<void> notifyPostLike({required String toUid, required String fromUid, required String postId}) {
    return create(
      toUid: toUid,
      fromUid: fromUid,
      type: NotificationType.postLike,
      targetId: postId,
    );
  }

  /// Placeholder for stories feature: call when [fromUid] likes [toUid]'s story.
  Future<void> notifyStoryLike({required String toUid, required String fromUid, required String storyId}) {
    return create(
      toUid: toUid,
      fromUid: fromUid,
      type: NotificationType.storyLike,
      targetId: storyId,
    );
  }
}
