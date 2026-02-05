import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Represents the current state of a voice call.
enum CallStatus {
  /// Call is being initiated, waiting for callee to respond.
  ringing,

  /// Call has been accepted and is active.
  connected,

  /// Call was ended normally by either party.
  ended,

  /// Call was rejected by the callee.
  rejected,

  /// Call was not answered (timed out).
  missed,
}

/// Represents a voice call between two users.
@immutable
class VoiceCall {
  const VoiceCall({
    required this.id,
    required this.callerUid,
    required this.calleeUid,
    required this.status,
    required this.createdAt,
    this.offer,
    this.answer,
    this.answeredAt,
    this.endedAt,
  });

  final String id;
  final String callerUid;
  final String calleeUid;
  final CallStatus status;
  final DateTime createdAt;
  final String? offer;
  final String? answer;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  /// Creates a VoiceCall from a Firestore document.
  factory VoiceCall.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return VoiceCall(
      id: doc.id,
      callerUid: data['callerUid'] as String,
      calleeUid: data['calleeUid'] as String,
      status: CallStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CallStatus.ended,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      offer: data['offer'] as String?,
      answer: data['answer'] as String?,
      answeredAt: data['answeredAt'] != null
          ? (data['answeredAt'] as Timestamp).toDate()
          : null,
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts the VoiceCall to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'callerUid': callerUid,
      'calleeUid': calleeUid,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (offer != null) 'offer': offer,
      if (answer != null) 'answer': answer,
      if (answeredAt != null) 'answeredAt': Timestamp.fromDate(answeredAt!),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
    };
  }

  VoiceCall copyWith({
    String? id,
    String? callerUid,
    String? calleeUid,
    CallStatus? status,
    DateTime? createdAt,
    String? offer,
    String? answer,
    DateTime? answeredAt,
    DateTime? endedAt,
  }) {
    return VoiceCall(
      id: id ?? this.id,
      callerUid: callerUid ?? this.callerUid,
      calleeUid: calleeUid ?? this.calleeUid,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      offer: offer ?? this.offer,
      answer: answer ?? this.answer,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  /// Check if this user is the caller.
  bool isCaller(String uid) => callerUid == uid;

  /// Check if this user is the callee.
  bool isCallee(String uid) => calleeUid == uid;

  /// Get the other user's UID.
  String otherUid(String currentUid) =>
      currentUid == callerUid ? calleeUid : callerUid;
}

/// Represents an ICE candidate for WebRTC connection.
@immutable
class IceCandidate {
  const IceCandidate({
    required this.candidate,
    required this.sdpMid,
    required this.sdpMLineIndex,
  });

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  factory IceCandidate.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return IceCandidate(
      candidate: data['candidate'] as String,
      sdpMid: data['sdpMid'] as String?,
      sdpMLineIndex: data['sdpMLineIndex'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'candidate': candidate,
      'sdpMid': sdpMid,
      'sdpMLineIndex': sdpMLineIndex,
    };
  }
}
