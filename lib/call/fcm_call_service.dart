import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles FCM token storage and background message processing.
class FcmCallService {
  FcmCallService._();
  static final instance = FcmCallService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentToken;
  String? get currentToken => _currentToken;

  /// Initialize FCM and request permissions.
  Future<void> initialize(String userId) async {
    // Request permission (required for iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    debugPrint('FCM: Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get FCM token
      _currentToken = await _messaging.getToken();
      debugPrint('FCM: Token: $_currentToken');

      if (_currentToken != null) {
        // Save token to Firestore for this user
        await _saveTokenToFirestore(userId, _currentToken!);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        _saveTokenToFirestore(userId, newToken);
      });
    }
  }

  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM: Token saved to Firestore');
    } catch (e) {
      debugPrint('FCM: Error saving token: $e');
    }
  }

  /// Remove FCM token when user signs out.
  Future<void> removeToken(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
      await _messaging.deleteToken();
      _currentToken = null;
    } catch (e) {
      debugPrint('FCM: Error removing token: $e');
    }
  }

  /// Get another user's FCM token.
  Future<String?> getUserToken(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['fcmToken'] as String?;
    } catch (e) {
      debugPrint('FCM: Error getting user token: $e');
      return null;
    }
  }
}

/// Background message handler - must be top-level function.
/// Note: Background notifications will show as regular notifications.
/// Full incoming call UI only works when app is in foreground.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM: Background message received: ${message.data}');

  // Handle incoming call notification
  if (message.data['type'] == 'incoming_call') {
    final callerName = message.data['callerName'] as String? ?? 'Unknown';
    debugPrint('FCM: Incoming call from $callerName (background)');
    // The notification will be shown by the system automatically
    // When user taps it, the app will open and handle the call
  }
}
