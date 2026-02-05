import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../call/voice_call_controller.dart';

/// Full-screen voice call UI.
class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({
    super.key,
    required this.currentUser,
    required this.otherUser,
    required this.callController,
    this.isIncoming = false,
    this.incomingCallId,
  });

  final AppUser currentUser;
  final AppUser otherUser;
  final VoiceCallController callController;
  final bool isIncoming;
  final String? incomingCallId;

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCall();
    widget.callController.addListener(_onCallStateChanged);
  }

  Future<void> _initCall() async {
    if (widget.isIncoming && widget.incomingCallId != null) {
      // Accept incoming call
      await widget.callController.acceptCall(
        callId: widget.incomingCallId!,
        currentUid: widget.currentUser.uid,
      );
    } else {
      // Start outgoing call
      await widget.callController.startCall(
        callerUid: widget.currentUser.uid,
        calleeUid: widget.otherUser.uid,
      );
    }
    setState(() => _isInitialized = true);
  }

  void _onCallStateChanged() {
    final state = widget.callController.state;
    
    if (state == LocalCallState.connected && _durationTimer == null) {
      _startDurationTimer();
    }
    
    if (state == LocalCallState.ended || state == LocalCallState.idle) {
      _stopDurationTimer();
      // Pop the page when call ends
      if (mounted && _isInitialized) {
        Navigator.of(context).maybePop();
      }
    }
    
    if (mounted) setState(() {});
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.callController.connectedAt != null) {
        setState(() {
          _callDuration = DateTime.now().difference(widget.callController.connectedAt!);
        });
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  @override
  void dispose() {
    widget.callController.removeListener(_onCallStateChanged);
    _stopDurationTimer();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getStatusText() {
    final state = widget.callController.state;
    final statusMessage = widget.callController.statusMessage;
    
    // Show duration when connected
    if (state == LocalCallState.connected) {
      return _formatDuration(_callDuration);
    }
    
    // Use the detailed status message if available
    if (statusMessage.isNotEmpty) {
      return statusMessage;
    }
    
    // Fallback to basic state descriptions
    switch (state) {
      case LocalCallState.outgoing:
        return 'Calling...';
      case LocalCallState.incoming:
        return 'Connecting...';
      case LocalCallState.connected:
        return _formatDuration(_callDuration);
      case LocalCallState.ended:
        return 'Call Ended';
      case LocalCallState.idle:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.callController.state;
    final isConnected = state == LocalCallState.connected;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button (only show when not connected)
            if (!isConnected)
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () {
                    widget.callController.endCall();
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            
            const Spacer(flex: 2),
            
            // Avatar
            CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                widget.otherUser.username.isNotEmpty
                    ? widget.otherUser.username[0].toUpperCase()
                    : '?',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Username
            Text(
              widget.otherUser.username,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Call status
            Text(
              _getStatusText(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: isConnected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const Spacer(flex: 3),
            
            // Call controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _CallControlButton(
                    icon: widget.callController.isMuted
                        ? Icons.mic_off
                        : Icons.mic,
                    label: widget.callController.isMuted ? 'Unmute' : 'Mute',
                    onPressed: isConnected
                        ? () => widget.callController.toggleMute()
                        : null,
                    isActive: widget.callController.isMuted,
                  ),
                  
                  // End call button
                  _CallControlButton(
                    icon: Icons.call_end,
                    label: 'End',
                    onPressed: () => widget.callController.endCall(),
                    isDestructive: true,
                    size: 72,
                  ),
                  
                  // Speaker button
                  _CallControlButton(
                    icon: widget.callController.isSpeakerOn
                        ? Icons.volume_up
                        : Icons.volume_down,
                    label: 'Speaker',
                    onPressed: isConnected
                        ? () => widget.callController.toggleSpeaker()
                        : null,
                    isActive: widget.callController.isSpeakerOn,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.isDestructive = false,
    this.size = 56,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isDestructive;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color backgroundColor;
    Color iconColor;
    
    if (isDestructive) {
      backgroundColor = theme.colorScheme.error;
      iconColor = theme.colorScheme.onError;
    } else if (isActive) {
      backgroundColor = theme.colorScheme.primaryContainer;
      iconColor = theme.colorScheme.onPrimaryContainer;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      iconColor = theme.colorScheme.onSurface;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: iconColor,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              elevation: isDestructive ? 4 : 1,
            ),
            child: Icon(icon, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
