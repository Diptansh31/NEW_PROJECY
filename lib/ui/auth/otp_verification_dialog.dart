import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/emailjs_otp_service.dart';

/// Dialog to verify OTP sent to user's email during login.
class OtpVerificationDialog extends StatefulWidget {
  const OtpVerificationDialog({
    super.key,
    required this.email,
    required this.expectedOtp,
    required this.onVerified,
    required this.onResendOtp,
  });

  final String email;
  final String expectedOtp;
  final VoidCallback onVerified;
  final Future<String> Function() onResendOtp; // Returns new OTP

  @override
  State<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<OtpVerificationDialog> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  
  String? _error;
  bool _verifying = false;
  bool _resending = false;
  
  late String _currentOtp;
  
  // Resend cooldown
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.expectedOtp;
    _startCooldown();
    
    // Auto-focus the OTP field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _verify() {
    final enteredOtp = _otpController.text.trim();
    
    if (enteredOtp.isEmpty) {
      setState(() => _error = 'Please enter the OTP');
      return;
    }
    
    if (enteredOtp.length != 6) {
      setState(() => _error = 'OTP must be 6 digits');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    // Small delay for UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (enteredOtp == _currentOtp) {
        widget.onVerified();
      } else {
        setState(() {
          _verifying = false;
          _error = 'Invalid OTP. Please try again.';
          _otpController.clear();
        });
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0 || _resending) return;

    setState(() {
      _resending = true;
      _error = null;
    });

    final newOtp = await widget.onResendOtp();
    
    setState(() {
      _currentOtp = newOtp;
      _resending = false;
      _otpController.clear();
    });
    
    _startCooldown();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent! Check your email.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Mask email for privacy (e.g., j***@example.com)
    final emailParts = widget.email.split('@');
    final maskedEmail = emailParts.length == 2
        ? '${emailParts[0][0]}***@${emailParts[1]}'
        : widget.email;

    return PopScope(
      canPop: false, // Prevent dismissing by back button
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.mail_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Verify Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'We\'ve sent a 6-digit code to',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              maskedEmail,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: theme.textTheme.headlineSmall?.copyWith(
                letterSpacing: 8,
                fontWeight: FontWeight.w600,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: 8,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onSubmitted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: (_resendCooldown > 0 || _resending) ? null : _resendOtp,
              child: Text(
                _resending
                    ? 'Sending...'
                    : _resendCooldown > 0
                        ? 'Resend OTP in ${_resendCooldown}s'
                        : 'Resend OTP',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _verifying ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _verifying ? null : _verify,
            child: Text(_verifying ? 'Verifying...' : 'Verify'),
          ),
        ],
      ),
    );
  }
}

/// Shows the OTP verification dialog and returns true if verified, false if cancelled.
Future<bool> showOtpVerificationDialog({
  required BuildContext context,
  required String email,
}) async {
  // Generate and send initial OTP
  String currentOtp = EmailJsOtpService.generateOtp();
  final sendError = await EmailJsOtpService.sendOtp(email: email, otp: currentOtp);
  
  if (sendError != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sendError), backgroundColor: Colors.red),
    );
    return false;
  }

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => OtpVerificationDialog(
      email: email,
      expectedOtp: currentOtp,
      onVerified: () => Navigator.of(ctx).pop(true),
      onResendOtp: () async {
        currentOtp = EmailJsOtpService.generateOtp();
        await EmailJsOtpService.sendOtp(email: email, otp: currentOtp);
        return currentOtp;
      },
    ),
  );

  return result ?? false;
}
