import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../call/call_models.dart';

/// Dialog shown when there's an incoming call.
class IncomingCallDialog extends StatelessWidget {
  const IncomingCallDialog({
    super.key,
    required this.call,
    required this.callerUser,
    required this.onAccept,
    required this.onReject,
  });

  final VoiceCall call;
  final AppUser callerUser;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Incoming call label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.call,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Incoming Call',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Caller avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Text(
                callerUser.username.isNotEmpty
                    ? callerUser.username[0].toUpperCase()
                    : '?',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Caller name
            Text(
              callerUser.username,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // "is calling you" text
            Text(
              'is calling you...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // Accept/Reject buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject button
                Column(
                  children: [
                    FloatingActionButton(
                      heroTag: 'reject_call',
                      onPressed: onReject,
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      child: const Icon(Icons.call_end),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Decline',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),

                // Accept button
                Column(
                  children: [
                    FloatingActionButton(
                      heroTag: 'accept_call',
                      onPressed: onAccept,
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.call),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Accept',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the incoming call dialog.
/// Returns true if accepted, false if rejected, null if dismissed.
Future<bool?> showIncomingCallDialog({
  required BuildContext context,
  required VoiceCall call,
  required AppUser callerUser,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => IncomingCallDialog(
      call: call,
      callerUser: callerUser,
      onAccept: () => Navigator.of(ctx).pop(true),
      onReject: () => Navigator.of(ctx).pop(false),
    ),
  );
}
