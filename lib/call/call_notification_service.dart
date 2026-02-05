import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// Callback types for call actions
typedef CallActionCallback = void Function(String callId, String callerUid);

/// Service to handle incoming call notifications with ringtone and vibration.
/// Uses flutter_local_notifications for notification display.
class CallNotificationService {
  CallNotificationService._();
  static final instance = CallNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  
  Timer? _vibrationTimer;
  bool _isRinging = false;
  bool _isInitialized = false;

  // Callbacks for notification actions
  CallActionCallback? onCallAccepted;
  CallActionCallback? onCallDeclined;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'incoming_calls',
        'Incoming Calls',
        description: 'Notifications for incoming voice calls',
        importance: Importance.max,
        playSound: false, // We handle sound separately
        enableVibration: false, // We handle vibration separately
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _isInitialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    final parts = payload.split('|');
    if (parts.length < 2) return;

    final callId = parts[0];
    final callerUid = parts[1];

    if (response.actionId == 'accept') {
      onCallAccepted?.call(callId, callerUid);
      hideIncomingCall(callId);
    } else if (response.actionId == 'decline') {
      onCallDeclined?.call(callId, callerUid);
      hideIncomingCall(callId);
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    // Background handling - will be processed when app opens
    debugPrint('Background notification response: ${response.actionId}');
  }

  /// Shows an incoming call notification with ringtone and vibration.
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerUid,
    String? callerAvatar,
  }) async {
    if (_isRinging) return;
    
    await initialize();
    
    _isRinging = true;

    // Show notification with actions
    const androidDetails = AndroidNotificationDetails(
      'incoming_calls',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming voice calls',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      actions: [
        AndroidNotificationAction(
          'accept',
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'decline',
          'Decline',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      callId.hashCode,
      'Incoming Call',
      '$callerName is calling...',
      notificationDetails,
      payload: '$callId|$callerUid',
    );

    // Start ringtone
    _startRingtone();
    
    // Start vibration pattern
    _startVibration();
  }

  /// Stops the incoming call notification.
  Future<void> hideIncomingCall(String callId) async {
    _isRinging = false;
    _stopRingtone();
    _stopVibration();
    await _notifications.cancel(callId.hashCode);
  }

  /// Shows that a call has ended.
  Future<void> endCall(String callId) async {
    await hideIncomingCall(callId);
  }

  /// Marks call as connected (answered).
  Future<void> setCallConnected(String callId) async {
    _isRinging = false;
    _stopRingtone();
    _stopVibration();
    await _notifications.cancel(callId.hashCode);
  }

  void _startRingtone() async {
    try {
      // Play a simple ringtone sound - using device's notification sound
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(
        AssetSource('sounds/ringtone.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      // If no custom ringtone, that's okay - vibration still works
      debugPrint('CallNotificationService: Could not play ringtone: $e');
    }
  }

  void _stopRingtone() {
    _ringtonePlayer.stop();
  }

  void _startVibration() async {
    if (Platform.isAndroid) {
      // Check if device can vibrate
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      // Vibrate in a pattern: vibrate 1s, pause 1s, repeat
      _vibrationTimer?.cancel();
      _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_isRinging) {
          Vibration.vibrate(duration: 1000);
        }
      });
      // Initial vibration
      Vibration.vibrate(duration: 1000);
    }
  }

  void _stopVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    if (Platform.isAndroid) {
      Vibration.cancel();
    }
  }

  /// End all calls
  Future<void> endAllCalls() async {
    _isRinging = false;
    _stopRingtone();
    _stopVibration();
    await _notifications.cancelAll();
  }

  void dispose() {
    _stopRingtone();
    _stopVibration();
    _ringtonePlayer.dispose();
  }
}
