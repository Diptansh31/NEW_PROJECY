import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class FirestoreChatThread {
  const FirestoreChatThread({
    required this.id,
    required this.userAUid,
    required this.userBUid,
    required this.userAEmail,
    required this.userBEmail,
    this.lastMessageAt,
  });

  final String id;
  final String userAUid;
  final String userBUid;
  final String userAEmail;
  final String userBEmail;
  final DateTime? lastMessageAt;

  String otherUid(String myUid) => userAUid == myUid ? userBUid : userAUid;
  String otherEmail(String myUid) => userAUid == myUid ? userBEmail : userAEmail;
}

/// A chat message stored in Firestore.
///
/// New messages use plaintext field `text`.
/// Older messages may contain encrypted payload fields.
@immutable
class FirestoreMessage {
  const FirestoreMessage({
    required this.id,
    required this.threadId,
    required this.fromUid,
    required this.toUid,
    required this.sentAt,
    this.text,
    this.ciphertextB64,
    this.nonceB64,
    this.macB64,
    this.replyToMessageId,
    this.replyToFromUid,
    this.replyToText,
  });

  final String id;
  final String threadId;
  final String fromUid;
  final String toUid;
  final DateTime sentAt;

  final String? text;
  final String? ciphertextB64;
  final String? nonceB64;
  final String? macB64;

  // Reply metadata (denormalized for easy display).
  final String? replyToMessageId;
  final String? replyToFromUid;
  final String? replyToText;

  static FirestoreMessage fromDoc({
    required String threadId,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final d = doc.data();
    return FirestoreMessage(
      id: doc.id,
      threadId: threadId,
      fromUid: d['fromUid'] as String,
      toUid: d['toUid'] as String,
      text: d['text'] as String?,
      ciphertextB64: d['ciphertextB64'] as String?,
      nonceB64: d['nonceB64'] as String?,
      macB64: d['macB64'] as String?,
      replyToMessageId: d['replyToMessageId'] as String?,
      replyToFromUid: d['replyToFromUid'] as String?,
      replyToText: d['replyToText'] as String?,
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
