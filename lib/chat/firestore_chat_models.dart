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

/// Message type enum for different kinds of messages.
enum MessageType {
  text,
  call,
  encrypted,
}

/// Call status for call messages.
enum CallMessageStatus {
  completed,  // Call was answered and ended normally
  missed,     // Call was not answered
  declined,   // Call was declined by receiver
  cancelled,  // Call was cancelled by caller
}

/// A chat message stored in Firestore.
///
/// New messages use plaintext field `text`.
/// Older messages may contain encrypted payload fields.
/// Call messages have `messageType: 'call'` with call metadata.
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
    this.reactions = const <String, List<String>>{},
    this.messageType = MessageType.text,
    this.callDurationSeconds,
    this.callStatus,
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

  /// Emoji -> list of uids.
  final Map<String, List<String>> reactions;

  /// Type of message (text, call, encrypted).
  final MessageType messageType;

  /// Duration of the call in seconds (only for call messages).
  final int? callDurationSeconds;

  /// Status of the call (only for call messages).
  final CallMessageStatus? callStatus;

  /// Helper to check if this is a call message.
  bool get isCallMessage => messageType == MessageType.call;

  /// Get formatted call duration string (e.g., "2:34").
  String? get formattedCallDuration {
    if (callDurationSeconds == null) return null;
    final minutes = callDurationSeconds! ~/ 60;
    final seconds = callDurationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static FirestoreMessage fromDoc({
    required String threadId,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final d = doc.data();
    final rawReactions = d['reactions'];
    final reactions = <String, List<String>>{};
    if (rawReactions is Map) {
      for (final entry in rawReactions.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is! String) continue;
        if (v is List) {
          reactions[k] = v.whereType<String>().toList(growable: false);
        }
      }
    }

    // Use server timestamp if available, otherwise fall back to local timestamp
    // This prevents the "time jump" lag when sending messages
    final serverTimestamp = d['sentAt'] as Timestamp?;
    final localTimestamp = d['sentAtLocal'] as Timestamp?;
    final sentAt = serverTimestamp?.toDate() ?? 
                   localTimestamp?.toDate() ?? 
                   DateTime.now(); // Final fallback for very old messages

    // Parse message type
    final messageTypeStr = d['messageType'] as String?;
    MessageType messageType;
    if (messageTypeStr == 'call') {
      messageType = MessageType.call;
    } else if (d['ciphertextB64'] != null) {
      messageType = MessageType.encrypted;
    } else {
      messageType = MessageType.text;
    }

    // Parse call status if this is a call message
    CallMessageStatus? callStatus;
    final callStatusStr = d['callStatus'] as String?;
    if (callStatusStr != null) {
      switch (callStatusStr) {
        case 'completed':
          callStatus = CallMessageStatus.completed;
          break;
        case 'missed':
          callStatus = CallMessageStatus.missed;
          break;
        case 'declined':
          callStatus = CallMessageStatus.declined;
          break;
        case 'cancelled':
          callStatus = CallMessageStatus.cancelled;
          break;
      }
    }

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
      reactions: reactions,
      sentAt: sentAt,
      messageType: messageType,
      callDurationSeconds: d['callDurationSeconds'] as int?,
      callStatus: callStatus,
    );
  }
}
