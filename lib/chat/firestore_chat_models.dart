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

@immutable
class FirestoreEncryptedMessage {
  const FirestoreEncryptedMessage({
    required this.id,
    required this.threadId,
    required this.fromUid,
    required this.toUid,
    required this.ciphertextB64,
    required this.nonceB64,
    required this.macB64,
    required this.sentAt,
  });

  final String id;
  final String threadId;
  final String fromUid;
  final String toUid;
  final String ciphertextB64;
  final String nonceB64;
  final String macB64;
  final DateTime sentAt;

  static FirestoreEncryptedMessage fromDoc({
    required String threadId,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final d = doc.data();
    return FirestoreEncryptedMessage(
      id: doc.id,
      threadId: threadId,
      fromUid: d['fromUid'] as String,
      toUid: d['toUid'] as String,
      ciphertextB64: d['ciphertextB64'] as String,
      nonceB64: d['nonceB64'] as String,
      macB64: d['macB64'] as String,
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
