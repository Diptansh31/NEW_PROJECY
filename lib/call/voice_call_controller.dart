import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_models.dart';
import 'firestore_call_signaling.dart';

/// Local state of the call from the user's perspective.
enum LocalCallState {
  idle,
  outgoing,
  incoming,
  connected,
  ended,
}

/// Controller for managing WebRTC voice calls.
///
/// Handles:
/// - Creating and joining calls
/// - WebRTC peer connection setup
/// - ICE candidate exchange via Firestore signaling
/// - Audio stream management
class VoiceCallController extends ChangeNotifier {
  VoiceCallController({
    FirestoreCallSignaling? signaling,
  }) : _signaling = signaling ?? FirestoreCallSignaling();

  final FirestoreCallSignaling _signaling;

  // WebRTC configuration with STUN and TURN servers
  // TURN servers help when direct peer-to-peer connection fails (NAT/firewall)
  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      // Google STUN servers
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      // Open Relay TURN servers (free, for testing)
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  /// Audio renderer to ensure remote audio plays on all platforms.
  RTCVideoRenderer? _remoteRenderer;
  
  String? _currentCallId;
  bool _isCaller = false;
  Timer? _callTimeoutTimer;
  
  /// Duration before an unanswered outgoing call times out.
  static const Duration callTimeout = Duration(seconds: 30);
  
  LocalCallState _state = LocalCallState.idle;
  LocalCallState get state => _state;

  /// Human-readable status message for the UI.
  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  VoiceCall? _currentCall;
  VoiceCall? get currentCall => _currentCall;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  DateTime? _connectedAt;
  DateTime? get connectedAt => _connectedAt;

  StreamSubscription<VoiceCall?>? _callSubscription;
  StreamSubscription<List<IceCandidate>>? _candidatesSubscription;

  /// Starts an outgoing call to another user.
  Future<String?> startCall({
    required String callerUid,
    required String calleeUid,
  }) async {
    if (_state != LocalCallState.idle) {
      debugPrint('VoiceCallController: Cannot start call, state is $_state');
      return null;
    }

    try {
      _isCaller = true;
      _state = LocalCallState.outgoing;
      _statusMessage = 'Connecting...';
      notifyListeners();

      // Get local audio stream
      _statusMessage = 'Accessing microphone...';
      notifyListeners();
      await _initLocalStream();

      // Create peer connection
      await _createPeerConnection();

      // Create offer
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(offer);

      // Create call in Firestore
      _currentCallId = await _signaling.createCall(
        callerUid: callerUid,
        calleeUid: calleeUid,
        offer: offer.sdp!,
      );

      // Listen for call updates (answer, status changes)
      _subscribeToCall();

      // Listen for callee's ICE candidates
      _subscribeToCalleeCandidates();

      // Start timeout timer
      _startCallTimeout();

      _statusMessage = 'Ringing...';
      notifyListeners();

      return _currentCallId;
    } catch (e) {
      debugPrint('VoiceCallController: Error starting call: $e');
      _statusMessage = 'Failed to start call';
      notifyListeners();
      await _cleanup();
      return null;
    }
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(callTimeout, () {
      if (_state == LocalCallState.outgoing) {
        debugPrint('VoiceCallController: Call timed out - no answer');
        _statusMessage = 'No answer';
        notifyListeners();
        // Mark as missed and cleanup
        if (_currentCallId != null) {
          _signaling.markCallMissed(_currentCallId!);
        }
        _cleanup();
      }
    });
  }

  /// Accepts an incoming call.
  Future<bool> acceptCall({
    required String callId,
    required String currentUid,
  }) async {
    try {
      _currentCallId = callId;
      _isCaller = false;
      _state = LocalCallState.incoming;
      notifyListeners();

      // Get the call details
      final call = await _signaling.getCall(callId);
      if (call == null || call.offer == null) {
        debugPrint('VoiceCallController: Call not found or no offer');
        await _cleanup();
        return false;
      }
      _currentCall = call;

      // Get local audio stream
      await _initLocalStream();

      // Create peer connection
      await _createPeerConnection();

      // Set remote description (caller's offer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(call.offer!, 'offer'),
      );

      // Create answer
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(answer);

      // Send answer to Firestore
      await _signaling.answerCall(
        callId: callId,
        answer: answer.sdp!,
      );

      // Subscribe to caller's ICE candidates
      _subscribeToCallerCandidates();

      // Subscribe to call updates
      _subscribeToCall();

      _state = LocalCallState.connected;
      _connectedAt = DateTime.now();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('VoiceCallController: Error accepting call: $e');
      await _cleanup();
      return false;
    }
  }

  /// Rejects an incoming call.
  Future<void> rejectCall(String callId) async {
    await _signaling.rejectCall(callId);
  }

  /// Ends the current call.
  Future<void> endCall() async {
    if (_currentCallId != null) {
      await _signaling.endCall(_currentCallId!);
    }
    await _cleanup();
  }

  /// Toggles microphone mute.
  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = _isMuted;
      }
      _isMuted = !_isMuted;
      notifyListeners();
    }
  }

  /// Toggles speaker mode.
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    // Note: Actual speaker switching requires platform-specific implementation
    // flutter_webrtc handles this internally on some platforms
    if (_localStream != null) {
      Helper.setSpeakerphoneOn(_isSpeakerOn);
    }
    notifyListeners();
  }

  Future<void> _initLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
  }

  Future<void> _createPeerConnection() async {
    // Initialize remote renderer for audio playback
    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer!.initialize();
    
    _peerConnection = await createPeerConnection(_rtcConfig);

    // Add local audio track
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null && _currentCallId != null) {
        final iceCandidate = IceCandidate(
          candidate: candidate.candidate!,
          sdpMid: candidate.sdpMid,
          sdpMLineIndex: candidate.sdpMLineIndex,
        );

        if (_isCaller) {
          _signaling.addCallerCandidate(
            callId: _currentCallId!,
            candidate: iceCandidate,
          );
        } else {
          _signaling.addCalleeCandidate(
            callId: _currentCallId!,
            candidate: iceCandidate,
          );
        }
      }
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (state) {
      debugPrint('VoiceCallController: Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        endCall();
      }
    };

    // Handle remote tracks (audio from the other party)
    _peerConnection!.onTrack = (event) {
      debugPrint('VoiceCallController: Received remote track: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        debugPrint('VoiceCallController: Remote stream set with ${_remoteStream!.getAudioTracks().length} audio tracks');
        
        // Attach to renderer to ensure audio plays
        _remoteRenderer?.srcObject = _remoteStream;
        
        // Ensure audio tracks are enabled
        for (final track in _remoteStream!.getAudioTracks()) {
          track.enabled = true;
          debugPrint('VoiceCallController: Remote audio track enabled: ${track.id}');
        }
        
        // Enable speaker for voice calls
        Helper.setSpeakerphoneOn(true);
        _isSpeakerOn = true;
        
        notifyListeners();
      }
    };

    // Also handle onAddStream for older WebRTC implementations
    _peerConnection!.onAddStream = (stream) {
      debugPrint('VoiceCallController: onAddStream - ${stream.getAudioTracks().length} audio tracks');
      _remoteStream = stream;
      _remoteRenderer?.srcObject = stream;
      
      for (final track in stream.getAudioTracks()) {
        track.enabled = true;
      }
      
      // Enable speaker for voice calls
      Helper.setSpeakerphoneOn(true);
      _isSpeakerOn = true;
      
      notifyListeners();
    };
  }

  void _subscribeToCall() {
    _callSubscription?.cancel();
    _callSubscription = _signaling.callStream(_currentCallId!).listen((call) {
      if (call == null) {
        _cleanup();
        return;
      }

      _currentCall = call;

      // Handle call state changes
      switch (call.status) {
        case CallStatus.connected:
          if (_isCaller && _state == LocalCallState.outgoing) {
            // Caller received answer, set remote description
            _handleAnswerReceived(call.answer!);
          }
          break;
        case CallStatus.ended:
          _statusMessage = 'Call ended';
          notifyListeners();
          _cleanup();
          break;
        case CallStatus.rejected:
          _statusMessage = 'Call declined';
          notifyListeners();
          _cleanup();
          break;
        case CallStatus.missed:
          _statusMessage = 'No answer';
          notifyListeners();
          _cleanup();
          break;
        case CallStatus.ringing:
          // Still waiting for answer
          break;
      }

      notifyListeners();
    });
  }

  Future<void> _handleAnswerReceived(String answerSdp) async {
    try {
      // Cancel timeout since call was answered
      _callTimeoutTimer?.cancel();
      _callTimeoutTimer = null;
      
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );
      _state = LocalCallState.connected;
      _connectedAt = DateTime.now();
      _statusMessage = 'Connected';
      notifyListeners();
    } catch (e) {
      debugPrint('VoiceCallController: Error setting remote description: $e');
      _statusMessage = 'Connection failed';
      notifyListeners();
    }
  }

  void _subscribeToCallerCandidates() {
    _candidatesSubscription?.cancel();
    _candidatesSubscription = _signaling
        .callerCandidatesStream(_currentCallId!)
        .listen((candidates) {
      for (final candidate in candidates) {
        _peerConnection?.addCandidate(RTCIceCandidate(
          candidate.candidate,
          candidate.sdpMid,
          candidate.sdpMLineIndex,
        ));
      }
    });
  }

  void _subscribeToCalleeCandidates() {
    _candidatesSubscription?.cancel();
    _candidatesSubscription = _signaling
        .calleeCandidatesStream(_currentCallId!)
        .listen((candidates) {
      for (final candidate in candidates) {
        _peerConnection?.addCandidate(RTCIceCandidate(
          candidate.candidate,
          candidate.sdpMid,
          candidate.sdpMLineIndex,
        ));
      }
    });
  }

  Future<void> _cleanup() async {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;

    _callSubscription?.cancel();
    _callSubscription = null;

    _candidatesSubscription?.cancel();
    _candidatesSubscription = null;

    await _localStream?.dispose();
    _localStream = null;

    await _remoteStream?.dispose();
    _remoteStream = null;

    _remoteRenderer?.srcObject = null;
    await _remoteRenderer?.dispose();
    _remoteRenderer = null;

    await _peerConnection?.close();
    _peerConnection = null;

    _currentCallId = null;
    _currentCall = null;
    _isCaller = false;
    _isMuted = false;
    _isSpeakerOn = false;
    _connectedAt = null;

    _state = LocalCallState.ended;
    notifyListeners();

    // Reset to idle after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (_state == LocalCallState.ended) {
        _state = LocalCallState.idle;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
