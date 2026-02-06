import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Service to send OTP emails using EmailJS.
class EmailJsOtpService {
  static const String _publicKey = 'vMHaw0fLsCU1hg1NL';
  static const String _serviceId = 'service_5o78aj6';
  static const String _templateId = 'template_6lrb5te';
  static const String _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  /// Generates a random 6-digit OTP.
  static String generateOtp() {
    final random = Random.secure();
    final otp = random.nextInt(900000) + 100000; // 100000 to 999999
    return otp.toString();
  }

  /// Sends an OTP email to the specified email address.
  /// Returns `null` on success, or an error message on failure.
  static Future<String?> sendOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': email,
            'otp_code': otp,
            'app_name': 'vibeU',
          },
        }),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        return 'Failed to send OTP. Please try again.';
      }
    } catch (e) {
      return 'Network error. Please check your connection.';
    }
  }
}
