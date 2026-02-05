import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'call_models.dart';

/// Handles Firestore-based signaling for WebRTC voice calls.
///
/// Firestore structure:
/// ```
/// calls/{callId}
///   - callerUid, calleeUid, status, offer, answer, timestamps
/// calls/{callId}/callerCandidates/{candidateId}
///   - ICE candidate data from caller
/// calls/{callId}/calleeCandidates/{candidateId}
///   - ICE candidate data from callee
/// ```
class FirestoreCallSignaling {
  FirestoreCallSignaling({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _callsCollection =>
      _firestore.collection('calls');

  DocumentReference<Map<String, dynamic>> _callDoc(String callId) =>
      _callsCollection.doc(callId);

  CollectionReference<Map<String, dynamic>> _callerCandidates(String callId) =>
      _callDoc(callId).collection('callerCandidates');

  CollectionReference<Map<String, dynamic>> _calleeCandidates(String callId) =>
      _callDoc(callId).collection('calleeCandidates');

  /// Creates a new call document and returns the call ID.
  Future<String> createCall({
    required String callerUid,
    required String calleeUid,
    required String offer,
  }) async {
    final docRef = _callsCollection.doc();
    final call = VoiceCall(
      id: docRef.id,
      callerUid: callerUid,
      calleeUid: calleeUid,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
      offer: offer,
    );
    await docRef.set(call.toFirestore());
    return docRef.id;
  }

  /// Gets a call by ID.
  Future<VoiceCall?> getCall(String callId) async {
    final doc = await _callDoc(callId).get();
    if (!doc.exists) return null;
    return VoiceCall.fromFirestore(doc);
  }

  /// Streams updates to a specific call.
  Stream<VoiceCall?> callStream(String callId) {
    return _callDoc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return VoiceCall.fromFirestore(doc);
    });
  }

  /// Streams incoming calls for a user (calls where they are the callee and status is ringing).
  Stream<List<VoiceCall>> incomingCallsStream(String uid) {
    return _callsCollection
        .where('calleeUid', isEqualTo: uid)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => VoiceCall.fromFirestore(doc)).toList());
  }

  /// Updates the call with an answer SDP.
  Future<void> answerCall({
    required String callId,
    required String answer,
  }) async {
    await _callDoc(callId).update({
      'answer': answer,
      'status': CallStatus.connected.name,
      'answeredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rejects an incoming call.
  Future<void> rejectCall(String callId) async {
    await _callDoc(callId).update({
      'status': CallStatus.rejected.name,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ends an active call.
  Future<void> endCall(String callId) async {
    await _callDoc(callId).update({
      'status': CallStatus.ended.name,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks a call as missed (unanswered).
  Future<void> markCallMissed(String callId) async {
    await _callDoc(callId).update({
      'status': CallStatus.missed.name,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds an ICE candidate from the caller.
  Future<void> addCallerCandidate({
    required String callId,
    required IceCandidate candidate,
  }) async {
    await _callerCandidates(callId).add(candidate.toFirestore());
  }

  /// Adds an ICE candidate from the callee.
  Future<void> addCalleeCandidate({
    required String callId,
    required IceCandidate candidate,
  }) async {
    await _calleeCandidates(callId).add(candidate.toFirestore());
  }

  /// Streams ICE candidates from the caller (for the callee to consume).
  Stream<List<IceCandidate>> callerCandidatesStream(String callId) {
    return _callerCandidates(callId).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => IceCandidate.fromFirestore(doc)).toList());
  }

  /// Streams ICE candidates from the callee (for the caller to consume).
  Stream<List<IceCandidate>> calleeCandidatesStream(String callId) {
    return _calleeCandidates(callId).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => IceCandidate.fromFirestore(doc)).toList());
  }

  /// Deletes a call and its subcollections.
  Future<void> deleteCall(String callId) async {
    // Delete caller candidates
    final callerCandidates = await _callerCandidates(callId).get();
    for (final doc in callerCandidates.docs) {
      await doc.reference.delete();
    }

    // Delete callee candidates
    final calleeCandidates = await _calleeCandidates(callId).get();
    for (final doc in calleeCandidates.docs) {
      await doc.reference.delete();
    }

    // Delete the call document
    await _callDoc(callId).delete();
  }
}
